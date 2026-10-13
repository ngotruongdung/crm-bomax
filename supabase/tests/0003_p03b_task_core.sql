begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

select has_table('public', 'tasks', 'P03B: tasks exists');
select has_table('public', 'task_checklist_items', 'P03B: task checklist exists');
select has_table('public', 'task_submissions', 'P03B: task submissions exists');
select has_table('public', 'task_events', 'P03B: task event history exists');
select has_table('private', 'outbox_events', 'P03B: transactional outbox exists');
select has_function('public', 'rpc_create_task', array['uuid', 'jsonb', 'text'], 'P03B: create task RPC exists');
select has_function('public', 'rpc_task_command', array['uuid', 'text', 'jsonb', 'integer', 'text'], 'P03B: task command RPC exists');
select has_function('public', 'rpc_create_task_batch', array['uuid', 'jsonb', 'jsonb', 'text', 'text'], 'P03B: batch create RPC exists');
select has_function('public', 'rpc_update_task', array['uuid', 'jsonb', 'integer', 'text'], 'P03B: optimistic update RPC exists');
select is((select relrowsecurity from pg_class where oid = 'public.tasks'::regclass), true, 'P03B: task RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.task_events'::regclass), true, 'P03B: task event RLS enabled');
select ok(not has_table_privilege('authenticated', 'public.tasks', 'INSERT'), 'P03B: authenticated cannot insert task rows directly');
select ok(not has_table_privilege('authenticated', 'public.tasks', 'UPDATE'), 'P03B: authenticated cannot update task rows directly');
select ok(not has_table_privilege('authenticated', 'public.tasks', 'DELETE'), 'P03B: authenticated cannot delete task rows directly');
select ok(not has_function_privilege('authenticated', 'public.rpc_create_task_p03b_legacy(uuid,jsonb,text)', 'EXECUTE'), 'P03B: legacy create RPC is isolated');
select ok(not has_function_privilege('authenticated', 'public.rpc_task_command_p03b_legacy(uuid,text,jsonb,integer,text)', 'EXECUTE'), 'P03B: legacy command RPC is isolated');

insert into auth.users (id, aud, role, email)
values
  ('43000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'p03b.admin@opsdesk.local'),
  ('43000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'p03b.manager@opsdesk.local'),
  ('43000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'p03b.assignee-a@opsdesk.local'),
  ('43000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'p03b.reviewer-a@opsdesk.local'),
  ('43000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'p03b.replacement-a@opsdesk.local'),
  ('43000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'p03b.employee-b@opsdesk.local'),
  ('43000000-0000-0000-0000-000000000007', 'authenticated', 'authenticated', 'p03b.employee-c@opsdesk.local');

insert into public.organizations (id, name, slug)
values ('53000000-0000-0000-0000-000000000001', 'pgTAP P03B', 'pgtap-p03b');

insert into public.organization_members (id, organization_id, user_id, employee_code, display_name, role, status)
values
  ('63000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000001', 'P3-ADM', 'P03B Admin', 'admin', 'active'),
  ('63000000-0000-0000-0000-000000000002', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000002', 'P3-MGR', 'P03B Manager', 'manager', 'active'),
  ('63000000-0000-0000-0000-000000000003', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000003', 'P3-A', 'P03B Assignee A', 'employee', 'active'),
  ('63000000-0000-0000-0000-000000000004', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000004', 'P3-REV', 'P03B Reviewer A', 'employee', 'active'),
  ('63000000-0000-0000-0000-000000000005', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000005', 'P3-A2', 'P03B Replacement A', 'employee', 'active'),
  ('63000000-0000-0000-0000-000000000006', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000006', 'P3-B', 'P03B Employee B', 'employee', 'active'),
  ('63000000-0000-0000-0000-000000000007', '53000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000007', 'P3-C', 'P03B Employee C', 'employee', 'active');

update public.organizations
set owner_member_id = '63000000-0000-0000-0000-000000000001'
where id = '53000000-0000-0000-0000-000000000001';

insert into public.sellers (id, organization_id, code, name, platform)
values
  ('73000000-0000-0000-0000-000000000001', '53000000-0000-0000-0000-000000000001', 'P3-A', 'P03B Seller A', 'shopee'),
  ('73000000-0000-0000-0000-000000000002', '53000000-0000-0000-0000-000000000001', 'P3-B', 'P03B Seller B', 'tiktok_shop'),
  ('73000000-0000-0000-0000-000000000003', '53000000-0000-0000-0000-000000000001', 'P3-C', 'P03B Seller C', 'lazada');

insert into public.seller_members (organization_id, seller_id, member_id, is_manager, active_from)
values
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000002', true, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000002', '63000000-0000-0000-0000-000000000002', true, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000003', '63000000-0000-0000-0000-000000000002', true, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000003', false, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000004', false, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000001', '63000000-0000-0000-0000-000000000005', false, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000002', '63000000-0000-0000-0000-000000000006', false, current_date - 1),
  ('53000000-0000-0000-0000-000000000001', '73000000-0000-0000-0000-000000000003', '63000000-0000-0000-0000-000000000007', false, current_date - 1);

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"43000000-0000-0000-0000-000000000002"}', true);

select lives_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-01 transactional create',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day',
      'checklist', jsonb_build_array(jsonb_build_object('title', 'Required proof', 'is_required', true))
    ),
    'task-01-create'
  )$$,
  'TASK-01: valid create succeeds transactionally'
);

reset role;
select is((select count(*)::integer from public.tasks where title = 'TASK-01 transactional create'), 1, 'TASK-01: one task row created');
select is((select count(*)::integer from public.task_checklist_items where task_id = (select id from public.tasks where title = 'TASK-01 transactional create')), 1, 'TASK-01: checklist created in same transaction');
select is((select count(*)::integer from public.task_events where task_id = (select id from public.tasks where title = 'TASK-01 transactional create') and event_type = 'created'), 1, 'TASK-01: create event written');
select is((select count(*)::integer from public.audit_logs where entity_type = 'task' and entity_id = (select id from public.tasks where title = 'TASK-01 transactional create') and action = 'task.created'), 1, 'TASK-01: audit written');
select is((select count(*)::integer from private.outbox_events where entity_id = (select id from public.tasks where title = 'TASK-01 transactional create') and event_type = 'task.assigned'), 1, 'TASK-01: outbox written');
select is((select requires_result from public.tasks where title = 'TASK-01 transactional create'), true, 'TASK-01: requires_result defaults ON');

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);

select lives_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-02 idempotent create',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '2 days'
    ),
    'task-02-same-key'
  )$$,
  'TASK-02: first idempotent create succeeds'
);
select is(
  (public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-02 idempotent create',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '2 days'
    ),
    'task-02-same-key'
  ) ->> 'task_id')::uuid,
  (select id from public.tasks where title = 'TASK-02 idempotent create'),
  'TASK-02: replay returns the same task result'
);
select is((select count(*)::integer from public.tasks where title = 'TASK-02 idempotent create'), 1, 'TASK-02: replay never duplicates the task');

select throws_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-03 changed payload',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '2 days'
    ),
    'task-02-same-key'
  )$$,
  '22023',
  'IDEMPOTENCY_KEY_REUSED',
  'TASK-03: idempotency key cannot be reused for a different payload'
);

select throws_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-04 outside scope',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000006',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day'
    ),
    'task-04-scope'
  )$$,
  '42501',
  'TASK_MEMBER_OUTSIDE_SELLER_SCOPE',
  'TASK-04: assignee outside seller scope is rejected'
);
reset role;
select is((select count(*)::integer from public.tasks where title = 'TASK-04 outside scope'), 0, 'TASK-04: scope failure leaves no partial task');

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-05 acknowledge',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day'
  ),
  'task-05-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-05 acknowledge'),
    'ack', '{}'::jsonb, 1, 'task-05-ack'
  )$$,
  'TASK-05: assignee can acknowledge a todo task'
);
select is((select status from public.tasks where title = 'TASK-05 acknowledge'), 'todo', 'TASK-05: ack keeps status todo');
select ok((select acknowledged_at is not null from public.tasks where title = 'TASK-05 acknowledge'), 'TASK-05: acknowledged_at is populated');

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-06 start auto ack',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day'
  ),
  'task-06-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-06 start auto ack'),
    'start', '{}'::jsonb, 1, 'task-06-start'
  )$$,
  'TASK-06: start succeeds without a prior ack'
);
select is((select status from public.tasks where title = 'TASK-06 start auto ack'), 'in_progress', 'TASK-06: start moves task to in_progress');
select ok((select acknowledged_at is not null and started_at is not null from public.tasks where title = 'TASK-06 start auto ack'), 'TASK-06: start auto-acks and sets started_at');
select is((select count(*)::integer from public.task_events where task_id = (select id from public.tasks where title = 'TASK-06 start auto ack') and event_type = 'started'), 1, 'TASK-06: start event is preserved');

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-07 checklist gate',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day',
    'requires_result', false,
    'checklist', jsonb_build_array(jsonb_build_object('title', 'Upload reconciliation', 'is_required', true))
  ),
  'task-07-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-07 checklist gate'),
    'submit', '{}'::jsonb, 1, 'task-07-submit'
  )$$,
  '23514',
  'TASK_REQUIRED_CHECKLIST_INCOMPLETE',
  'TASK-07: submit is blocked while a required checklist item is missing'
);
select is((select title from public.task_checklist_items where task_id = (select id from public.tasks where title = 'TASK-07 checklist gate') and checked_at is null), 'Upload reconciliation', 'TASK-07: missing required item remains identifiable');

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-08 result evidence gate',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day',
    'requires_result', true,
    'requires_attachment', true
  ),
  'task-08-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-08 result evidence gate'),
    'submit', '{}'::jsonb, 1, 'task-08-no-result'
  )$$,
  '23514',
  'TASK_RESULT_REQUIRED',
  'TASK-08: result text is required when configured'
);
select throws_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-08 result evidence gate'),
    'submit', jsonb_build_object('result_text', 'Completed'), 1, 'task-08-no-evidence'
  )$$,
  '23514',
  'TASK_EVIDENCE_REQUIRED',
  'TASK-08: evidence is required when configured'
);

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-09 review flow',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'reviewer_member_id', '63000000-0000-0000-0000-000000000002',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day',
    'requires_review', true,
    'requires_result', true
  ),
  'task-09-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-09 review flow'),
    'submit', jsonb_build_object('result_text', 'Ready for review'), 1, 'task-09-submit'
  )$$,
  'TASK-09: submit with reviewer succeeds'
);
select is((select status from public.tasks where title = 'TASK-09 review flow'), 'in_review', 'TASK-09: reviewed task enters in_review');
select is((select count(*)::integer from public.task_submissions where task_id = (select id from public.tasks where title = 'TASK-09 review flow') and review_state = 'pending'), 1, 'TASK-09: immutable pending submission is created');
reset role;
select is((select count(*)::integer from private.outbox_events where entity_id = (select id from public.tasks where title = 'TASK-09 review flow') and event_type = 'task.review_requested'), 1, 'TASK-09: reviewer outbox event is queued');

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-10 no review done',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day',
    'requires_review', false,
    'requires_result', true
  ),
  'task-10-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-10 no review done'),
    'submit', jsonb_build_object('result_text', 'Done'), 1, 'task-10-submit'
  )$$,
  'TASK-10: submit without review completes immediately'
);
select ok((select status = 'done' and completed_at is not null from public.tasks where title = 'TASK-10 no review done'), 'TASK-10: task is done with completed_at');

select throws_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-09 review flow'),
    'approve', '{}'::jsonb, 2, 'task-11-self-approve'
  )$$,
  '42501',
  'TASK_SELF_APPROVAL_DENIED',
  'TASK-11: assignee can never approve their own submission'
);

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-09 review flow'),
    'request_changes',
    jsonb_build_object('reason', 'Need clearer proof', 'revision_due_at', timezone('utc', now()) + interval '12 hours'),
    2,
    'task-12-request-changes'
  )$$,
  'TASK-12: reviewer can request changes with reason'
);
select is((select status from public.tasks where title = 'TASK-09 review flow'), 'in_progress', 'TASK-12: request changes returns task to in_progress');
select is((select review_state from public.task_submissions where task_id = (select id from public.tasks where title = 'TASK-09 review flow') and revision = 1), 'changes_requested', 'TASK-12: prior submission is retained as changes_requested');
select is((select review_reason from public.task_submissions where task_id = (select id from public.tasks where title = 'TASK-09 review flow') and revision = 1), 'Need clearer proof', 'TASK-12: review reason is retained');

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-13 version conflict',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day'
  ),
  'task-13-create'
);
select lives_ok(
  $$select public.rpc_update_task(
    (select id from public.tasks where title = 'TASK-13 version conflict'),
    jsonb_build_object('title', 'TASK-13 winner'),
    1,
    'task-13-winner'
  )$$,
  'TASK-13: first writer with expected version succeeds'
);
select throws_ok(
  $$select public.rpc_update_task(
    (select id from public.tasks where title = 'TASK-13 winner'),
    jsonb_build_object('title', 'TASK-13 stale writer'),
    1,
    'task-13-stale'
  )$$,
  '40001',
  'VERSION_CONFLICT',
  'TASK-13: stale concurrent version is rejected'
);
select is((select title from public.tasks where title like 'TASK-13%'), 'TASK-13 winner', 'TASK-13: stale writer cannot overwrite the winner');

select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-14 reassign',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', timezone('utc', now()) + interval '1 day'
  ),
  'task-14-create'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000003', true);
select public.rpc_task_command(
  (select id from public.tasks where title = 'TASK-14 reassign'),
  'ack', '{}'::jsonb, 1, 'task-14-ack'
);
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-14 reassign'),
    'reassign',
    jsonb_build_object('assignee_member_id', '63000000-0000-0000-0000-000000000005', 'reason', 'Balance workload'),
    2,
    'task-14-reassign'
  )$$,
  'TASK-14: manager can reassign with reason'
);
select ok((select assignee_member_id = '63000000-0000-0000-0000-000000000005'::uuid and acknowledged_at is null from public.tasks where title = 'TASK-14 reassign'), 'TASK-14: new assignee is unacknowledged');
select is((select count(*)::integer from public.task_events where task_id = (select id from public.tasks where title = 'TASK-14 reassign')), 3, 'TASK-14: assignment history is preserved');
select is((select event_payload ->> 'reason' from public.task_events where task_id = (select id from public.tasks where title = 'TASK-14 reassign') and event_type = 'reassigned'), 'Balance workload', 'TASK-14: reassign reason is audited in history');

select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object(
    'title', 'TASK-15 deadline history',
    'seller_id', '73000000-0000-0000-0000-000000000001',
    'assignee_member_id', '63000000-0000-0000-0000-000000000003',
    'planned_date', current_date,
    'due_at', '2030-01-01T10:00:00+00:00'
  ),
  'task-15-create'
);
select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-15 deadline history'),
    'change_deadline',
    jsonb_build_object('due_at', '2030-01-02T10:00:00+00:00', 'reason', 'Carrier cutoff changed'),
    1,
    'task-15-deadline'
  )$$,
  'TASK-15: manager can change deadline with reason'
);
select ok((select original_due_at = '2030-01-01T10:00:00+00:00'::timestamptz and due_at = '2030-01-02T10:00:00+00:00'::timestamptz from public.tasks where title = 'TASK-15 deadline history'), 'TASK-15: original_due_at is immutable');
select ok((select event_payload ? 'before' and event_payload ? 'after' and event_payload ->> 'reason' = 'Carrier cutoff changed' from public.task_events where task_id = (select id from public.tasks where title = 'TASK-15 deadline history') and event_type = 'deadline_changed'), 'TASK-15: event keeps before/after deadline and reason');
reset role;
select is((select count(*)::integer from private.outbox_events where entity_id = (select id from public.tasks where title = 'TASK-15 deadline history') and event_type = 'task.deadline_changed'), 1, 'TASK-15: deadline outbox event is queued');

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object('title', 'TASK-16 cancel', 'seller_id', '73000000-0000-0000-0000-000000000001', 'assignee_member_id', '63000000-0000-0000-0000-000000000003', 'planned_date', current_date, 'due_at', timezone('utc', now()) + interval '1 day'),
  'task-16-cancel-create'
);
select public.rpc_create_task(
  '53000000-0000-0000-0000-000000000001',
  jsonb_build_object('title', 'TASK-16 waive', 'seller_id', '73000000-0000-0000-0000-000000000001', 'assignee_member_id', '63000000-0000-0000-0000-000000000003', 'planned_date', current_date, 'due_at', timezone('utc', now()) + interval '1 day'),
  'task-16-waive-create'
);
select public.rpc_task_command((select id from public.tasks where title = 'TASK-16 cancel'), 'cancel', jsonb_build_object('reason', 'No longer needed'), 1, 'task-16-cancel');
select public.rpc_task_command((select id from public.tasks where title = 'TASK-16 waive'), 'waive', jsonb_build_object('reason', 'Seller exception'), 1, 'task-16-waive');
select is((select status from public.tasks where title = 'TASK-16 cancel'), 'canceled', 'TASK-16: cancel reaches terminal canceled state');
select is((select status from public.tasks where title = 'TASK-16 waive'), 'waived', 'TASK-16: waive reaches terminal waived state');
select is((select count(*)::integer from public.task_events where task_id = (select id from public.tasks where title = 'TASK-16 cancel')), 2, 'TASK-16: canceled task keeps raw event history');
select is((select count(*)::integer from public.task_events where task_id = (select id from public.tasks where title = 'TASK-16 waive')), 2, 'TASK-16: waived task keeps raw event history');

select lives_ok(
  $$select public.rpc_task_command(
    (select id from public.tasks where title = 'TASK-10 no review done'),
    'reopen', jsonb_build_object('reason', 'Correction required'), 2, 'task-18-reopen'
  )$$,
  'TASK-18: manager can reopen a completed task with reason'
);
select is((select status from public.tasks where title = 'TASK-10 no review done'), 'in_progress', 'TASK-18: reopened task returns to in_progress');
select is((select report_state_after ->> 'status' from public.task_events where task_id = (select id from public.tasks where title = 'TASK-10 no review done') and event_type = 'completed'), 'done', 'TASK-18: prior completed report snapshot remains immutable');
select is((select report_state_after ->> 'status' from public.task_events where task_id = (select id from public.tasks where title = 'TASK-10 no review done') and event_type = 'reopened'), 'in_progress', 'TASK-18: reopen writes a new report snapshot');

select throws_ok(
  $$select public.rpc_create_task_batch(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object('title', 'TASK-19 atomic bulk', 'planned_date', current_date, 'due_at', timezone('utc', now()) + interval '1 day'),
    jsonb_build_array(
      jsonb_build_object('target_id', 'a', 'seller_id', '73000000-0000-0000-0000-000000000001', 'assignee_member_id', '63000000-0000-0000-0000-000000000003'),
      jsonb_build_object('target_id', 'b-bad', 'seller_id', '73000000-0000-0000-0000-000000000002', 'assignee_member_id', '63000000-0000-0000-0000-000000000003'),
      jsonb_build_object('target_id', 'c', 'seller_id', '73000000-0000-0000-0000-000000000003', 'assignee_member_id', '63000000-0000-0000-0000-000000000007')
    ),
    'task-19-atomic',
    'atomic'
  )$$,
  '22023',
  'TASK_BATCH_TARGET_INVALID',
  'TASK-19: atomic bulk rejects the whole batch when one seller target is invalid'
);
reset role;
select is((select count(*)::integer from public.tasks where title = 'TASK-19 atomic bulk'), 0, 'TASK-19: atomic mode rolls back earlier valid targets');

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select is(
  (public.rpc_create_task_batch(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object('title', 'TASK-19 valid only bulk', 'planned_date', current_date, 'due_at', timezone('utc', now()) + interval '1 day'),
    jsonb_build_array(
      jsonb_build_object('target_id', 'a', 'seller_id', '73000000-0000-0000-0000-000000000001', 'assignee_member_id', '63000000-0000-0000-0000-000000000003'),
      jsonb_build_object('target_id', 'b-bad', 'seller_id', '73000000-0000-0000-0000-000000000002', 'assignee_member_id', '63000000-0000-0000-0000-000000000003'),
      jsonb_build_object('target_id', 'c', 'seller_id', '73000000-0000-0000-0000-000000000003', 'assignee_member_id', '63000000-0000-0000-0000-000000000007')
    ),
    'task-19-valid-only',
    'valid_only'
  ) ->> 'created_count')::integer,
  2,
  'TASK-19: valid_only creates the two valid seller targets'
);
select is((select count(*)::integer from public.tasks where title = 'TASK-19 valid only bulk'), 2, 'TASK-19: valid_only persists exactly two tasks');

select throws_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-20 rollback after insert',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day',
      'checklist', jsonb_build_array(jsonb_build_object('title', '   ', 'is_required', true))
    ),
    'task-20-rollback'
  )$$,
  '22023',
  'TASK_CHECKLIST_TITLE_REQUIRED',
  'TASK-20: SQL failure after task insert aborts the create statement'
);
reset role;
select is((select count(*)::integer from public.tasks where title = 'TASK-20 rollback after insert'), 0, 'TASK-20: rollback leaves no orphan task');
select is((select count(*)::integer from public.audit_logs where entity_type = 'task' and safe_metadata ->> 'task_number' is not null and entity_id not in (select id from public.tasks)), 0, 'TASK-20: no orphan task audit is left behind');
select is((select count(*)::integer from private.outbox_events where entity_type = 'task' and entity_id not in (select id from public.tasks)), 0, 'TASK-20: no orphan task outbox event is left behind');

set local role authenticated;
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000002', true);
select throws_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-21 employee reviewer create denied',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'reviewer_member_id', '63000000-0000-0000-0000-000000000004',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day',
      'requires_review', true
    ),
    'task-21-employee-reviewer-create'
  )$$,
  '42501',
  'TASK_REVIEWER_ROLE_DENIED',
  'TASK-21: employee reviewer is rejected on create'
);
select is((select count(*)::integer from public.tasks where title = 'TASK-21 employee reviewer create denied'), 0, 'TASK-21: rejected reviewer create leaves no task');

select lives_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-21 manager reviewer valid',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000003',
      'reviewer_member_id', '63000000-0000-0000-0000-000000000002',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day',
      'requires_review', true
    ),
    'task-21-manager-reviewer-create'
  )$$,
  'TASK-21: scoped manager reviewer is accepted'
);

select throws_ok(
  $$select public.rpc_update_task(
    (select id from public.tasks where title = 'TASK-21 manager reviewer valid'),
    jsonb_build_object('reviewer_member_id', '63000000-0000-0000-0000-000000000004'),
    1,
    'task-21-employee-reviewer-update'
  )$$,
  '42501',
  'TASK_REVIEWER_ROLE_DENIED',
  'TASK-21: employee reviewer is rejected on update'
);
select is((select reviewer_member_id from public.tasks where title = 'TASK-21 manager reviewer valid'), '63000000-0000-0000-0000-000000000002'::uuid, 'TASK-21: rejected update preserves the manager reviewer');

select throws_ok(
  $$select public.rpc_create_task(
    '53000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'TASK-21 reviewer cannot self-assign',
      'seller_id', '73000000-0000-0000-0000-000000000001',
      'assignee_member_id', '63000000-0000-0000-0000-000000000002',
      'reviewer_member_id', '63000000-0000-0000-0000-000000000002',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day',
      'requires_review', true
    ),
    'task-21-reviewer-self-assignee'
  )$$,
  '22023',
  'TASK_REVIEWER_CANNOT_BE_ASSIGNEE',
  'TASK-21: reviewer still cannot equal assignee'
);

select * from finish();
rollback;
