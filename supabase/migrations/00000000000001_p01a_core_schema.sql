-- P01A: multi-tenant organization, membership and auth foundation.
-- Business feature tables are intentionally deferred to later phases.

create schema if not exists extensions;
create schema if not exists private;
create extension if not exists pgcrypto with schema extensions;

revoke all on schema private from public;
revoke all on schema private from anon;
grant usage on schema private to authenticated;
grant usage on schema private to service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;
alter default privileges for role postgres in schema private
  revoke execute on functions from public;

create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  slug text not null check (
    slug = lower(slug)
    and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    and char_length(slug) between 2 and 80
  ),
  timezone text not null default 'Asia/Ho_Chi_Minh',
  owner_member_id uuid,
  status text not null default 'active' check (status in ('active', 'suspended')),
  settings_version integer not null default 1 check (settings_version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (slug)
);

create table public.organization_members (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  employee_code text not null check (
    employee_code = upper(trim(employee_code))
    and char_length(employee_code) between 2 and 32
  ),
  display_name text not null check (char_length(trim(display_name)) between 1 and 160),
  role text not null default 'employee' check (role in ('admin', 'manager', 'employee')),
  status text not null default 'invited' check (status in ('invited', 'active', 'inactive')),
  can_manage_attendance boolean not null default false,
  can_approve_requests boolean not null default false,
  can_view_attendance_evidence boolean not null default false,
  scope_version integer not null default 1 check (scope_version > 0),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, user_id),
  unique (organization_id, employee_code)
);

alter table public.organizations
  add constraint organizations_owner_member_fk
  foreign key (id, owner_member_id)
  references public.organization_members(organization_id, id)
  on delete restrict;

create table public.member_hr_settings (
  member_id uuid primary key references public.organization_members(id) on delete restrict,
  organization_id uuid not null,
  employment_start date not null,
  employment_end date,
  standard_day_minutes integer not null default 480 check (standard_day_minutes between 1 and 1440),
  default_work_mode text not null default 'office' check (default_work_mode in ('office', 'remote', 'hybrid')),
  policy_version_id uuid,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (employment_end is null or employment_end >= employment_start),
  unique (organization_id, member_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.specialties (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null check (code = upper(trim(code)) and char_length(code) between 2 and 40),
  name text not null check (char_length(trim(name)) between 1 and 120),
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, code)
);

create table public.member_specialties (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  specialty_id uuid not null,
  primary key (organization_id, member_id, specialty_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, specialty_id)
    references public.specialties(organization_id, id)
    on delete restrict
);

create table public.invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  email text not null check (
    email = lower(trim(email))
    and char_length(email) between 3 and 320
    and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  invited_role text not null check (invited_role in ('admin', 'manager', 'employee')),
  invited_by uuid not null,
  auth_invite_reference text,
  token_hash text,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  capabilities jsonb not null default '{}'::jsonb check (jsonb_typeof(capabilities) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  foreign key (organization_id, invited_by)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create unique index invitations_one_open_per_email_idx
  on public.invitations(organization_id, email)
  where accepted_at is null and revoked_at is null;

create table public.policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  policy_kind text not null check (policy_kind in ('attendance', 'reminders', 'retention', 'report')),
  version_number integer not null check (version_number > 0),
  effective_from timestamptz not null,
  config jsonb not null check (jsonb_typeof(config) = 'object'),
  created_by uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, policy_kind, version_number),
  foreign key (organization_id, created_by)
    references public.organization_members(organization_id, id)
    on delete restrict
);

alter table public.member_hr_settings
  add constraint member_hr_settings_policy_version_fk
  foreign key (organization_id, policy_version_id)
  references public.policy_versions(organization_id, id)
  on delete restrict;

create table public.audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_member_id uuid,
  actor_kind text not null check (actor_kind in ('member', 'system')),
  action text not null check (char_length(trim(action)) between 1 and 120),
  entity_type text not null check (char_length(trim(entity_type)) between 1 and 120),
  entity_id uuid,
  recorded_at timestamptz not null default timezone('utc', now()),
  request_id uuid not null default extensions.gen_random_uuid(),
  safe_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(safe_metadata) = 'object'),
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((actor_kind = 'member' and actor_member_id is not null) or (actor_kind = 'system' and actor_member_id is null))
);

create table private.command_idempotency (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_key text not null check (char_length(trim(actor_key)) between 1 and 160),
  command_name text not null check (char_length(trim(command_name)) between 1 and 120),
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 1 and 200),
  payload_hash text not null check (char_length(payload_hash) between 32 and 256),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (organization_id, actor_key, command_name, idempotency_key)
);

create index organization_members_user_idx
  on public.organization_members(user_id, status);
create index organization_members_active_idx
  on public.organization_members(organization_id, status, role);
create index member_specialties_member_idx
  on public.member_specialties(organization_id, member_id);
create index audit_logs_org_recorded_idx
  on public.audit_logs(organization_id, recorded_at desc, id desc);
create index private_command_idempotency_created_idx
  on private.command_idempotency(created_at desc);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function private.set_updated_at();
create trigger organization_members_set_updated_at
before update on public.organization_members
for each row execute function private.set_updated_at();
create trigger member_hr_settings_set_updated_at
before update on public.member_hr_settings
for each row execute function private.set_updated_at();
create trigger specialties_set_updated_at
before update on public.specialties
for each row execute function private.set_updated_at();
create trigger invitations_set_updated_at
before update on public.invitations
for each row execute function private.set_updated_at();

create or replace function private.prevent_immutable_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '42501',
    message = 'IMMUTABLE_RECORD';
end;
$$;

create or replace function private.assert_organization_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.owner_member_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.organization_members as m
    where m.organization_id = new.id
      and m.id = new.owner_member_id
      and m.role = 'admin'
      and m.status = 'active'
  ) then
    raise exception using
      errcode = '23514',
      message = 'OWNER_MEMBER_MUST_BE_ACTIVE_ADMIN';
  end if;

  return new;
end;
$$;

create or replace function private.assert_membership_owner_eligibility()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.organizations as o
    where o.id = new.organization_id
      and o.owner_member_id = new.id
      and (new.role <> 'admin' or new.status <> 'active')
  ) then
    raise exception using
      errcode = '23514',
      message = 'OWNER_MEMBER_MUST_BE_ACTIVE_ADMIN';
  end if;

  return new;
end;
$$;

create trigger organizations_owner_eligibility
before insert or update of owner_member_id on public.organizations
for each row execute function private.assert_organization_owner();

create trigger organization_members_owner_eligibility
before insert or update of organization_id, role, status on public.organization_members
for each row execute function private.assert_membership_owner_eligibility();

create trigger audit_logs_immutable
before update or delete on public.audit_logs
for each row execute function private.prevent_immutable_mutation();
create trigger policy_versions_immutable
before update or delete on public.policy_versions
for each row execute function private.prevent_immutable_mutation();

create or replace function private.current_member_id(p_organization_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.organization_members as m
  join public.organizations as o
    on o.id = m.organization_id
  where m.organization_id = p_organization_id
    and m.user_id = (select auth.uid())
    and m.status = 'active'
    and o.status = 'active'
  limit 1;
$$;

create or replace function private.is_active_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_member_id(p_organization_id) is not null;
$$;

create or replace function private.is_admin(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    where m.id = private.current_member_id(p_organization_id)
      and m.role = 'admin'
      and m.status = 'active'
  );
$$;

create or replace function private.can_manage_attendance(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    where m.id = private.current_member_id(p_organization_id)
      and (m.role = 'admin' or m.can_manage_attendance)
  );
$$;

create or replace function private.write_audit(
  p_organization_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_safe_metadata jsonb default '{}'::jsonb,
  p_request_id uuid default extensions.gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_id uuid := extensions.gen_random_uuid();
begin
  insert into public.audit_logs (
    id,
    organization_id,
    actor_member_id,
    actor_kind,
    action,
    entity_type,
    entity_id,
    request_id,
    safe_metadata
  )
  values (
    v_id,
    p_organization_id,
    v_member_id,
    case when v_member_id is null then 'system' else 'member' end,
    p_action,
    p_entity_type,
    p_entity_id,
    p_request_id,
    coalesce(p_safe_metadata, '{}'::jsonb)
  );
  return v_id;
end;
$$;

create or replace function public.rpc_get_context(p_organization_id uuid default null)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_organization_id uuid := p_organization_id;
  v_context jsonb;
begin
  if v_organization_id is null then
    select m.organization_id
      into v_organization_id
    from public.organization_members as m
    join public.organizations as o on o.id = m.organization_id
    where m.user_id = (select auth.uid())
      and m.status = 'active'
      and o.status = 'active'
    order by m.created_at, m.id
    limit 1;
  end if;

  if v_organization_id is null or private.current_member_id(v_organization_id) is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select jsonb_build_object(
    'organization_id', o.id,
    'organization_name', o.name,
    'organization_slug', o.slug,
    'timezone', o.timezone,
    'member_id', m.id,
    'user_id', m.user_id,
    'employee_code', m.employee_code,
    'display_name', m.display_name,
    'role', m.role,
    'status', m.status,
    'capabilities', (
      select coalesce(jsonb_agg(granted_capability order by granted_capability), '[]'::jsonb)
      from (
        select 'can_manage_attendance'::text as granted_capability
        where m.role = 'admin' or m.can_manage_attendance
        union all
        select 'can_approve_requests'::text
        where m.role = 'admin' or m.can_approve_requests
        union all
        select 'can_view_attendance_evidence'::text
        where m.role = 'admin' or m.can_view_attendance_evidence
      ) as capabilities_for_member
    ),
    'scope_version', m.scope_version,
    'server_now', timezone('utc', now())
  )
    into v_context
  from public.organizations as o
  join public.organization_members as m
    on m.organization_id = o.id
   and m.id = private.current_member_id(v_organization_id)
  where o.id = v_organization_id
    and o.status = 'active';

  return v_context;
end;
$$;

revoke all on function private.current_member_id(uuid) from public, anon;
revoke all on function private.is_active_member(uuid) from public, anon;
revoke all on function private.is_admin(uuid) from public, anon;
revoke all on function private.can_manage_attendance(uuid) from public, anon;
revoke all on function private.write_audit(uuid, text, text, uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function private.current_member_id(uuid) to authenticated;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.is_admin(uuid) to authenticated;
grant execute on function private.can_manage_attendance(uuid) to authenticated;
grant execute on function private.write_audit(uuid, text, text, uuid, jsonb, uuid) to service_role;
revoke all on function public.rpc_get_context(uuid) from public, anon;
grant execute on function public.rpc_get_context(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.member_hr_settings enable row level security;
alter table public.specialties enable row level security;
alter table public.member_specialties enable row level security;
alter table public.invitations enable row level security;
alter table public.policy_versions enable row level security;
alter table public.audit_logs enable row level security;
alter table private.command_idempotency enable row level security;

create policy organizations_read_active_member
on public.organizations for select to authenticated
using (private.is_active_member(id));

create policy organization_members_read_self_or_admin
on public.organization_members for select to authenticated
using (
  id = private.current_member_id(organization_id)
  or private.is_admin(organization_id)
);

create policy member_hr_settings_read_own_or_hr
on public.member_hr_settings for select to authenticated
using (
  member_id = private.current_member_id(organization_id)
  or private.is_admin(organization_id)
  or private.can_manage_attendance(organization_id)
);

create policy specialties_read_active_member
on public.specialties for select to authenticated
using (private.is_active_member(organization_id));

create policy member_specialties_read_active_member
on public.member_specialties for select to authenticated
using (private.is_active_member(organization_id));

create policy policy_versions_read_admin
on public.policy_versions for select to authenticated
using (private.is_admin(organization_id));

create policy audit_logs_read_admin
on public.audit_logs for select to authenticated
using (private.is_admin(organization_id));

revoke all on public.organizations from anon;
revoke all on public.organization_members from anon;
revoke all on public.member_hr_settings from anon;
revoke all on public.specialties from anon;
revoke all on public.member_specialties from anon;
revoke all on public.invitations from anon;
revoke all on public.policy_versions from anon;
revoke all on public.audit_logs from anon;
revoke all on private.command_idempotency from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.organizations, public.organization_members, public.member_hr_settings,
     public.specialties, public.member_specialties, public.invitations,
     public.policy_versions, public.audit_logs
  from authenticated;

grant select on public.organizations, public.organization_members,
  public.member_hr_settings, public.specialties, public.member_specialties,
  public.policy_versions, public.audit_logs to authenticated;

