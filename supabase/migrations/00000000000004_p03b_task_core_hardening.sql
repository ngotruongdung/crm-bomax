-- P03B hardening: stable payload validation, batch create, task updates,
-- immutable report snapshots and assignment lifecycle fixes.

alter table public.tasks
  alter column requires_result set default true;

alter table public.task_events
  add column report_state_after jsonb not null default '{}'::jsonb;

alter table public.task_events
  add constraint task_events_report_state_after_object
  check (jsonb_typeof(report_state_after) = 'object');

create or replace function private.task_json_uuid(
  p_payload jsonb,
  p_key text,
  p_error text,
  p_required boolean default false
)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  v_text := nullif(trim(p_payload ->> p_key), '');
  if v_text is null then
    if p_required then
      raise exception using errcode = '22023', message = p_error;
    end if;
    return null;
  end if;

  begin
    return v_text::uuid;
  exception when invalid_text_representation then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_json_boolean(
  p_payload jsonb,
  p_key text,
  p_default boolean,
  p_error text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if not (p_payload ? p_key) then
    return p_default;
  end if;
  if jsonb_typeof(p_payload -> p_key) <> 'boolean' then
    raise exception using errcode = '22023', message = p_error;
  end if;
  return (p_payload ->> p_key)::boolean;
end;
$$;

create or replace function private.task_json_integer(
  p_payload jsonb,
  p_key text,
  p_error text
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  if not (p_payload ? p_key) or jsonb_typeof(p_payload -> p_key) = 'null' then
    return null;
  end if;
  v_text := p_payload ->> p_key;
  if jsonb_typeof(p_payload -> p_key) <> 'number' or v_text !~ '^-?[0-9]+$' then
    raise exception using errcode = '22023', message = p_error;
  end if;
  begin
    return v_text::integer;
  exception when numeric_value_out_of_range then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_json_date(
  p_payload jsonb,
  p_key text,
  p_error text
)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  v_text := nullif(trim(p_payload ->> p_key), '');
  if v_text is null then
    return null;
  end if;
  begin
    return v_text::date;
  exception when datetime_field_overflow or invalid_datetime_format then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_json_timestamptz(
  p_payload jsonb,
  p_key text,
  p_error text
)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_text text;
begin
  v_text := nullif(trim(p_payload ->> p_key), '');
  if v_text is null then
    return null;
  end if;
  begin
    return v_text::timestamptz;
  exception when datetime_field_overflow or invalid_datetime_format then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

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

create or replace function private.normalize_task_draft(p_task jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_result jsonb;
  v_uuid uuid;
  v_date date;
  v_timestamp timestamptz;
  v_integer integer;
  v_boolean boolean;
  v_item jsonb;
  v_items jsonb := '[]'::jsonb;
  v_member jsonb;
  v_member_id uuid;
  v_members jsonb := '[]'::jsonb;
begin
  if p_task is null or jsonb_typeof(p_task) <> 'object' then
    raise exception using errcode = '22023', message = 'TASK_DRAFT_INVALID';
  end if;
  v_result := p_task;

  if p_task ? 'assignee_member_id' then
    v_uuid := private.task_json_uuid(p_task, 'assignee_member_id', 'TASK_ASSIGNEE_INVALID');
    v_result := jsonb_set(v_result, '{assignee_member_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
  end if;
  if p_task ? 'reviewer_member_id' then
    v_uuid := private.task_json_uuid(p_task, 'reviewer_member_id', 'TASK_REVIEWER_INVALID');
    v_result := jsonb_set(v_result, '{reviewer_member_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
  end if;
  if p_task ? 'seller_id' then
    v_uuid := private.task_json_uuid(p_task, 'seller_id', 'TASK_SELLER_INVALID');
    v_result := jsonb_set(v_result, '{seller_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
  end if;

  if p_task ? 'planned_date' then
    v_date := private.task_json_date(p_task, 'planned_date', 'TASK_PLANNED_DATE_INVALID');
    v_result := jsonb_set(v_result, '{planned_date}', coalesce(to_jsonb(v_date), 'null'::jsonb), true);
  end if;
  if p_task ? 'due_at' then
    v_timestamp := private.task_json_timestamptz(p_task, 'due_at', 'TASK_DUE_AT_INVALID');
    v_result := jsonb_set(v_result, '{due_at}', coalesce(to_jsonb(v_timestamp), 'null'::jsonb), true);
  end if;
  if p_task ? 'visible_from' then
    v_timestamp := private.task_json_timestamptz(p_task, 'visible_from', 'TASK_VISIBLE_FROM_INVALID');
    v_result := jsonb_set(v_result, '{visible_from}', coalesce(to_jsonb(v_timestamp), 'null'::jsonb), true);
  end if;

  v_boolean := private.task_json_boolean(p_task, 'requires_review', false, 'TASK_REQUIRES_REVIEW_INVALID');
  v_result := jsonb_set(v_result, '{requires_review}', to_jsonb(v_boolean), true);
  v_boolean := private.task_json_boolean(p_task, 'requires_result', true, 'TASK_REQUIRES_RESULT_INVALID');
  v_result := jsonb_set(v_result, '{requires_result}', to_jsonb(v_boolean), true);
  v_boolean := private.task_json_boolean(p_task, 'requires_attachment', false, 'TASK_REQUIRES_ATTACHMENT_INVALID');
  v_result := jsonb_set(v_result, '{requires_attachment}', to_jsonb(v_boolean), true);
  v_boolean := private.task_json_boolean(p_task, 'allow_no_incident', false, 'TASK_ALLOW_NO_INCIDENT_INVALID');
  v_result := jsonb_set(v_result, '{allow_no_incident}', to_jsonb(v_boolean), true);

  if p_task ? 'estimated_minutes' then
    v_integer := private.task_json_integer(p_task, 'estimated_minutes', 'TASK_ESTIMATED_MINUTES_INVALID');
    if v_integer is not null and v_integer <= 0 then
      raise exception using errcode = '22023', message = 'TASK_ESTIMATED_MINUTES_INVALID';
    end if;
    v_result := jsonb_set(v_result, '{estimated_minutes}', coalesce(to_jsonb(v_integer), 'null'::jsonb), true);
  end if;

  if p_task ? 'checklist' then
    if jsonb_typeof(p_task -> 'checklist') <> 'array' then
      raise exception using errcode = '22023', message = 'TASK_ARRAY_FIELD_INVALID';
    end if;
    for v_item in select value from jsonb_array_elements(p_task -> 'checklist')
    loop
      if jsonb_typeof(v_item) <> 'object' then
        raise exception using errcode = '22023', message = 'TASK_CHECKLIST_ITEM_INVALID';
      end if;
      if v_item ? 'sort_order' then
        v_integer := private.task_json_integer(v_item, 'sort_order', 'TASK_CHECKLIST_SORT_ORDER_INVALID');
        if v_integer is null or v_integer < 0 then
          raise exception using errcode = '22023', message = 'TASK_CHECKLIST_SORT_ORDER_INVALID';
        end if;
        v_item := jsonb_set(v_item, '{sort_order}', to_jsonb(v_integer), true);
      end if;
      v_boolean := private.task_json_boolean(v_item, 'is_required', true, 'TASK_CHECKLIST_REQUIRED_FLAG_INVALID');
      v_item := jsonb_set(v_item, '{is_required}', to_jsonb(v_boolean), true);
      v_items := v_items || jsonb_build_array(v_item);
    end loop;
    v_result := jsonb_set(v_result, '{checklist}', v_items, true);
  end if;

  if p_task ? 'participant_member_ids' then
    if jsonb_typeof(p_task -> 'participant_member_ids') <> 'array' then
      raise exception using errcode = '22023', message = 'TASK_ARRAY_FIELD_INVALID';
    end if;
    for v_member in select value from jsonb_array_elements(p_task -> 'participant_member_ids')
    loop
      if jsonb_typeof(v_member) <> 'string' then
        raise exception using errcode = '22023', message = 'TASK_PARTICIPANT_INVALID';
      end if;
      begin
        v_member_id := nullif(trim(v_member #>> '{}'), '')::uuid;
      exception when invalid_text_representation then
        raise exception using errcode = '22023', message = 'TASK_PARTICIPANT_INVALID';
      end;
      if v_member_id is null then
        raise exception using errcode = '22023', message = 'TASK_PARTICIPANT_INVALID';
      end if;
      v_members := v_members || jsonb_build_array(v_member_id::text);
    end loop;
    v_result := jsonb_set(v_result, '{participant_member_ids}', v_members, true);
  end if;

  return v_result;
end;
$$;

create or replace function private.normalize_task_command_payload(
  p_action text,
  p_payload jsonb
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_result jsonb := coalesce(p_payload, '{}'::jsonb);
  v_uuid uuid;
  v_timestamp timestamptz;
  v_boolean boolean;
begin
  if jsonb_typeof(v_result) <> 'object' then
    raise exception using errcode = '22023', message = 'TASK_COMMAND_PAYLOAD_INVALID';
  end if;

  if p_action = 'checklist' then
    v_uuid := private.task_json_uuid(v_result, 'item_id', 'TASK_CHECKLIST_ITEM_INVALID', true);
    v_result := jsonb_set(v_result, '{item_id}', to_jsonb(v_uuid), true);
    v_boolean := private.task_json_boolean(v_result, 'checked', false, 'TASK_CHECKLIST_CHECKED_INVALID');
    v_result := jsonb_set(v_result, '{checked}', to_jsonb(v_boolean), true);
  elsif p_action = 'submit' then
    v_boolean := private.task_json_boolean(v_result, 'no_incident', false, 'TASK_NO_INCIDENT_INVALID');
    v_result := jsonb_set(v_result, '{no_incident}', to_jsonb(v_boolean), true);
  elsif p_action = 'request_changes' then
    if v_result ? 'revision_due_at' then
      v_timestamp := private.task_json_timestamptz(v_result, 'revision_due_at', 'TASK_REVISION_DUE_AT_INVALID');
      v_result := jsonb_set(v_result, '{revision_due_at}', coalesce(to_jsonb(v_timestamp), 'null'::jsonb), true);
    end if;
  elsif p_action = 'report_blocker' then
    if v_result ? 'owner_member_id' then
      v_uuid := private.task_json_uuid(v_result, 'owner_member_id', 'TASK_BLOCKER_OWNER_INVALID');
      v_result := jsonb_set(v_result, '{owner_member_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
    end if;
  elsif p_action = 'reassign' then
    v_uuid := private.task_json_uuid(v_result, 'assignee_member_id', 'TASK_ASSIGNEE_INVALID', true);
    v_result := jsonb_set(v_result, '{assignee_member_id}', to_jsonb(v_uuid), true);
  elsif p_action = 'change_deadline' then
    v_timestamp := private.task_json_timestamptz(v_result, 'due_at', 'TASK_DUE_AT_INVALID');
    if v_timestamp is null then
      raise exception using errcode = '22023', message = 'TASK_DUE_AT_REQUIRED';
    end if;
    v_result := jsonb_set(v_result, '{due_at}', to_jsonb(v_timestamp), true);
  end if;

  return v_result;
end;
$$;

alter function public.rpc_create_task(uuid, jsonb, text)
  rename to rpc_create_task_p03b_legacy;

alter function public.rpc_task_command(uuid, text, jsonb, integer, text)
  rename to rpc_task_command_p03b_legacy;

revoke all on function public.rpc_create_task_p03b_legacy(uuid, jsonb, text)
  from public, anon, authenticated;
revoke all on function public.rpc_task_command_p03b_legacy(uuid, text, jsonb, integer, text)
  from public, anon, authenticated;

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
  v_task jsonb;
  v_replay jsonb;
  v_result jsonb;
  v_created public.tasks%rowtype;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  v_task := private.normalize_task_draft(p_task);
  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'task.create',
    p_idempotency_key,
    v_task
  );
  if v_replay is not null then
    return v_replay;
  end if;

  v_result := public.rpc_create_task_p03b_legacy(p_organization_id, v_task, p_idempotency_key);

  select t.* into v_created
  from public.tasks as t
  where t.organization_id = p_organization_id
    and t.id = (v_result ->> 'task_id')::uuid;

  update public.task_events
  set report_state_after = private.task_report_state(v_created)
  where organization_id = p_organization_id
    and task_id = v_created.id
    and task_version = v_created.version;

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
  v_before public.tasks%rowtype;
  v_after public.tasks%rowtype;
  v_actor_id uuid;
  v_action text := trim(coalesce(p_action, ''));
  v_payload jsonb;
  v_replay jsonb;
  v_result jsonb;
  v_reason text;
  v_version integer;
  v_outbox_type text;
begin
  select t.* into v_before
  from public.tasks as t
  where t.id = p_task_id;
  if v_before.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;

  v_actor_id := private.current_member_id(v_before.organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  v_payload := private.normalize_task_command_payload(v_action, p_payload);

  if v_action in ('reassign', 'change_deadline') then
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = case
        when v_action = 'reassign' then 'TASK_REASSIGN_REASON_REQUIRED'
        else 'TASK_DEADLINE_CHANGE_REASON_REQUIRED'
      end;
    end if;
  end if;

  v_replay := private.task_idempotency_replay(
    v_before.organization_id,
    v_actor_id,
    'task.' || v_action,
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'payload', v_payload)
  );
  if v_replay is not null then
    return v_replay;
  end if;

  v_result := public.rpc_task_command_p03b_legacy(
    p_task_id,
    v_action,
    v_payload,
    p_expected_version,
    p_idempotency_key
  );
  v_version := (v_result ->> 'version')::integer;

  if v_action = 'reassign' then
    update public.tasks
    set assigned_at = timezone('utc', now())
    where id = p_task_id
    returning * into v_after;

    update public.task_events
    set event_payload = event_payload || jsonb_build_object(
      'reason', v_reason,
      'assigned_at', v_after.assigned_at
    )
    where organization_id = v_after.organization_id
      and task_id = v_after.id
      and task_version = v_version;

    update private.outbox_events
    set payload = payload || jsonb_build_object(
      'previous_assignee_member_id', v_before.assignee_member_id,
      'reason', v_reason,
      'assigned_at', v_after.assigned_at
    )
    where organization_id = v_after.organization_id
      and entity_id = v_after.id
      and dedupe_key = 'task:' || v_after.id::text || ':task-assigned:' || v_version::text;
  elsif v_action = 'withdraw_submission' then
    update public.tasks
    set current_submission_id = null
    where id = p_task_id
    returning * into v_after;
  else
    select t.* into v_after from public.tasks as t where t.id = p_task_id;
  end if;

  if v_action = 'change_deadline' then
    update public.task_events
    set event_payload = event_payload || jsonb_build_object('reason', v_reason)
    where organization_id = v_after.organization_id
      and task_id = v_after.id
      and task_version = v_version;
  end if;

  update public.task_events
  set report_state_after = private.task_report_state(v_after)
  where organization_id = v_after.organization_id
    and task_id = v_after.id
    and task_version = v_version;

  v_outbox_type := case
    when v_action in ('approve', 'request_changes', 'withdraw_submission') then 'task.review_resolved'
    when v_action = 'change_deadline' then 'task.deadline_changed'
    when v_action in ('cancel', 'waive') then 'task.reminders_invalidated'
    when v_action = 'reopen' then 'task.reopened'
    when v_action = 'report_blocker' then 'task.blocker_reported'
    when v_action = 'resolve_blocker' then 'task.blocker_resolved'
    else null
  end;

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
      v_after.organization_id,
      v_outbox_type,
      'task',
      v_after.id,
      'task:' || v_after.id::text || ':' || replace(v_outbox_type, '.', '-') || ':' || v_version::text,
      jsonb_build_object(
        'task_id', v_after.id,
        'task_version', v_version,
        'actor_member_id', v_actor_id,
        'status', v_after.status
      )
    )
    on conflict (organization_id, dedupe_key) do nothing;
  end if;

  return v_result;
end;
$$;

create or replace function public.rpc_create_task_batch(
  p_organization_id uuid,
  p_common_task jsonb,
  p_targets jsonb,
  p_idempotency_key text,
  p_mode text default 'atomic'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_mode text := lower(trim(coalesce(p_mode, 'atomic')));
  v_common jsonb;
  v_replay jsonb;
  v_batch_id uuid := extensions.gen_random_uuid();
  v_results jsonb := '[]'::jsonb;
  v_target jsonb;
  v_task jsonb;
  v_created jsonb;
  v_created_task public.tasks%rowtype;
  v_index integer := 0;
  v_created_count integer := 0;
  v_failed_count integer := 0;
  v_error text;
  v_sqlstate text;
  v_target_id text;
  v_invalid_key text;
  v_request jsonb;
  v_result jsonb;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  if v_mode not in ('atomic', 'valid_only') then
    raise exception using errcode = '22023', message = 'TASK_BATCH_MODE_INVALID';
  end if;
  if p_targets is null or jsonb_typeof(p_targets) <> 'array' then
    raise exception using errcode = '22023', message = 'TASK_BATCH_TARGETS_INVALID';
  end if;
  if jsonb_array_length(p_targets) = 0 then
    raise exception using errcode = '22023', message = 'TASK_BATCH_TARGETS_REQUIRED';
  end if;
  if jsonb_array_length(p_targets) > 50 then
    raise exception using errcode = '22023', message = 'TASK_BATCH_TOO_LARGE';
  end if;

  v_common := private.normalize_task_draft(p_common_task);
  v_request := jsonb_build_object('common_task', v_common, 'targets', p_targets, 'mode', v_mode);
  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'task.create_batch',
    p_idempotency_key,
    v_request
  );
  if v_replay is not null then
    return v_replay;
  end if;

  for v_target in select value from jsonb_array_elements(p_targets)
  loop
    v_index := v_index + 1;
    if jsonb_typeof(v_target) <> 'object' then
      if v_mode = 'atomic' then
        raise exception using
          errcode = '22023',
          message = 'TASK_BATCH_TARGET_INVALID',
          detail = jsonb_build_object('target_index', v_index, 'error_code', 'TASK_BATCH_TARGET_INVALID')::text;
      end if;
      v_failed_count := v_failed_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'ok', false,
        'error_code', 'TASK_BATCH_TARGET_INVALID'
      ));
      continue;
    end if;

    select key into v_invalid_key
    from jsonb_object_keys(v_target) as key
    where key not in ('target_id', 'seller_id', 'assignee_member_id', 'due_at')
    limit 1;
    if v_invalid_key is not null then
      if v_mode = 'atomic' then
        raise exception using
          errcode = '22023',
          message = 'TASK_BATCH_TARGET_FIELD_NOT_ALLOWED',
          detail = jsonb_build_object(
            'target_index', v_index,
            'field', v_invalid_key,
            'error_code', 'TASK_BATCH_TARGET_FIELD_NOT_ALLOWED'
          )::text;
      end if;
      v_failed_count := v_failed_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'target_id', nullif(v_target ->> 'target_id', ''),
        'ok', false,
        'error_code', 'TASK_BATCH_TARGET_FIELD_NOT_ALLOWED',
        'field', v_invalid_key
      ));
      continue;
    end if;

    v_target_id := nullif(v_target ->> 'target_id', '');
    v_task := v_common || (v_target - 'target_id');

    begin
      v_created := public.rpc_create_task(
        p_organization_id,
        v_task,
        p_idempotency_key || ':' || v_index::text
      );

      update public.tasks
      set batch_id = v_batch_id
      where organization_id = p_organization_id
        and id = (v_created ->> 'task_id')::uuid
      returning * into v_created_task;

      update public.task_events
      set report_state_after = private.task_report_state(v_created_task)
      where organization_id = p_organization_id
        and task_id = v_created_task.id
        and task_version = v_created_task.version;

      v_created_count := v_created_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'target_id', v_target_id,
        'seller_id', v_created_task.seller_id,
        'assignee_member_id', v_created_task.assignee_member_id,
        'ok', true,
        'task_id', v_created_task.id,
        'task_number', v_created_task.task_number,
        'version', v_created_task.version
      ));
    exception when others then
      get stacked diagnostics v_error = message_text, v_sqlstate = returned_sqlstate;
      if v_mode = 'atomic' then
        raise exception using
          errcode = '22023',
          message = 'TASK_BATCH_TARGET_INVALID',
          detail = jsonb_build_object(
            'target_index', v_index,
            'target_id', v_target_id,
            'error_code', v_error,
            'sqlstate', v_sqlstate
          )::text;
      end if;
      v_failed_count := v_failed_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'target_id', v_target_id,
        'ok', false,
        'error_code', v_error
      ));
    end;
  end loop;

  v_result := jsonb_build_object(
    'batch_id', v_batch_id,
    'mode', v_mode,
    'created_count', v_created_count,
    'failed_count', v_failed_count,
    'results', v_results
  );

  perform private.task_idempotency_store(
    p_organization_id,
    v_actor_id,
    'task.create_batch',
    p_idempotency_key,
    v_request,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_update_task(
  p_task_id uuid,
  p_patch jsonb,
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
  v_patch jsonb := coalesce(p_patch, '{}'::jsonb);
  v_replay jsonb;
  v_result jsonb;
  v_now timestamptz := timezone('utc', now());
  v_title text;
  v_description text;
  v_priority text;
  v_planned_date date;
  v_due_at timestamptz;
  v_assignee_id uuid;
  v_reviewer_id uuid;
  v_requires_review boolean;
  v_requires_result boolean;
  v_requires_attachment boolean;
  v_allow_no_incident boolean;
  v_estimated_minutes integer;
  v_assigned_at timestamptz;
  v_acknowledged_at timestamptz;
  v_reason text;
  v_assignee_changed boolean := false;
  v_due_changed boolean := false;
  v_invalid_key text;
  v_before jsonb;
  v_after jsonb;
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

  if jsonb_typeof(v_patch) <> 'object' then
    raise exception using errcode = '22023', message = 'TASK_UPDATE_PATCH_INVALID';
  end if;
  select key into v_invalid_key
  from jsonb_object_keys(v_patch) as key
  where key not in (
    'title', 'description', 'priority', 'planned_date', 'due_at',
    'assignee_member_id', 'reviewer_member_id', 'requires_review',
    'requires_result', 'requires_attachment', 'allow_no_incident',
    'estimated_minutes', 'reason'
  )
  limit 1;
  if v_invalid_key is not null then
    raise exception using errcode = '22023', message = 'TASK_UPDATE_FIELD_NOT_ALLOWED', detail = v_invalid_key;
  end if;

  v_replay := private.task_idempotency_replay(
    v_task.organization_id,
    v_actor_id,
    'task.update',
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'patch', v_patch)
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if p_expected_version is null or p_expected_version <> v_task.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;
  if not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
    raise exception using errcode = '42501', message = 'TASK_UPDATE_DENIED';
  end if;
  if v_task.status in ('in_review', 'done', 'canceled', 'waived') then
    raise exception using errcode = '23514', message = 'TASK_UPDATE_NOT_ALLOWED';
  end if;

  v_title := v_task.title;
  v_description := v_task.description;
  v_priority := v_task.priority;
  v_planned_date := v_task.planned_date;
  v_due_at := v_task.due_at;
  v_assignee_id := v_task.assignee_member_id;
  v_reviewer_id := v_task.reviewer_member_id;
  v_requires_review := v_task.requires_review;
  v_requires_result := v_task.requires_result;
  v_requires_attachment := v_task.requires_attachment;
  v_allow_no_incident := v_task.allow_no_incident;
  v_estimated_minutes := v_task.estimated_minutes;
  v_assigned_at := v_task.assigned_at;
  v_acknowledged_at := v_task.acknowledged_at;
  v_reason := nullif(trim(v_patch ->> 'reason'), '');

  if v_patch ? 'title' then
    v_title := nullif(trim(v_patch ->> 'title'), '');
    if v_title is null or char_length(v_title) > 240 then
      raise exception using errcode = '22023', message = 'TASK_TITLE_INVALID';
    end if;
  end if;
  if v_patch ? 'description' then
    v_description := coalesce(v_patch ->> 'description', '');
    if char_length(v_description) > 10000 then
      raise exception using errcode = '22023', message = 'TASK_DESCRIPTION_TOO_LONG';
    end if;
  end if;
  if v_patch ? 'priority' then
    v_priority := nullif(trim(v_patch ->> 'priority'), '');
    if v_priority not in ('low', 'normal', 'high', 'urgent') then
      raise exception using errcode = '22023', message = 'TASK_PRIORITY_INVALID';
    end if;
  end if;
  if v_patch ? 'planned_date' then
    v_planned_date := private.task_json_date(v_patch, 'planned_date', 'TASK_PLANNED_DATE_INVALID');
    if v_planned_date is null then
      raise exception using errcode = '22023', message = 'TASK_PLANNED_DATE_REQUIRED';
    end if;
  end if;
  if v_patch ? 'due_at' then
    v_due_at := private.task_json_timestamptz(v_patch, 'due_at', 'TASK_DUE_AT_INVALID');
    if v_due_at is null then
      raise exception using errcode = '22023', message = 'TASK_DUE_AT_REQUIRED';
    end if;
    v_due_changed := v_due_at is distinct from v_task.due_at;
    if v_due_changed and v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_DEADLINE_CHANGE_REASON_REQUIRED';
    end if;
  end if;
  if v_patch ? 'assignee_member_id' then
    v_assignee_id := private.task_json_uuid(v_patch, 'assignee_member_id', 'TASK_ASSIGNEE_INVALID', true);
    v_assignee_changed := v_assignee_id is distinct from v_task.assignee_member_id;
    if v_assignee_changed then
      if v_task.status not in ('todo', 'in_progress') then
        raise exception using errcode = '23514', message = 'TASK_REASSIGN_DENIED';
      end if;
      if v_reason is null then
        raise exception using errcode = '22023', message = 'TASK_REASSIGN_REASON_REQUIRED';
      end if;
      if v_task.seller_id is null and v_actor.role <> 'admin' and v_assignee_id <> v_actor_id then
        raise exception using errcode = '42501', message = 'INTERNAL_TASK_REASSIGN_DENIED';
      end if;
      perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_assignee_id);
      v_assigned_at := v_now;
      v_acknowledged_at := null;
    end if;
  end if;
  if v_patch ? 'reviewer_member_id' then
    v_reviewer_id := private.task_json_uuid(v_patch, 'reviewer_member_id', 'TASK_REVIEWER_INVALID');
    if v_reviewer_id is not null then
      perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_reviewer_id);
    end if;
  end if;
  if v_patch ? 'requires_review' then
    v_requires_review := private.task_json_boolean(v_patch, 'requires_review', v_task.requires_review, 'TASK_REQUIRES_REVIEW_INVALID');
  end if;
  if v_patch ? 'requires_result' then
    v_requires_result := private.task_json_boolean(v_patch, 'requires_result', v_task.requires_result, 'TASK_REQUIRES_RESULT_INVALID');
  end if;
  if v_patch ? 'requires_attachment' then
    v_requires_attachment := private.task_json_boolean(v_patch, 'requires_attachment', v_task.requires_attachment, 'TASK_REQUIRES_ATTACHMENT_INVALID');
  end if;
  if v_patch ? 'allow_no_incident' then
    v_allow_no_incident := private.task_json_boolean(v_patch, 'allow_no_incident', v_task.allow_no_incident, 'TASK_ALLOW_NO_INCIDENT_INVALID');
  end if;
  if v_patch ? 'estimated_minutes' then
    v_estimated_minutes := private.task_json_integer(v_patch, 'estimated_minutes', 'TASK_ESTIMATED_MINUTES_INVALID');
    if v_estimated_minutes is not null and v_estimated_minutes <= 0 then
      raise exception using errcode = '22023', message = 'TASK_ESTIMATED_MINUTES_INVALID';
    end if;
  end if;

  if v_requires_review and v_reviewer_id is null then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_REQUIRED';
  end if;
  if v_reviewer_id is not null and v_reviewer_id = v_assignee_id then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
  end if;

  v_before := private.task_report_state(v_task);

  update public.tasks
  set title = v_title,
      description = v_description,
      priority = v_priority,
      planned_date = v_planned_date,
      due_at = v_due_at,
      assignee_member_id = v_assignee_id,
      reviewer_member_id = v_reviewer_id,
      requires_review = v_requires_review,
      requires_result = v_requires_result,
      requires_attachment = v_requires_attachment,
      allow_no_incident = v_allow_no_incident,
      estimated_minutes = v_estimated_minutes,
      assigned_at = v_assigned_at,
      acknowledged_at = v_acknowledged_at,
      last_meaningful_update_at = v_now,
      version = version + 1
  where id = v_task.id
  returning * into v_task;

  v_after := private.task_report_state(v_task);
  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload,
    report_state_after
  )
  values (
    v_task.organization_id,
    v_task.id,
    v_task.version,
    case when v_assignee_changed then 'reassigned' when v_due_changed then 'deadline_changed' else 'details_updated' end,
    v_actor_id,
    jsonb_build_object(
      'reason', v_reason,
      'before', v_before,
      'after', v_after
    ),
    v_after
  );

  perform private.write_audit(
    v_task.organization_id,
    case when v_assignee_changed then 'task.reassigned' when v_due_changed then 'task.deadline_changed' else 'task.details_updated' end,
    'task',
    v_task.id,
    jsonb_build_object('task_version', v_task.version, 'reason', v_reason),
    v_request_id
  );

  if v_assignee_changed then
    insert into private.outbox_events (
      organization_id, event_type, entity_type, entity_id, dedupe_key, payload
    )
    values (
      v_task.organization_id,
      'task.assigned',
      'task',
      v_task.id,
      'task:' || v_task.id::text || ':task-assigned:' || v_task.version::text,
      jsonb_build_object(
        'task_id', v_task.id,
        'task_version', v_task.version,
        'previous_assignee_member_id', (v_before ->> 'assignee_member_id')::uuid,
        'assignee_member_id', v_task.assignee_member_id,
        'reason', v_reason,
        'assigned_at', v_task.assigned_at
      )
    );
  end if;

  if v_due_changed then
    insert into private.outbox_events (
      organization_id, event_type, entity_type, entity_id, dedupe_key, payload
    )
    values (
      v_task.organization_id,
      'task.deadline_changed',
      'task',
      v_task.id,
      'task:' || v_task.id::text || ':task-deadline-changed:' || v_task.version::text,
      jsonb_build_object(
        'task_id', v_task.id,
        'task_version', v_task.version,
        'previous_due_at', v_before ->> 'due_at',
        'due_at', v_task.due_at,
        'reason', v_reason
      )
    )
    on conflict (organization_id, dedupe_key) do nothing;
  end if;

  v_result := jsonb_build_object(
    'task_id', v_task.id,
    'status', v_task.status,
    'version', v_task.version,
    'event_type', case when v_assignee_changed then 'reassigned' when v_due_changed then 'deadline_changed' else 'details_updated' end
  );

  perform private.task_idempotency_store(
    v_task.organization_id,
    v_actor_id,
    'task.update',
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'patch', v_patch),
    v_result
  );

  return v_result;
end;
$$;

revoke all on function private.task_json_uuid(jsonb, text, text, boolean) from public, anon, authenticated;
revoke all on function private.task_json_boolean(jsonb, text, boolean, text) from public, anon, authenticated;
revoke all on function private.task_json_integer(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.task_json_date(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.task_json_timestamptz(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.task_report_state(public.tasks) from public, anon, authenticated;
revoke all on function private.normalize_task_draft(jsonb) from public, anon, authenticated;
revoke all on function private.normalize_task_command_payload(text, jsonb) from public, anon, authenticated;

revoke all on function public.rpc_create_task(uuid, jsonb, text) from public, anon;
revoke all on function public.rpc_task_command(uuid, text, jsonb, integer, text) from public, anon;
revoke all on function public.rpc_create_task_batch(uuid, jsonb, jsonb, text, text) from public, anon;
revoke all on function public.rpc_update_task(uuid, jsonb, integer, text) from public, anon;

grant execute on function public.rpc_create_task(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_task_command(uuid, text, jsonb, integer, text) to authenticated;
grant execute on function public.rpc_create_task_batch(uuid, jsonb, jsonb, text, text) to authenticated;
grant execute on function public.rpc_update_task(uuid, jsonb, integer, text) to authenticated;
