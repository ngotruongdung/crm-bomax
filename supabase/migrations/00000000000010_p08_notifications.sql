-- P08: durable notification inbox, reminder engine, push endpoints and leased outbox workers.
-- Business mutations continue to enqueue outbox rows transactionally; delivery is server-side and retryable.

alter table private.outbox_events
  add column if not exists lease_owner uuid,
  add column if not exists lease_until timestamptz,
  add column if not exists last_error_code text,
  add column if not exists dead_lettered_at timestamptz;

update private.outbox_events
set status = 'done'
where status = 'published';

alter table private.outbox_events
  drop constraint if exists outbox_events_status_check;

alter table private.outbox_events
  add constraint outbox_events_status_check
  check (status in ('pending', 'processing', 'done', 'failed'));

create index if not exists private_outbox_claim_idx
  on private.outbox_events(status, available_at, lease_until, created_at)
  where status in ('pending', 'processing', 'failed') and dead_lettered_at is null;

create table public.push_endpoints (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  device_id uuid not null,
  provider text not null check (provider in ('expo', 'webpush')),
  token_encrypted text not null check (char_length(token_encrypted) between 16 and 8192),
  token_hash text not null check (char_length(token_hash) between 32 and 256),
  active boolean not null default true,
  last_error_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, provider, token_hash),
  foreign key (organization_id, device_id)
    references public.user_devices(organization_id, id)
    on delete restrict
);

create index push_endpoints_device_idx
  on public.push_endpoints(organization_id, device_id, active, provider);

create table public.notification_preferences (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  push_enabled boolean not null default true,
  email_enabled boolean not null default false,
  quiet_hours jsonb not null default '{}'::jsonb check (jsonb_typeof(quiet_hours) = 'object'),
  closer_reminder_mode boolean not null default false,
  closer_mode_reason text,
  closer_mode_review_at date,
  daily_push_limit integer not null default 8 check (daily_push_limit between 0 and 50),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  primary key (organization_id, member_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (
    not closer_reminder_mode
    or (nullif(trim(closer_mode_reason), '') is not null and closer_mode_review_at is not null)
  )
);

create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  recipient_member_id uuid not null,
  kind text not null check (kind in (
    'task_assigned',
    'task_unacknowledged',
    'task_due_soon',
    'task_overdue',
    'task_blocked',
    'task_review_requested',
    'request_result',
    'report_ready',
    'digest',
    'system'
  )),
  title text not null check (char_length(trim(title)) between 1 and 180),
  body text not null check (char_length(trim(body)) between 1 and 500),
  target_type text not null check (target_type in ('task', 'request', 'report', 'system')),
  target_id uuid,
  safe_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(safe_payload) = 'object'),
  dedupe_key text not null check (char_length(trim(dedupe_key)) between 1 and 240),
  created_at timestamptz not null default timezone('utc', now()),
  read_at timestamptz,
  expires_at timestamptz,
  unique (organization_id, id),
  unique (organization_id, recipient_member_id, dedupe_key),
  foreign key (organization_id, recipient_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (expires_at is null or expires_at > created_at)
);

create index notifications_recipient_feed_idx
  on public.notifications(organization_id, recipient_member_id, created_at desc, id desc);
create index notifications_recipient_unread_idx
  on public.notifications(organization_id, recipient_member_id, created_at desc)
  where read_at is null;

create table public.notification_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  notification_id uuid not null,
  endpoint_id uuid,
  channel text not null check (channel in ('in_app', 'push', 'email')),
  status text not null default 'pending'
    check (status in ('pending', 'sending', 'accepted', 'provider_confirmed', 'failed', 'expired')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default timezone('utc', now()),
  provider_ticket_id text,
  last_error_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, notification_id)
    references public.notifications(organization_id, id)
    on delete restrict,
  foreign key (organization_id, endpoint_id)
    references public.push_endpoints(organization_id, id)
    on delete restrict,
  check ((channel = 'push' and endpoint_id is not null) or (channel <> 'push' and endpoint_id is null))
);

create unique index notification_deliveries_push_unique_idx
  on public.notification_deliveries(notification_id, channel, endpoint_id)
  where endpoint_id is not null;
create unique index notification_deliveries_non_endpoint_unique_idx
  on public.notification_deliveries(notification_id, channel)
  where endpoint_id is null;
create index notification_deliveries_retry_idx
  on public.notification_deliveries(status, next_attempt_at, channel)
  where status in ('pending', 'failed', 'accepted');

create table public.task_reminder_snoozes (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  member_id uuid not null,
  rule_key text not null check (rule_key in ('unack', 'due_soon', 'overdue', 'blocked', 'reviewer')),
  snoozed_until timestamptz not null,
  set_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  primary key (organization_id, task_id, member_id, rule_key),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (snoozed_until > set_at)
);

create index task_reminder_snoozes_expiry_idx
  on public.task_reminder_snoozes(snoozed_until);

create trigger push_endpoints_set_updated_at
before update on public.push_endpoints
for each row execute function private.set_updated_at();

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function private.set_updated_at();

create trigger notification_deliveries_set_updated_at
before update on public.notification_deliveries
for each row execute function private.set_updated_at();

create or replace function private.deactivate_push_endpoints_for_revoked_device()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.revoked_at is null and new.revoked_at is not null then
    update public.push_endpoints
    set active = false,
        last_error_code = 'DEVICE_REVOKED'
    where organization_id = new.organization_id
      and device_id = new.id
      and active;
  end if;
  return new;
end;
$$;

create trigger user_devices_deactivate_push_endpoints
after update of revoked_at on public.user_devices
for each row execute function private.deactivate_push_endpoints_for_revoked_device();

create or replace function private.notification_member_on_approved_leave(
  p_organization_id uuid,
  p_member_id uuid,
  p_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.employee_requests as r
    where r.organization_id = p_organization_id
      and r.member_id = p_member_id
      and r.status = 'approved'
      and r.request_type in ('leave', 'early_leave', 'late_arrival')
      and r.starts_at <= p_at
      and r.ends_at > p_at
  );
$$;

create or replace function private.notification_working_seconds_between(
  p_organization_id uuid,
  p_member_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  with segments as (
    select
      greatest((segment ->> 'start')::timestamptz, p_starts_at) as starts_at,
      least((segment ->> 'end')::timestamptz, p_ends_at) as ends_at
    from public.shift_instances as s
    cross join lateral jsonb_array_elements(s.working_segments) as segment
    where s.organization_id = p_organization_id
      and s.member_id = p_member_id
      and s.status = 'scheduled'
      and s.ends_at > p_starts_at
      and s.starts_at < p_ends_at
  ),
  valid_segments as (
    select starts_at, ends_at
    from segments
    where ends_at > starts_at
  ),
  approved_leave as (
    select rs.starts_at, rs.ends_at
    from public.request_segments as rs
    join public.employee_requests as r
      on r.organization_id = rs.organization_id
     and r.id = rs.request_id
    where r.organization_id = p_organization_id
      and r.member_id = p_member_id
      and r.status = 'approved'
      and r.request_type in ('leave', 'early_leave', 'late_arrival')
      and rs.ends_at > p_starts_at
      and rs.starts_at < p_ends_at
  )
  select coalesce(sum(greatest(
    0,
    extract(epoch from (v.ends_at - v.starts_at))::bigint - coalesce((
      select sum(extract(epoch from (
        least(v.ends_at, l.ends_at) - greatest(v.starts_at, l.starts_at)
      )))::bigint
      from approved_leave as l
      where l.ends_at > v.starts_at
        and l.starts_at < v.ends_at
    ), 0)
  )), 0)::bigint
  from valid_segments as v;
$$;

create or replace function private.notification_reminder_policy(
  p_organization_id uuid,
  p_at timestamptz
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.config
    from public.policy_versions as p
    where p.organization_id = p_organization_id
      and p.policy_kind = 'reminders'
      and p.effective_from <= p_at
    order by p.effective_from desc, p.version_number desc
    limit 1
  ), '{}'::jsonb);
$$;

create or replace function private.notification_unack_threshold_minutes(
  p_reminder_profile jsonb,
  p_profile_reason text,
  p_default integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(p_reminder_profile ->> 'mode', 'standard') = 'closer'
      and nullif(trim(coalesce(p_profile_reason, '')), '') is not null
      then greatest(5, least(p_default, coalesce((p_reminder_profile ->> 'unack_minutes')::integer, 15)))
    else p_default
  end;
$$;

create or replace function private.enqueue_task_reminders(p_now timestamptz default clock_timestamp())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_org_timezone text;
  v_policy jsonb;
  v_default_unack integer;
  v_due_soon integer;
  v_recipient uuid;
  v_rule text;
  v_threshold integer;
  v_working_seconds bigint;
  v_count integer := 0;
  v_dedupe_key text;
begin
  for v_task in
    select t.*
    from public.tasks as t
    join public.organization_members as m
      on m.organization_id = t.organization_id
     and m.id = t.assignee_member_id
     and m.status = 'active'
    where t.status not in ('done', 'canceled', 'waived')
      and t.visible_from <= p_now
  loop
    select o.timezone into v_org_timezone
    from public.organizations as o
    where o.id = v_task.organization_id;

    v_policy := private.notification_reminder_policy(v_task.organization_id, p_now);
    v_default_unack := greatest(5, least(240, coalesce((v_policy ->> 'unack_minutes')::integer, 30)));
    v_due_soon := greatest(5, least(1440, coalesce((v_policy ->> 'due_soon_minutes')::integer, 60)));
    v_threshold := private.notification_unack_threshold_minutes(
      v_task.reminder_profile,
      v_task.reminder_profile_reason,
      v_default_unack
    );

    v_recipient := null;
    v_rule := null;

    if v_task.blocked_at is not null and v_task.blocker_owner_member_id is not null then
      v_recipient := v_task.blocker_owner_member_id;
      v_rule := 'blocked';
    elsif v_task.status = 'in_review' and v_task.reviewer_member_id is not null then
      v_recipient := v_task.reviewer_member_id;
      v_rule := 'reviewer';
    elsif v_task.acknowledged_at is null then
      v_working_seconds := private.notification_working_seconds_between(
        v_task.organization_id,
        v_task.assignee_member_id,
        v_task.assigned_at,
        p_now
      );
      if v_working_seconds >= v_threshold * 60 then
        v_recipient := v_task.assignee_member_id;
        v_rule := 'unack';
      end if;
    end if;

    if v_rule is null and v_task.due_at <= p_now then
      v_recipient := v_task.assignee_member_id;
      v_rule := 'overdue';
    elsif v_rule is null and v_task.due_at <= p_now + make_interval(mins => v_due_soon) then
      v_recipient := v_task.assignee_member_id;
      v_rule := 'due_soon';
    end if;

    if v_rule is null or v_recipient is null then
      continue;
    end if;

    if exists (
      select 1
      from public.task_reminder_snoozes as s
      where s.organization_id = v_task.organization_id
        and s.task_id = v_task.id
        and s.member_id = v_recipient
        and s.rule_key = v_rule
        and s.snoozed_until > p_now
    ) then
      continue;
    end if;

    v_dedupe_key := 'reminder:' || v_task.id::text || ':' || v_recipient::text || ':' || v_rule || ':' ||
      v_task.version::text || ':' || (p_now at time zone v_org_timezone)::date::text;

    insert into private.outbox_events (
      organization_id,
      event_type,
      entity_type,
      entity_id,
      dedupe_key,
      payload,
      available_at
    ) values (
      v_task.organization_id,
      'reminder.task_' || v_rule,
      'task',
      v_task.id,
      v_dedupe_key,
      jsonb_build_object(
        'task_id', v_task.id,
        'recipient_member_id', v_recipient,
        'rule_key', v_rule,
        'task_version', v_task.version,
        'threshold_minutes', case when v_rule = 'unack' then v_threshold else null end
      ),
      p_now
    ) on conflict (organization_id, dedupe_key) do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

create or replace function public.rpc_internal_enqueue_task_reminders(p_now timestamptz default clock_timestamp())
returns integer
language sql
security definer
set search_path = ''
as $$
  select private.enqueue_task_reminders(p_now);
$$;

create or replace function private.notification_outbox_recipient(p_event private.outbox_events)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    case
      when nullif(p_event.payload ->> 'recipient_member_id', '') is not null
        then (p_event.payload ->> 'recipient_member_id')::uuid
      when nullif(p_event.payload ->> 'assignee_member_id', '') is not null
        then (p_event.payload ->> 'assignee_member_id')::uuid
      when nullif(p_event.payload ->> 'reviewer_member_id', '') is not null
        then (p_event.payload ->> 'reviewer_member_id')::uuid
      when nullif(p_event.payload ->> 'member_id', '') is not null
        then (p_event.payload ->> 'member_id')::uuid
      else null
    end,
    case when p_event.entity_type = 'task' then (
      select case
        when p_event.event_type = 'task.review_requested' then t.reviewer_member_id
        else t.assignee_member_id
      end
      from public.tasks as t
      where t.organization_id = p_event.organization_id
        and t.id = p_event.entity_id
    ) end,
    case when p_event.entity_type = 'employee_request' then (
      select r.member_id
      from public.employee_requests as r
      where r.organization_id = p_event.organization_id
        and r.id = p_event.entity_id
    ) end
  );
$$;

create or replace function private.notification_kind_for_event(p_event_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_event_type = 'task.assigned' then 'task_assigned'
    when p_event_type = 'task.review_requested' then 'task_review_requested'
    when p_event_type = 'reminder.task_unack' then 'task_unacknowledged'
    when p_event_type = 'reminder.task_due_soon' then 'task_due_soon'
    when p_event_type = 'reminder.task_overdue' then 'task_overdue'
    when p_event_type = 'reminder.task_blocked' then 'task_blocked'
    when p_event_type = 'reminder.task_reviewer' then 'task_review_requested'
    when p_event_type like 'request.%' or p_event_type like 'leave.%' then 'request_result'
    when p_event_type like 'report.%' then 'report_ready'
    else 'system'
  end;
$$;

create or replace function private.notification_copy_for_event(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_task_title text;
begin
  if p_entity_type = 'task' then
    select t.title into v_task_title
    from public.tasks as t
    where t.id = p_entity_id;
  end if;

  return case
    when p_event_type = 'task.assigned' then jsonb_build_object(
      'title', 'Bạn có công việc mới',
      'body', coalesce(v_task_title, 'Một công việc mới đã được giao cho bạn.')
    )
    when p_event_type = 'task.review_requested' or p_event_type = 'reminder.task_reviewer' then jsonb_build_object(
      'title', 'Có công việc chờ duyệt',
      'body', coalesce(v_task_title, 'Mở công việc để xem nội dung cần duyệt.')
    )
    when p_event_type = 'reminder.task_unack' then jsonb_build_object(
      'title', 'Công việc đang chờ nhận',
      'body', coalesce(v_task_title, 'Bạn có công việc chưa xác nhận nhận việc.')
    )
    when p_event_type = 'reminder.task_due_soon' then jsonb_build_object(
      'title', 'Công việc sắp đến hạn',
      'body', coalesce(v_task_title, 'Một công việc của bạn sắp đến hạn.')
    )
    when p_event_type = 'reminder.task_overdue' then jsonb_build_object(
      'title', 'Công việc đã quá hạn',
      'body', coalesce(v_task_title, 'Một công việc của bạn đã quá hạn.')
    )
    when p_event_type = 'reminder.task_blocked' then jsonb_build_object(
      'title', 'Có công việc đang bị vướng',
      'body', coalesce(v_task_title, 'Bạn đang được chỉ định hỗ trợ tháo gỡ một công việc.')
    )
    when p_event_type like 'request.%' or p_event_type like 'leave.%' then jsonb_build_object(
      'title', 'Yêu cầu của bạn đã có cập nhật',
      'body', 'Mở ứng dụng để xem trạng thái mới nhất.'
    )
    when p_event_type like 'report.%' then jsonb_build_object(
      'title', 'Báo cáo đã sẵn sàng',
      'body', 'Mở ứng dụng để xem báo cáo mới.'
    )
    else jsonb_build_object(
      'title', 'Có cập nhật mới',
      'body', 'Mở ứng dụng để xem chi tiết.'
    )
  end;
end;
$$;

create or replace function private.notification_daily_push_limit(
  p_organization_id uuid,
  p_member_id uuid,
  p_at timestamptz
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select np.daily_push_limit
     from public.notification_preferences as np
     where np.organization_id = p_organization_id and np.member_id = p_member_id),
    greatest(0, least(50, coalesce((private.notification_reminder_policy(p_organization_id, p_at) ->> 'daily_push_limit')::integer, 8)))
  );
$$;

create or replace function private.notification_push_count_today(
  p_organization_id uuid,
  p_member_id uuid,
  p_at timestamptz
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.notification_deliveries as d
  join public.notifications as n
    on n.organization_id = d.organization_id
   and n.id = d.notification_id
  join public.organizations as o on o.id = n.organization_id
  where n.organization_id = p_organization_id
    and n.recipient_member_id = p_member_id
    and d.channel = 'push'
    and d.status in ('sending', 'accepted', 'provider_confirmed')
    and (d.created_at at time zone o.timezone)::date = (p_at at time zone o.timezone)::date;
$$;

create or replace function public.rpc_internal_claim_outbox(
  p_worker_id uuid,
  p_limit integer default 25
)
returns setof private.outbox_events
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_worker_id is null then
    raise exception using errcode = '22023', message = 'WORKER_ID_REQUIRED';
  end if;

  return query
  with candidates as (
    select e.id
    from private.outbox_events as e
    where e.dead_lettered_at is null
      and e.attempts < 5
      and e.available_at <= clock_timestamp()
      and (
        e.status in ('pending', 'failed')
        or (e.status = 'processing' and e.lease_until < clock_timestamp())
      )
    order by e.created_at, e.id
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 25), 25))
  )
  update private.outbox_events as e
  set status = 'processing',
      lease_owner = p_worker_id,
      lease_until = clock_timestamp() + interval '60 seconds',
      attempts = e.attempts + 1,
      last_error_code = null
  from candidates as c
  where e.id = c.id
  returning e.*;
end;
$$;

create or replace function public.rpc_internal_ack_outbox(
  p_event_id uuid,
  p_worker_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  update private.outbox_events
  set status = 'done',
      published_at = coalesce(published_at, clock_timestamp()),
      lease_owner = null,
      lease_until = null,
      last_error_code = null
  where id = p_event_id
    and status = 'processing'
    and lease_owner = p_worker_id;
  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

create or replace function public.rpc_internal_fail_outbox(
  p_event_id uuid,
  p_worker_id uuid,
  p_error_code text,
  p_retryable boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event private.outbox_events%rowtype;
  v_delay interval;
  v_dead boolean;
begin
  select * into v_event
  from private.outbox_events
  where id = p_event_id
  for update;

  if v_event.id is null or v_event.status <> 'processing' or v_event.lease_owner <> p_worker_id then
    return jsonb_build_object('updated', false, 'reason', 'LEASE_MISMATCH');
  end if;

  v_dead := not coalesce(p_retryable, true) or v_event.attempts >= 5;
  v_delay := case v_event.attempts
    when 1 then interval '1 minute'
    when 2 then interval '5 minutes'
    when 3 then interval '15 minutes'
    else interval '1 hour'
  end;

  update private.outbox_events
  set status = 'failed',
      available_at = case when v_dead then available_at else clock_timestamp() + v_delay end,
      lease_owner = null,
      lease_until = null,
      last_error_code = left(coalesce(nullif(trim(p_error_code), ''), 'UNKNOWN_ERROR'), 120),
      dead_lettered_at = case when v_dead then clock_timestamp() else null end
  where id = p_event_id;

  return jsonb_build_object('updated', true, 'dead_lettered', v_dead, 'attempts', v_event.attempts);
end;
$$;

create or replace function public.rpc_internal_materialize_notification(
  p_event_id uuid,
  p_worker_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event private.outbox_events%rowtype;
  v_recipient uuid;
  v_copy jsonb;
  v_kind text;
  v_target_type text;
  v_notification public.notifications%rowtype;
  v_push_enabled boolean;
  v_push_limit integer;
  v_push_count integer;
  v_suppress_push boolean;
  v_org_timezone text;
  v_digest_id uuid;
begin
  select * into v_event
  from private.outbox_events
  where id = p_event_id;

  if v_event.id is null or v_event.status <> 'processing' or v_event.lease_owner <> p_worker_id then
    raise exception using errcode = '42501', message = 'OUTBOX_LEASE_MISMATCH';
  end if;

  v_recipient := private.notification_outbox_recipient(v_event);
  if v_recipient is null then
    return jsonb_build_object('materialized', false, 'reason', 'NO_RECIPIENT');
  end if;

  if not exists (
    select 1 from public.organization_members as m
    where m.organization_id = v_event.organization_id
      and m.id = v_recipient
      and m.status = 'active'
  ) then
    return jsonb_build_object('materialized', false, 'reason', 'RECIPIENT_INACTIVE');
  end if;

  v_copy := private.notification_copy_for_event(v_event.event_type, v_event.entity_type, v_event.entity_id);
  v_kind := private.notification_kind_for_event(v_event.event_type);
  v_target_type := case
    when v_event.entity_type = 'task' then 'task'
    when v_event.entity_type = 'employee_request' then 'request'
    when v_event.entity_type like 'report%' then 'report'
    else 'system'
  end;

  insert into public.notifications (
    organization_id,
    recipient_member_id,
    kind,
    title,
    body,
    target_type,
    target_id,
    safe_payload,
    dedupe_key
  ) values (
    v_event.organization_id,
    v_recipient,
    v_kind,
    v_copy ->> 'title',
    v_copy ->> 'body',
    v_target_type,
    case when v_target_type = 'system' then null else v_event.entity_id end,
    jsonb_build_object(
      'kind', v_kind,
      'target_type', v_target_type,
      'target_id', case when v_target_type = 'system' then null else v_event.entity_id end,
      'notification_source', 'outbox'
    ),
    v_event.dedupe_key
  )
  on conflict (organization_id, recipient_member_id, dedupe_key)
  do update set dedupe_key = excluded.dedupe_key
  returning * into v_notification;

  insert into public.notification_deliveries (
    organization_id, notification_id, endpoint_id, channel, status, attempts, next_attempt_at
  ) values (
    v_notification.organization_id, v_notification.id, null, 'in_app', 'provider_confirmed', 1, clock_timestamp()
  ) on conflict do nothing;

  select coalesce(np.push_enabled, true)
  into v_push_enabled
  from public.organization_members as m
  left join public.notification_preferences as np
    on np.organization_id = m.organization_id and np.member_id = m.id
  where m.organization_id = v_notification.organization_id and m.id = v_recipient;

  v_suppress_push := v_event.event_type like 'reminder.%'
    and private.notification_member_on_approved_leave(v_event.organization_id, v_recipient, clock_timestamp());
  v_push_limit := private.notification_daily_push_limit(v_event.organization_id, v_recipient, clock_timestamp());
  v_push_count := private.notification_push_count_today(v_event.organization_id, v_recipient, clock_timestamp());

  if v_push_enabled and not v_suppress_push and v_push_count < v_push_limit then
    insert into public.notification_deliveries (
      organization_id, notification_id, endpoint_id, channel, status, attempts, next_attempt_at
    )
    select
      v_notification.organization_id,
      v_notification.id,
      pe.id,
      'push',
      'pending',
      0,
      clock_timestamp()
    from public.push_endpoints as pe
    join public.user_devices as d
      on d.organization_id = pe.organization_id and d.id = pe.device_id
    where pe.organization_id = v_notification.organization_id
      and d.member_id = v_recipient
      and d.revoked_at is null
      and pe.active
    on conflict do nothing;
  elsif v_push_enabled and not v_suppress_push and v_push_count >= v_push_limit then
    select o.timezone into v_org_timezone from public.organizations as o where o.id = v_event.organization_id;
    insert into public.notifications (
      organization_id, recipient_member_id, kind, title, body, target_type, target_id, safe_payload, dedupe_key
    ) values (
      v_event.organization_id,
      v_recipient,
      'digest',
      'Bạn còn thông báo mới',
      'Một số thông báo đã được gộp vào hộp thư để tránh gửi push quá nhiều.',
      'system',
      null,
      jsonb_build_object('kind', 'digest', 'delivery_mode', 'inbox_only'),
      'digest:' || (clock_timestamp() at time zone v_org_timezone)::date::text
    )
    on conflict (organization_id, recipient_member_id, dedupe_key)
    do update set dedupe_key = excluded.dedupe_key
    returning id into v_digest_id;

    insert into public.notification_deliveries (
      organization_id, notification_id, endpoint_id, channel, status, attempts, next_attempt_at
    ) values (
      v_event.organization_id, v_digest_id, null, 'in_app', 'provider_confirmed', 1, clock_timestamp()
    ) on conflict do nothing;
  end if;

  return jsonb_build_object(
    'materialized', true,
    'notification_id', v_notification.id,
    'push_suppressed_for_leave', v_suppress_push,
    'daily_push_limit', v_push_limit,
    'push_count_before', v_push_count
  );
end;
$$;

create or replace function public.rpc_list_notifications(
  p_organization_id uuid,
  p_limit integer default 100,
  p_before timestamptz default null
)
returns jsonb
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

  return coalesce((
    select jsonb_agg(to_jsonb(n) - 'dedupe_key' order by n.created_at desc, n.id desc)
    from (
      select *
      from public.notifications
      where organization_id = p_organization_id
        and recipient_member_id = v_member_id
        and (expires_at is null or expires_at > clock_timestamp())
        and (p_before is null or created_at < p_before)
      order by created_at desc, id desc
      limit greatest(1, least(coalesce(p_limit, 100), 200))
    ) as n
  ), '[]'::jsonb);
end;
$$;

create or replace function public.rpc_mark_notification_read(p_notification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notification public.notifications%rowtype;
  v_member_id uuid;
begin
  select * into v_notification
  from public.notifications
  where id = p_notification_id
  for update;

  if v_notification.id is null then
    raise exception using errcode = 'P0002', message = 'NOTIFICATION_NOT_FOUND';
  end if;

  v_member_id := private.current_member_id(v_notification.organization_id);
  if v_member_id is null or v_member_id <> v_notification.recipient_member_id then
    raise exception using errcode = '42501', message = 'NOTIFICATION_ACCESS_DENIED';
  end if;

  update public.notifications
  set read_at = coalesce(read_at, clock_timestamp())
  where id = v_notification.id
  returning * into v_notification;

  return jsonb_build_object('notification_id', v_notification.id, 'read_at', v_notification.read_at);
end;
$$;

create or replace function public.rpc_mark_all_notifications_read(
  p_organization_id uuid,
  p_cutoff timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_count integer;
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  update public.notifications
  set read_at = coalesce(read_at, clock_timestamp())
  where organization_id = p_organization_id
    and recipient_member_id = v_member_id
    and read_at is null
    and created_at <= least(coalesce(p_cutoff, clock_timestamp()), clock_timestamp());
  get diagnostics v_count = row_count;
  return jsonb_build_object('updated_count', v_count);
end;
$$;

create or replace function public.rpc_snooze_reminder(
  p_task_id uuid,
  p_rule_key text,
  p_until timestamptz,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_member_id uuid;
  v_existing public.task_reminder_snoozes%rowtype;
  v_payload_hash text;
  v_previous private.command_idempotency%rowtype;
  v_result jsonb;
begin
  select * into v_task from public.tasks where id = p_task_id for update;
  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;
  v_member_id := private.current_member_id(v_task.organization_id);
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  if not (
    v_member_id = v_task.assignee_member_id
    or v_member_id = v_task.reviewer_member_id
    or v_member_id = v_task.blocker_owner_member_id
  ) then
    raise exception using errcode = '42501', message = 'REMINDER_SNOOZE_ACCESS_DENIED';
  end if;
  if p_rule_key not in ('unack', 'due_soon', 'overdue', 'blocked', 'reviewer') then
    raise exception using errcode = '22023', message = 'REMINDER_RULE_INVALID';
  end if;
  if p_until <= clock_timestamp() or p_until > clock_timestamp() + interval '24 hours' then
    raise exception using errcode = '22023', message = 'REMINDER_SNOOZE_RANGE_INVALID';
  end if;

  v_payload_hash := encode(extensions.digest(
    convert_to(jsonb_build_object(
      'task_id', p_task_id,
      'rule_key', p_rule_key,
      'until', p_until,
      'expected_version', p_expected_version
    )::text, 'utf8'),
    'sha256'
  ), 'hex');

  select * into v_previous
  from private.command_idempotency
  where organization_id = v_task.organization_id
    and actor_key = v_member_id::text
    and command_name = 'notification.snooze_reminder'
    and idempotency_key = p_idempotency_key;

  if v_previous.organization_id is not null then
    if v_previous.payload_hash <> v_payload_hash then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_previous.result;
  end if;

  select * into v_existing
  from public.task_reminder_snoozes
  where organization_id = v_task.organization_id
    and task_id = v_task.id
    and member_id = v_member_id
    and rule_key = p_rule_key
  for update;

  if v_existing.task_id is null then
    if coalesce(p_expected_version, 0) <> 0 then
      raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
    end if;
    insert into public.task_reminder_snoozes (
      organization_id, task_id, member_id, rule_key, snoozed_until, set_at, version
    ) values (
      v_task.organization_id, v_task.id, v_member_id, p_rule_key, p_until, clock_timestamp(), 1
    );
    v_result := jsonb_build_object('task_id', v_task.id, 'rule_key', p_rule_key, 'snoozed_until', p_until, 'version', 1);
    insert into private.command_idempotency (
      organization_id, actor_key, command_name, idempotency_key, payload_hash, result
    ) values (
      v_task.organization_id, v_member_id::text, 'notification.snooze_reminder', p_idempotency_key, v_payload_hash, v_result
    );
    return v_result;
  end if;

  if p_expected_version <> v_existing.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  update public.task_reminder_snoozes
  set snoozed_until = p_until,
      set_at = clock_timestamp(),
      version = version + 1
  where organization_id = v_task.organization_id
    and task_id = v_task.id
    and member_id = v_member_id
    and rule_key = p_rule_key
  returning * into v_existing;

  perform private.write_audit(
    v_task.organization_id,
    'task.reminder_snoozed',
    'task',
    v_task.id,
    jsonb_build_object('rule_key', p_rule_key, 'snoozed_until', p_until, 'idempotency_key', p_idempotency_key)
  );

  v_result := jsonb_build_object(
    'task_id', v_task.id,
    'rule_key', p_rule_key,
    'snoozed_until', v_existing.snoozed_until,
    'version', v_existing.version
  );
  insert into private.command_idempotency (
    organization_id, actor_key, command_name, idempotency_key, payload_hash, result
  ) values (
    v_task.organization_id, v_member_id::text, 'notification.snooze_reminder', p_idempotency_key, v_payload_hash, v_result
  );
  return v_result;
end;
$$;

create or replace function public.rpc_revoke_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device public.user_devices%rowtype;
  v_member_id uuid;
begin
  select * into v_device from public.user_devices where id = p_device_id for update;
  if v_device.id is null then
    raise exception using errcode = 'P0002', message = 'DEVICE_NOT_FOUND';
  end if;
  v_member_id := private.current_member_id(v_device.organization_id);
  if v_member_id is null or v_member_id <> v_device.member_id then
    raise exception using errcode = '42501', message = 'DEVICE_ACCESS_DENIED';
  end if;
  update public.user_devices
  set revoked_at = coalesce(revoked_at, clock_timestamp())
  where id = v_device.id;
  return jsonb_build_object('device_id', v_device.id, 'revoked', true);
end;
$$;

alter table public.push_endpoints enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.task_reminder_snoozes enable row level security;

create policy push_endpoints_read_owner
on public.push_endpoints for select to authenticated
using (
  exists (
    select 1 from public.user_devices as d
    where d.organization_id = push_endpoints.organization_id
      and d.id = push_endpoints.device_id
      and d.member_id = private.current_member_id(push_endpoints.organization_id)
  )
);

create policy notification_preferences_read_self
on public.notification_preferences for select to authenticated
using (member_id = private.current_member_id(organization_id));

create policy notifications_read_recipient
on public.notifications for select to authenticated
using (recipient_member_id = private.current_member_id(organization_id));

create policy notification_deliveries_read_recipient
on public.notification_deliveries for select to authenticated
using (
  exists (
    select 1 from public.notifications as n
    where n.organization_id = notification_deliveries.organization_id
      and n.id = notification_deliveries.notification_id
      and n.recipient_member_id = private.current_member_id(notification_deliveries.organization_id)
  )
);

create policy task_reminder_snoozes_read_self
on public.task_reminder_snoozes for select to authenticated
using (member_id = private.current_member_id(organization_id));

grant select on public.push_endpoints, public.notification_preferences, public.notifications,
  public.notification_deliveries, public.task_reminder_snoozes to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.push_endpoints, public.notification_preferences, public.notifications,
  public.notification_deliveries, public.task_reminder_snoozes
from authenticated;

revoke all on function private.notification_member_on_approved_leave(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_working_seconds_between(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_reminder_policy(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_unack_threshold_minutes(jsonb, text, integer) from public, anon, authenticated;
revoke all on function private.enqueue_task_reminders(timestamptz) from public, anon, authenticated;
revoke all on function private.notification_outbox_recipient(private.outbox_events) from public, anon, authenticated;
revoke all on function private.notification_kind_for_event(text) from public, anon, authenticated;
revoke all on function private.notification_copy_for_event(text, text, uuid) from public, anon, authenticated;
revoke all on function private.notification_daily_push_limit(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_push_count_today(uuid, uuid, timestamptz) from public, anon, authenticated;

grant execute on function private.enqueue_task_reminders(timestamptz) to service_role;
grant execute on function public.rpc_internal_enqueue_task_reminders(timestamptz) to service_role;
grant execute on function public.rpc_internal_claim_outbox(uuid, integer) to service_role;
grant execute on function public.rpc_internal_ack_outbox(uuid, uuid) to service_role;
grant execute on function public.rpc_internal_fail_outbox(uuid, uuid, text, boolean) to service_role;
grant execute on function public.rpc_internal_materialize_notification(uuid, uuid) to service_role;

grant execute on function public.rpc_list_notifications(uuid, integer, timestamptz) to authenticated;
grant execute on function public.rpc_mark_notification_read(uuid) to authenticated;
grant execute on function public.rpc_mark_all_notifications_read(uuid, timestamptz) to authenticated;
grant execute on function public.rpc_snooze_reminder(uuid, text, timestamptz, integer, text) to authenticated;
grant execute on function public.rpc_revoke_device(uuid) to authenticated;

revoke execute on function public.rpc_internal_claim_outbox(uuid, integer) from authenticated, anon;
revoke execute on function public.rpc_internal_enqueue_task_reminders(timestamptz) from authenticated, anon;
revoke execute on function public.rpc_internal_ack_outbox(uuid, uuid) from authenticated, anon;
revoke execute on function public.rpc_internal_fail_outbox(uuid, uuid, text, boolean) from authenticated, anon;
revoke execute on function public.rpc_internal_materialize_notification(uuid, uuid) from authenticated, anon;

