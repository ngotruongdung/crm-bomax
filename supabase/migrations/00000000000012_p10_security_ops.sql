-- P10 - file security, privacy, retention, export, audit and backup-readiness boundaries.
-- Storage bytes remain private; clients receive only short-lived signed URLs after server-side ACL checks.

alter table public.files
  add column if not exists legal_hold boolean not null default false,
  add column if not exists verified_at timestamptz,
  add column if not exists verification_code text;

alter table public.files drop constraint if exists files_size_bytes_check;
alter table public.files
  add constraint files_size_bytes_check check (
    size_bytes > 0
    and (
      (purpose = 'attendance' and size_bytes <= 5242880)
      or (purpose = 'request' and size_bytes <= 10485760)
      or (purpose = 'task' and size_bytes <= 20971520)
      or (purpose = 'export' and size_bytes <= 52428800)
    )
  );

alter table public.files drop constraint if exists files_bucket_matches_purpose;
alter table public.files
  add constraint files_bucket_matches_purpose check (
    (purpose = 'attendance' and bucket_id = 'attendance-evidence')
    or (purpose = 'request' and bucket_id = 'request-evidence')
    or (purpose = 'task' and bucket_id = 'task-files')
    or (purpose = 'export' and bucket_id = 'exports')
  );

alter table public.files drop constraint if exists files_object_path_server_generated;
alter table public.files
  add constraint files_object_path_server_generated check (
    object_path ~ ('^' || organization_id::text || '/(task|attendance|request|export)/[0-9a-f-]{36}/[0-9a-f-]{36}\.[a-z0-9]{1,8}$')
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'attendance-evidence', 'attendance-evidence', false, 5242880,
    array['image/jpeg', 'image/webp']::text[]
  ),
  (
    'request-evidence', 'request-evidence', false, 10485760,
    array['image/jpeg', 'image/webp', 'application/pdf']::text[]
  ),
  (
    'task-files', 'task-files', false, 20971520,
    array[
      'image/jpeg', 'image/webp', 'image/png', 'application/pdf',
      'text/plain', 'text/csv',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]::text[]
  ),
  (
    'exports', 'exports', false, 52428800,
    array['text/csv']::text[]
  )
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- No authenticated bucket policy is created for business objects. The Storage service keeps
-- its own admin access while application users cannot query/mutate storage.objects directly.
revoke all on storage.objects from anon, authenticated;

create table public.export_jobs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  requested_by uuid not null,
  export_kind text not null check (export_kind in ('timesheet', 'report', 'tasks', 'audit')),
  format text not null default 'csv' check (format = 'csv'),
  scope_snapshot jsonb not null check (jsonb_typeof(scope_snapshot) = 'object'),
  parameters jsonb not null default '{}'::jsonb check (jsonb_typeof(parameters) = 'object'),
  source_period_id uuid,
  source_revision integer,
  status text not null default 'queued' check (status in ('queued', 'processing', 'ready', 'failed', 'expired')),
  file_id uuid,
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  requested_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  expires_at timestamptz,
  error_code text,
  worker_id uuid,
  processing_started_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, requested_by, idempotency_key),
  foreign key (organization_id, requested_by)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, file_id)
    references public.files(organization_id, id)
    on delete restrict,
  check (source_revision is null or source_revision > 0),
  check ((status = 'ready' and file_id is not null and completed_at is not null and expires_at is not null) or status <> 'ready')
);

create index export_jobs_requester_idx
  on public.export_jobs(organization_id, requested_by, requested_at desc);
create index export_jobs_worker_idx
  on public.export_jobs(status, requested_at)
  where status in ('queued', 'processing');
create index files_retention_idx
  on public.files(retention_until, created_at)
  where state <> 'deleted' and legal_hold = false;

create trigger export_jobs_set_updated_at
before update on public.export_jobs
for each row execute function private.set_updated_at();

create or replace function private.current_export_scope(p_organization_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_role text;
  v_sellers jsonb;
begin
  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = v_member_id
    and m.status = 'active';

  if v_role is null then return null; end if;
  if v_role = 'admin' then return jsonb_build_object('kind', 'organization'); end if;

  if v_role = 'manager' then
    select coalesce(jsonb_agg(sm.seller_id order by sm.seller_id), '[]'::jsonb)
    into v_sellers
    from public.seller_members as sm
    where sm.organization_id = p_organization_id
      and sm.member_id = v_member_id
      and sm.is_manager
      and sm.active_from <= private.organization_local_date(p_organization_id)
      and (sm.active_until is null or sm.active_until >= private.organization_local_date(p_organization_id));
    if jsonb_array_length(v_sellers) > 0 then
      return jsonb_build_object('kind', 'sellers', 'seller_ids', v_sellers);
    end if;
  end if;

  return jsonb_build_object('kind', 'personal', 'member_id', v_member_id);
end;
$$;

create or replace function private.export_scope_still_allowed(
  p_organization_id uuid,
  p_requested_by uuid,
  p_scope jsonb
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_current jsonb;
begin
  if private.current_member_id(p_organization_id) <> p_requested_by then return false; end if;
  v_current := private.current_export_scope(p_organization_id);
  if v_current is null then return false; end if;
  if v_current ->> 'kind' = 'organization' then return true; end if;
  if p_scope ->> 'kind' = 'organization' then return false; end if;
  if p_scope ->> 'kind' = 'personal' then
    return v_current ->> 'kind' = 'personal'
      and p_scope ->> 'member_id' = p_requested_by::text
      and v_current ->> 'member_id' = p_requested_by::text;
  end if;
  if p_scope ->> 'kind' <> 'sellers' or v_current ->> 'kind' <> 'sellers' then return false; end if;
  return not exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_scope -> 'seller_ids', '[]'::jsonb)) as wanted(seller_id)
    where not (coalesce(v_current -> 'seller_ids', '[]'::jsonb) ? wanted.seller_id)
  );
end;
$$;

create or replace function private.file_access_allowed(
  p_organization_id uuid,
  p_file_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_file public.files%rowtype;
  v_actor uuid := private.current_member_id(p_organization_id);
begin
  if v_actor is null then return false; end if;
  select * into v_file
  from public.files
  where organization_id = p_organization_id and id = p_file_id;
  if not found or v_file.state <> 'ready' or v_file.deleted_at is not null then return false; end if;

  if v_file.purpose = 'attendance' then
    return exists (
      select 1
      from public.attendance_evidence ae
      join public.attendance_events e
        on e.organization_id = ae.organization_id and e.id = ae.attendance_event_id
      where ae.organization_id = v_file.organization_id
        and ae.file_id = v_file.id
        and (e.member_id = v_actor or private.has_capability(v_file.organization_id, 'can_view_attendance_evidence'))
    );
  end if;

  if v_file.purpose = 'request' then
    return exists (
      select 1
      from public.upload_intents ui
      where ui.organization_id = v_file.organization_id
        and ui.file_id = v_file.id
        and ui.target_kind = 'request'
        and ui.target_id is not null
        and private.current_actor_can_read_employee_request(v_file.organization_id, ui.target_id)
    );
  end if;

  if v_file.purpose = 'task' then
    return exists (
      select 1
      from public.upload_intents ui
      where ui.organization_id = v_file.organization_id
        and ui.file_id = v_file.id
        and ui.target_kind = 'task'
        and ui.target_id is not null
        and private.current_actor_can_read_task(v_file.organization_id, ui.target_id)
    );
  end if;

  if v_file.purpose = 'export' then
    return exists (
      select 1
      from public.export_jobs ej
      where ej.organization_id = v_file.organization_id
        and ej.file_id = v_file.id
        and ej.requested_by = v_actor
        and ej.status = 'ready'
        and ej.expires_at > timezone('utc', now())
        and private.export_scope_still_allowed(ej.organization_id, ej.requested_by, ej.scope_snapshot)
    );
  end if;

  return false;
end;
$$;

create or replace function public.rpc_authorize_file_download(p_file_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_file public.files%rowtype;
  v_actor uuid;
begin
  select * into v_file from public.files where id = p_file_id;
  if not found then raise exception using errcode = 'P0002', message = 'FILE_NOT_FOUND'; end if;
  v_actor := private.current_member_id(v_file.organization_id);
  if v_actor is null or not private.file_access_allowed(v_file.organization_id, v_file.id) then
    raise exception using errcode = 'P0002', message = 'FILE_NOT_FOUND';
  end if;

  if v_file.purpose in ('attendance', 'request') then
    perform private.write_audit(
      v_file.organization_id,
      'evidence.view_authorized',
      'file',
      v_file.id,
      jsonb_build_object('purpose', v_file.purpose, 'bucket_id', v_file.bucket_id)
    );
  end if;

  return jsonb_build_object(
    'file_id', v_file.id,
    'bucket_id', v_file.bucket_id,
    'object_path', v_file.object_path,
    'original_name', v_file.original_name,
    'mime_type', v_file.mime_type,
    'size_bytes', v_file.size_bytes,
    'purpose', v_file.purpose
  );
end;
$$;

create or replace function public.rpc_create_export_job(
  p_organization_id uuid,
  p_export_kind text,
  p_parameters jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.current_member_id(p_organization_id);
  v_scope jsonb;
  v_job public.export_jobs%rowtype;
  v_retention_days integer;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;
  if p_export_kind not in ('timesheet', 'report', 'tasks', 'audit') then
    raise exception using errcode = '22023', message = 'EXPORT_KIND_INVALID';
  end if;
  if p_export_kind = 'audit' and not private.is_admin(p_organization_id) then
    raise exception using errcode = '42501', message = 'EXPORT_SCOPE_DENIED';
  end if;
  v_scope := private.current_export_scope(p_organization_id);

  select (p.config ->> 'export_retention_days')::integer
  into v_retention_days
  from public.policy_versions p
  where p.organization_id = p_organization_id
    and p.policy_kind = 'retention'
    and p.effective_from <= timezone('utc', now())
  order by p.effective_from desc, p.version_number desc
  limit 1;
  if v_retention_days is null or v_retention_days < 1 or v_retention_days > 365 then
    raise exception using errcode = '22023', message = 'RETENTION_POLICY_REQUIRED';
  end if;

  insert into public.export_jobs (
    organization_id, requested_by, export_kind, scope_snapshot, parameters,
    idempotency_key, expires_at
  ) values (
    p_organization_id, v_actor, p_export_kind, v_scope, coalesce(p_parameters, '{}'::jsonb),
    p_idempotency_key, timezone('utc', now()) + make_interval(days => v_retention_days)
  )
  on conflict (organization_id, requested_by, idempotency_key) do update
    set idempotency_key = excluded.idempotency_key
  returning * into v_job;

  perform private.write_audit(
    p_organization_id,
    'export.requested',
    'export_job',
    v_job.id,
    jsonb_build_object('export_kind', v_job.export_kind, 'scope_kind', v_scope ->> 'kind')
  );

  return jsonb_build_object(
    'id', v_job.id,
    'organization_id', v_job.organization_id,
    'requested_by', v_job.requested_by,
    'export_kind', v_job.export_kind,
    'format', v_job.format,
    'status', v_job.status,
    'scope_snapshot', v_job.scope_snapshot,
    'parameters', v_job.parameters,
    'file_id', v_job.file_id,
    'requested_at', v_job.requested_at,
    'completed_at', v_job.completed_at,
    'expires_at', v_job.expires_at,
    'error_code', v_job.error_code
  );
end;
$$;

create or replace function public.rpc_get_export_job(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_job public.export_jobs%rowtype;
begin
  select * into v_job from public.export_jobs where id = p_job_id;
  if not found
     or private.current_member_id(v_job.organization_id) <> v_job.requested_by
     or not private.export_scope_still_allowed(v_job.organization_id, v_job.requested_by, v_job.scope_snapshot) then
    raise exception using errcode = 'P0002', message = 'EXPORT_NOT_FOUND';
  end if;
  return jsonb_build_object(
    'id', v_job.id,
    'organization_id', v_job.organization_id,
    'requested_by', v_job.requested_by,
    'export_kind', v_job.export_kind,
    'format', v_job.format,
    'status', v_job.status,
    'scope_snapshot', v_job.scope_snapshot,
    'parameters', v_job.parameters,
    'file_id', v_job.file_id,
    'requested_at', v_job.requested_at,
    'completed_at', v_job.completed_at,
    'expires_at', v_job.expires_at,
    'error_code', v_job.error_code
  );
end;
$$;

create or replace function public.rpc_list_audit_logs(
  p_organization_id uuid,
  p_before timestamptz default null,
  p_limit integer default 50,
  p_action text default null,
  p_entity_type text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
  v_next timestamptz;
begin
  if not private.is_admin(p_organization_id) then
    raise exception using errcode = '42501', message = 'AUDIT_READ_DENIED';
  end if;

  with rows as (
    select a.*, m.display_name as actor_display_name
    from public.audit_logs a
    left join public.organization_members m
      on m.organization_id = a.organization_id and m.id = a.actor_member_id
    where a.organization_id = p_organization_id
      and (p_before is null or a.recorded_at < p_before)
      and (p_action is null or a.action = p_action)
      and (p_entity_type is null or a.entity_type = p_entity_type)
    order by a.recorded_at desc, a.id desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', id,
      'organization_id', organization_id,
      'actor_member_id', actor_member_id,
      'actor_kind', actor_kind,
      'actor_display_name', actor_display_name,
      'action', action,
      'entity_type', entity_type,
      'entity_id', entity_id,
      'recorded_at', recorded_at,
      'request_id', request_id,
      'safe_metadata', safe_metadata
    ) order by recorded_at desc, id desc), '[]'::jsonb),
    min(recorded_at)
  into v_items, v_next
  from rows;

  return jsonb_build_object('items', v_items, 'next_before', v_next);
end;
$$;

create or replace function public.rpc_internal_claim_retention_cleanup(
  p_now timestamptz default timezone('utc', now()),
  p_limit integer default 100
)
returns table (
  file_id uuid,
  organization_id uuid,
  bucket_id text,
  object_path text
)
language sql
volatile
security definer
set search_path = ''
as $$
  select f.id, f.organization_id, f.bucket_id, f.object_path
  from public.files f
  where f.state in ('ready', 'quarantined')
    and f.deleted_at is null
    and not f.legal_hold
    and f.retention_until is not null
    and f.retention_until <= p_now
  order by f.retention_until, f.id
  for update skip locked
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

create or replace function public.rpc_internal_claim_export_jobs(
  p_worker_id uuid,
  p_limit integer default 10,
  p_now timestamptz default timezone('utc', now())
)
returns table (
  id uuid,
  organization_id uuid,
  requested_by uuid,
  export_kind text,
  format text,
  scope_snapshot jsonb,
  parameters jsonb,
  expires_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  return query
  with candidates as (
    select ej.id
    from public.export_jobs ej
    where ej.status = 'queued'
      or (
        ej.status = 'processing'
        and ej.processing_started_at < p_now - interval '10 minutes'
      )
    order by ej.requested_at, ej.id
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 10), 50))
  ), claimed as (
    update public.export_jobs ej
    set status = 'processing',
        worker_id = p_worker_id,
        processing_started_at = p_now,
        error_code = null,
        version = version + 1
    from candidates c
    where ej.id = c.id
    returning ej.*
  )
  select
    c.id, c.organization_id, c.requested_by, c.export_kind, c.format,
    c.scope_snapshot, c.parameters, c.expires_at
  from claimed c;
end;
$$;

create or replace function public.rpc_internal_complete_export_job(
  p_job_id uuid,
  p_worker_id uuid,
  p_file_id uuid,
  p_completed_at timestamptz default timezone('utc', now())
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_job public.export_jobs%rowtype;
begin
  select * into v_job
  from public.export_jobs
  where id = p_job_id and status = 'processing' and worker_id = p_worker_id
  for update;
  if not found then raise exception using errcode = '40001', message = 'EXPORT_LEASE_LOST'; end if;
  if not exists (
    select 1 from public.files f
    where f.organization_id = v_job.organization_id
      and f.id = p_file_id
      and f.purpose = 'export'
      and f.state = 'ready'
  ) then
    raise exception using errcode = '22023', message = 'EXPORT_FILE_NOT_READY';
  end if;

  update public.export_jobs
  set status = 'ready',
      file_id = p_file_id,
      completed_at = p_completed_at,
      worker_id = null,
      processing_started_at = null,
      version = version + 1
  where id = p_job_id;

  perform private.write_audit(
    v_job.organization_id,
    'export.ready',
    'export_job',
    v_job.id,
    jsonb_build_object('export_kind', v_job.export_kind)
  );
end;
$$;

create or replace function public.rpc_internal_fail_export_job(
  p_job_id uuid,
  p_worker_id uuid,
  p_error_code text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  update public.export_jobs
  set status = 'failed',
      error_code = left(coalesce(nullif(trim(p_error_code), ''), 'EXPORT_FAILED'), 120),
      worker_id = null,
      processing_started_at = null,
      version = version + 1
  where id = p_job_id
    and status = 'processing'
    and worker_id = p_worker_id;
end;
$$;

create or replace function public.rpc_internal_mark_file_deleted(p_file_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_file public.files%rowtype;
begin
  select * into v_file from public.files where id = p_file_id for update;
  if not found then return; end if;
  if v_file.legal_hold then raise exception using errcode = '42501', message = 'FILE_LEGAL_HOLD'; end if;
  update public.files
  set state = 'deleted', deleted_at = timezone('utc', now())
  where id = p_file_id and state <> 'deleted';
  perform private.write_audit(
    v_file.organization_id,
    'file.retention_deleted',
    'file',
    v_file.id,
    jsonb_build_object('purpose', v_file.purpose, 'bucket_id', v_file.bucket_id)
  );
end;
$$;

alter table public.export_jobs enable row level security;

create policy export_jobs_read_own_current_scope
on public.export_jobs for select to authenticated
using (
  requested_by = private.current_member_id(organization_id)
  and private.export_scope_still_allowed(organization_id, requested_by, scope_snapshot)
);

grant select on public.export_jobs to authenticated;
revoke insert, update, delete, truncate, references, trigger on public.export_jobs from authenticated;
revoke select, insert, update, delete, truncate, references, trigger on public.files, public.upload_intents from authenticated;

revoke all on function private.current_export_scope(uuid) from public, anon, authenticated;
revoke all on function private.export_scope_still_allowed(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function private.file_access_allowed(uuid, uuid) from public, anon, authenticated;
grant execute on function private.current_export_scope(uuid) to service_role;
grant execute on function private.export_scope_still_allowed(uuid, uuid, jsonb) to service_role;
grant execute on function private.file_access_allowed(uuid, uuid) to service_role;
grant execute on function private.export_scope_still_allowed(uuid, uuid, jsonb) to authenticated;

revoke all on function public.rpc_authorize_file_download(uuid) from public, anon;
revoke all on function public.rpc_create_export_job(uuid, text, jsonb, text) from public, anon;
revoke all on function public.rpc_get_export_job(uuid) from public, anon;
revoke all on function public.rpc_list_audit_logs(uuid, timestamptz, integer, text, text) from public, anon;
grant execute on function public.rpc_authorize_file_download(uuid) to authenticated;
grant execute on function public.rpc_create_export_job(uuid, text, jsonb, text) to authenticated;
grant execute on function public.rpc_get_export_job(uuid) to authenticated;
grant execute on function public.rpc_list_audit_logs(uuid, timestamptz, integer, text, text) to authenticated;

revoke all on function public.rpc_internal_claim_retention_cleanup(timestamptz, integer) from public, anon, authenticated;
revoke all on function public.rpc_internal_mark_file_deleted(uuid) from public, anon, authenticated;
revoke all on function public.rpc_internal_claim_export_jobs(uuid, integer, timestamptz) from public, anon, authenticated;
revoke all on function public.rpc_internal_complete_export_job(uuid, uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.rpc_internal_fail_export_job(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.rpc_internal_claim_retention_cleanup(timestamptz, integer) to service_role;
grant execute on function public.rpc_internal_mark_file_deleted(uuid) to service_role;
grant execute on function public.rpc_internal_claim_export_jobs(uuid, integer, timestamptz) to service_role;
grant execute on function public.rpc_internal_complete_export_job(uuid, uuid, uuid, timestamptz) to service_role;
grant execute on function public.rpc_internal_fail_export_job(uuid, uuid, text) to service_role;
