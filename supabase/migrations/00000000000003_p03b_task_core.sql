-- P03B: task core, transactional state machine and read projections.
-- Recurrence/templates/daily generation are intentionally deferred to P04.

create table private.outbox_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  event_type text not null check (char_length(trim(event_type)) between 1 and 120),
  entity_type text not null check (char_length(trim(entity_type)) between 1 and 120),
  entity_id uuid not null,
  dedupe_key text not null check (char_length(trim(dedupe_key)) between 1 and 240),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  status text not null default 'pending' check (status in ('pending', 'published', 'failed')),
  available_at timestamptz not null default timezone('utc', now()),
  attempts integer not null default 0 check (attempts >= 0),
  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, dedupe_key)
);

create table private.task_number_counters (
  organization_id uuid primary key references public.organizations(id) on delete restrict,
  next_number bigint not null default 1 check (next_number > 0)
);

create table public.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_number bigint not null check (task_number > 0),
  batch_id uuid,
  seller_id uuid,
  template_occurrence_id uuid,
  title text not null check (char_length(trim(title)) between 1 and 240),
  description text not null default '',
  assignee_member_id uuid not null,
  created_by_member_id uuid not null,
  reviewer_member_id uuid,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'in_review', 'done', 'canceled', 'waived')),
  planned_date date not null,
  original_due_at timestamptz not null,
  due_at timestamptz not null,
  assigned_at timestamptz not null default timezone('utc', now()),
  visible_from timestamptz not null default timezone('utc', now()),
  acknowledged_at timestamptz,
  started_at timestamptz,
  submitted_at timestamptz,
  completed_at timestamptz,
  requires_review boolean not null default false,
  requires_result boolean not null default false,
  requires_attachment boolean not null default false,
  allow_no_incident boolean not null default false,
  reminder_profile jsonb not null default '{}'::jsonb check (jsonb_typeof(reminder_profile) = 'object'),
  reminder_profile_reason text,
  reminder_profile_review_at timestamptz,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  blocked_at timestamptz,
  blocker_reason text,
  blocker_owner_member_id uuid,
  last_meaningful_update_at timestamptz not null default timezone('utc', now()),
  current_submission_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, task_number),
  foreign key (organization_id, seller_id)
    references public.sellers(organization_id, id)
    on delete restrict,
  foreign key (organization_id, assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, reviewer_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, blocker_owner_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (reviewer_member_id is null or reviewer_member_id <> assignee_member_id),
  check (not requires_review or reviewer_member_id is not null),
  check ((status = 'done' and completed_at is not null) or status <> 'done'),
  check (
    (blocked_at is null and blocker_reason is null and blocker_owner_member_id is null)
    or (blocked_at is not null and nullif(trim(blocker_reason), '') is not null and blocker_owner_member_id is not null)
  )
);

create table public.task_participants (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  member_id uuid not null,
  participant_role text not null default 'collaborator' check (participant_role in ('collaborator', 'observer')),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (organization_id, task_id, member_id),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.task_checklist_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  title text not null check (char_length(trim(title)) between 1 and 240),
  sort_order integer not null default 0 check (sort_order >= 0),
  is_required boolean not null default true,
  checked_at timestamptz,
  checked_by_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, checked_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((checked_at is null and checked_by_member_id is null) or (checked_at is not null and checked_by_member_id is not null))
);

create table public.task_submissions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  revision integer not null check (revision > 0),
  submitted_by_member_id uuid not null,
  result_text text,
  no_incident boolean not null default false,
  evidence jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence) in ('array', 'object')),
  review_state text not null default 'pending' check (review_state in ('pending', 'approved', 'changes_requested', 'withdrawn')),
  reviewed_by_member_id uuid,
  reviewed_at timestamptz,
  review_reason text,
  revision_due_at timestamptz,
  submitted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (task_id, revision),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, submitted_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, reviewed_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

alter table public.tasks
  add constraint tasks_current_submission_fk
  foreign key (organization_id, current_submission_id)
  references public.task_submissions(organization_id, id)
  on delete restrict;

create table public.task_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  task_version integer not null check (task_version > 0),
  event_type text not null check (char_length(trim(event_type)) between 1 and 120),
  actor_member_id uuid,
  event_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(event_payload) = 'object'),
  occurred_at timestamptz not null default timezone('utc', now()),
  unique (task_id, task_version),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create index tasks_org_status_planned_idx
  on public.tasks(organization_id, status, planned_date, due_at, id);
create index tasks_assignee_status_idx
  on public.tasks(organization_id, assignee_member_id, status, due_at);
create index tasks_reviewer_status_idx
  on public.tasks(organization_id, reviewer_member_id, status, due_at)
  where reviewer_member_id is not null;
create index tasks_seller_status_idx
  on public.tasks(organization_id, seller_id, status, due_at)
  where seller_id is not null;
create index task_checklist_task_idx
  on public.task_checklist_items(organization_id, task_id, sort_order, id);
create index task_submissions_task_idx
  on public.task_submissions(organization_id, task_id, revision desc);
create index task_events_task_idx
  on public.task_events(organization_id, task_id, task_version desc);
create index private_outbox_pending_idx
  on private.outbox_events(status, available_at, created_at)
  where status in ('pending', 'failed');

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function private.set_updated_at();

create or replace function private.current_actor_can_read_task(
  p_organization_id uuid,
  p_task_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tasks as t
    join public.organization_members as actor
      on actor.organization_id = t.organization_id
     and actor.id = private.current_member_id(t.organization_id)
     and actor.status = 'active'
    where t.organization_id = p_organization_id
      and t.id = p_task_id
      and (
        actor.role = 'admin'
        or t.assignee_member_id = actor.id
        or t.reviewer_member_id = actor.id
        or exists (
          select 1
          from public.task_participants as tp
          where tp.organization_id = t.organization_id
            and tp.task_id = t.id
            and tp.member_id = actor.id
        )
        or (
          actor.role = 'manager'
          and t.seller_id is not null
          and private.is_seller_manager(t.organization_id, t.seller_id, actor.id)
        )
      )
  );
$$;

create or replace function private.current_actor_can_manage_task(
  p_organization_id uuid,
  p_task_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tasks as t
    join public.organization_members as actor
      on actor.organization_id = t.organization_id
     and actor.id = private.current_member_id(t.organization_id)
     and actor.status = 'active'
    where t.organization_id = p_organization_id
      and t.id = p_task_id
      and (
        actor.role = 'admin'
        or (
          actor.role = 'manager'
          and (
            (t.seller_id is not null and private.is_seller_manager(t.organization_id, t.seller_id, actor.id))
            or (t.seller_id is null and t.assignee_member_id = actor.id)
          )
        )
      )
  );
$$;

create or replace function private.assert_task_member_scope(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.organization_members as m
    where m.organization_id = p_organization_id
      and m.id = p_member_id
      and m.status = 'active'
  ) then
    raise exception using errcode = '22023', message = 'TASK_MEMBER_NOT_ACTIVE';
  end if;

  if p_seller_id is not null
     and not private.is_seller_member(p_organization_id, p_seller_id, p_member_id) then
    raise exception using errcode = '42501', message = 'TASK_MEMBER_OUTSIDE_SELLER_SCOPE';
  end if;
end;
$$;

create or replace function private.task_idempotency_replay(
  p_organization_id uuid,
  p_actor_member_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_key text := p_actor_member_id::text;
  v_payload_hash text;
  v_existing private.command_idempotency%rowtype;
begin
  if nullif(trim(p_idempotency_key), '') is null then
    raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_organization_id::text || ':' || v_actor_key || ':' || p_command_name || ':' || p_idempotency_key,
      0
    )
  );

  v_payload_hash := pg_catalog.encode(
    extensions.digest(coalesce(p_payload, '{}'::jsonb)::text, 'sha256'),
    'hex'
  );

  select ci.*
    into v_existing
  from private.command_idempotency as ci
  where ci.organization_id = p_organization_id
    and ci.actor_key = v_actor_key
    and ci.command_name = p_command_name
    and ci.idempotency_key = p_idempotency_key;

  if v_existing.organization_id is not null then
    if v_existing.payload_hash <> v_payload_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_existing.result;
  end if;

  return null;
end;
$$;

create or replace function private.task_idempotency_store(
  p_organization_id uuid,
  p_actor_member_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_payload jsonb,
  p_result jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.command_idempotency (
    organization_id,
    actor_key,
    command_name,
    idempotency_key,
    payload_hash,
    result
  )
  values (
    p_organization_id,
    p_actor_member_id::text,
    p_command_name,
    p_idempotency_key,
    pg_catalog.encode(extensions.digest(coalesce(p_payload, '{}'::jsonb)::text, 'sha256'), 'hex'),
    p_result
  );
end;
$$;

create or replace function public.rpc_create_task(
  p_organization_id uuid,
  p_task jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_actor public.organization_members%rowtype;
  v_assignee_id uuid := nullif(p_task ->> 'assignee_member_id', '')::uuid;
  v_reviewer_id uuid := nullif(p_task ->> 'reviewer_member_id', '')::uuid;
  v_seller_id uuid := nullif(p_task ->> 'seller_id', '')::uuid;
  v_task_id uuid := extensions.gen_random_uuid();
  v_task_number bigint;
  v_task public.tasks%rowtype;
  v_replay jsonb;
  v_result jsonb;
  v_checklist jsonb := coalesce(p_task -> 'checklist', '[]'::jsonb);
  v_participants jsonb := coalesce(p_task -> 'participant_member_ids', '[]'::jsonb);
  v_item jsonb;
  v_member_text text;
  v_request_id uuid := extensions.gen_random_uuid();
  v_requires_review boolean := coalesce((p_task ->> 'requires_review')::boolean, false);
  v_priority text := coalesce(nullif(p_task ->> 'priority', ''), 'normal');
  v_planned_date date := nullif(p_task ->> 'planned_date', '')::date;
  v_due_at timestamptz := nullif(p_task ->> 'due_at', '')::timestamptz;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = p_organization_id and m.id = v_actor_id;

  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'task.create',
    p_idempotency_key,
    p_task
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if nullif(trim(p_task ->> 'title'), '') is null
     or v_assignee_id is null
     or v_planned_date is null
     or v_due_at is null then
    raise exception using errcode = '22023', message = 'TASK_REQUIRED_FIELDS_MISSING';
  end if;

  if v_priority not in ('low', 'normal', 'high', 'urgent') then
    raise exception using errcode = '22023', message = 'TASK_PRIORITY_INVALID';
  end if;

  if v_requires_review and v_reviewer_id is null then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_REQUIRED';
  end if;

  if v_reviewer_id is not null and v_reviewer_id = v_assignee_id then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
  end if;

  perform private.assert_task_member_scope(p_organization_id, v_seller_id, v_assignee_id);
  if v_reviewer_id is not null then
    perform private.assert_task_member_scope(p_organization_id, v_seller_id, v_reviewer_id);
  end if;

  if v_assignee_id <> v_actor_id then
    if v_actor.role = 'admin' then
      null;
    elsif v_actor.role = 'manager'
      and v_seller_id is not null
      and private.is_seller_manager(p_organization_id, v_seller_id, v_actor_id) then
      null;
    else
      raise exception using errcode = '42501', message = 'TASK_ASSIGNMENT_SCOPE_DENIED';
    end if;
  elsif v_seller_id is not null
    and v_actor.role = 'manager'
    and not private.is_seller_manager(p_organization_id, v_seller_id, v_actor_id) then
    -- Managers may self-create only inside a seller they manage. Employees may self-create in membership scope.
    raise exception using errcode = '42501', message = 'TASK_ASSIGNMENT_SCOPE_DENIED';
  end if;

  if v_seller_id is null and v_actor.role <> 'admin' and v_reviewer_id is not null then
    raise exception using errcode = '42501', message = 'INTERNAL_TASK_REVIEW_ASSIGNMENT_DENIED';
  end if;

  if jsonb_typeof(v_checklist) <> 'array' or jsonb_typeof(v_participants) <> 'array' then
    raise exception using errcode = '22023', message = 'TASK_ARRAY_FIELD_INVALID';
  end if;

  insert into private.task_number_counters (organization_id, next_number)
  values (p_organization_id, 2)
  on conflict (organization_id) do update
    set next_number = private.task_number_counters.next_number + 1
  returning next_number - 1 into v_task_number;

  insert into public.tasks (
    id,
    organization_id,
    task_number,
    seller_id,
    title,
    description,
    assignee_member_id,
    created_by_member_id,
    reviewer_member_id,
    priority,
    planned_date,
    original_due_at,
    due_at,
    visible_from,
    requires_review,
    requires_result,
    requires_attachment,
    allow_no_incident,
    reminder_profile,
    estimated_minutes
  )
  values (
    v_task_id,
    p_organization_id,
    v_task_number,
    v_seller_id,
    trim(p_task ->> 'title'),
    coalesce(p_task ->> 'description', ''),
    v_assignee_id,
    v_actor_id,
    v_reviewer_id,
    v_priority,
    v_planned_date,
    v_due_at,
    v_due_at,
    coalesce(nullif(p_task ->> 'visible_from', '')::timestamptz, timezone('utc', now())),
    v_requires_review,
    coalesce((p_task ->> 'requires_result')::boolean, false),
    coalesce((p_task ->> 'requires_attachment')::boolean, false),
    coalesce((p_task ->> 'allow_no_incident')::boolean, false),
    case
      when jsonb_typeof(coalesce(p_task -> 'reminder_profile', '{}'::jsonb)) = 'object'
        then coalesce(p_task -> 'reminder_profile', '{}'::jsonb)
      else '{}'::jsonb
    end,
    nullif(p_task ->> 'estimated_minutes', '')::integer
  )
  returning * into v_task;

  for v_item in select value from jsonb_array_elements(v_checklist)
  loop
    if nullif(trim(v_item ->> 'title'), '') is null then
      raise exception using errcode = '22023', message = 'TASK_CHECKLIST_TITLE_REQUIRED';
    end if;

    insert into public.task_checklist_items (
      organization_id,
      task_id,
      title,
      sort_order,
      is_required
    )
    values (
      p_organization_id,
      v_task_id,
      trim(v_item ->> 'title'),
      coalesce((v_item ->> 'sort_order')::integer, 0),
      coalesce((v_item ->> 'is_required')::boolean, true)
    );
  end loop;

  for v_member_text in select value #>> '{}' from jsonb_array_elements(v_participants)
  loop
    if v_member_text::uuid = v_assignee_id or v_member_text::uuid = v_reviewer_id then
      continue;
    end if;
    perform private.assert_task_member_scope(p_organization_id, v_seller_id, v_member_text::uuid);
    insert into public.task_participants (organization_id, task_id, member_id)
    values (p_organization_id, v_task_id, v_member_text::uuid)
    on conflict do nothing;
  end loop;

  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload
  )
  values (
    p_organization_id,
    v_task_id,
    1,
    'created',
    v_actor_id,
    jsonb_build_object(
      'assignee_member_id', v_assignee_id,
      'reviewer_member_id', v_reviewer_id,
      'seller_id', v_seller_id,
      'due_at', v_due_at,
      'planned_date', v_planned_date
    )
  );

  perform private.write_audit(
    p_organization_id,
    'task.created',
    'task',
    v_task_id,
    jsonb_build_object('task_number', v_task_number, 'seller_id', v_seller_id),
    v_request_id
  );

  insert into private.outbox_events (
    organization_id,
    event_type,
    entity_type,
    entity_id,
    dedupe_key,
    payload
  )
  values (
    p_organization_id,
    'task.assigned',
    'task',
    v_task_id,
    'task:' || v_task_id::text || ':assigned:1',
    jsonb_build_object('task_id', v_task_id, 'assignee_member_id', v_assignee_id, 'task_version', 1)
  );

  v_result := jsonb_build_object(
    'task_id', v_task_id,
    'task_number', v_task_number,
    'status', v_task.status,
    'version', v_task.version
  );

  perform private.task_idempotency_store(
    p_organization_id,
    v_actor_id,
    'task.create',
    p_idempotency_key,
    p_task,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_task_command(
  p_task_id uuid,
  p_action text,
  p_payload jsonb,
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
  v_actor_id uuid;
  v_actor public.organization_members%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_command_name text := 'task.' || trim(coalesce(p_action, ''));
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_replay jsonb;
  v_result jsonb;
  v_event_type text;
  v_event_payload jsonb := '{}'::jsonb;
  v_outbox_type text;
  v_outbox_payload jsonb;
  v_status text;
  v_assignee_id uuid;
  v_acknowledged_at timestamptz;
  v_started_at timestamptz;
  v_submitted_at timestamptz;
  v_completed_at timestamptz;
  v_due_at timestamptz;
  v_blocked_at timestamptz;
  v_blocker_reason text;
  v_blocker_owner_id uuid;
  v_current_submission_id uuid;
  v_submission_id uuid;
  v_revision integer;
  v_item_id uuid;
  v_target_member_id uuid;
  v_reason text;
  v_missing_items jsonb;
  v_request_id uuid := extensions.gen_random_uuid();
begin
  select t.* into v_task
  from public.tasks as t
  where t.id = p_task_id
  for update;

  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;

  v_actor_id := private.current_member_id(v_task.organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = v_task.organization_id and m.id = v_actor_id;

  v_replay := private.task_idempotency_replay(
    v_task.organization_id,
    v_actor_id,
    v_command_name,
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'payload', v_payload)
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if p_expected_version is null or p_expected_version <> v_task.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  if not private.current_actor_can_read_task(v_task.organization_id, v_task.id) then
    raise exception using errcode = '42501', message = 'TASK_ACCESS_DENIED';
  end if;

  v_status := v_task.status;
  v_assignee_id := v_task.assignee_member_id;
  v_acknowledged_at := v_task.acknowledged_at;
  v_started_at := v_task.started_at;
  v_submitted_at := v_task.submitted_at;
  v_completed_at := v_task.completed_at;
  v_due_at := v_task.due_at;
  v_blocked_at := v_task.blocked_at;
  v_blocker_reason := v_task.blocker_reason;
  v_blocker_owner_id := v_task.blocker_owner_member_id;
  v_current_submission_id := v_task.current_submission_id;

  if p_action = 'ack' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status <> 'todo' then
      raise exception using errcode = '42501', message = 'TASK_ACK_NOT_ALLOWED';
    end if;
    if v_acknowledged_at is null then
      v_acknowledged_at := v_now;
    end if;
    v_event_type := 'acknowledged';

  elsif p_action = 'start' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status <> 'todo' then
      raise exception using errcode = '42501', message = 'TASK_START_NOT_ALLOWED';
    end if;
    v_acknowledged_at := coalesce(v_acknowledged_at, v_now);
    v_started_at := coalesce(v_started_at, v_now);
    v_status := 'in_progress';
    v_event_type := 'started';
    v_event_payload := jsonb_build_object('auto_acknowledged', v_task.acknowledged_at is null);

  elsif p_action = 'checklist' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status not in ('todo', 'in_progress') then
      raise exception using errcode = '42501', message = 'TASK_CHECKLIST_NOT_EDITABLE';
    end if;
    v_item_id := nullif(v_payload ->> 'item_id', '')::uuid;
    if v_item_id is null or not exists (
      select 1 from public.task_checklist_items as item
      where item.organization_id = v_task.organization_id
        and item.task_id = v_task.id
        and item.id = v_item_id
    ) then
      raise exception using errcode = 'P0002', message = 'TASK_CHECKLIST_ITEM_NOT_FOUND';
    end if;
    update public.task_checklist_items
    set checked_at = case when coalesce((v_payload ->> 'checked')::boolean, false) then v_now else null end,
        checked_by_member_id = case when coalesce((v_payload ->> 'checked')::boolean, false) then v_actor_id else null end
    where organization_id = v_task.organization_id and task_id = v_task.id and id = v_item_id;
    v_event_type := 'checklist_updated';
    v_event_payload := jsonb_build_object(
      'item_id', v_item_id,
      'checked', coalesce((v_payload ->> 'checked')::boolean, false)
    );

  elsif p_action = 'submit' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status not in ('todo', 'in_progress') then
      raise exception using errcode = '42501', message = 'TASK_SUBMIT_NOT_ALLOWED';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object('id', item.id, 'title', item.title) order by item.sort_order, item.id), '[]'::jsonb)
      into v_missing_items
    from public.task_checklist_items as item
    where item.organization_id = v_task.organization_id
      and item.task_id = v_task.id
      and item.is_required
      and item.checked_at is null;

    if jsonb_array_length(v_missing_items) > 0 then
      raise exception using
        errcode = '23514',
        message = 'TASK_REQUIRED_CHECKLIST_INCOMPLETE',
        detail = v_missing_items::text;
    end if;

    if v_task.requires_result
      and nullif(trim(coalesce(v_payload ->> 'result_text', '')), '') is null
      and not (v_task.allow_no_incident and coalesce((v_payload ->> 'no_incident')::boolean, false)) then
      raise exception using errcode = '23514', message = 'TASK_RESULT_REQUIRED';
    end if;

    if v_task.requires_attachment then
      if v_payload -> 'evidence' is null
        or jsonb_typeof(v_payload -> 'evidence') not in ('array', 'object')
        or (jsonb_typeof(v_payload -> 'evidence') = 'array' and jsonb_array_length(v_payload -> 'evidence') = 0)
        or (jsonb_typeof(v_payload -> 'evidence') = 'object' and v_payload -> 'evidence' = '{}'::jsonb) then
        raise exception using errcode = '23514', message = 'TASK_EVIDENCE_REQUIRED';
      end if;
    end if;

    if v_task.requires_review and v_task.reviewer_member_id is null then
      raise exception using errcode = '23514', message = 'TASK_REVIEWER_REQUIRED';
    end if;
    if v_task.reviewer_member_id = v_task.assignee_member_id then
      raise exception using errcode = '23514', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
    end if;

    select coalesce(max(s.revision), 0) + 1 into v_revision
    from public.task_submissions as s
    where s.organization_id = v_task.organization_id and s.task_id = v_task.id;
    v_submission_id := extensions.gen_random_uuid();

    insert into public.task_submissions (
      id,
      organization_id,
      task_id,
      revision,
      submitted_by_member_id,
      result_text,
      no_incident,
      evidence,
      review_state
    )
    values (
      v_submission_id,
      v_task.organization_id,
      v_task.id,
      v_revision,
      v_actor_id,
      nullif(trim(v_payload ->> 'result_text'), ''),
      coalesce((v_payload ->> 'no_incident')::boolean, false),
      coalesce(v_payload -> 'evidence', '[]'::jsonb),
      case when v_task.requires_review then 'pending' else 'approved' end
    );

    v_current_submission_id := v_submission_id;
    v_submitted_at := v_now;
    if v_task.requires_review then
      v_status := 'in_review';
      v_event_type := 'submitted_for_review';
      v_outbox_type := 'task.review_requested';
      v_outbox_payload := jsonb_build_object(
        'task_id', v_task.id,
        'reviewer_member_id', v_task.reviewer_member_id,
        'submission_id', v_submission_id
      );
    else
      v_status := 'done';
      v_completed_at := v_now;
      v_event_type := 'completed';
    end if;
    v_event_payload := jsonb_build_object('submission_id', v_submission_id, 'revision', v_revision);

  elsif p_action = 'withdraw_submission' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status <> 'in_review' or v_task.current_submission_id is null then
      raise exception using errcode = '42501', message = 'TASK_WITHDRAW_NOT_ALLOWED';
    end if;
    update public.task_submissions
    set review_state = 'withdrawn'
    where organization_id = v_task.organization_id
      and task_id = v_task.id
      and id = v_task.current_submission_id
      and review_state = 'pending';
    v_status := 'in_progress';
    v_submitted_at := null;
    v_event_type := 'submission_withdrawn';
    v_event_payload := jsonb_build_object('submission_id', v_task.current_submission_id);

  elsif p_action = 'approve' then
    if v_task.status <> 'in_review' or v_task.current_submission_id is null then
      raise exception using errcode = '23514', message = 'TASK_NOT_IN_REVIEW';
    end if;
    if v_actor_id = v_task.assignee_member_id then
      raise exception using errcode = '42501', message = 'TASK_SELF_APPROVAL_DENIED';
    end if;
    if v_actor.role <> 'admin' and v_actor_id <> v_task.reviewer_member_id then
      raise exception using errcode = '42501', message = 'TASK_REVIEW_DENIED';
    end if;
    update public.task_submissions
    set review_state = 'approved', reviewed_by_member_id = v_actor_id, reviewed_at = v_now, review_reason = null
    where organization_id = v_task.organization_id and task_id = v_task.id and id = v_task.current_submission_id;
    v_status := 'done';
    v_completed_at := v_now;
    v_event_type := 'approved';
    v_event_payload := jsonb_build_object('submission_id', v_task.current_submission_id);

  elsif p_action = 'request_changes' then
    if v_task.status <> 'in_review' or v_task.current_submission_id is null then
      raise exception using errcode = '23514', message = 'TASK_NOT_IN_REVIEW';
    end if;
    if v_actor_id = v_task.assignee_member_id then
      raise exception using errcode = '42501', message = 'TASK_SELF_APPROVAL_DENIED';
    end if;
    if v_actor.role <> 'admin' and v_actor_id <> v_task.reviewer_member_id then
      raise exception using errcode = '42501', message = 'TASK_REVIEW_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_CHANGE_REASON_REQUIRED';
    end if;
    update public.task_submissions
    set review_state = 'changes_requested',
        reviewed_by_member_id = v_actor_id,
        reviewed_at = v_now,
        review_reason = v_reason,
        revision_due_at = coalesce(nullif(v_payload ->> 'revision_due_at', '')::timestamptz, v_task.due_at)
    where organization_id = v_task.organization_id and task_id = v_task.id and id = v_task.current_submission_id;
    v_status := 'in_progress';
    v_submitted_at := null;
    v_completed_at := null;
    v_event_type := 'changes_requested';
    v_event_payload := jsonb_build_object(
      'submission_id', v_task.current_submission_id,
      'reason', v_reason,
      'revision_due_at', coalesce(nullif(v_payload ->> 'revision_due_at', '')::timestamptz, v_task.due_at)
    );

  elsif p_action = 'report_blocker' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status not in ('todo', 'in_progress') then
      raise exception using errcode = '42501', message = 'TASK_BLOCKER_REPORT_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    v_blocker_owner_id := coalesce(nullif(v_payload ->> 'owner_member_id', '')::uuid, v_actor_id);
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_BLOCKER_REASON_REQUIRED';
    end if;
    perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_blocker_owner_id);
    v_blocked_at := v_now;
    v_blocker_reason := v_reason;
    v_event_type := 'blocker_reported';
    v_event_payload := jsonb_build_object('owner_member_id', v_blocker_owner_id, 'reason', v_reason);

  elsif p_action = 'resolve_blocker' then
    if v_task.blocked_at is null then
      raise exception using errcode = '23514', message = 'TASK_BLOCKER_NOT_FOUND';
    end if;
    if v_actor_id <> v_task.assignee_member_id
      and v_actor_id <> v_task.blocker_owner_member_id
      and not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_BLOCKER_RESOLVE_DENIED';
    end if;
    v_event_type := 'blocker_resolved';
    v_event_payload := jsonb_build_object('previous_reason', v_task.blocker_reason);
    v_blocked_at := null;
    v_blocker_reason := null;
    v_blocker_owner_id := null;

  elsif p_action = 'reassign' then
    if v_task.status not in ('todo', 'in_progress') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_REASSIGN_DENIED';
    end if;
    v_target_member_id := nullif(v_payload ->> 'assignee_member_id', '')::uuid;
    if v_target_member_id is null then
      raise exception using errcode = '22023', message = 'TASK_ASSIGNEE_REQUIRED';
    end if;
    if v_task.seller_id is null and v_actor.role <> 'admin' and v_target_member_id <> v_actor_id then
      raise exception using errcode = '42501', message = 'INTERNAL_TASK_REASSIGN_DENIED';
    end if;
    perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_target_member_id);
    if v_task.reviewer_member_id = v_target_member_id then
      raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
    end if;
    v_event_payload := jsonb_build_object(
      'from_assignee_member_id', v_task.assignee_member_id,
      'to_assignee_member_id', v_target_member_id
    );
    v_assignee_id := v_target_member_id;
    v_acknowledged_at := null;
    v_event_type := 'reassigned';
    v_outbox_type := 'task.assigned';
    v_outbox_payload := jsonb_build_object('task_id', v_task.id, 'assignee_member_id', v_target_member_id);

  elsif p_action = 'change_deadline' then
    if v_task.status in ('canceled', 'waived') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_DEADLINE_CHANGE_DENIED';
    end if;
    v_due_at := nullif(v_payload ->> 'due_at', '')::timestamptz;
    if v_due_at is null then
      raise exception using errcode = '22023', message = 'TASK_DUE_AT_REQUIRED';
    end if;
    v_event_type := 'deadline_changed';
    v_event_payload := jsonb_build_object('before', v_task.due_at, 'after', v_due_at);

  elsif p_action = 'cancel' then
    if v_task.status in ('done', 'canceled', 'waived') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_CANCEL_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_CANCEL_REASON_REQUIRED';
    end if;
    v_status := 'canceled';
    v_completed_at := null;
    v_event_type := 'canceled';
    v_event_payload := jsonb_build_object('reason', v_reason);

  elsif p_action = 'waive' then
    if v_task.status in ('done', 'canceled', 'waived') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_WAIVE_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_WAIVE_REASON_REQUIRED';
    end if;
    v_status := 'waived';
    v_completed_at := null;
    v_event_type := 'waived';
    v_event_payload := jsonb_build_object('reason', v_reason);

  elsif p_action = 'reopen' then
    if v_task.status <> 'done' or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_REOPEN_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_REOPEN_REASON_REQUIRED';
    end if;
    v_status := 'in_progress';
    v_completed_at := null;
    v_event_type := 'reopened';
    v_event_payload := jsonb_build_object('reason', v_reason, 'previous_completed_at', v_task.completed_at);

  else
    raise exception using errcode = '22023', message = 'TASK_ACTION_INVALID';
  end if;

  update public.tasks
  set status = v_status,
      assignee_member_id = v_assignee_id,
      acknowledged_at = v_acknowledged_at,
      started_at = v_started_at,
      submitted_at = v_submitted_at,
      completed_at = v_completed_at,
      due_at = v_due_at,
      blocked_at = v_blocked_at,
      blocker_reason = v_blocker_reason,
      blocker_owner_member_id = v_blocker_owner_id,
      current_submission_id = v_current_submission_id,
      last_meaningful_update_at = v_now,
      version = version + 1
  where id = v_task.id
  returning * into v_task;

  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload
  )
  values (
    v_task.organization_id,
    v_task.id,
    v_task.version,
    v_event_type,
    v_actor_id,
    v_event_payload
  );

  perform private.write_audit(
    v_task.organization_id,
    'task.' || v_event_type,
    'task',
    v_task.id,
    jsonb_build_object('task_version', v_task.version, 'status', v_task.status),
    v_request_id
  );

  if v_outbox_type is not null then
    insert into private.outbox_events (
      organization_id,
      event_type,
      entity_type,
      entity_id,
      dedupe_key,
      payload
    )
    values (
      v_task.organization_id,
      v_outbox_type,
      'task',
      v_task.id,
      'task:' || v_task.id::text || ':' || replace(v_outbox_type, '.', '-') || ':' || v_task.version::text,
      coalesce(v_outbox_payload, '{}'::jsonb) || jsonb_build_object('task_version', v_task.version)
    );
  end if;

  v_result := jsonb_build_object(
    'task_id', v_task.id,
    'status', v_task.status,
    'version', v_task.version,
    'event_type', v_event_type,
    'submission_id', v_submission_id
  );

  perform private.task_idempotency_store(
    v_task.organization_id,
    v_actor_id,
    v_command_name,
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'payload', v_payload),
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_list_tasks(
  p_organization_id uuid,
  p_include_terminal boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'task_number', t.task_number,
        'title', t.title,
        'description', t.description,
        'seller_id', t.seller_id,
        'seller_name', s.name,
        'assignee_member_id', t.assignee_member_id,
        'assignee_name', assignee.display_name,
        'reviewer_member_id', t.reviewer_member_id,
        'reviewer_name', reviewer.display_name,
        'priority', t.priority,
        'status', t.status,
        'planned_date', t.planned_date,
        'original_due_at', t.original_due_at,
        'due_at', t.due_at,
        'acknowledged_at', t.acknowledged_at,
        'blocked_at', t.blocked_at,
        'blocker_reason', t.blocker_reason,
        'requires_review', t.requires_review,
        'version', t.version,
        'checklist_total', (select count(*) from public.task_checklist_items item where item.organization_id = t.organization_id and item.task_id = t.id),
        'checklist_checked', (select count(*) from public.task_checklist_items item where item.organization_id = t.organization_id and item.task_id = t.id and item.checked_at is not null)
      )
      order by
        case t.priority when 'urgent' then 0 when 'high' then 1 when 'normal' then 2 else 3 end,
        t.due_at,
        t.task_number
    ),
    '[]'::jsonb
  )
  from public.tasks as t
  join public.organization_members as assignee
    on assignee.organization_id = t.organization_id and assignee.id = t.assignee_member_id
  left join public.organization_members as reviewer
    on reviewer.organization_id = t.organization_id and reviewer.id = t.reviewer_member_id
  left join public.sellers as s
    on s.organization_id = t.organization_id and s.id = t.seller_id
  where t.organization_id = p_organization_id
    and private.current_actor_can_read_task(t.organization_id, t.id)
    and (p_include_terminal or t.status not in ('done', 'canceled', 'waived'));
$$;

create or replace function public.rpc_get_task(p_task_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_actor_id uuid;
  v_actor public.organization_members%rowtype;
begin
  select t.* into v_task from public.tasks as t where t.id = p_task_id;
  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;
  if not private.current_actor_can_read_task(v_task.organization_id, v_task.id) then
    raise exception using errcode = '42501', message = 'TASK_ACCESS_DENIED';
  end if;

  v_actor_id := private.current_member_id(v_task.organization_id);
  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = v_task.organization_id and m.id = v_actor_id;

  return (
    select jsonb_build_object(
      'id', t.id,
      'organization_id', t.organization_id,
      'task_number', t.task_number,
      'seller_id', t.seller_id,
      'seller_name', s.name,
      'title', t.title,
      'description', t.description,
      'assignee_member_id', t.assignee_member_id,
      'assignee_name', assignee.display_name,
      'created_by_member_id', t.created_by_member_id,
      'created_by_name', creator.display_name,
      'reviewer_member_id', t.reviewer_member_id,
      'reviewer_name', reviewer.display_name,
      'priority', t.priority,
      'status', t.status,
      'planned_date', t.planned_date,
      'original_due_at', t.original_due_at,
      'due_at', t.due_at,
      'assigned_at', t.assigned_at,
      'visible_from', t.visible_from,
      'acknowledged_at', t.acknowledged_at,
      'started_at', t.started_at,
      'submitted_at', t.submitted_at,
      'completed_at', t.completed_at,
      'requires_review', t.requires_review,
      'requires_result', t.requires_result,
      'requires_attachment', t.requires_attachment,
      'allow_no_incident', t.allow_no_incident,
      'blocked_at', t.blocked_at,
      'blocker_reason', t.blocker_reason,
      'blocker_owner_member_id', t.blocker_owner_member_id,
      'current_submission_id', t.current_submission_id,
      'version', t.version,
      'checklist', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', item.id,
          'title', item.title,
          'sort_order', item.sort_order,
          'is_required', item.is_required,
          'checked_at', item.checked_at,
          'checked_by_member_id', item.checked_by_member_id
        ) order by item.sort_order, item.id), '[]'::jsonb)
        from public.task_checklist_items as item
        where item.organization_id = t.organization_id and item.task_id = t.id
      ),
      'submissions', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', sub.id,
          'revision', sub.revision,
          'submitted_by_member_id', sub.submitted_by_member_id,
          'result_text', sub.result_text,
          'no_incident', sub.no_incident,
          'evidence', sub.evidence,
          'review_state', sub.review_state,
          'reviewed_by_member_id', sub.reviewed_by_member_id,
          'reviewed_at', sub.reviewed_at,
          'review_reason', sub.review_reason,
          'revision_due_at', sub.revision_due_at,
          'submitted_at', sub.submitted_at
        ) order by sub.revision desc), '[]'::jsonb)
        from public.task_submissions as sub
        where sub.organization_id = t.organization_id and sub.task_id = t.id
      ),
      'events', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', ev.id,
          'task_version', ev.task_version,
          'event_type', ev.event_type,
          'actor_member_id', ev.actor_member_id,
          'actor_name', actor_member.display_name,
          'event_payload', ev.event_payload,
          'occurred_at', ev.occurred_at
        ) order by ev.task_version desc), '[]'::jsonb)
        from public.task_events as ev
        left join public.organization_members as actor_member
          on actor_member.organization_id = ev.organization_id and actor_member.id = ev.actor_member_id
        where ev.organization_id = t.organization_id and ev.task_id = t.id
      ),
      'permissions', jsonb_build_object(
        'is_assignee', v_actor_id = t.assignee_member_id,
        'can_review', v_actor_id <> t.assignee_member_id and (v_actor.role = 'admin' or v_actor_id = t.reviewer_member_id),
        'can_manage', private.current_actor_can_manage_task(t.organization_id, t.id)
      )
    )
    from public.tasks as t
    join public.organization_members as assignee
      on assignee.organization_id = t.organization_id and assignee.id = t.assignee_member_id
    join public.organization_members as creator
      on creator.organization_id = t.organization_id and creator.id = t.created_by_member_id
    left join public.organization_members as reviewer
      on reviewer.organization_id = t.organization_id and reviewer.id = t.reviewer_member_id
    left join public.sellers as s
      on s.organization_id = t.organization_id and s.id = t.seller_id
    where t.id = v_task.id
  );
end;
$$;

revoke all on function private.current_actor_can_read_task(uuid, uuid) from public, anon;
revoke all on function private.current_actor_can_manage_task(uuid, uuid) from public, anon;
revoke all on function private.assert_task_member_scope(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function private.task_idempotency_replay(uuid, uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function private.task_idempotency_store(uuid, uuid, text, text, jsonb, jsonb) from public, anon, authenticated;
grant execute on function private.current_actor_can_read_task(uuid, uuid) to authenticated;
grant execute on function private.current_actor_can_manage_task(uuid, uuid) to authenticated;

revoke all on function public.rpc_create_task(uuid, jsonb, text) from public, anon;
revoke all on function public.rpc_task_command(uuid, text, jsonb, integer, text) from public, anon;
revoke all on function public.rpc_list_tasks(uuid, boolean) from public, anon;
revoke all on function public.rpc_get_task(uuid) from public, anon;
grant execute on function public.rpc_create_task(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_task_command(uuid, text, jsonb, integer, text) to authenticated;
grant execute on function public.rpc_list_tasks(uuid, boolean) to authenticated;
grant execute on function public.rpc_get_task(uuid) to authenticated;

alter table public.tasks enable row level security;
alter table public.task_participants enable row level security;
alter table public.task_checklist_items enable row level security;
alter table public.task_submissions enable row level security;
alter table public.task_events enable row level security;
alter table private.outbox_events enable row level security;
alter table private.task_number_counters enable row level security;

create policy tasks_read_by_scope
on public.tasks for select to authenticated
using (private.current_actor_can_read_task(organization_id, id));

create policy task_participants_read_by_scope
on public.task_participants for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

create policy task_checklist_read_by_scope
on public.task_checklist_items for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

create policy task_submissions_read_by_scope
on public.task_submissions for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

create policy task_events_read_by_scope
on public.task_events for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

revoke all on public.tasks from anon;
revoke all on public.task_participants from anon;
revoke all on public.task_checklist_items from anon;
revoke all on public.task_submissions from anon;
revoke all on public.task_events from anon;
revoke all on private.outbox_events from anon, authenticated;
revoke all on private.task_number_counters from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.tasks, public.task_participants, public.task_checklist_items,
     public.task_submissions, public.task_events
  from authenticated;

grant select
  on public.tasks, public.task_participants, public.task_checklist_items,
     public.task_submissions, public.task_events
  to authenticated;
