-- P07 - Timesheet summaries, monthly reconciliation and immutable close/reopen snapshots.
-- Raw attendance remains append-only; closing a period snapshots calculated rows instead of mutating sources.

create table public.attendance_day_summaries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  work_date date not null,
  scheduled_seconds bigint not null check (scheduled_seconds >= 0),
  worked_office_seconds bigint not null default 0 check (worked_office_seconds >= 0),
  worked_remote_seconds bigint not null default 0 check (worked_remote_seconds >= 0),
  paid_leave_seconds bigint not null default 0 check (paid_leave_seconds >= 0),
  unpaid_leave_seconds bigint not null default 0 check (unpaid_leave_seconds >= 0),
  unexplained_seconds bigint not null default 0 check (unexplained_seconds >= 0),
  unknown_seconds bigint not null default 0 check (unknown_seconds >= 0),
  late_seconds bigint not null default 0 check (late_seconds >= 0),
  early_seconds bigint not null default 0 check (early_seconds >= 0),
  outside_schedule_seconds bigint not null default 0 check (outside_schedule_seconds >= 0),
  standard_day_minutes integer not null check (standard_day_minutes between 1 and 1440),
  state text not null check (state in ('provisional', 'needs_review', 'verified')),
  exceptions jsonb not null default '[]'::jsonb check (jsonb_typeof(exceptions) = 'array'),
  calculation_version integer not null check (calculation_version > 0),
  source_revision_hash text not null check (char_length(source_revision_hash) = 64),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, member_id, work_date),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.timesheet_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  month_start date not null,
  status text not null default 'open' check (status in ('open', 'reconciling', 'closed', 'reopened')),
  revision integer not null default 1 check (revision > 0),
  closed_at timestamptz,
  closed_by uuid,
  reopen_reason text,
  policy_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(policy_snapshot) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, month_start),
  foreign key (organization_id, closed_by)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (month_start = date_trunc('month', month_start)::date),
  check ((status = 'closed' and closed_at is not null and closed_by is not null) or status <> 'closed')
);

create table public.timesheet_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  period_id uuid not null,
  revision integer not null check (revision > 0),
  member_id uuid not null,
  daily_rows jsonb not null check (jsonb_typeof(daily_rows) = 'object'),
  totals jsonb not null check (jsonb_typeof(totals) = 'object'),
  source_hash text not null check (char_length(source_hash) = 64),
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, period_id, revision, member_id),
  foreign key (organization_id, period_id)
    references public.timesheet_periods(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.timesheet_period_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  period_id uuid not null,
  event_type text not null check (event_type in ('reconciliation_started', 'closed', 'reopened')),
  actor_member_id uuid not null,
  reason text not null check (char_length(trim(reason)) between 3 and 1000),
  recorded_at timestamptz not null default timezone('utc', now()),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  unique (organization_id, id),
  unique (organization_id, idempotency_key),
  foreign key (organization_id, period_id)
    references public.timesheet_periods(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create index attendance_day_summaries_member_day_idx
  on public.attendance_day_summaries(organization_id, member_id, work_date);
create index timesheet_snapshots_period_idx
  on public.timesheet_snapshots(organization_id, period_id, revision, member_id);
create index timesheet_period_events_period_idx
  on public.timesheet_period_events(organization_id, period_id, recorded_at desc);

create trigger attendance_day_summaries_set_updated_at
before update on public.attendance_day_summaries
for each row execute function private.set_updated_at();

create trigger timesheet_periods_set_updated_at
before update on public.timesheet_periods
for each row execute function private.set_updated_at();

create trigger timesheet_snapshots_immutable
before update or delete on public.timesheet_snapshots
for each row execute function private.prevent_immutable_mutation();

create trigger timesheet_period_events_immutable
before update or delete on public.timesheet_period_events
for each row execute function private.prevent_immutable_mutation();

create or replace function private.prevent_closed_timesheet_day_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid := coalesce(new.organization_id, old.organization_id);
  v_work_date date := coalesce(new.work_date, old.work_date);
begin
  if exists (
    select 1
    from public.timesheet_periods p
    where p.organization_id = v_org
      and p.month_start = date_trunc('month', v_work_date)::date
      and p.status = 'closed'
  ) then
    raise exception using errcode = '55000', message = 'PERIOD_CLOSED';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger attendance_day_summaries_closed_guard
before insert or update or delete on public.attendance_day_summaries
for each row execute function private.prevent_closed_timesheet_day_mutation();

create or replace function private.assert_timesheet_hr(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := private.current_member_id(p_organization_id);
  if v_actor_id is null or not private.has_capability(p_organization_id, 'can_manage_attendance') then
    raise exception using errcode = '42501', message = 'TIMESHEET_HR_PERMISSION_REQUIRED';
  end if;
  return v_actor_id;
end;
$$;

create or replace function private.assert_timesheet_admin(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
begin
  select m.id into v_actor_id
  from public.organization_members m
  where m.organization_id = p_organization_id
    and m.id = private.current_member_id(p_organization_id)
    and m.status = 'active'
    and m.role = 'admin';
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'TIMESHEET_ADMIN_PERMISSION_REQUIRED';
  end if;
  return v_actor_id;
end;
$$;

create or replace function private.timesheet_live_member_json(
  p_organization_id uuid,
  p_member_id uuid,
  p_month_start date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rows jsonb;
  v_totals jsonb;
  v_timezone text;
begin
  select o.timezone into v_timezone
  from public.organizations o
  where o.id = p_organization_id;
  if v_timezone is null then
    raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'work_date', s.work_date,
        'shift_label', case when si.id is null then '—'
          else to_char(si.starts_at at time zone v_timezone, 'HH24:MI') || '–' ||
               to_char(si.ends_at at time zone v_timezone, 'HH24:MI') end,
        'allowed_mode', coalesce(si.allowed_mode, 'office'),
        'first_check_in_at', session_bounds.first_check_in_at,
        'last_check_out_at', session_bounds.last_check_out_at,
        'state', case when s.state = 'verified' then 'ready' else s.state end,
        'scheduled_seconds', s.scheduled_seconds,
        'worked_seconds', s.worked_office_seconds + s.worked_remote_seconds,
        'worked_office_seconds', s.worked_office_seconds,
        'worked_remote_seconds', s.worked_remote_seconds,
        'paid_leave_seconds', s.paid_leave_seconds,
        'unpaid_leave_seconds', s.unpaid_leave_seconds,
        'unknown_seconds', s.unknown_seconds,
        'unexplained_seconds', s.unexplained_seconds,
        'outside_schedule_seconds', s.outside_schedule_seconds,
        'conflict_seconds', 0,
        'scheduled_units', s.scheduled_seconds::numeric / (s.standard_day_minutes * 60),
        'worked_units', (s.worked_office_seconds + s.worked_remote_seconds)::numeric / (s.standard_day_minutes * 60),
        'paid_leave_units', s.paid_leave_seconds::numeric / (s.standard_day_minutes * 60),
        'unpaid_leave_units', s.unpaid_leave_seconds::numeric / (s.standard_day_minutes * 60),
        'schedule_snapshot_ref', coalesce(si.id::text, 'summary:' || s.id::text),
        'policy_snapshot_version', coalesce(si.version, 1),
        'exceptions', s.exceptions
      ) order by s.work_date
    ),
    '[]'::jsonb
  ) into v_rows
  from public.attendance_day_summaries s
  left join public.shift_instances si
    on si.organization_id = s.organization_id
   and si.member_id = s.member_id
   and si.work_date = s.work_date
  left join lateral (
    select min(a.starts_at) as first_check_in_at, max(a.ends_at) as last_check_out_at
    from public.attendance_sessions a
    where a.organization_id = s.organization_id
      and a.member_id = s.member_id
      and a.shift_instance_id = si.id
      and a.status <> 'superseded'
  ) session_bounds on true
  where s.organization_id = p_organization_id
    and s.member_id = p_member_id
    and s.work_date >= p_month_start
    and s.work_date < (p_month_start + interval '1 month')::date;

  select jsonb_build_object(
    'scheduled_seconds', coalesce(sum(s.scheduled_seconds), 0),
    'worked_seconds', coalesce(sum(s.worked_office_seconds + s.worked_remote_seconds), 0),
    'worked_office_seconds', coalesce(sum(s.worked_office_seconds), 0),
    'worked_remote_seconds', coalesce(sum(s.worked_remote_seconds), 0),
    'paid_leave_seconds', coalesce(sum(s.paid_leave_seconds), 0),
    'unpaid_leave_seconds', coalesce(sum(s.unpaid_leave_seconds), 0),
    'unknown_seconds', coalesce(sum(s.unknown_seconds), 0),
    'unexplained_seconds', coalesce(sum(s.unexplained_seconds), 0),
    'outside_schedule_seconds', coalesce(sum(s.outside_schedule_seconds), 0),
    'scheduled_units', coalesce(sum(s.scheduled_seconds::numeric / (s.standard_day_minutes * 60)), 0),
    'worked_units', coalesce(sum((s.worked_office_seconds + s.worked_remote_seconds)::numeric / (s.standard_day_minutes * 60)), 0),
    'paid_leave_units', coalesce(sum(s.paid_leave_seconds::numeric / (s.standard_day_minutes * 60)), 0),
    'unpaid_leave_units', coalesce(sum(s.unpaid_leave_seconds::numeric / (s.standard_day_minutes * 60)), 0),
    'scheduled_days', count(*) filter (where s.scheduled_seconds > 0),
    'requires_reconciliation_days', count(*) filter (where s.state <> 'verified')
  ) into v_totals
  from public.attendance_day_summaries s
  where s.organization_id = p_organization_id
    and s.member_id = p_member_id
    and s.work_date >= p_month_start
    and s.work_date < (p_month_start + interval '1 month')::date;

  return jsonb_build_object('rows', v_rows, 'totals', v_totals);
end;
$$;

create or replace function public.rpc_internal_upsert_attendance_day_summary(
  p_organization_id uuid,
  p_member_id uuid,
  p_work_date date,
  p_summary jsonb,
  p_source_revision_hash text
)
returns public.attendance_day_summaries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.attendance_day_summaries%rowtype;
begin
  if p_summary is null or jsonb_typeof(p_summary) <> 'object' then
    raise exception using errcode = '22023', message = 'TIMESHEET_SUMMARY_INVALID';
  end if;
  if p_source_revision_hash is null or char_length(p_source_revision_hash) <> 64 then
    raise exception using errcode = '22023', message = 'SOURCE_REVISION_HASH_INVALID';
  end if;
  if exists (
    select 1 from public.timesheet_periods p
    where p.organization_id = p_organization_id
      and p.month_start = date_trunc('month', p_work_date)::date
      and p.status = 'closed'
  ) then
    raise exception using errcode = '55000', message = 'PERIOD_CLOSED';
  end if;

  insert into public.attendance_day_summaries (
    organization_id, member_id, work_date, scheduled_seconds, worked_office_seconds,
    worked_remote_seconds, paid_leave_seconds, unpaid_leave_seconds, unexplained_seconds,
    unknown_seconds, late_seconds, early_seconds, outside_schedule_seconds, standard_day_minutes,
    state, exceptions, calculation_version, source_revision_hash
  ) values (
    p_organization_id, p_member_id, p_work_date,
    (p_summary->>'scheduled_seconds')::bigint,
    coalesce((p_summary->>'worked_office_seconds')::bigint, 0),
    coalesce((p_summary->>'worked_remote_seconds')::bigint, 0),
    coalesce((p_summary->>'paid_leave_seconds')::bigint, 0),
    coalesce((p_summary->>'unpaid_leave_seconds')::bigint, 0),
    coalesce((p_summary->>'unexplained_seconds')::bigint, 0),
    coalesce((p_summary->>'unknown_seconds')::bigint, 0),
    coalesce((p_summary->>'late_seconds')::bigint, 0),
    coalesce((p_summary->>'early_seconds')::bigint, 0),
    coalesce((p_summary->>'outside_schedule_seconds')::bigint, 0),
    (p_summary->>'standard_day_minutes')::integer,
    case when p_summary->>'state' = 'ready' then 'verified' else p_summary->>'state' end,
    coalesce(p_summary->'exceptions', '[]'::jsonb),
    coalesce((p_summary->>'calculation_version')::integer, 1),
    lower(p_source_revision_hash)
  )
  on conflict (organization_id, member_id, work_date) do update
  set scheduled_seconds = excluded.scheduled_seconds,
      worked_office_seconds = excluded.worked_office_seconds,
      worked_remote_seconds = excluded.worked_remote_seconds,
      paid_leave_seconds = excluded.paid_leave_seconds,
      unpaid_leave_seconds = excluded.unpaid_leave_seconds,
      unexplained_seconds = excluded.unexplained_seconds,
      unknown_seconds = excluded.unknown_seconds,
      late_seconds = excluded.late_seconds,
      early_seconds = excluded.early_seconds,
      outside_schedule_seconds = excluded.outside_schedule_seconds,
      standard_day_minutes = excluded.standard_day_minutes,
      state = excluded.state,
      exceptions = excluded.exceptions,
      calculation_version = excluded.calculation_version,
      source_revision_hash = excluded.source_revision_hash,
      version = public.attendance_day_summaries.version + 1
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.rpc_get_timesheet(
  p_organization_id uuid,
  p_month_start date,
  p_member_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_member_id uuid;
  v_member public.organization_members%rowtype;
  v_period public.timesheet_periods%rowtype;
  v_snapshot public.timesheet_snapshots%rowtype;
  v_live jsonb;
begin
  if p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception using errcode = '22023', message = 'MONTH_START_REQUIRED';
  end if;
  v_actor_id := private.current_member_id(p_organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  v_member_id := coalesce(p_member_id, v_actor_id);
  if v_member_id <> v_actor_id and not private.has_capability(p_organization_id, 'can_manage_attendance') then
    raise exception using errcode = '42501', message = 'TIMESHEET_SCOPE_DENIED';
  end if;
  select * into v_member from public.organization_members m
  where m.organization_id = p_organization_id and m.id = v_member_id;
  if not found then raise exception using errcode = 'P0002', message = 'MEMBER_NOT_FOUND'; end if;

  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.month_start = p_month_start;

  if v_period.id is not null and v_period.status = 'closed' then
    select * into v_snapshot from public.timesheet_snapshots s
    where s.organization_id = p_organization_id
      and s.period_id = v_period.id
      and s.revision = v_period.revision
      and s.member_id = v_member_id;
    return jsonb_build_object(
      'organization_id', p_organization_id,
      'member_id', v_member_id,
      'member_name', v_member.display_name,
      'employee_code', v_member.employee_code,
      'month_start', p_month_start,
      'period_id', v_period.id,
      'period_status', 'closed',
      'period_version', v_period.version,
      'revision', v_period.revision,
      'source', 'snapshot',
      'rows', coalesce(v_snapshot.daily_rows->'rows', '[]'::jsonb),
      'totals', coalesce(
        v_snapshot.totals,
        jsonb_build_object(
          'scheduled_seconds', 0,
          'worked_seconds', 0,
          'worked_office_seconds', 0,
          'worked_remote_seconds', 0,
          'paid_leave_seconds', 0,
          'unpaid_leave_seconds', 0,
          'unknown_seconds', 0,
          'unexplained_seconds', 0,
          'outside_schedule_seconds', 0,
          'scheduled_units', 0,
          'worked_units', 0,
          'paid_leave_units', 0,
          'unpaid_leave_units', 0,
          'scheduled_days', 0,
          'requires_reconciliation_days', 0
        )
      )
    );
  end if;

  v_live := private.timesheet_live_member_json(p_organization_id, v_member_id, p_month_start);
  return jsonb_build_object(
    'organization_id', p_organization_id,
    'member_id', v_member_id,
    'member_name', v_member.display_name,
    'employee_code', v_member.employee_code,
    'month_start', p_month_start,
    'period_id', v_period.id,
    'period_status', coalesce(v_period.status, 'open'),
    'period_version', coalesce(v_period.version, 1),
    'revision', coalesce(v_period.revision, 1),
    'source', 'live',
    'rows', v_live->'rows',
    'totals', v_live->'totals'
  );
end;
$$;

create or replace function public.rpc_begin_timesheet_reconciliation(
  p_organization_id uuid,
  p_month_start date,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_period public.timesheet_periods%rowtype;
  v_existing_type text;
begin
  if p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception using errcode = '22023', message = 'MONTH_START_REQUIRED';
  end if;
  v_actor_id := private.assert_timesheet_hr(p_organization_id);
  select e.event_type into v_existing_type from public.timesheet_period_events e
  where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_type <> 'reconciliation_started' then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    select p.* into v_period from public.timesheet_periods p join public.timesheet_period_events e on e.period_id = p.id
    where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
    return to_jsonb(v_period);
  end if;

  insert into public.timesheet_periods (organization_id, month_start, policy_snapshot)
  values (p_organization_id, p_month_start, jsonb_build_object('calculation_version', 1, 'schema_version', 1))
  on conflict (organization_id, month_start) do nothing;
  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.month_start = p_month_start for update;
  if v_period.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;
  if v_period.status = 'closed' then
    raise exception using errcode = '55000', message = 'PERIOD_CLOSED';
  end if;

  update public.timesheet_periods
  set status = 'reconciling', version = version + 1
  where organization_id = p_organization_id and id = v_period.id
  returning * into v_period;
  insert into public.timesheet_period_events (
    organization_id, period_id, event_type, actor_member_id, reason, payload, idempotency_key
  ) values (
    p_organization_id, v_period.id, 'reconciliation_started', v_actor_id,
    'Bắt đầu đối soát công tháng', jsonb_build_object('revision', v_period.revision), p_idempotency_key
  );
  return to_jsonb(v_period);
end;
$$;

create or replace function public.rpc_close_timesheet(
  p_organization_id uuid,
  p_month_start date,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_period public.timesheet_periods%rowtype;
  v_existing_type text;
  v_blocking_count integer;
  v_member_id uuid;
  v_live jsonb;
  v_daily_rows jsonb;
  v_totals jsonb;
  v_source_hash text;
  v_now timestamptz := clock_timestamp();
begin
  if p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception using errcode = '22023', message = 'MONTH_START_REQUIRED';
  end if;
  v_actor_id := private.assert_timesheet_admin(p_organization_id);
  select e.event_type into v_existing_type from public.timesheet_period_events e
  where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_type <> 'closed' then raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    select p.* into v_period from public.timesheet_periods p join public.timesheet_period_events e on e.period_id = p.id
    where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
    return to_jsonb(v_period);
  end if;
  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.month_start = p_month_start for update;
  if not found then raise exception using errcode = 'P0002', message = 'TIMESHEET_PERIOD_NOT_FOUND'; end if;
  if v_period.version <> p_expected_version then raise exception using errcode = '40001', message = 'VERSION_CONFLICT'; end if;
  if v_period.status not in ('reconciling', 'reopened') then
    raise exception using errcode = '55000', message = 'TIMESHEET_NOT_RECONCILING';
  end if;

  select count(*) into v_blocking_count
  from public.shift_instances si
  left join public.attendance_day_summaries s
    on s.organization_id = si.organization_id and s.member_id = si.member_id and s.work_date = si.work_date
  where si.organization_id = p_organization_id
    and si.work_date >= p_month_start
    and si.work_date < (p_month_start + interval '1 month')::date
    and si.status <> 'canceled'
    and (s.id is null or s.state <> 'verified');
  if v_blocking_count > 0 then
    raise exception using errcode = '55000', message = 'TIMESHEET_BLOCKING_EXCEPTIONS';
  end if;

  for v_member_id in
    select distinct q.member_id from (
      select si.member_id from public.shift_instances si
      where si.organization_id = p_organization_id
        and si.work_date >= p_month_start and si.work_date < (p_month_start + interval '1 month')::date
        and si.status <> 'canceled'
      union
      select s.member_id from public.attendance_day_summaries s
      where s.organization_id = p_organization_id
        and s.work_date >= p_month_start and s.work_date < (p_month_start + interval '1 month')::date
    ) q
  loop
    v_live := private.timesheet_live_member_json(p_organization_id, v_member_id, p_month_start);
    v_daily_rows := jsonb_build_object('schema_version', 1, 'rows', v_live->'rows');
    v_totals := v_live->'totals';
    v_source_hash := pg_catalog.encode(
      extensions.digest(convert_to(v_daily_rows::text || v_totals::text || v_period.policy_snapshot::text, 'UTF8'), 'sha256'),
      'hex'
    );
    insert into public.timesheet_snapshots (
      organization_id, period_id, revision, member_id, daily_rows, totals, source_hash
    ) values (
      p_organization_id, v_period.id, v_period.revision, v_member_id, v_daily_rows, v_totals, v_source_hash
    );
  end loop;

  update public.timesheet_periods
  set status = 'closed', closed_at = v_now, closed_by = v_actor_id, reopen_reason = null, version = version + 1
  where organization_id = p_organization_id and id = v_period.id
  returning * into v_period;
  insert into public.timesheet_period_events (
    organization_id, period_id, event_type, actor_member_id, reason, payload, idempotency_key, recorded_at
  ) values (
    p_organization_id, v_period.id, 'closed', v_actor_id, 'Chốt bảng công tháng',
    jsonb_build_object('revision', v_period.revision, 'closed_at', v_now), p_idempotency_key, v_now
  );
  return to_jsonb(v_period);
end;
$$;

create or replace function public.rpc_reopen_timesheet(
  p_organization_id uuid,
  p_period_id uuid,
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
  v_actor_id uuid;
  v_period public.timesheet_periods%rowtype;
  v_existing_type text;
begin
  if p_reason is null or char_length(trim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'TIMESHEET_REOPEN_REASON_REQUIRED';
  end if;
  v_actor_id := private.assert_timesheet_admin(p_organization_id);
  select e.event_type into v_existing_type from public.timesheet_period_events e
  where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_type <> 'reopened' then raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    select p.* into v_period from public.timesheet_periods p join public.timesheet_period_events e on e.period_id = p.id
    where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
    return to_jsonb(v_period);
  end if;
  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.id = p_period_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'TIMESHEET_PERIOD_NOT_FOUND'; end if;
  if v_period.version <> p_expected_version then raise exception using errcode = '40001', message = 'VERSION_CONFLICT'; end if;
  if v_period.status <> 'closed' then raise exception using errcode = '55000', message = 'TIMESHEET_NOT_CLOSED'; end if;

  update public.timesheet_periods
  set status = 'reopened', revision = revision + 1, closed_at = null, closed_by = null,
      reopen_reason = trim(p_reason), version = version + 1
  where organization_id = p_organization_id and id = p_period_id
  returning * into v_period;
  insert into public.timesheet_period_events (
    organization_id, period_id, event_type, actor_member_id, reason, payload, idempotency_key
  ) values (
    p_organization_id, v_period.id, 'reopened', v_actor_id, trim(p_reason),
    jsonb_build_object('new_revision', v_period.revision), p_idempotency_key
  );
  return to_jsonb(v_period);
end;
$$;

alter table public.attendance_day_summaries enable row level security;
alter table public.timesheet_periods enable row level security;
alter table public.timesheet_snapshots enable row level security;
alter table public.timesheet_period_events enable row level security;

create policy attendance_day_summaries_read_own_or_hr on public.attendance_day_summaries
for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));

create policy timesheet_periods_read_active_member on public.timesheet_periods
for select to authenticated
using (private.current_member_id(organization_id) is not null);

create policy timesheet_snapshots_read_own_or_hr on public.timesheet_snapshots
for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));

create policy timesheet_period_events_read_hr on public.timesheet_period_events
for select to authenticated
using (private.has_capability(organization_id, 'can_manage_attendance'));

grant select on public.attendance_day_summaries, public.timesheet_periods, public.timesheet_snapshots, public.timesheet_period_events to authenticated;
revoke insert, update, delete, truncate, references, trigger
on public.attendance_day_summaries, public.timesheet_periods, public.timesheet_snapshots, public.timesheet_period_events
from authenticated;

revoke all on function private.prevent_closed_timesheet_day_mutation() from public, anon, authenticated;
revoke all on function private.assert_timesheet_hr(uuid) from public, anon, authenticated;
revoke all on function private.assert_timesheet_admin(uuid) from public, anon, authenticated;
revoke all on function private.timesheet_live_member_json(uuid, uuid, date) from public, anon, authenticated;
revoke all on function public.rpc_internal_upsert_attendance_day_summary(uuid, uuid, date, jsonb, text) from public, anon, authenticated;
grant execute on function public.rpc_internal_upsert_attendance_day_summary(uuid, uuid, date, jsonb, text) to service_role;

revoke all on function public.rpc_get_timesheet(uuid, date, uuid) from public, anon;
revoke all on function public.rpc_begin_timesheet_reconciliation(uuid, date, integer, text) from public, anon;
revoke all on function public.rpc_close_timesheet(uuid, date, integer, text) from public, anon;
revoke all on function public.rpc_reopen_timesheet(uuid, uuid, text, integer, text) from public, anon;
grant execute on function public.rpc_get_timesheet(uuid, date, uuid) to authenticated;
grant execute on function public.rpc_begin_timesheet_reconciliation(uuid, date, integer, text) to authenticated;
grant execute on function public.rpc_close_timesheet(uuid, date, integer, text) to authenticated;
grant execute on function public.rpc_reopen_timesheet(uuid, uuid, text, integer, text) to authenticated;
