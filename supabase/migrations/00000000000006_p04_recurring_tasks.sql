-- P04: recurring task templates, version-forward schedules and safe materialization.
--
-- Design goals:
--   template -> immutable version snapshot -> target snapshot -> occurrence
--   one occurrence per template/target-key/work-date
--   projected calendar rows remain virtual until this materializer creates an occurrence
--   pause/resume never backfills the paused window
--   unavailable assignees become coverage issues instead of silent assignment/drop

create table public.recurring_task_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'paused', 'ended', 'needs_attention')),
  current_version_number integer not null default 1 check (current_version_number > 0),
  generation_floor_date date not null,
  last_generated_work_date date,
  paused_at timestamptz,
  ended_at timestamptz,
  attention_code text,
  attention_context jsonb not null default '{}'::jsonb
    check (jsonb_typeof(attention_context) = 'object'),
  created_by_member_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((status = 'paused' and paused_at is not null) or status <> 'paused'),
  check ((status = 'ended' and ended_at is not null) or status <> 'ended')
);

create table public.recurring_task_template_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_id uuid not null,
  version_number integer not null check (version_number > 0),
  effective_from date not null,
  title text not null check (char_length(trim(title)) between 1 and 240),
  description text not null default '',
  schedule_kind text not null check (schedule_kind in ('working_days', 'every_day', 'weekdays')),
  weekdays smallint[] not null default '{}'::smallint[],
  start_date date not null,
  end_date date,
  due_time time without time zone not null,
  reviewer_member_id uuid,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  requires_review boolean not null default false,
  requires_result boolean not null default true,
  requires_attachment boolean not null default false,
  allow_no_incident boolean not null default false,
  reminder_profile jsonb not null default '{}'::jsonb
    check (jsonb_typeof(reminder_profile) = 'object'),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  checklist jsonb not null default '[]'::jsonb check (jsonb_typeof(checklist) = 'array'),
  created_by_member_id uuid not null,
  change_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, template_id, version_number),
  foreign key (organization_id, template_id)
    references public.recurring_task_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, reviewer_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (end_date is null or end_date >= start_date),
  check (
    (schedule_kind = 'weekdays' and cardinality(weekdays) between 1 and 7)
    or (schedule_kind in ('working_days', 'every_day') and cardinality(weekdays) = 0)
  ),
  check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (not requires_review or reviewer_member_id is not null),
  check (version_number = 1 or nullif(trim(change_reason), '') is not null)
);

create table public.recurring_task_targets (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_id uuid not null,
  version_id uuid not null,
  target_key text not null default 'primary'
    check (target_key ~ '^[a-z0-9][a-z0-9_-]{0,39}$'),
  seller_id uuid,
  assignment_mode text not null check (assignment_mode in ('fixed', 'seller_owner')),
  assignee_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, version_id, target_key),
  foreign key (organization_id, template_id)
    references public.recurring_task_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, version_id)
    references public.recurring_task_template_versions(organization_id, id)
    on delete restrict,
  foreign key (organization_id, seller_id)
    references public.sellers(organization_id, id)
    on delete restrict,
  foreign key (organization_id, assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((assignment_mode = 'fixed' and assignee_member_id is not null) or assignment_mode <> 'fixed'),
  check ((assignment_mode = 'seller_owner' and seller_id is not null) or assignment_mode <> 'seller_owner')
);

create table public.recurring_task_occurrences (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_id uuid not null,
  version_id uuid not null,
  target_id uuid not null,
  target_key text not null,
  work_date date not null,
  due_at timestamptz not null,
  state text not null default 'pending'
    check (state in ('pending', 'materialized', 'needs_assignment', 'skipped')),
  generation_kind text not null default 'scheduled'
    check (generation_kind in ('scheduled', 'system_delay', 'manual')),
  issue_code text,
  issue_context jsonb not null default '{}'::jsonb
    check (jsonb_typeof(issue_context) = 'object'),
  resolved_assignee_member_id uuid,
  assigned_by_member_id uuid,
  assignment_reason text,
  task_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, template_id, target_key, work_date),
  foreign key (organization_id, template_id)
    references public.recurring_task_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, version_id)
    references public.recurring_task_template_versions(organization_id, id)
    on delete restrict,
  foreign key (organization_id, target_id)
    references public.recurring_task_targets(organization_id, id)
    on delete restrict,
  foreign key (organization_id, resolved_assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, assigned_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (
    (resolved_assignee_member_id is null and assigned_by_member_id is null and assignment_reason is null)
    or (
      resolved_assignee_member_id is not null
      and assigned_by_member_id is not null
      and nullif(trim(assignment_reason), '') is not null
    )
  ),
  check ((state = 'materialized' and task_id is not null) or state <> 'materialized'),
  check ((state in ('needs_assignment', 'skipped') and task_id is null) or state not in ('needs_assignment', 'skipped'))
);

create unique index recurring_occurrences_task_idx
  on public.recurring_task_occurrences(organization_id, task_id)
  where task_id is not null;
create index recurring_versions_template_effective_idx
  on public.recurring_task_template_versions(organization_id, template_id, effective_from desc, version_number desc);
create index recurring_targets_template_version_idx
  on public.recurring_task_targets(organization_id, template_id, version_id, target_key);
create index recurring_occurrences_calendar_idx
  on public.recurring_task_occurrences(organization_id, work_date, state, due_at, id);
create index recurring_occurrences_issue_idx
  on public.recurring_task_occurrences(organization_id, state, work_date, id)
  where state = 'needs_assignment';

alter table public.recurring_task_occurrences
  add constraint recurring_occurrences_task_fk
  foreign key (organization_id, task_id)
  references public.tasks(organization_id, id)
  on delete restrict;

alter table public.tasks
  add constraint tasks_template_occurrence_fk
  foreign key (organization_id, template_occurrence_id)
  references public.recurring_task_occurrences(organization_id, id)
  on delete restrict;

create trigger recurring_task_templates_set_updated_at
before update on public.recurring_task_templates
for each row execute function private.set_updated_at();

create trigger recurring_task_occurrences_set_updated_at
before update on public.recurring_task_occurrences
for each row execute function private.set_updated_at();

create or replace function private.recurring_normalize_weekdays(p_weekdays jsonb)
returns smallint[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_result smallint[];
begin
  if coalesce(jsonb_typeof(p_weekdays), 'array') <> 'array' then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_INVALID';
  end if;

  select coalesce(array_agg(day_value order by day_value), '{}'::smallint[])
    into v_result
  from (
    select distinct
      case when raw_day = 0 then 7 else raw_day end::smallint as day_value
    from (
      select value::integer as raw_day
      from jsonb_array_elements_text(coalesce(p_weekdays, '[]'::jsonb))
    ) as parsed
    where raw_day between 0 and 7
  ) as normalized;

  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_weekdays, '[]'::jsonb)) as item(value)
    where value !~ '^[0-7]$'
  ) then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_INVALID';
  end if;

  return v_result;
end;
$$;

create or replace function private.recurring_schedule_matches(
  p_schedule_kind text,
  p_weekdays smallint[],
  p_start_date date,
  p_end_date date,
  p_work_date date
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_work_date >= p_start_date
    and (p_end_date is null or p_work_date <= p_end_date)
    and case
      when p_schedule_kind = 'every_day' then true
      when p_schedule_kind = 'working_days' then extract(isodow from p_work_date)::integer between 1 and 5
      when p_schedule_kind = 'weekdays' then extract(isodow from p_work_date)::smallint = any(p_weekdays)
      else false
    end;
$$;

create or replace function private.recurring_due_at(
  p_organization_id uuid,
  p_work_date date,
  p_due_time time without time zone
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select (p_work_date + p_due_time) at time zone o.timezone
  from public.organizations as o
  where o.id = p_organization_id;
$$;

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
      on hr.organization_id = m.organization_id
     and hr.member_id = m.id
    where m.organization_id = p_organization_id
      and m.id = p_member_id
      and m.status = 'active'
      and (hr.member_id is null or hr.employment_start <= p_work_date)
      and (hr.member_id is null or hr.employment_end is null or hr.employment_end >= p_work_date)
      and (
        p_seller_id is null
        or exists (
          select 1
          from public.seller_members as sm
          where sm.organization_id = p_organization_id
            and sm.seller_id = p_seller_id
            and sm.member_id = p_member_id
            and sm.active_from <= p_work_date
            and (sm.active_until is null or sm.active_until >= p_work_date)
        )
      )
      and (
        p_seller_id is null
        or private.is_seller_member(p_organization_id, p_seller_id, p_member_id)
      )
  );
$$;

create or replace function private.recurring_reviewer_available_for_work_date(
  p_organization_id uuid,
  p_seller_id uuid,
  p_reviewer_member_id uuid,
  p_assignee_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_reviewer_member_id is null
    or (
      p_reviewer_member_id <> p_assignee_member_id
      and exists (
        select 1
        from public.organization_members as m
        where m.organization_id = p_organization_id
          and m.id = p_reviewer_member_id
          and m.status = 'active'
          and m.role in ('admin', 'manager')
      )
      and private.recurring_member_available_for_work_date(
        p_organization_id,
        p_seller_id,
        p_reviewer_member_id,
        p_work_date
      )
    );
$$;

create or replace function private.assert_recurring_manager(
  p_organization_id uuid,
  p_seller_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_role text;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id and m.id = v_actor_id;

  if v_role = 'admin' then
    return v_actor_id;
  end if;

  if v_role = 'manager'
     and p_seller_id is not null
     and private.is_seller_manager(p_organization_id, p_seller_id, v_actor_id) then
    return v_actor_id;
  end if;

  raise exception using errcode = '42501', message = 'RECURRING_TEMPLATE_MANAGE_DENIED';
end;
$$;

create or replace function private.current_actor_can_read_recurring_template(
  p_organization_id uuid,
  p_template_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin(p_organization_id)
    or exists (
      select 1
      from public.recurring_task_templates as rt
      join public.recurring_task_template_versions as rv
        on rv.organization_id = rt.organization_id
       and rv.template_id = rt.id
       and rv.version_number = rt.current_version_number
      join public.recurring_task_targets as trg
        on trg.organization_id = rv.organization_id
       and trg.version_id = rv.id
      where rt.organization_id = p_organization_id
        and rt.id = p_template_id
        and (
          (trg.seller_id is not null and private.is_seller_member(p_organization_id, trg.seller_id))
          or trg.assignee_member_id = private.current_member_id(p_organization_id)
        )
    );
$$;

create or replace function private.insert_task_from_recurring_occurrence(
  p_occurrence_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occ public.recurring_task_occurrences%rowtype;
  v_template public.recurring_task_templates%rowtype;
  v_version public.recurring_task_template_versions%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_assignee_id uuid;
  v_task_id uuid := extensions.gen_random_uuid();
  v_task_number bigint;
  v_item jsonb;
begin
  select o.* into v_occ
  from public.recurring_task_occurrences as o
  where o.id = p_occurrence_id
  for update;

  if v_occ.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_OCCURRENCE_NOT_FOUND';
  end if;
  if v_occ.task_id is not null then
    return v_occ.task_id;
  end if;

  select t.* into v_template
  from public.recurring_task_templates as t
  where t.organization_id = v_occ.organization_id and t.id = v_occ.template_id;

  select v.* into v_version
  from public.recurring_task_template_versions as v
  where v.organization_id = v_occ.organization_id and v.id = v_occ.version_id;

  select trg.* into v_target
  from public.recurring_task_targets as trg
  where trg.organization_id = v_occ.organization_id and trg.id = v_occ.target_id;

  v_assignee_id := coalesce(v_occ.resolved_assignee_member_id, v_target.assignee_member_id);

  if v_assignee_id is null then
    raise exception using errcode = '23514', message = 'RECURRING_OCCURRENCE_NEEDS_ASSIGNMENT';
  end if;

  perform private.assert_task_member_scope(
    v_occ.organization_id,
    v_target.seller_id,
    v_assignee_id
  );

  if v_version.reviewer_member_id is not null then
    if v_target.seller_id is null then
      raise exception using errcode = '42501', message = 'RECURRING_INTERNAL_REVIEWER_NOT_SUPPORTED';
    end if;
    perform private.assert_task_reviewer_policy(
      v_occ.organization_id,
      v_target.seller_id,
      v_version.reviewer_member_id,
      v_assignee_id
    );
  end if;

  insert into private.task_number_counters (organization_id, next_number)
  values (v_occ.organization_id, 2)
  on conflict (organization_id) do update
    set next_number = private.task_number_counters.next_number + 1
  returning next_number - 1 into v_task_number;

  insert into public.tasks (
    id,
    organization_id,
    task_number,
    seller_id,
    template_occurrence_id,
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
    v_occ.organization_id,
    v_task_number,
    v_target.seller_id,
    v_occ.id,
    v_version.title,
    v_version.description,
    v_assignee_id,
    v_template.created_by_member_id,
    v_version.reviewer_member_id,
    v_version.priority,
    v_occ.work_date,
    v_occ.due_at,
    v_occ.due_at,
    least(timezone('utc', now()), v_occ.due_at),
    v_version.requires_review,
    v_version.requires_result,
    v_version.requires_attachment,
    v_version.allow_no_incident,
    v_version.reminder_profile,
    v_version.estimated_minutes
  );

  for v_item in select value from jsonb_array_elements(v_version.checklist)
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
      v_occ.organization_id,
      v_task_id,
      trim(v_item ->> 'title'),
      coalesce((v_item ->> 'sort_order')::integer, 0),
      coalesce((v_item ->> 'is_required')::boolean, true)
    );
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
    v_occ.organization_id,
    v_task_id,
    1,
    'created',
    null,
    jsonb_build_object(
      'source', 'recurring_template',
      'template_id', v_occ.template_id,
      'occurrence_id', v_occ.id,
      'work_date', v_occ.work_date,
      'generation_kind', v_occ.generation_kind
    )
  );

  perform private.write_audit(
    v_occ.organization_id,
    'task.generated_from_recurring',
    'task',
    v_task_id,
    jsonb_build_object(
      'template_id', v_occ.template_id,
      'occurrence_id', v_occ.id,
      'task_number', v_task_number
    )
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
    v_occ.organization_id,
    'task.assigned',
    'task',
    v_task_id,
    'task:' || v_task_id::text || ':assigned:1',
    jsonb_build_object(
      'task_id', v_task_id,
      'assignee_member_id', v_assignee_id,
      'task_version', 1,
      'template_occurrence_id', v_occ.id
    )
  );

  update public.recurring_task_occurrences
  set task_id = v_task_id,
      state = 'materialized',
      issue_code = null,
      issue_context = '{}'::jsonb
  where id = v_occ.id;

  return v_task_id;
end;
$$;

create or replace function public.rpc_create_recurring_template(
  p_organization_id uuid,
  p_definition jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_today date := private.organization_local_date(p_organization_id);
  v_template_id uuid := extensions.gen_random_uuid();
  v_version_id uuid := extensions.gen_random_uuid();
  v_target_id uuid := extensions.gen_random_uuid();
  v_schedule jsonb := coalesce(p_definition -> 'schedule', '{}'::jsonb);
  v_target jsonb := coalesce(p_definition -> 'target', '{}'::jsonb);
  v_kind text := nullif(v_schedule ->> 'kind', '');
  v_weekdays smallint[] := private.recurring_normalize_weekdays(v_schedule -> 'weekdays');
  v_start_date date := nullif(v_schedule ->> 'start_date', '')::date;
  v_end_date date := nullif(v_schedule ->> 'end_date', '')::date;
  v_due_time time := nullif(v_schedule ->> 'due_time', '')::time;
  v_seller_id uuid := nullif(v_target ->> 'seller_id', '')::uuid;
  v_assignment_mode text := coalesce(nullif(v_target ->> 'assignment_mode', ''), 'fixed');
  v_assignee_id uuid := nullif(v_target ->> 'assignee_member_id', '')::uuid;
  v_reviewer_id uuid := nullif(p_definition ->> 'reviewer_member_id', '')::uuid;
  v_replay jsonb;
  v_result jsonb;
begin
  v_actor_id := private.assert_recurring_manager(p_organization_id, v_seller_id);

  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'recurring.create',
    p_idempotency_key,
    p_definition
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if nullif(trim(p_definition ->> 'title'), '') is null
     or v_start_date is null
     or v_due_time is null
     or v_kind not in ('working_days', 'every_day', 'weekdays')
     or v_assignment_mode not in ('fixed', 'seller_owner') then
    raise exception using errcode = '22023', message = 'RECURRING_REQUIRED_FIELDS_MISSING';
  end if;
  if v_end_date is not null and v_end_date < v_start_date then
    raise exception using errcode = '22023', message = 'RECURRING_END_DATE_INVALID';
  end if;
  if v_kind = 'weekdays' and cardinality(v_weekdays) = 0 then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_REQUIRED';
  end if;
  if v_kind <> 'weekdays' then
    v_weekdays := '{}'::smallint[];
  end if;
  if v_assignment_mode = 'fixed' and v_assignee_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNEE_REQUIRED';
  end if;
  if v_assignment_mode = 'seller_owner' and v_seller_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_SELLER_OWNER_REQUIRES_SELLER';
  end if;
  if v_assignment_mode = 'fixed'
     and not private.recurring_member_available_for_work_date(
       p_organization_id,
       v_seller_id,
       v_assignee_id,
       greatest(v_start_date, v_today)
     ) then
    raise exception using errcode = '42501', message = 'RECURRING_ASSIGNEE_UNAVAILABLE';
  end if;
  if v_reviewer_id is not null then
    if v_seller_id is null then
      raise exception using errcode = '42501', message = 'RECURRING_INTERNAL_REVIEWER_NOT_SUPPORTED';
    end if;
    perform private.assert_task_reviewer_policy(
      p_organization_id,
      v_seller_id,
      v_reviewer_id,
      v_assignee_id
    );
  end if;

  insert into public.recurring_task_templates (
    id,
    organization_id,
    status,
    current_version_number,
    generation_floor_date,
    created_by_member_id
  )
  values (
    v_template_id,
    p_organization_id,
    'active',
    1,
    greatest(v_start_date, v_today),
    v_actor_id
  );

  insert into public.recurring_task_template_versions (
    id,
    organization_id,
    template_id,
    version_number,
    effective_from,
    title,
    description,
    schedule_kind,
    weekdays,
    start_date,
    end_date,
    due_time,
    reviewer_member_id,
    priority,
    requires_review,
    requires_result,
    requires_attachment,
    allow_no_incident,
    reminder_profile,
    estimated_minutes,
    checklist,
    created_by_member_id
  )
  values (
    v_version_id,
    p_organization_id,
    v_template_id,
    1,
    greatest(v_start_date, v_today),
    trim(p_definition ->> 'title'),
    coalesce(p_definition ->> 'description', ''),
    v_kind,
    v_weekdays,
    v_start_date,
    v_end_date,
    v_due_time,
    v_reviewer_id,
    coalesce(nullif(p_definition ->> 'priority', ''), 'normal'),
    coalesce((p_definition ->> 'requires_review')::boolean, false),
    coalesce((p_definition ->> 'requires_result')::boolean, true),
    coalesce((p_definition ->> 'requires_attachment')::boolean, false),
    coalesce((p_definition ->> 'allow_no_incident')::boolean, false),
    case when jsonb_typeof(coalesce(p_definition -> 'reminder_profile', '{}'::jsonb)) = 'object'
      then coalesce(p_definition -> 'reminder_profile', '{}'::jsonb) else '{}'::jsonb end,
    nullif(p_definition ->> 'estimated_minutes', '')::integer,
    case when jsonb_typeof(coalesce(p_definition -> 'checklist', '[]'::jsonb)) = 'array'
      then coalesce(p_definition -> 'checklist', '[]'::jsonb) else '[]'::jsonb end,
    v_actor_id
  );

  insert into public.recurring_task_targets (
    id,
    organization_id,
    template_id,
    version_id,
    target_key,
    seller_id,
    assignment_mode,
    assignee_member_id
  )
  values (
    v_target_id,
    p_organization_id,
    v_template_id,
    v_version_id,
    'primary',
    v_seller_id,
    v_assignment_mode,
    v_assignee_id
  );

  perform private.write_audit(
    p_organization_id,
    'recurring_template.created',
    'recurring_task_template',
    v_template_id,
    jsonb_build_object('version_number', 1, 'seller_id', v_seller_id)
  );

  v_result := jsonb_build_object(
    'template_id', v_template_id,
    'version_number', 1,
    'status', 'active',
    'generation_floor_date', greatest(v_start_date, v_today)
  );

  perform private.task_idempotency_store(
    p_organization_id,
    v_actor_id,
    'recurring.create',
    p_idempotency_key,
    p_definition,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_update_recurring_template(
  p_template_id uuid,
  p_definition jsonb,
  p_effective_from date,
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
  v_template public.recurring_task_templates%rowtype;
  v_actor_id uuid;
  v_today date;
  v_version_id uuid := extensions.gen_random_uuid();
  v_target_id uuid := extensions.gen_random_uuid();
  v_next_version integer;
  v_schedule jsonb := coalesce(p_definition -> 'schedule', '{}'::jsonb);
  v_target jsonb := coalesce(p_definition -> 'target', '{}'::jsonb);
  v_kind text := nullif(v_schedule ->> 'kind', '');
  v_weekdays smallint[] := private.recurring_normalize_weekdays(v_schedule -> 'weekdays');
  v_start_date date := nullif(v_schedule ->> 'start_date', '')::date;
  v_end_date date := nullif(v_schedule ->> 'end_date', '')::date;
  v_due_time time := nullif(v_schedule ->> 'due_time', '')::time;
  v_seller_id uuid := nullif(v_target ->> 'seller_id', '')::uuid;
  v_assignment_mode text := coalesce(nullif(v_target ->> 'assignment_mode', ''), 'fixed');
  v_assignee_id uuid := nullif(v_target ->> 'assignee_member_id', '')::uuid;
  v_reviewer_id uuid := nullif(p_definition ->> 'reviewer_member_id', '')::uuid;
  v_replay jsonb;
  v_payload jsonb;
  v_result jsonb;
begin
  select t.* into v_template
  from public.recurring_task_templates as t
  where t.id = p_template_id
  for update;

  if v_template.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_TEMPLATE_NOT_FOUND';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'RECURRING_CHANGE_REASON_REQUIRED';
  end if;

  v_actor_id := private.assert_recurring_manager(v_template.organization_id, v_seller_id);
  v_payload := jsonb_build_object(
    'definition', p_definition,
    'effective_from', p_effective_from,
    'reason', p_reason,
    'expected_version', p_expected_version
  );
  v_replay := private.task_idempotency_replay(
    v_template.organization_id,
    v_actor_id,
    'recurring.update',
    p_idempotency_key,
    v_payload
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if v_template.status = 'ended' then
    raise exception using errcode = '23514', message = 'RECURRING_TEMPLATE_ENDED';
  end if;
  if p_expected_version is null or p_expected_version <> v_template.version then
    raise exception using errcode = '40001', message = 'RECURRING_VERSION_CONFLICT';
  end if;

  v_today := private.organization_local_date(v_template.organization_id);
  if p_effective_from is null or p_effective_from < v_today then
    raise exception using errcode = '22023', message = 'RECURRING_EFFECTIVE_DATE_INVALID';
  end if;

  if nullif(trim(p_definition ->> 'title'), '') is null
     or v_start_date is null
     or v_due_time is null
     or v_kind not in ('working_days', 'every_day', 'weekdays')
     or v_assignment_mode not in ('fixed', 'seller_owner') then
    raise exception using errcode = '22023', message = 'RECURRING_REQUIRED_FIELDS_MISSING';
  end if;
  if v_end_date is not null and v_end_date < v_start_date then
    raise exception using errcode = '22023', message = 'RECURRING_END_DATE_INVALID';
  end if;
  if v_kind = 'weekdays' and cardinality(v_weekdays) = 0 then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_REQUIRED';
  end if;
  if v_kind <> 'weekdays' then
    v_weekdays := '{}'::smallint[];
  end if;
  if v_assignment_mode = 'fixed' and v_assignee_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNEE_REQUIRED';
  end if;
  if v_assignment_mode = 'seller_owner' and v_seller_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_SELLER_OWNER_REQUIRES_SELLER';
  end if;
  if v_assignment_mode = 'fixed'
     and not private.recurring_member_available_for_work_date(
       v_template.organization_id,
       v_seller_id,
       v_assignee_id,
       greatest(v_start_date, p_effective_from)
     ) then
    raise exception using errcode = '42501', message = 'RECURRING_ASSIGNEE_UNAVAILABLE';
  end if;
  if v_reviewer_id is not null then
    if v_seller_id is null then
      raise exception using errcode = '42501', message = 'RECURRING_INTERNAL_REVIEWER_NOT_SUPPORTED';
    end if;
    perform private.assert_task_reviewer_policy(
      v_template.organization_id,
      v_seller_id,
      v_reviewer_id,
      v_assignee_id
    );
  end if;

  v_next_version := v_template.current_version_number + 1;

  insert into public.recurring_task_template_versions (
    id, organization_id, template_id, version_number, effective_from,
    title, description, schedule_kind, weekdays, start_date, end_date, due_time,
    reviewer_member_id, priority, requires_review, requires_result, requires_attachment,
    allow_no_incident, reminder_profile, estimated_minutes, checklist,
    created_by_member_id, change_reason
  ) values (
    v_version_id, v_template.organization_id, v_template.id, v_next_version, p_effective_from,
    trim(p_definition ->> 'title'), coalesce(p_definition ->> 'description', ''),
    v_kind, v_weekdays, v_start_date, v_end_date, v_due_time,
    v_reviewer_id, coalesce(nullif(p_definition ->> 'priority', ''), 'normal'),
    coalesce((p_definition ->> 'requires_review')::boolean, false),
    coalesce((p_definition ->> 'requires_result')::boolean, true),
    coalesce((p_definition ->> 'requires_attachment')::boolean, false),
    coalesce((p_definition ->> 'allow_no_incident')::boolean, false),
    case when jsonb_typeof(coalesce(p_definition -> 'reminder_profile', '{}'::jsonb)) = 'object'
      then coalesce(p_definition -> 'reminder_profile', '{}'::jsonb) else '{}'::jsonb end,
    nullif(p_definition ->> 'estimated_minutes', '')::integer,
    case when jsonb_typeof(coalesce(p_definition -> 'checklist', '[]'::jsonb)) = 'array'
      then coalesce(p_definition -> 'checklist', '[]'::jsonb) else '[]'::jsonb end,
    v_actor_id,
    trim(p_reason)
  );

  insert into public.recurring_task_targets (
    id, organization_id, template_id, version_id, target_key,
    seller_id, assignment_mode, assignee_member_id
  ) values (
    v_target_id, v_template.organization_id, v_template.id, v_version_id, 'primary',
    v_seller_id, v_assignment_mode, v_assignee_id
  );

  update public.recurring_task_templates
  set current_version_number = v_next_version,
      version = version + 1,
      attention_code = null,
      attention_context = '{}'::jsonb,
      status = case when status = 'needs_attention' then 'active' else status end
  where id = v_template.id;

  perform private.write_audit(
    v_template.organization_id,
    'recurring_template.version_created',
    'recurring_task_template',
    v_template.id,
    jsonb_build_object(
      'version_number', v_next_version,
      'effective_from', p_effective_from,
      'reason', trim(p_reason)
    )
  );

  v_result := jsonb_build_object(
    'template_id', v_template.id,
    'version_number', v_next_version,
    'status', case when v_template.status = 'needs_attention' then 'active' else v_template.status end,
    'version', v_template.version + 1
  );

  perform private.task_idempotency_store(
    v_template.organization_id,
    v_actor_id,
    'recurring.update',
    p_idempotency_key,
    v_payload,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_recurring_template_command(
  p_template_id uuid,
  p_command text,
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
  v_template public.recurring_task_templates%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_actor_id uuid;
  v_today date;
  v_payload jsonb;
  v_replay jsonb;
  v_status text;
  v_result jsonb;
begin
  select t.* into v_template
  from public.recurring_task_templates as t
  where t.id = p_template_id
  for update;

  if v_template.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_TEMPLATE_NOT_FOUND';
  end if;
  if p_command not in ('pause', 'resume', 'end') then
    raise exception using errcode = '22023', message = 'RECURRING_COMMAND_INVALID';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'RECURRING_COMMAND_REASON_REQUIRED';
  end if;

  select trg.* into v_target
  from public.recurring_task_template_versions as rv
  join public.recurring_task_targets as trg
    on trg.organization_id = rv.organization_id and trg.version_id = rv.id
  where rv.organization_id = v_template.organization_id
    and rv.template_id = v_template.id
    and rv.version_number = v_template.current_version_number
    and trg.target_key = 'primary';

  v_actor_id := private.assert_recurring_manager(v_template.organization_id, v_target.seller_id);
  v_today := private.organization_local_date(v_template.organization_id);
  v_payload := jsonb_build_object(
    'template_id', p_template_id,
    'command', p_command,
    'reason', p_reason,
    'expected_version', p_expected_version
  );
  v_replay := private.task_idempotency_replay(
    v_template.organization_id,
    v_actor_id,
    'recurring.command.' || p_command,
    p_idempotency_key,
    v_payload
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if p_expected_version is null or p_expected_version <> v_template.version then
    raise exception using errcode = '40001', message = 'RECURRING_VERSION_CONFLICT';
  end if;

  if p_command = 'pause' then
    if v_template.status not in ('active', 'needs_attention') then
      raise exception using errcode = '23514', message = 'RECURRING_PAUSE_STATE_INVALID';
    end if;
    v_status := 'paused';
    update public.recurring_task_templates
    set status = 'paused',
        paused_at = timezone('utc', now()),
        attention_code = null,
        attention_context = '{}'::jsonb,
        version = version + 1
    where id = v_template.id;
  elsif p_command = 'resume' then
    if v_template.status <> 'paused' then
      raise exception using errcode = '23514', message = 'RECURRING_RESUME_STATE_INVALID';
    end if;
    v_status := 'active';
    update public.recurring_task_templates
    set status = 'active',
        paused_at = null,
        generation_floor_date = greatest(generation_floor_date, v_today),
        attention_code = null,
        attention_context = '{}'::jsonb,
        version = version + 1
    where id = v_template.id;
  else
    if v_template.status = 'ended' then
      raise exception using errcode = '23514', message = 'RECURRING_END_STATE_INVALID';
    end if;
    v_status := 'ended';
    update public.recurring_task_templates
    set status = 'ended',
        paused_at = null,
        ended_at = timezone('utc', now()),
        attention_code = null,
        attention_context = '{}'::jsonb,
        version = version + 1
    where id = v_template.id;
  end if;

  perform private.write_audit(
    v_template.organization_id,
    'recurring_template.' || p_command,
    'recurring_task_template',
    v_template.id,
    jsonb_build_object('reason', trim(p_reason))
  );

  v_result := jsonb_build_object(
    'template_id', v_template.id,
    'status', v_status,
    'version', v_template.version + 1,
    'generation_floor_date', case when p_command = 'resume'
      then greatest(v_template.generation_floor_date, v_today)
      else v_template.generation_floor_date end
  );

  perform private.task_idempotency_store(
    v_template.organization_id,
    v_actor_id,
    'recurring.command.' || p_command,
    p_idempotency_key,
    v_payload,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_assign_recurring_occurrence(
  p_occurrence_id uuid,
  p_assignee_member_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occ public.recurring_task_occurrences%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_version public.recurring_task_template_versions%rowtype;
  v_actor_id uuid;
  v_task_id uuid;
  v_payload jsonb;
  v_replay jsonb;
  v_result jsonb;
begin
  if p_assignee_member_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNEE_REQUIRED';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNMENT_REASON_REQUIRED';
  end if;

  select occ.* into v_occ
  from public.recurring_task_occurrences as occ
  where occ.id = p_occurrence_id
  for update;

  if v_occ.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_OCCURRENCE_NOT_FOUND';
  end if;

  select trg.* into v_target
  from public.recurring_task_targets as trg
  where trg.organization_id = v_occ.organization_id
    and trg.id = v_occ.target_id;

  select rv.* into v_version
  from public.recurring_task_template_versions as rv
  where rv.organization_id = v_occ.organization_id
    and rv.id = v_occ.version_id;

  v_actor_id := private.assert_recurring_manager(v_occ.organization_id, v_target.seller_id);
  v_payload := jsonb_build_object(
    'occurrence_id', p_occurrence_id,
    'assignee_member_id', p_assignee_member_id,
    'reason', p_reason
  );
  v_replay := private.task_idempotency_replay(
    v_occ.organization_id,
    v_actor_id,
    'recurring.assign_occurrence',
    p_idempotency_key,
    v_payload
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if v_occ.state <> 'needs_assignment' or v_occ.task_id is not null then
    raise exception using errcode = '23514', message = 'RECURRING_OCCURRENCE_ASSIGNMENT_STATE_INVALID';
  end if;

  if not private.recurring_member_available_for_work_date(
    v_occ.organization_id,
    v_target.seller_id,
    p_assignee_member_id,
    v_occ.work_date
  ) then
    raise exception using errcode = '42501', message = 'RECURRING_ASSIGNEE_UNAVAILABLE';
  end if;

  if not private.recurring_reviewer_available_for_work_date(
    v_occ.organization_id,
    v_target.seller_id,
    v_version.reviewer_member_id,
    p_assignee_member_id,
    v_occ.work_date
  ) then
    raise exception using errcode = '42501', message = 'RECURRING_REVIEWER_UNAVAILABLE';
  end if;

  update public.recurring_task_occurrences
  set resolved_assignee_member_id = p_assignee_member_id,
      assigned_by_member_id = v_actor_id,
      assignment_reason = trim(p_reason)
  where id = v_occ.id;

  v_task_id := private.insert_task_from_recurring_occurrence(v_occ.id);

  update public.recurring_task_templates as rt
  set status = 'active',
      attention_code = null,
      attention_context = '{}'::jsonb
  where rt.organization_id = v_occ.organization_id
    and rt.id = v_occ.template_id
    and rt.status = 'needs_attention'
    and rt.attention_code in ('SELLER_COVERAGE_REQUIRED', 'ASSIGNEE_UNAVAILABLE')
    and not exists (
      select 1
      from public.recurring_task_occurrences as pending_issue
      where pending_issue.organization_id = rt.organization_id
        and pending_issue.template_id = rt.id
        and pending_issue.state = 'needs_assignment'
    );

  perform private.write_audit(
    v_occ.organization_id,
    'recurring_occurrence.assigned',
    'recurring_task_occurrence',
    v_occ.id,
    jsonb_build_object(
      'assignee_member_id', p_assignee_member_id,
      'assigned_by_member_id', v_actor_id,
      'reason', trim(p_reason),
      'task_id', v_task_id
    )
  );

  v_result := jsonb_build_object(
    'occurrence_id', v_occ.id,
    'task_id', v_task_id,
    'state', 'materialized',
    'assignee_member_id', p_assignee_member_id
  );

  perform private.task_idempotency_store(
    v_occ.organization_id,
    v_actor_id,
    'recurring.assign_occurrence',
    p_idempotency_key,
    v_payload,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_list_recurring_templates(
  p_organization_id uuid,
  p_include_ended boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_data order by row_data ->> 'title'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', rt.id,
      'status', rt.status,
      'version', rt.version,
      'current_version_number', rt.current_version_number,
      'generation_floor_date', rt.generation_floor_date,
      'last_generated_work_date', rt.last_generated_work_date,
      'attention_code', rt.attention_code,
      'attention_context', rt.attention_context,
      'title', rv.title,
      'description', rv.description,
      'schedule', jsonb_build_object(
        'kind', rv.schedule_kind,
        'weekdays', rv.weekdays,
        'start_date', rv.start_date,
        'end_date', rv.end_date,
        'due_time', to_char(rv.due_time, 'HH24:MI')
      ),
      'target', jsonb_build_object(
        'seller_id', trg.seller_id,
        'seller_name', s.name,
        'assignment_mode', trg.assignment_mode,
        'assignee_member_id', trg.assignee_member_id,
        'assignee_name', assignee.display_name
      ),
      'open_assignment_issues', (
        select count(*)
        from public.recurring_task_occurrences as occ
        where occ.organization_id = rt.organization_id
          and occ.template_id = rt.id
          and occ.state = 'needs_assignment'
      )
    ) as row_data
    from public.recurring_task_templates as rt
    join public.recurring_task_template_versions as rv
      on rv.organization_id = rt.organization_id
     and rv.template_id = rt.id
     and rv.version_number = rt.current_version_number
    join public.recurring_task_targets as trg
      on trg.organization_id = rv.organization_id
     and trg.version_id = rv.id
     and trg.target_key = 'primary'
    left join public.sellers as s
      on s.organization_id = trg.organization_id and s.id = trg.seller_id
    left join public.organization_members as assignee
      on assignee.organization_id = trg.organization_id and assignee.id = trg.assignee_member_id
    where rt.organization_id = p_organization_id
      and (p_include_ended or rt.status <> 'ended')
      and private.current_actor_can_read_recurring_template(rt.organization_id, rt.id)
  ) as rows;
$$;

create or replace function public.rpc_get_recurring_template(p_template_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_template public.recurring_task_templates%rowtype;
  v_result jsonb;
begin
  select rt.* into v_template
  from public.recurring_task_templates as rt
  where rt.id = p_template_id;

  if v_template.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_TEMPLATE_NOT_FOUND';
  end if;
  if not private.current_actor_can_read_recurring_template(v_template.organization_id, v_template.id) then
    raise exception using errcode = '42501', message = 'RECURRING_TEMPLATE_READ_DENIED';
  end if;

  select jsonb_build_object(
    'id', v_template.id,
    'organization_id', v_template.organization_id,
    'status', v_template.status,
    'version', v_template.version,
    'generation_floor_date', v_template.generation_floor_date,
    'last_generated_work_date', v_template.last_generated_work_date,
    'attention_code', v_template.attention_code,
    'attention_context', v_template.attention_context,
    'versions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', rv.id,
          'version_number', rv.version_number,
          'effective_from', rv.effective_from,
          'title', rv.title,
          'description', rv.description,
          'schedule_kind', rv.schedule_kind,
          'weekdays', rv.weekdays,
          'start_date', rv.start_date,
          'end_date', rv.end_date,
          'due_time', to_char(rv.due_time, 'HH24:MI'),
          'change_reason', rv.change_reason,
          'target', jsonb_build_object(
            'seller_id', trg.seller_id,
            'assignment_mode', trg.assignment_mode,
            'assignee_member_id', trg.assignee_member_id
          )
        ) order by rv.version_number
      )
      from public.recurring_task_template_versions as rv
      join public.recurring_task_targets as trg
        on trg.organization_id = rv.organization_id
       and trg.version_id = rv.id
       and trg.target_key = 'primary'
      where rv.organization_id = v_template.organization_id
        and rv.template_id = v_template.id
    ), '[]'::jsonb),
    'recent_occurrences', coalesce((
      select jsonb_agg(occurrence_row order by occurrence_row ->> 'work_date' desc)
      from (
        select jsonb_build_object(
          'id', occ.id,
          'work_date', occ.work_date,
          'due_at', occ.due_at,
          'state', occ.state,
          'generation_kind', occ.generation_kind,
          'issue_code', occ.issue_code,
          'issue_context', occ.issue_context,
          'task_id', occ.task_id
        ) as occurrence_row
        from public.recurring_task_occurrences as occ
        where occ.organization_id = v_template.organization_id
          and occ.template_id = v_template.id
        order by occ.work_date desc, occ.id desc
        limit 30
      ) as recent
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

create or replace function private.materialize_recurring_occurrences(
  p_organization_id uuid,
  p_through_date date,
  p_catchup_limit integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := private.organization_local_date(p_organization_id);
  v_window_start date;
  v_template public.recurring_task_templates%rowtype;
  v_version public.recurring_task_template_versions%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_work_date date;
  v_occurrence_id uuid;
  v_due_at timestamptz;
  v_generation_kind text;
  v_created integer := 0;
  v_materialized integer := 0;
  v_issues integer := 0;
  v_delayed_templates integer := 0;
begin
  if p_through_date is null or p_through_date > v_today then
    raise exception using errcode = '22023', message = 'RECURRING_THROUGH_DATE_INVALID';
  end if;
  if p_catchup_limit is null or p_catchup_limit < 1 or p_catchup_limit > 31 then
    raise exception using errcode = '22023', message = 'RECURRING_CATCHUP_LIMIT_INVALID';
  end if;

  for v_template in
    select rt.*
    from public.recurring_task_templates as rt
    where rt.organization_id = p_organization_id
      and rt.status in ('active', 'needs_attention')
    order by rt.created_at, rt.id
  loop
    v_window_start := greatest(
      v_template.generation_floor_date,
      p_through_date - (p_catchup_limit - 1)
    );

    if v_template.generation_floor_date < p_through_date - (p_catchup_limit - 1)
       and coalesce(v_template.last_generated_work_date, v_template.generation_floor_date - 1)
           < p_through_date - (p_catchup_limit - 1) then
      update public.recurring_task_templates
      set status = 'needs_attention',
          attention_code = 'SYSTEM_DELAY_CATCHUP_LIMITED',
          attention_context = jsonb_build_object(
            'requested_through_date', p_through_date,
            'catchup_limit_days', p_catchup_limit,
            'window_start', v_window_start
          )
      where id = v_template.id;
      v_delayed_templates := v_delayed_templates + 1;
    end if;

    for v_work_date in
      select d::date
      from generate_series(v_window_start, p_through_date, interval '1 day') as d
    loop
      select rv.* into v_version
      from public.recurring_task_template_versions as rv
      where rv.organization_id = v_template.organization_id
        and rv.template_id = v_template.id
        and rv.effective_from <= v_work_date
      order by rv.effective_from desc, rv.version_number desc
      limit 1;

      if v_version.id is null
         or not private.recurring_schedule_matches(
           v_version.schedule_kind,
           v_version.weekdays,
           v_version.start_date,
           v_version.end_date,
           v_work_date
         ) then
        continue;
      end if;

      for v_target in
        select trg.*
        from public.recurring_task_targets as trg
        where trg.organization_id = v_template.organization_id
          and trg.template_id = v_template.id
          and trg.version_id = v_version.id
        order by trg.target_key, trg.id
      loop
        v_due_at := private.recurring_due_at(v_template.organization_id, v_work_date, v_version.due_time);
        v_generation_kind := case when v_work_date < v_today then 'system_delay' else 'scheduled' end;
        v_occurrence_id := extensions.gen_random_uuid();

        insert into public.recurring_task_occurrences (
          id, organization_id, template_id, version_id, target_id, target_key,
          work_date, due_at, state, generation_kind
        ) values (
          v_occurrence_id, v_template.organization_id, v_template.id, v_version.id,
          v_target.id, v_target.target_key, v_work_date, v_due_at, 'pending', v_generation_kind
        )
        on conflict (organization_id, template_id, target_key, work_date) do nothing;

        if not found then
          continue;
        end if;
        v_created := v_created + 1;

        if v_target.assignment_mode = 'seller_owner' then
          update public.recurring_task_occurrences
          set state = 'needs_assignment',
              issue_code = 'SELLER_COVERAGE_REQUIRED',
              issue_context = jsonb_build_object(
                'seller_id', v_target.seller_id,
                'reason', 'Roster/coverage owner must be selected explicitly'
              )
          where id = v_occurrence_id;
          update public.recurring_task_templates
          set status = 'needs_attention',
              attention_code = 'SELLER_COVERAGE_REQUIRED',
              attention_context = jsonb_build_object('occurrence_id', v_occurrence_id, 'work_date', v_work_date)
          where id = v_template.id;
          insert into private.outbox_events (
            organization_id, event_type, entity_type, entity_id, dedupe_key, payload
          ) values (
            v_template.organization_id,
            'recurring.assignment_needed',
            'recurring_task_occurrence',
            v_occurrence_id,
            'recurring:' || v_occurrence_id::text || ':assignment-needed',
            jsonb_build_object('template_id', v_template.id, 'work_date', v_work_date, 'seller_id', v_target.seller_id)
          ) on conflict (organization_id, dedupe_key) do nothing;
          v_issues := v_issues + 1;
          continue;
        end if;

        if not private.recurring_member_available_for_work_date(
          v_template.organization_id,
          v_target.seller_id,
          v_target.assignee_member_id,
          v_work_date
        ) then
          update public.recurring_task_occurrences
          set state = 'needs_assignment',
              issue_code = 'ASSIGNEE_UNAVAILABLE',
              issue_context = jsonb_build_object(
                'assignee_member_id', v_target.assignee_member_id,
                'seller_id', v_target.seller_id,
                'work_date', v_work_date
              )
          where id = v_occurrence_id;
          update public.recurring_task_templates
          set status = 'needs_attention',
              attention_code = 'ASSIGNEE_UNAVAILABLE',
              attention_context = jsonb_build_object('occurrence_id', v_occurrence_id, 'work_date', v_work_date)
          where id = v_template.id;
          insert into private.outbox_events (
            organization_id, event_type, entity_type, entity_id, dedupe_key, payload
          ) values (
            v_template.organization_id,
            'recurring.assignment_needed',
            'recurring_task_occurrence',
            v_occurrence_id,
            'recurring:' || v_occurrence_id::text || ':assignment-needed',
            jsonb_build_object(
              'template_id', v_template.id,
              'work_date', v_work_date,
              'assignee_member_id', v_target.assignee_member_id,
              'seller_id', v_target.seller_id
            )
          ) on conflict (organization_id, dedupe_key) do nothing;
          v_issues := v_issues + 1;
          continue;
        end if;

        if not private.recurring_reviewer_available_for_work_date(
          v_template.organization_id,
          v_target.seller_id,
          v_version.reviewer_member_id,
          v_target.assignee_member_id,
          v_work_date
        ) then
          update public.recurring_task_occurrences
          set state = 'needs_assignment',
              issue_code = 'REVIEWER_UNAVAILABLE',
              issue_context = jsonb_build_object(
                'reviewer_member_id', v_version.reviewer_member_id,
                'work_date', v_work_date
              )
          where id = v_occurrence_id;
          update public.recurring_task_templates
          set status = 'needs_attention',
              attention_code = 'REVIEWER_UNAVAILABLE',
              attention_context = jsonb_build_object('occurrence_id', v_occurrence_id, 'work_date', v_work_date)
          where id = v_template.id;
          v_issues := v_issues + 1;
          continue;
        end if;

        perform private.insert_task_from_recurring_occurrence(v_occurrence_id);
        v_materialized := v_materialized + 1;
      end loop;
    end loop;

    update public.recurring_task_templates
    set last_generated_work_date = greatest(coalesce(last_generated_work_date, v_window_start), p_through_date)
    where id = v_template.id;
  end loop;

  return jsonb_build_object(
    'organization_id', p_organization_id,
    'through_date', p_through_date,
    'created_occurrences', v_created,
    'materialized_tasks', v_materialized,
    'assignment_issues', v_issues,
    'delayed_templates', v_delayed_templates
  );
end;
$$;

revoke all on function private.recurring_normalize_weekdays(jsonb) from public, anon, authenticated;
revoke all on function private.recurring_schedule_matches(text, smallint[], date, date, date) from public, anon, authenticated;
revoke all on function private.recurring_due_at(uuid, date, time without time zone) from public, anon, authenticated;
revoke all on function private.recurring_member_available_for_work_date(uuid, uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.recurring_reviewer_available_for_work_date(uuid, uuid, uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.assert_recurring_manager(uuid, uuid) from public, anon, authenticated;
revoke all on function private.insert_task_from_recurring_occurrence(uuid) from public, anon, authenticated;
revoke all on function private.materialize_recurring_occurrences(uuid, date, integer) from public, anon, authenticated;

revoke all on function private.current_actor_can_read_recurring_template(uuid, uuid) from public, anon;
grant execute on function private.current_actor_can_read_recurring_template(uuid, uuid) to authenticated;
grant execute on function private.materialize_recurring_occurrences(uuid, date, integer) to service_role;

revoke all on function public.rpc_create_recurring_template(uuid, jsonb, text) from public, anon;
revoke all on function public.rpc_update_recurring_template(uuid, jsonb, date, text, integer, text) from public, anon;
revoke all on function public.rpc_recurring_template_command(uuid, text, text, integer, text) from public, anon;
revoke all on function public.rpc_assign_recurring_occurrence(uuid, uuid, text, text) from public, anon;
revoke all on function public.rpc_list_recurring_templates(uuid, boolean) from public, anon;
revoke all on function public.rpc_get_recurring_template(uuid) from public, anon;

grant execute on function public.rpc_create_recurring_template(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_update_recurring_template(uuid, jsonb, date, text, integer, text) to authenticated;
grant execute on function public.rpc_recurring_template_command(uuid, text, text, integer, text) to authenticated;
grant execute on function public.rpc_assign_recurring_occurrence(uuid, uuid, text, text) to authenticated;
grant execute on function public.rpc_list_recurring_templates(uuid, boolean) to authenticated;
grant execute on function public.rpc_get_recurring_template(uuid) to authenticated;

alter table public.recurring_task_templates enable row level security;
alter table public.recurring_task_template_versions enable row level security;
alter table public.recurring_task_targets enable row level security;
alter table public.recurring_task_occurrences enable row level security;

create policy recurring_templates_read_by_scope
on public.recurring_task_templates
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, id));

create policy recurring_versions_read_by_scope
on public.recurring_task_template_versions
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, template_id));

create policy recurring_targets_read_by_scope
on public.recurring_task_targets
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, template_id));

create policy recurring_occurrences_read_by_scope
on public.recurring_task_occurrences
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, template_id));

revoke all on public.recurring_task_templates from anon;
revoke all on public.recurring_task_template_versions from anon;
revoke all on public.recurring_task_targets from anon;
revoke all on public.recurring_task_occurrences from anon;

grant select on public.recurring_task_templates to authenticated;
grant select on public.recurring_task_template_versions to authenticated;
grant select on public.recurring_task_targets to authenticated;
grant select on public.recurring_task_occurrences to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.recurring_task_templates,
   public.recurring_task_template_versions,
   public.recurring_task_targets,
   public.recurring_task_occurrences
from authenticated;
