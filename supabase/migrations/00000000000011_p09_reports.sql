-- P09 - 18:00 report snapshots, scoped recipients and idempotent server generation.
-- Facts are reconstructed from task event state at cutoff, never from current task state on retry.

create table public.report_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  report_date date not null,
  cutoff_at timestamptz not null,
  timezone text not null check (char_length(trim(timezone)) between 1 and 120),
  revision integer not null default 1 check (revision > 0),
  status text not null default 'generating' check (status in ('generating', 'ready', 'failed')),
  generated_at timestamptz,
  is_late boolean not null default false,
  source_hash text check (source_hash is null or char_length(source_hash) = 64),
  error_code text,
  revision_reason text,
  created_by_member_id uuid,
  supersedes_run_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, report_date, cutoff_at, revision),
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, supersedes_run_id)
    references public.report_runs(organization_id, id)
    on delete restrict,
  check (revision_reason is null or char_length(trim(revision_reason)) between 3 and 500),
  check ((status = 'ready' and generated_at is not null and source_hash is not null) or status <> 'ready')
);

create table public.report_recipient_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  run_id uuid not null,
  recipient_member_id uuid not null,
  scope jsonb not null check (jsonb_typeof(scope) = 'object'),
  facts jsonb not null check (jsonb_typeof(facts) = 'object'),
  summary_template text not null check (char_length(trim(summary_template)) between 1 and 2000),
  source_hash text not null check (char_length(source_hash) = 64),
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, run_id, recipient_member_id),
  foreign key (organization_id, run_id)
    references public.report_runs(organization_id, id)
    on delete restrict,
  foreign key (organization_id, recipient_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.report_run_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  run_id uuid not null,
  event_type text not null check (event_type in ('ready', 'failed', 'revision_created')),
  actor_member_id uuid,
  reason text,
  safe_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(safe_metadata) = 'object'),
  recorded_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, run_id)
    references public.report_runs(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (reason is null or char_length(trim(reason)) between 3 and 500)
);

create index report_runs_org_date_idx
  on public.report_runs(organization_id, report_date desc, revision desc);
create index report_snapshots_recipient_idx
  on public.report_recipient_snapshots(organization_id, recipient_member_id, created_at desc);
create index report_run_events_run_idx
  on public.report_run_events(organization_id, run_id, recorded_at desc);

create trigger report_runs_set_updated_at
before update on public.report_runs
for each row execute function private.set_updated_at();

create trigger report_recipient_snapshots_immutable
before update or delete on public.report_recipient_snapshots
for each row execute function private.prevent_immutable_mutation();

create trigger report_run_events_immutable
before update or delete on public.report_run_events
for each row execute function private.prevent_immutable_mutation();

-- Future task events include a display-safe title in their report state. Historical events remain untouched;
-- missing historical fields are surfaced as a report warning instead of being invented from current state.
create or replace function private.task_report_state(p_task public.tasks)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'task_id', p_task.id,
    'task_number', p_task.task_number,
    'batch_id', p_task.batch_id,
    'seller_id', p_task.seller_id,
    'title', p_task.title,
    'status', p_task.status,
    'priority', p_task.priority,
    'assignee_member_id', p_task.assignee_member_id,
    'reviewer_member_id', p_task.reviewer_member_id,
    'planned_date', p_task.planned_date,
    'original_due_at', p_task.original_due_at,
    'due_at', p_task.due_at,
    'assigned_at', p_task.assigned_at,
    'acknowledged_at', p_task.acknowledged_at,
    'started_at', p_task.started_at,
    'submitted_at', p_task.submitted_at,
    'completed_at', p_task.completed_at,
    'requires_review', p_task.requires_review,
    'requires_result', p_task.requires_result,
    'requires_attachment', p_task.requires_attachment,
    'blocked_at', p_task.blocked_at,
    'blocker_reason', p_task.blocker_reason,
    'blocker_owner_member_id', p_task.blocker_owner_member_id,
    'current_submission_id', p_task.current_submission_id,
    'version', p_task.version
  );
$$;

create or replace function private.report_cutoff_at(
  p_organization_id uuid,
  p_report_date date
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_timezone text;
  v_cutoff_text text := '18:00';
  v_cutoff_time time;
begin
  select o.timezone into v_timezone
  from public.organizations as o
  where o.id = p_organization_id;
  if v_timezone is null then
    raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND';
  end if;

  select coalesce(nullif(trim(p.config ->> 'cutoff_local'), ''), '18:00')
  into v_cutoff_text
  from public.policy_versions as p
  where p.organization_id = p_organization_id
    and p.policy_kind = 'report'
    and p.effective_from <= ((p_report_date + time '23:59:59') at time zone v_timezone)
  order by p.effective_from desc, p.version_number desc
  limit 1;
  v_cutoff_text := coalesce(v_cutoff_text, '18:00');

  begin
    v_cutoff_time := v_cutoff_text::time;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception using errcode = '22023', message = 'REPORT_CUTOFF_INVALID';
  end;

  return (p_report_date + v_cutoff_time) at time zone v_timezone;
end;
$$;

create or replace function private.report_task_states_at_cutoff(
  p_organization_id uuid,
  p_cutoff_at timestamptz
)
returns table (
  task_id uuid,
  task_version integer,
  occurred_at timestamptz,
  state jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct on (e.task_id)
    e.task_id,
    e.task_version,
    e.occurred_at,
    e.report_state_after
  from public.task_events as e
  where e.organization_id = p_organization_id
    and e.occurred_at <= p_cutoff_at
  order by e.task_id, e.occurred_at desc, e.task_version desc;
$$;

create or replace function private.report_scope_for_recipient(
  p_organization_id uuid,
  p_member_id uuid,
  p_report_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_seller_ids jsonb;
begin
  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = p_member_id
    and m.status = 'active';
  if v_role is null then
    return null;
  end if;

  if v_role = 'admin' then
    return jsonb_build_object('kind', 'organization');
  end if;

  if v_role = 'manager' then
    select coalesce(jsonb_agg(sm.seller_id order by sm.seller_id), '[]'::jsonb)
    into v_seller_ids
    from public.seller_members as sm
    where sm.organization_id = p_organization_id
      and sm.member_id = p_member_id
      and sm.is_manager
      and sm.active_from <= p_report_date
      and (sm.active_until is null or sm.active_until >= p_report_date);
    if jsonb_array_length(v_seller_ids) > 0 then
      return jsonb_build_object('kind', 'sellers', 'seller_ids', v_seller_ids);
    end if;
  end if;

  return jsonb_build_object('kind', 'personal', 'member_id', p_member_id);
end;
$$;

create or replace function private.report_scope_still_allowed(
  p_organization_id uuid,
  p_member_id uuid,
  p_scope jsonb
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_kind text := p_scope ->> 'kind';
  v_local_date date;
begin
  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = p_member_id
    and m.status = 'active';
  if v_role is null then return false; end if;
  if v_role = 'admin' then return true; end if;
  if v_kind = 'personal' then return p_scope ->> 'member_id' = p_member_id::text; end if;
  if v_kind <> 'sellers' or v_role <> 'manager' then return false; end if;

  select (clock_timestamp() at time zone o.timezone)::date
  into v_local_date
  from public.organizations as o
  where o.id = p_organization_id;

  return not exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_scope -> 'seller_ids', '[]'::jsonb)) as wanted(seller_id)
    where not exists (
      select 1
      from public.seller_members as sm
      where sm.organization_id = p_organization_id
        and sm.member_id = p_member_id
        and sm.seller_id = wanted.seller_id::uuid
        and sm.is_manager
        and sm.active_from <= v_local_date
        and (sm.active_until is null or sm.active_until >= v_local_date)
    )
  );
end;
$$;

create or replace function private.report_build_facts(
  p_organization_id uuid,
  p_report_date date,
  p_cutoff_at timestamptz,
  p_timezone text,
  p_scope jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_people jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_member record;
  v_due integer;
  v_done integer;
  v_review integer;
  v_open integer;
  v_blocked integer;
  v_due_ids jsonb;
  v_overdue_ids jsonb;
  v_after_ids jsonb;
  v_canceled_ids jsonb;
  v_availability text;
  v_total_due integer := 0;
  v_total_done integer := 0;
  v_total_review integer := 0;
  v_total_open integer := 0;
  v_total_blocked integer := 0;
begin
  if p_scope ->> 'kind' not in ('organization', 'sellers', 'personal') then
    raise exception using errcode = '22023', message = 'REPORT_SCOPE_INVALID';
  end if;

  if exists (
    select 1
    from private.report_task_states_at_cutoff(p_organization_id, p_cutoff_at) as s
    where s.state = '{}'::jsonb
  ) then
    v_warnings := v_warnings || jsonb_build_array('TASK_HISTORY_INCOMPLETE');
  end if;

  for v_member in
    select m.id, m.display_name
    from public.organization_members as m
    where m.organization_id = p_organization_id
      and m.status = 'active'
      and (
        p_scope ->> 'kind' = 'organization'
        or (p_scope ->> 'kind' = 'personal' and p_scope ->> 'member_id' = m.id::text)
        or (
          p_scope ->> 'kind' = 'sellers'
          and (
            exists (
              select 1
              from public.seller_members as sm
              where sm.organization_id = p_organization_id
                and sm.member_id = m.id
                and (p_scope -> 'seller_ids') ? sm.seller_id::text
                and sm.active_from <= p_report_date
                and (sm.active_until is null or sm.active_until >= p_report_date)
            )
            or exists (
              select 1
              from private.report_task_states_at_cutoff(p_organization_id, p_cutoff_at) as sx
              where sx.state ->> 'assignee_member_id' = m.id::text
                and (p_scope -> 'seller_ids') ? coalesce(sx.state ->> 'seller_id', '')
            )
          )
        )
      )
    order by m.display_name, m.id
  loop
    select
      count(*) filter (
        where st not in ('canceled', 'waived')
          and due_local = p_report_date and due_at <= p_cutoff_at
          and st in ('done', 'in_review', 'todo', 'in_progress')
      )::integer,
      count(*) filter (where due_local = p_report_date and due_at <= p_cutoff_at and st = 'done')::integer,
      count(*) filter (where due_local = p_report_date and due_at <= p_cutoff_at and st = 'in_review')::integer,
      count(*) filter (where due_local = p_report_date and due_at <= p_cutoff_at and st in ('todo', 'in_progress'))::integer,
      count(*) filter (
        where due_local = p_report_date and due_at <= p_cutoff_at and st in ('todo', 'in_progress')
          and nullif(state ->> 'blocked_at', '') is not null
      )::integer,
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where st not in ('canceled', 'waived')
          and due_local = p_report_date and due_at <= p_cutoff_at
          and st in ('done', 'in_review', 'todo', 'in_progress')
      ), '[]'::jsonb),
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where due_local < p_report_date and st in ('todo', 'in_progress', 'in_review')
      ), '[]'::jsonb),
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where due_local = p_report_date and due_at > p_cutoff_at and st not in ('canceled', 'waived')
      ), '[]'::jsonb),
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where due_local = p_report_date and st in ('canceled', 'waived')
      ), '[]'::jsonb)
    into v_due, v_done, v_review, v_open, v_blocked, v_due_ids, v_overdue_ids, v_after_ids, v_canceled_ids
    from (
      select
        s.task_id,
        s.state,
        s.state ->> 'status' as st,
        (s.state ->> 'due_at')::timestamptz as due_at,
        ((s.state ->> 'due_at')::timestamptz at time zone p_timezone)::date as due_local
      from private.report_task_states_at_cutoff(p_organization_id, p_cutoff_at) as s
      where s.state ->> 'assignee_member_id' = v_member.id::text
        and nullif(s.state ->> 'due_at', '') is not null
        and (
          p_scope ->> 'kind' <> 'sellers'
          or (p_scope -> 'seller_ids') ? coalesce(s.state ->> 'seller_id', '')
        )
    ) as scoped;

    v_availability := case when exists (
      select 1
      from public.attendance_sessions as a
      where a.organization_id = p_organization_id
        and a.member_id = v_member.id
        and a.starts_at <= p_cutoff_at
        and (a.ends_at is null or a.ends_at > p_cutoff_at)
        and a.status in ('open', 'closed')
    ) then 'working' else 'unknown' end;

    v_people := v_people || jsonb_build_array(jsonb_build_object(
      'member_id', v_member.id,
      'display_name', v_member.display_name,
      'counts', jsonb_build_object(
        'due_count', coalesce(v_due, 0),
        'done_count', coalesce(v_done, 0),
        'review_count', coalesce(v_review, 0),
        'open_count', coalesce(v_open, 0),
        'blocked_count', coalesce(v_blocked, 0)
      ),
      'due_task_ids', coalesce(v_due_ids, '[]'::jsonb),
      'overdue_previous_day_task_ids', coalesce(v_overdue_ids, '[]'::jsonb),
      'due_after_cutoff_task_ids', coalesce(v_after_ids, '[]'::jsonb),
      'canceled_or_waived_task_ids', coalesce(v_canceled_ids, '[]'::jsonb),
      'availability', v_availability
    ));

    v_total_due := v_total_due + coalesce(v_due, 0);
    v_total_done := v_total_done + coalesce(v_done, 0);
    v_total_review := v_total_review + coalesce(v_review, 0);
    v_total_open := v_total_open + coalesce(v_open, 0);
    v_total_blocked := v_total_blocked + coalesce(v_blocked, 0);
  end loop;

  return jsonb_build_object(
    'schema_version', 1,
    'report_date', p_report_date,
    'cutoff_at', p_cutoff_at,
    'timezone', p_timezone,
    'scope', p_scope,
    'totals', jsonb_build_object(
      'due_count', v_total_due,
      'done_count', v_total_done,
      'review_count', v_total_review,
      'open_count', v_total_open,
      'blocked_count', v_total_blocked
    ),
    'people', v_people,
    'sellers', '[]'::jsonb,
    'manager_actions', '[]'::jsonb,
    'warnings', v_warnings
  );
end;
$$;

create or replace function private.generate_report_run(
  p_organization_id uuid,
  p_report_date date,
  p_revision integer,
  p_revision_reason text default null,
  p_created_by_member_id uuid default null,
  p_now timestamptz default clock_timestamp()
)
returns public.report_runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.organizations%rowtype;
  v_cutoff timestamptz;
  v_run public.report_runs%rowtype;
  v_recipient record;
  v_scope jsonb;
  v_facts jsonb;
  v_snapshot public.report_recipient_snapshots%rowtype;
  v_snapshot_hash text;
  v_run_hash text;
  v_summary text;
begin
  if p_revision < 1 then
    raise exception using errcode = '22023', message = 'REPORT_REVISION_INVALID';
  end if;
  if p_revision > 1 and (p_revision_reason is null or char_length(trim(p_revision_reason)) < 3) then
    raise exception using errcode = '22023', message = 'REPORT_REVISION_REASON_REQUIRED';
  end if;

  select * into v_org
  from public.organizations as o
  where o.id = p_organization_id and o.status = 'active';
  if v_org.id is null then
    raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND';
  end if;
  v_cutoff := private.report_cutoff_at(p_organization_id, p_report_date);
  if p_now < v_cutoff then
    raise exception using errcode = '55000', message = 'REPORT_NOT_DUE';
  end if;

  select * into v_run
  from public.report_runs as r
  where r.organization_id = p_organization_id
    and r.report_date = p_report_date
    and r.cutoff_at = v_cutoff
    and r.revision = p_revision
  for update;

  if v_run.id is not null and v_run.status = 'ready' then
    return v_run;
  end if;

  if v_run.id is null then
    insert into public.report_runs (
      organization_id, report_date, cutoff_at, timezone, revision, status, is_late,
      revision_reason, created_by_member_id
    ) values (
      p_organization_id, p_report_date, v_cutoff, v_org.timezone, p_revision, 'generating',
      p_now > v_cutoff + interval '2 minutes', nullif(trim(p_revision_reason), ''), p_created_by_member_id
    ) returning * into v_run;
  else
    update public.report_runs
    set status = 'generating', error_code = null,
        revision_reason = coalesce(revision_reason, nullif(trim(p_revision_reason), '')),
        created_by_member_id = coalesce(created_by_member_id, p_created_by_member_id)
    where id = v_run.id
    returning * into v_run;
  end if;

  for v_recipient in
    select m.id
    from public.organization_members as m
    where m.organization_id = p_organization_id and m.status = 'active'
    order by m.id
  loop
    v_scope := private.report_scope_for_recipient(p_organization_id, v_recipient.id, p_report_date);
    if v_scope is null then continue; end if;
    v_facts := private.report_build_facts(
      p_organization_id, p_report_date, v_cutoff, v_org.timezone, v_scope
    );
    v_snapshot_hash := pg_catalog.encode(
      extensions.digest(convert_to(v_scope::text || v_facts::text, 'UTF8'), 'sha256'),
      'hex'
    );
    v_summary := format(
      'Chốt %s: %s việc đến hạn, %s hoàn thành, %s chờ duyệt, %s còn mở, %s có vướng mắc.',
      to_char(p_report_date, 'DD/MM/YYYY'),
      v_facts #>> '{totals,due_count}',
      v_facts #>> '{totals,done_count}',
      v_facts #>> '{totals,review_count}',
      v_facts #>> '{totals,open_count}',
      v_facts #>> '{totals,blocked_count}'
    );

    insert into public.report_recipient_snapshots (
      organization_id, run_id, recipient_member_id, scope, facts, summary_template, source_hash
    ) values (
      p_organization_id, v_run.id, v_recipient.id, v_scope, v_facts, v_summary, v_snapshot_hash
    ) returning * into v_snapshot;

    insert into private.outbox_events (
      organization_id, event_type, entity_type, entity_id, dedupe_key, payload, status, available_at
    ) values (
      p_organization_id,
      'report.ready',
      'report_run',
      v_run.id,
      'report:' || v_run.id::text || ':' || v_snapshot.id::text || ':' || v_recipient.id::text,
      jsonb_build_object(
        'recipient_member_id', v_recipient.id,
        'run_id', v_run.id,
        'snapshot_id', v_snapshot.id,
        'report_date', p_report_date,
        'revision', p_revision
      ),
      'pending',
      p_now
    ) on conflict (organization_id, dedupe_key) do nothing;
  end loop;

  select pg_catalog.encode(
    extensions.digest(
      convert_to(coalesce(string_agg(s.source_hash, ',' order by s.recipient_member_id), ''), 'UTF8'),
      'sha256'
    ),
    'hex'
  ) into v_run_hash
  from public.report_recipient_snapshots as s
  where s.organization_id = p_organization_id and s.run_id = v_run.id;

  update public.report_runs
  set status = 'ready', generated_at = p_now, source_hash = v_run_hash, error_code = null
  where id = v_run.id
  returning * into v_run;

  insert into public.report_run_events (
    organization_id, run_id, event_type, actor_member_id, reason, safe_metadata, recorded_at
  ) values (
    p_organization_id,
    v_run.id,
    case when p_revision > 1 then 'revision_created' else 'ready' end,
    p_created_by_member_id,
    nullif(trim(p_revision_reason), ''),
    jsonb_build_object('revision', p_revision, 'cutoff_at', v_cutoff, 'is_late', v_run.is_late),
    p_now
  );

  return v_run;
end;
$$;

create or replace function public.rpc_internal_generate_due_reports(
  p_now timestamptz default clock_timestamp(),
  p_limit integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org record;
  v_date date;
  v_cutoff timestamptz;
  v_generated integer := 0;
  v_failed integer := 0;
  v_run_id uuid;
begin
  for v_org in
    select o.id, o.timezone
    from public.organizations as o
    where o.status = 'active'
    order by o.id
    limit greatest(1, least(coalesce(p_limit, 10), 50))
  loop
    v_date := (p_now at time zone v_org.timezone)::date;
    v_cutoff := private.report_cutoff_at(v_org.id, v_date);
    if p_now < v_cutoff then continue; end if;
    if exists (
      select 1 from public.report_runs as r
      where r.organization_id = v_org.id
        and r.report_date = v_date
        and r.cutoff_at = v_cutoff
        and r.revision = 1
        and r.status = 'ready'
    ) then continue; end if;

    begin
      perform private.generate_report_run(v_org.id, v_date, 1, null, null, p_now);
      v_generated := v_generated + 1;
    exception when others then
      insert into public.report_runs (
        organization_id, report_date, cutoff_at, timezone, revision, status, is_late, error_code
      ) values (
        v_org.id, v_date, v_cutoff, v_org.timezone, 1, 'failed',
        p_now > v_cutoff + interval '2 minutes', left(sqlerrm, 120)
      )
      on conflict (organization_id, report_date, cutoff_at, revision)
      do update set status = 'failed', error_code = excluded.error_code
      returning id into v_run_id;

      insert into public.report_run_events (
        organization_id, run_id, event_type, actor_member_id, reason, safe_metadata, recorded_at
      ) values (
        v_org.id, v_run_id, 'failed', null, 'Report generation failed',
        jsonb_build_object('error_code', left(sqlerrm, 120)), p_now
      );
      v_failed := v_failed + 1;
    end;
  end loop;

  return jsonb_build_object('generated', v_generated, 'failed', v_failed, 'evaluated_at', p_now);
end;
$$;

create or replace function public.rpc_list_reports(
  p_organization_id uuid,
  p_limit integer default 31
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_result jsonb;
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select coalesce(jsonb_agg(row_value order by report_date desc, revision desc), '[]'::jsonb)
  into v_result
  from (
    select
      r.report_date,
      r.revision,
      jsonb_build_object(
        'run_id', r.id,
        'snapshot_id', s.id,
        'report_date', r.report_date,
        'cutoff_at', r.cutoff_at,
        'generated_at', r.generated_at,
        'timezone', r.timezone,
        'revision', r.revision,
        'is_late', r.is_late,
        'scope', s.scope,
        'totals', s.facts -> 'totals',
        'people_count', jsonb_array_length(coalesce(s.facts -> 'people', '[]'::jsonb)),
        'warnings', coalesce(s.facts -> 'warnings', '[]'::jsonb)
      ) as row_value
    from public.report_runs as r
    join public.report_recipient_snapshots as s
      on s.organization_id = r.organization_id and s.run_id = r.id
    where r.organization_id = p_organization_id
      and r.status = 'ready'
      and s.recipient_member_id = v_member_id
      and private.report_scope_still_allowed(p_organization_id, v_member_id, s.scope)
    order by r.report_date desc, r.revision desc
    limit greatest(1, least(coalesce(p_limit, 31), 100))
  ) as visible;
  return v_result;
end;
$$;

create or replace function public.rpc_get_report(p_run_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_run public.report_runs%rowtype;
  v_member_id uuid;
  v_snapshot public.report_recipient_snapshots%rowtype;
begin
  select * into v_run from public.report_runs as r where r.id = p_run_id and r.status = 'ready';
  if v_run.id is null then raise exception using errcode = 'P0002', message = 'REPORT_NOT_FOUND'; end if;
  v_member_id := private.current_member_id(v_run.organization_id);
  if v_member_id is null then raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;

  select * into v_snapshot
  from public.report_recipient_snapshots as s
  where s.organization_id = v_run.organization_id
    and s.run_id = v_run.id
    and s.recipient_member_id = v_member_id;
  if v_snapshot.id is null then raise exception using errcode = '42501', message = 'REPORT_ACCESS_DENIED'; end if;
  if not private.report_scope_still_allowed(v_run.organization_id, v_member_id, v_snapshot.scope) then
    raise exception using errcode = '42501', message = 'REPORT_SCOPE_CHANGED';
  end if;

  return jsonb_build_object(
    'run_id', v_run.id,
    'snapshot_id', v_snapshot.id,
    'report_date', v_run.report_date,
    'cutoff_at', v_run.cutoff_at,
    'generated_at', v_run.generated_at,
    'timezone', v_run.timezone,
    'revision', v_run.revision,
    'is_late', v_run.is_late,
    'revision_reason', v_run.revision_reason,
    'scope', v_snapshot.scope,
    'facts', v_snapshot.facts,
    'summary_template', v_snapshot.summary_template,
    'source_hash', v_snapshot.source_hash
  );
end;
$$;

create or replace function public.rpc_create_report_revision(
  p_organization_id uuid,
  p_run_id uuid,
  p_reason text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.organization_members%rowtype;
  v_base public.report_runs%rowtype;
  v_current_revision integer;
  v_payload jsonb;
  v_replay jsonb;
  v_new public.report_runs%rowtype;
  v_result jsonb;
begin
  select * into v_actor
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.user_id = auth.uid()
    and m.status = 'active';
  if v_actor.id is null or v_actor.role <> 'admin' then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;
  if p_reason is null or char_length(trim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'REPORT_REVISION_REASON_REQUIRED';
  end if;

  v_payload := jsonb_build_object(
    'run_id', p_run_id,
    'reason', trim(p_reason),
    'expected_version', p_expected_version
  );
  v_replay := private.task_idempotency_replay(
    p_organization_id, v_actor.id, 'report.create_revision', p_idempotency_key, v_payload
  );
  if v_replay is not null then return v_replay; end if;

  select * into v_base
  from public.report_runs as r
  where r.organization_id = p_organization_id and r.id = p_run_id and r.status = 'ready';
  if v_base.id is null then raise exception using errcode = 'P0002', message = 'REPORT_NOT_FOUND'; end if;

  select max(r.revision) into v_current_revision
  from public.report_runs as r
  where r.organization_id = p_organization_id
    and r.report_date = v_base.report_date
    and r.cutoff_at = v_base.cutoff_at;
  if v_current_revision <> p_expected_version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  v_new := private.generate_report_run(
    p_organization_id,
    v_base.report_date,
    v_current_revision + 1,
    trim(p_reason),
    v_actor.id,
    clock_timestamp()
  );
  update public.report_runs set supersedes_run_id = v_base.id where id = v_new.id;
  select * into v_new from public.report_runs where id = v_new.id;

  perform private.write_audit(
    p_organization_id,
    'report.revision_created',
    'report_run',
    v_new.id,
    jsonb_build_object(
      'previous_run_id', v_base.id,
      'revision', v_new.revision,
      'reason', trim(p_reason)
    )
  );

  v_result := jsonb_build_object(
    'run_id', v_new.id,
    'revision', v_new.revision,
    'report_date', v_new.report_date,
    'status', v_new.status
  );
  perform private.task_idempotency_store(
    p_organization_id, v_actor.id, 'report.create_revision', p_idempotency_key, v_payload, v_result
  );
  return v_result;
end;
$$;

alter table public.report_runs enable row level security;
alter table public.report_recipient_snapshots enable row level security;
alter table public.report_run_events enable row level security;

create policy report_runs_read_active_member
on public.report_runs for select to authenticated
using (private.current_member_id(organization_id) is not null);

create policy report_snapshots_read_recipient_current_scope
on public.report_recipient_snapshots for select to authenticated
using (
  recipient_member_id = private.current_member_id(organization_id)
  and private.report_scope_still_allowed(organization_id, recipient_member_id, scope)
);

create policy report_run_events_read_admin
on public.report_run_events for select to authenticated
using (
  exists (
    select 1 from public.organization_members as m
    where m.organization_id = report_run_events.organization_id
      and m.id = private.current_member_id(report_run_events.organization_id)
      and m.status = 'active'
      and m.role = 'admin'
  )
);

grant select on public.report_runs, public.report_recipient_snapshots, public.report_run_events to authenticated;
revoke insert, update, delete, truncate, references, trigger
on public.report_runs, public.report_recipient_snapshots, public.report_run_events
from authenticated;

revoke all on function private.report_cutoff_at(uuid, date) from public, anon, authenticated;
revoke all on function private.report_task_states_at_cutoff(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.report_scope_for_recipient(uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.report_scope_still_allowed(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function private.report_build_facts(uuid, date, timestamptz, text, jsonb) from public, anon, authenticated;
revoke all on function private.generate_report_run(uuid, date, integer, text, uuid, timestamptz) from public, anon, authenticated;

revoke all on function public.rpc_internal_generate_due_reports(timestamptz, integer) from public, anon, authenticated;
grant execute on function public.rpc_internal_generate_due_reports(timestamptz, integer) to service_role;

revoke all on function public.rpc_list_reports(uuid, integer) from public, anon;
revoke all on function public.rpc_get_report(uuid) from public, anon;
revoke all on function public.rpc_create_report_revision(uuid, uuid, text, integer, text) from public, anon;
grant execute on function public.rpc_list_reports(uuid, integer) to authenticated;
grant execute on function public.rpc_get_report(uuid) to authenticated;
grant execute on function public.rpc_create_report_revision(uuid, uuid, text, integer, text) to authenticated;
