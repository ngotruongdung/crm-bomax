-- P05: work schedules, leave types, employee requests and HR approval boundaries.
--
-- This migration intentionally models time as shift snapshots and approved request segments.
-- Attendance events are deferred to P06; a correction remains a reviewed claim here.

create table public.offices (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 160),
  timezone text not null,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, name)
);

create table public.shift_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  office_id uuid,
  name text not null check (char_length(trim(name)) between 1 and 160),
  start_local time without time zone not null,
  end_local time without time zone not null,
  end_day_offset smallint not null default 0 check (end_day_offset in (0, 1)),
  breaks jsonb not null default '[]'::jsonb check (jsonb_typeof(breaks) = 'array'),
  allowed_mode text not null default 'office' check (allowed_mode in ('office', 'remote', 'hybrid')),
  standard_day_minutes integer not null default 480 check (standard_day_minutes between 1 and 1440),
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, name),
  foreign key (organization_id, office_id)
    references public.offices(organization_id, id)
    on delete restrict,
  check (end_day_offset = 1 or end_local > start_local)
);

create table public.shift_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  shift_template_id uuid not null,
  weekdays smallint[] not null,
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_template_id)
    references public.shift_templates(organization_id, id)
    on delete restrict,
  check (cardinality(weekdays) between 1 and 7),
  check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (effective_until is null or effective_until >= effective_from)
);

create table public.calendar_overrides (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid,
  work_date date not null,
  kind text not null check (kind in ('nonworking', 'custom_shift', 'paid_holiday')),
  shift_template_id uuid,
  paid_credit_policy jsonb check (paid_credit_policy is null or jsonb_typeof(paid_credit_policy) = 'object'),
  reason text not null check (char_length(trim(reason)) between 1 and 500),
  created_by_member_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique nulls not distinct (organization_id, member_id, work_date),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_template_id)
    references public.shift_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((kind = 'custom_shift' and shift_template_id is not null) or kind <> 'custom_shift')
);

create table public.shift_instances (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  template_id uuid,
  work_date date not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  working_segments jsonb not null check (jsonb_typeof(working_segments) = 'array'),
  scheduled_seconds bigint not null check (scheduled_seconds >= 0),
  standard_day_minutes integer not null check (standard_day_minutes between 1 and 1440),
  allowed_mode text not null check (allowed_mode in ('office', 'remote', 'hybrid')),
  office_id uuid,
  policy_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(policy_snapshot) = 'object'),
  status text not null default 'scheduled' check (status in ('scheduled', 'canceled', 'closed')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, member_id, work_date),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, template_id)
    references public.shift_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, office_id)
    references public.offices(organization_id, id)
    on delete restrict,
  check (ends_at > starts_at)
);

alter table public.shift_instances
  add constraint shift_instances_no_active_overlap
  exclude using gist (
    organization_id with =,
    member_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'scheduled');

create table public.leave_types (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null check (code = upper(trim(code)) and char_length(code) between 2 and 40),
  name text not null check (char_length(trim(name)) between 1 and 160),
  pay_treatment text not null check (pay_treatment in ('paid', 'unpaid', 'pending_hr')),
  consumes_balance boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, code)
);

create table public.employee_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  request_type text not null check (request_type in ('leave', 'early_leave', 'late_arrival', 'remote_work', 'attendance_correction', 'cancel_approved_request')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'withdrawn', 'canceled')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  leave_type_id uuid,
  pay_treatment_snapshot text not null default 'not_applicable'
    check (pay_treatment_snapshot in ('paid', 'unpaid', 'pending_hr', 'not_applicable')),
  reason_private text not null check (char_length(trim(reason_private)) between 10 and 2000),
  handover_note text,
  target_request_id uuid,
  correction_payload jsonb check (correction_payload is null or jsonb_typeof(correction_payload) = 'object'),
  submitted_at timestamptz not null default timezone('utc', now()),
  decided_at timestamptz,
  decided_by_member_id uuid,
  decision_reason_private text,
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, member_id, idempotency_key),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, leave_type_id)
    references public.leave_types(organization_id, id)
    on delete restrict,
  foreign key (organization_id, target_request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, decided_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (ends_at > starts_at),
  check ((status = 'pending' and decided_at is null and decided_by_member_id is null) or status <> 'pending'),
  check ((request_type in ('leave', 'early_leave', 'late_arrival') and leave_type_id is not null) or request_type not in ('leave', 'early_leave', 'late_arrival')),
  check ((request_type = 'attendance_correction' and correction_payload is not null) or request_type <> 'attendance_correction')
);

create table public.request_segments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_id uuid not null,
  shift_instance_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  affected_seconds bigint not null check (affected_seconds >= 0),
  pay_treatment_snapshot text not null check (pay_treatment_snapshot in ('paid', 'unpaid', 'pending_hr', 'not_applicable')),
  leave_type_version integer,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, request_id, shift_instance_id),
  foreign key (organization_id, request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_instance_id)
    references public.shift_instances(organization_id, id)
    on delete restrict,
  check (ends_at > starts_at)
);

create table public.request_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_id uuid not null,
  decision text not null check (decision in ('approved', 'rejected', 'withdrawn', 'canceled')),
  actor_member_id uuid not null,
  reason_private text,
  before_state jsonb not null check (jsonb_typeof(before_state) = 'object'),
  after_state jsonb not null check (jsonb_typeof(after_state) = 'object'),
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  recorded_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, request_id, idempotency_key),
  foreign key (organization_id, request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.leave_balance_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  leave_type_id uuid not null,
  delta_seconds bigint not null,
  effective_date date not null,
  source_request_id uuid,
  reason text not null check (char_length(trim(reason)) between 1 and 500),
  created_by_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, source_request_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, leave_type_id)
    references public.leave_types(organization_id, id)
    on delete restrict,
  foreign key (organization_id, source_request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.task_handover_actions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_id uuid not null,
  task_id uuid,
  occurrence_id uuid,
  action text not null default 'pending' check (action in ('pending', 'reassign', 'reschedule', 'waive', 'keep')),
  new_assignee_member_id uuid,
  new_planned_date date,
  new_due_at timestamptz,
  reason text,
  resolved_by_member_id uuid,
  resolved_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, request_id, task_id),
  unique (organization_id, request_id, occurrence_id),
  foreign key (organization_id, request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, occurrence_id)
    references public.recurring_task_occurrences(organization_id, id)
    on delete restrict,
  foreign key (organization_id, new_assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, resolved_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (num_nonnulls(task_id, occurrence_id) = 1),
  check ((action = 'pending' and resolved_at is null and resolved_by_member_id is null) or action <> 'pending')
);

create index shift_instances_member_work_date_idx
  on public.shift_instances(organization_id, member_id, work_date, status);
create index employee_requests_member_period_idx
  on public.employee_requests(organization_id, member_id, status, starts_at, ends_at);
create index employee_requests_approval_queue_idx
  on public.employee_requests(organization_id, status, submitted_at, id)
  where status = 'pending';
create index request_segments_request_idx
  on public.request_segments(organization_id, request_id, shift_instance_id);
create index task_handover_actions_pending_idx
  on public.task_handover_actions(organization_id, action, request_id, id)
  where action = 'pending';

create or replace function private.assert_shift_instance_segments()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_segment jsonb;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_previous_end timestamptz;
  v_total_seconds bigint := 0;
begin
  if jsonb_typeof(new.working_segments) <> 'array' then
    raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_INVALID';
  end if;

  for v_segment in select value from jsonb_array_elements(new.working_segments)
  loop
    if jsonb_typeof(v_segment) <> 'object'
       or not (v_segment ? 'start')
       or not (v_segment ? 'end') then
      raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_INVALID';
    end if;
    v_starts_at := (v_segment ->> 'start')::timestamptz;
    v_ends_at := (v_segment ->> 'end')::timestamptz;
    if v_starts_at < new.starts_at or v_ends_at > new.ends_at or v_ends_at <= v_starts_at then
      raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_INVALID';
    end if;
    if v_previous_end is not null and v_starts_at < v_previous_end then
      raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_OVERLAP';
    end if;
    v_total_seconds := v_total_seconds + extract(epoch from v_ends_at - v_starts_at)::bigint;
    v_previous_end := v_ends_at;
  end loop;

  if v_total_seconds <> new.scheduled_seconds then
    raise exception using errcode = '22023', message = 'SHIFT_SCHEDULED_SECONDS_INVALID';
  end if;
  return new;
end;
$$;

create or replace function private.request_affected_seconds(
  p_working_segments jsonb,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns bigint
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_segment jsonb;
  v_segment_start timestamptz;
  v_segment_end timestamptz;
  v_overlap_start timestamptz;
  v_overlap_end timestamptz;
  v_seconds bigint := 0;
begin
  if p_ends_at <= p_starts_at then
    return 0;
  end if;
  for v_segment in select value from jsonb_array_elements(p_working_segments)
  loop
    v_segment_start := (v_segment ->> 'start')::timestamptz;
    v_segment_end := (v_segment ->> 'end')::timestamptz;
    v_overlap_start := greatest(v_segment_start, p_starts_at);
    v_overlap_end := least(v_segment_end, p_ends_at);
    if v_overlap_end > v_overlap_start then
      v_seconds := v_seconds + extract(epoch from v_overlap_end - v_overlap_start)::bigint;
    end if;
  end loop;
  return v_seconds;
end;
$$;

create or replace function private.assert_request_submitter(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  return v_member_id;
end;
$$;

create or replace function private.assert_request_approver(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
begin
  if v_member_id is null or not private.has_capability(p_organization_id, 'can_approve_requests') then
    raise exception using errcode = '42501', message = 'REQUEST_APPROVAL_DENIED';
  end if;
  return v_member_id;
end;
$$;

create or replace function private.current_actor_can_read_employee_request(
  p_organization_id uuid,
  p_request_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_capability(p_organization_id, 'can_approve_requests')
    or exists (
      select 1
      from public.employee_requests as er
      where er.organization_id = p_organization_id
        and er.id = p_request_id
        and er.member_id = private.current_member_id(p_organization_id)
    );
$$;

create or replace function private.recurring_member_on_approved_full_day_leave(
  p_organization_id uuid,
  p_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.employee_requests as er
    join public.request_segments as rs
      on rs.organization_id = er.organization_id
     and rs.request_id = er.id
    join public.shift_instances as si
      on si.organization_id = rs.organization_id
     and si.id = rs.shift_instance_id
    where er.organization_id = p_organization_id
      and er.member_id = p_member_id
      and er.request_type = 'leave'
      and er.status = 'approved'
      and si.work_date = p_work_date
      and rs.affected_seconds >= si.scheduled_seconds
  );
$$;

create or replace function private.create_leave_coverage_actions(p_request_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employee_requests%rowtype;
  v_org_timezone text;
  v_start_date date;
  v_end_date date;
  v_count integer := 0;
begin
  select * into v_request from public.employee_requests where id = p_request_id;
  if v_request.id is null or v_request.status <> 'approved'
     or v_request.request_type not in ('leave', 'early_leave', 'late_arrival') then
    return 0;
  end if;
  select timezone into v_org_timezone from public.organizations where id = v_request.organization_id;
  v_start_date := (v_request.starts_at at time zone v_org_timezone)::date;
  v_end_date := (v_request.ends_at at time zone v_org_timezone)::date;

  insert into public.task_handover_actions (
    organization_id, request_id, task_id, action
  )
  select v_request.organization_id, v_request.id, t.id, 'pending'
  from public.tasks as t
  where t.organization_id = v_request.organization_id
    and t.assignee_member_id = v_request.member_id
    and t.planned_date between v_start_date and v_end_date
    and t.status not in ('done', 'canceled', 'waived')
  on conflict (organization_id, request_id, task_id) do nothing;
  get diagnostics v_count = row_count;

  insert into public.task_handover_actions (
    organization_id, request_id, occurrence_id, action
  )
  select o.organization_id, v_request.id, o.id, 'pending'
  from public.recurring_task_occurrences as o
  join public.recurring_task_targets as rt
    on rt.organization_id = o.organization_id and rt.id = o.target_id
  where o.organization_id = v_request.organization_id
    and o.work_date between v_start_date and v_end_date
    and o.state = 'pending'
    and o.task_id is null
    and coalesce(o.resolved_assignee_member_id, rt.assignee_member_id) = v_request.member_id
    and private.recurring_member_on_approved_full_day_leave(o.organization_id, v_request.member_id, o.work_date)
  on conflict (organization_id, request_id, occurrence_id) do nothing;

  update public.recurring_task_occurrences as o
  set state = 'needs_assignment',
      issue_code = 'APPROVED_LEAVE_COVERAGE_REQUIRED',
      issue_context = jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id),
      updated_at = timezone('utc', now())
  from public.recurring_task_targets as rt
  where rt.organization_id = o.organization_id
    and rt.id = o.target_id
    and o.organization_id = v_request.organization_id
    and o.work_date between v_start_date and v_end_date
    and o.state = 'pending'
    and o.task_id is null
    and coalesce(o.resolved_assignee_member_id, rt.assignee_member_id) = v_request.member_id
    and private.recurring_member_on_approved_full_day_leave(o.organization_id, v_request.member_id, o.work_date);

  insert into private.outbox_events (
    organization_id, event_type, entity_type, entity_id, dedupe_key, payload
  ) values (
    v_request.organization_id,
    'leave.coverage_required',
    'employee_request',
    v_request.id,
    'leave:' || v_request.id::text || ':coverage',
    jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id)
  ) on conflict (organization_id, dedupe_key) do nothing;

  insert into private.outbox_events (
    organization_id, event_type, entity_type, entity_id, dedupe_key, payload
  ) values (
    v_request.organization_id,
    'leave.reminder_suppression_requested',
    'employee_request',
    v_request.id,
    'leave:' || v_request.id::text || ':suppress-reminders',
    jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id)
  ) on conflict (organization_id, dedupe_key) do nothing;

  return v_count;
end;
$$;

create or replace function public.rpc_create_employee_request(
  p_organization_id uuid,
  p_payload jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.assert_request_submitter(p_organization_id);
  v_request public.employee_requests%rowtype;
  v_shift public.shift_instances%rowtype;
  v_request_id uuid := extensions.gen_random_uuid();
  v_request_type text := lower(coalesce(p_payload ->> 'request_type', ''));
  v_starts_at timestamptz := nullif(p_payload ->> 'starts_at', '')::timestamptz;
  v_ends_at timestamptz := nullif(p_payload ->> 'ends_at', '')::timestamptz;
  v_leave_type_id uuid := nullif(p_payload ->> 'leave_type_id', '')::uuid;
  v_target_request_id uuid := nullif(p_payload ->> 'target_request_id', '')::uuid;
  v_reason text := trim(coalesce(p_payload ->> 'reason_private', ''));
  v_handover_note text := nullif(trim(coalesce(p_payload ->> 'handover_note', '')), '');
  v_correction_payload jsonb := p_payload -> 'correction_payload';
  v_pay_treatment text := 'not_applicable';
  v_affected_seconds bigint;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'REQUEST_PAYLOAD_INVALID';
  end if;
  if char_length(trim(coalesce(p_idempotency_key, ''))) < 8 then
    raise exception using errcode = '22023', message = 'REQUEST_IDEMPOTENCY_KEY_INVALID';
  end if;
  if v_request_type not in ('leave', 'early_leave', 'late_arrival', 'remote_work', 'attendance_correction', 'cancel_approved_request') then
    raise exception using errcode = '22023', message = 'REQUEST_TYPE_INVALID';
  end if;
  if v_starts_at is null or v_ends_at is null or v_ends_at <= v_starts_at then
    raise exception using errcode = '22023', message = 'REQUEST_INTERVAL_INVALID';
  end if;
  if char_length(v_reason) not between 10 and 2000 then
    raise exception using errcode = '22023', message = 'REQUEST_REASON_INVALID';
  end if;
  if v_request_type = 'attendance_correction' and (v_correction_payload is null or jsonb_typeof(v_correction_payload) <> 'object') then
    raise exception using errcode = '22023', message = 'REQUEST_CORRECTION_PAYLOAD_INVALID';
  end if;
  if v_request_type = 'cancel_approved_request' and not exists (
    select 1 from public.employee_requests as target
    where target.organization_id = p_organization_id
      and target.id = v_target_request_id
      and target.member_id = v_member_id
      and target.status = 'approved'
  ) then
    raise exception using errcode = '22023', message = 'REQUEST_CANCELLATION_TARGET_INVALID';
  end if;

  select * into v_request
  from public.employee_requests
  where organization_id = p_organization_id
    and member_id = v_member_id
    and idempotency_key = p_idempotency_key;
  if v_request.id is not null then
    return jsonb_build_object('request_id', v_request.id, 'status', v_request.status, 'idempotent_replay', true);
  end if;

  if v_request_type in ('leave', 'early_leave', 'late_arrival') then
    select lt.pay_treatment into v_pay_treatment
    from public.leave_types as lt
    where lt.organization_id = p_organization_id and lt.id = v_leave_type_id and lt.active;
    if v_pay_treatment is null then
      raise exception using errcode = '22023', message = 'REQUEST_LEAVE_TYPE_INVALID';
    end if;
    if exists (
      select 1
      from public.employee_requests as er
      where er.organization_id = p_organization_id
        and er.member_id = v_member_id
        and er.status = 'approved'
        and er.request_type in ('leave', 'early_leave', 'late_arrival')
        and tstzrange(er.starts_at, er.ends_at, '[)') && tstzrange(v_starts_at, v_ends_at, '[)')
    ) then
      raise exception using errcode = '23505', message = 'REQUEST_APPROVED_OVERLAP';
    end if;
  else
    v_leave_type_id := null;
  end if;

  insert into public.employee_requests (
    id, organization_id, member_id, request_type, starts_at, ends_at, leave_type_id,
    pay_treatment_snapshot, reason_private, handover_note, target_request_id, correction_payload, idempotency_key
  ) values (
    v_request_id, p_organization_id, v_member_id, v_request_type, v_starts_at, v_ends_at, v_leave_type_id,
    v_pay_treatment, v_reason, v_handover_note, v_target_request_id, v_correction_payload, p_idempotency_key
  );

  for v_shift in
    select * from public.shift_instances
    where organization_id = p_organization_id
      and member_id = v_member_id
      and status = 'scheduled'
      and starts_at < v_ends_at and ends_at > v_starts_at
  loop
    v_affected_seconds := private.request_affected_seconds(v_shift.working_segments, v_starts_at, v_ends_at);
    insert into public.request_segments (
      organization_id, request_id, shift_instance_id, starts_at, ends_at, affected_seconds, pay_treatment_snapshot
    ) values (
      p_organization_id, v_request_id, v_shift.id,
      greatest(v_starts_at, v_shift.starts_at), least(v_ends_at, v_shift.ends_at),
      v_affected_seconds, v_pay_treatment
    ) on conflict (organization_id, request_id, shift_instance_id) do nothing;
  end loop;

  perform private.write_audit(
    p_organization_id,
    'request.created',
    'employee_request',
    v_request_id,
    jsonb_build_object('request_type', v_request_type, 'starts_at', v_starts_at, 'ends_at', v_ends_at)
  );

  return jsonb_build_object('request_id', v_request_id, 'status', 'pending', 'idempotent_replay', false);
end;
$$;

create or replace function public.rpc_decide_employee_request(
  p_request_id uuid,
  p_decision text,
  p_reason_private text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employee_requests%rowtype;
  v_after public.employee_requests%rowtype;
  v_actor_member_id uuid;
  v_decision text := lower(trim(coalesce(p_decision, '')));
  v_reason text := nullif(trim(coalesce(p_reason_private, '')), '');
  v_existing_decision public.request_decisions%rowtype;
  v_affected_seconds bigint;
  v_target_request public.employee_requests%rowtype;
  v_target_affected_seconds bigint;
begin
  select * into v_request from public.employee_requests where id = p_request_id for update;
  if v_request.id is null then
    raise exception using errcode = 'P0002', message = 'REQUEST_NOT_FOUND';
  end if;
  v_actor_member_id := private.assert_request_approver(v_request.organization_id);
  if v_request.member_id = v_actor_member_id then
    raise exception using errcode = '42501', message = 'REQUEST_SELF_APPROVAL_DENIED';
  end if;
  if char_length(trim(coalesce(p_idempotency_key, ''))) < 8 then
    raise exception using errcode = '22023', message = 'REQUEST_IDEMPOTENCY_KEY_INVALID';
  end if;
  select * into v_existing_decision from public.request_decisions
  where organization_id = v_request.organization_id and request_id = p_request_id and idempotency_key = p_idempotency_key;
  if v_existing_decision.id is not null then
    return jsonb_build_object('request_id', p_request_id, 'status', v_existing_decision.decision, 'idempotent_replay', true);
  end if;
  if v_decision not in ('approved', 'rejected') then
    raise exception using errcode = '22023', message = 'REQUEST_DECISION_INVALID';
  end if;
  if v_decision = 'rejected' and char_length(coalesce(v_reason, '')) < 10 then
    raise exception using errcode = '22023', message = 'REQUEST_REJECTION_REASON_REQUIRED';
  end if;
  if v_request.status <> 'pending' then
    raise exception using errcode = '40901', message = 'REQUEST_ALREADY_DECIDED';
  end if;
  if p_expected_version is null or p_expected_version <> v_request.version then
    raise exception using errcode = '40901', message = 'REQUEST_VERSION_CONFLICT';
  end if;
  if v_decision = 'approved'
     and v_request.request_type in ('leave', 'early_leave', 'late_arrival')
     and exists (
       select 1 from public.employee_requests as other
       where other.organization_id = v_request.organization_id
         and other.member_id = v_request.member_id
         and other.status = 'approved'
         and other.request_type in ('leave', 'early_leave', 'late_arrival')
         and other.id <> v_request.id
         and tstzrange(other.starts_at, other.ends_at, '[)') && tstzrange(v_request.starts_at, v_request.ends_at, '[)')
     ) then
    raise exception using errcode = '23505', message = 'REQUEST_APPROVED_OVERLAP';
  end if;

  update public.employee_requests
  set status = v_decision,
      decided_at = timezone('utc', now()),
      decided_by_member_id = v_actor_member_id,
      decision_reason_private = v_reason,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = v_request.id
  returning * into v_after;

  insert into public.request_decisions (
    organization_id, request_id, decision, actor_member_id, reason_private,
    before_state, after_state, idempotency_key
  ) values (
    v_request.organization_id, v_request.id, v_decision, v_actor_member_id, v_reason,
    to_jsonb(v_request), to_jsonb(v_after), p_idempotency_key
  );

  if v_decision = 'approved' then
    select coalesce(sum(affected_seconds), 0) into v_affected_seconds
    from public.request_segments where organization_id = v_request.organization_id and request_id = v_request.id;

    if v_request.leave_type_id is not null and v_request.pay_treatment_snapshot = 'paid'
       and exists (
         select 1 from public.leave_types where id = v_request.leave_type_id and consumes_balance
       ) then
      insert into public.leave_balance_entries (
        organization_id, member_id, leave_type_id, delta_seconds, effective_date,
        source_request_id, reason, created_by_member_id
      ) values (
        v_request.organization_id, v_request.member_id, v_request.leave_type_id, -v_affected_seconds,
        (v_request.starts_at at time zone (select timezone from public.organizations where id = v_request.organization_id))::date,
        v_request.id, 'Approved employee request', v_actor_member_id
      ) on conflict (organization_id, source_request_id) do nothing;
    end if;
    perform private.create_leave_coverage_actions(v_request.id);

    if v_request.request_type = 'attendance_correction' then
      insert into private.outbox_events (
        organization_id, event_type, entity_type, entity_id, dedupe_key, payload
      ) values (
        v_request.organization_id,
        'attendance.correction_approved',
        'employee_request',
        v_request.id,
        'request:' || v_request.id::text || ':attendance-correction',
        jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id)
      ) on conflict (organization_id, dedupe_key) do nothing;
    end if;

    if v_request.request_type = 'cancel_approved_request' then
      select * into v_target_request
      from public.employee_requests as target
      where target.organization_id = v_request.organization_id
        and target.id = v_request.target_request_id
        and target.status = 'approved'
      for update;
      if v_target_request.id is null then
        raise exception using errcode = '40901', message = 'REQUEST_CANCELLATION_TARGET_NOT_APPROVED';
      end if;
      update public.employee_requests as target
      set status = 'canceled', version = version + 1, updated_at = timezone('utc', now())
      where target.organization_id = v_request.organization_id
        and target.id = v_request.target_request_id
        and target.status = 'approved';
      if v_target_request.leave_type_id is not null and v_target_request.pay_treatment_snapshot = 'paid'
         and exists (
           select 1 from public.leave_types where id = v_target_request.leave_type_id and consumes_balance
         ) then
        select coalesce(sum(affected_seconds), 0) into v_target_affected_seconds
        from public.request_segments
        where organization_id = v_target_request.organization_id and request_id = v_target_request.id;
        insert into public.leave_balance_entries (
          organization_id, member_id, leave_type_id, delta_seconds, effective_date,
          source_request_id, reason, created_by_member_id
        ) values (
          v_target_request.organization_id, v_target_request.member_id, v_target_request.leave_type_id,
          v_target_affected_seconds,
          (v_target_request.starts_at at time zone (select timezone from public.organizations where id = v_target_request.organization_id))::date,
          v_request.id, 'Approved cancellation of leave request', v_actor_member_id
        ) on conflict (organization_id, source_request_id) do nothing;
      end if;
      insert into private.outbox_events (
        organization_id, event_type, entity_type, entity_id, dedupe_key, payload
      ) values (
        v_request.organization_id,
        'leave.cancellation_approved',
        'employee_request',
        v_request.id,
        'request:' || v_request.id::text || ':cancellation',
        jsonb_build_object('request_id', v_request.id, 'target_request_id', v_target_request.id)
      ) on conflict (organization_id, dedupe_key) do nothing;
    end if;
  end if;

  perform private.write_audit(
    v_request.organization_id,
    'request.' || v_decision,
    'employee_request',
    v_request.id,
    jsonb_build_object('request_type', v_request.request_type, 'decision', v_decision, 'version', v_after.version)
  );
  return jsonb_build_object('request_id', v_request.id, 'status', v_decision, 'version', v_after.version, 'idempotent_replay', false);
end;
$$;

create or replace function public.rpc_withdraw_employee_request(
  p_request_id uuid,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employee_requests%rowtype;
  v_actor_member_id uuid;
  v_after public.employee_requests%rowtype;
begin
  select * into v_request from public.employee_requests where id = p_request_id for update;
  if v_request.id is null then
    raise exception using errcode = 'P0002', message = 'REQUEST_NOT_FOUND';
  end if;
  v_actor_member_id := private.assert_request_submitter(v_request.organization_id);
  if v_request.member_id <> v_actor_member_id then
    raise exception using errcode = '42501', message = 'REQUEST_WITHDRAW_DENIED';
  end if;
  if v_request.status <> 'pending' then
    raise exception using errcode = '40901', message = 'REQUEST_WITHDRAW_NOT_PENDING';
  end if;
  if p_expected_version is null or p_expected_version <> v_request.version then
    raise exception using errcode = '40901', message = 'REQUEST_VERSION_CONFLICT';
  end if;
  update public.employee_requests
  set status = 'withdrawn', version = version + 1, updated_at = timezone('utc', now())
  where id = v_request.id returning * into v_after;
  insert into public.request_decisions (
    organization_id, request_id, decision, actor_member_id, before_state, after_state, idempotency_key
  ) values (
    v_request.organization_id, v_request.id, 'withdrawn', v_actor_member_id,
    to_jsonb(v_request), to_jsonb(v_after), p_idempotency_key
  ) on conflict (organization_id, request_id, idempotency_key) do nothing;
  perform private.write_audit(
    v_request.organization_id, 'request.withdrawn', 'employee_request', v_request.id,
    jsonb_build_object('request_type', v_request.request_type, 'version', v_after.version)
  );
  return jsonb_build_object('request_id', v_request.id, 'status', 'withdrawn', 'version', v_after.version);
end;
$$;

create or replace function public.rpc_list_request_availability(
  p_organization_id uuid,
  p_from_date date,
  p_to_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_request_submitter(p_organization_id);
  if p_from_date is null or p_to_date is null or p_to_date < p_from_date or p_to_date - p_from_date > 31 then
    raise exception using errcode = '22023', message = 'REQUEST_AVAILABILITY_RANGE_INVALID';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'member_id', er.member_id,
      'starts_at', er.starts_at,
      'ends_at', er.ends_at,
      'availability', case when er.request_type = 'remote_work' then 'remote' else 'unavailable' end
    ) order by er.starts_at, er.id)
    from public.employee_requests as er
    where er.organization_id = p_organization_id
      and er.status = 'approved'
      and er.request_type in ('leave', 'early_leave', 'late_arrival', 'remote_work')
      and er.starts_at < ((p_to_date + 1)::timestamp at time zone (select timezone from public.organizations where id = p_organization_id))
      and er.ends_at > (p_from_date::timestamp at time zone (select timezone from public.organizations where id = p_organization_id))
  ), '[]'::jsonb);
end;
$$;

-- An approved full-day leave makes future Daily occurrences coverage work, never silent deletion.
create or replace function private.recurring_member_available_for_work_date(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    left join public.member_hr_settings as hr
      on hr.organization_id = m.organization_id and hr.member_id = m.id
    where m.organization_id = p_organization_id
      and m.id = p_member_id
      and m.status = 'active'
      and (hr.member_id is null or hr.employment_start <= p_work_date)
      and (hr.member_id is null or hr.employment_end is null or hr.employment_end >= p_work_date)
      and not private.recurring_member_on_approved_full_day_leave(p_organization_id, p_member_id, p_work_date)
      and (
        p_seller_id is null or exists (
          select 1 from public.seller_members as sm
          where sm.organization_id = p_organization_id and sm.seller_id = p_seller_id
            and sm.member_id = p_member_id and sm.active_from <= p_work_date
            and (sm.active_until is null or sm.active_until >= p_work_date)
        )
      )
      and (p_seller_id is null or private.is_seller_member(p_organization_id, p_seller_id, p_member_id))
  );
$$;

create trigger offices_set_updated_at before update on public.offices
for each row execute function private.set_updated_at();
create trigger shift_templates_set_updated_at before update on public.shift_templates
for each row execute function private.set_updated_at();
create trigger shift_assignments_set_updated_at before update on public.shift_assignments
for each row execute function private.set_updated_at();
create trigger calendar_overrides_set_updated_at before update on public.calendar_overrides
for each row execute function private.set_updated_at();
create trigger shift_instances_set_updated_at before update on public.shift_instances
for each row execute function private.set_updated_at();
create trigger shift_instances_validate_segments before insert or update on public.shift_instances
for each row execute function private.assert_shift_instance_segments();
create trigger leave_types_set_updated_at before update on public.leave_types
for each row execute function private.set_updated_at();
create trigger employee_requests_set_updated_at before update on public.employee_requests
for each row execute function private.set_updated_at();
create trigger task_handover_actions_set_updated_at before update on public.task_handover_actions
for each row execute function private.set_updated_at();

alter table public.offices enable row level security;
alter table public.shift_templates enable row level security;
alter table public.shift_assignments enable row level security;
alter table public.calendar_overrides enable row level security;
alter table public.shift_instances enable row level security;
alter table public.leave_types enable row level security;
alter table public.employee_requests enable row level security;
alter table public.request_segments enable row level security;
alter table public.request_decisions enable row level security;
alter table public.leave_balance_entries enable row level security;
alter table public.task_handover_actions enable row level security;

create policy offices_read_active_member on public.offices for select to authenticated
using (private.current_member_id(organization_id) is not null);
create policy shift_templates_read_active_member on public.shift_templates for select to authenticated
using (private.current_member_id(organization_id) is not null);
create policy shift_assignments_read_own_or_hr on public.shift_assignments for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));
create policy calendar_overrides_read_own_or_hr on public.calendar_overrides for select to authenticated
using (member_id is null or member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));
create policy shift_instances_read_own_or_hr on public.shift_instances for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));
create policy leave_types_read_active_member on public.leave_types for select to authenticated
using (private.current_member_id(organization_id) is not null);
create policy employee_requests_read_owner_or_approver on public.employee_requests for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, id));
create policy request_segments_read_owner_or_approver on public.request_segments for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, request_id));
create policy request_decisions_read_owner_or_approver on public.request_decisions for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, request_id));
create policy leave_balance_entries_read_owner_or_approver on public.leave_balance_entries for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_approve_requests'));
create policy task_handover_actions_read_owner_or_approver on public.task_handover_actions for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, request_id));

revoke all on function private.assert_shift_instance_segments() from public, anon, authenticated;
revoke all on function private.request_affected_seconds(jsonb, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.assert_request_submitter(uuid) from public, anon;
revoke all on function private.assert_request_approver(uuid) from public, anon;
revoke all on function private.current_actor_can_read_employee_request(uuid, uuid) from public, anon;
revoke all on function private.recurring_member_on_approved_full_day_leave(uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.create_leave_coverage_actions(uuid) from public, anon, authenticated;
grant execute on function private.assert_request_submitter(uuid) to authenticated;
grant execute on function private.assert_request_approver(uuid) to authenticated;
grant execute on function private.current_actor_can_read_employee_request(uuid, uuid) to authenticated;
grant execute on function public.rpc_create_employee_request(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_decide_employee_request(uuid, text, text, integer, text) to authenticated;
grant execute on function public.rpc_withdraw_employee_request(uuid, integer, text) to authenticated;
grant execute on function public.rpc_list_request_availability(uuid, date, date) to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.offices, public.shift_templates, public.shift_assignments, public.calendar_overrides,
  public.shift_instances, public.leave_types, public.employee_requests, public.request_segments,
  public.request_decisions, public.leave_balance_entries, public.task_handover_actions
from authenticated;
