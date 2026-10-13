begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

select has_table('public', 'recurring_task_templates', 'P04: recurring templates exist');
select has_table('public', 'recurring_task_template_versions', 'P04: immutable template versions exist');
select has_table('public', 'recurring_task_targets', 'P04: recurring targets exist');
select has_table('public', 'recurring_task_occurrences', 'P04: recurring occurrences exist');
select has_function('public', 'rpc_create_recurring_template', array['uuid', 'jsonb', 'text'], 'P04: create recurring template RPC exists');
select has_function('public', 'rpc_update_recurring_template', array['uuid', 'jsonb', 'date', 'text', 'integer', 'text'], 'P04: update recurring template RPC exists');
select has_function('public', 'rpc_recurring_template_command', array['uuid', 'text', 'text', 'integer', 'text'], 'P04: recurring command RPC exists');
select has_function('public', 'rpc_assign_recurring_occurrence', array['uuid', 'uuid', 'text', 'text'], 'P04: manager assignment RPC exists');
select has_function('private', 'materialize_recurring_occurrences', array['uuid', 'date', 'integer'], 'P04: service materializer exists');

select is((select relrowsecurity from pg_class where oid = 'public.recurring_task_templates'::regclass), true, 'P04: template RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.recurring_task_occurrences'::regclass), true, 'P04: occurrence RLS enabled');
select ok(not has_table_privilege('authenticated', 'public.recurring_task_templates', 'INSERT'), 'P04: authenticated cannot insert templates directly');
select ok(not has_table_privilege('authenticated', 'public.recurring_task_occurrences', 'UPDATE'), 'P04: authenticated cannot update occurrences directly');
select ok(not has_function_privilege('authenticated', 'private.materialize_recurring_occurrences(uuid,date,integer)', 'EXECUTE'), 'P04: authenticated cannot invoke materializer');
select ok(has_function_privilege('service_role', 'private.materialize_recurring_occurrences(uuid,date,integer)', 'EXECUTE'), 'P04: service role can invoke materializer');

insert into auth.users (id, aud, role, email)
values
  ('44000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'p04.admin@opsdesk.local'),
  ('44000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'p04.assignee@opsdesk.local'),
  ('44000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'p04.replacement@opsdesk.local'),
  ('44000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'p04.inactive@opsdesk.local');

insert into public.organizations (id, name, slug, timezone)
values ('54000000-0000-0000-0000-000000000001', 'pgTAP P04', 'pgtap-p04', 'Asia/Ho_Chi_Minh');

insert into public.organization_members (id, organization_id, user_id, employee_code, display_name, role, status)
values
  ('64000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001', '44000000-0000-0000-0000-000000000001', 'P4-ADM', 'P04 Admin', 'admin', 'active'),
  ('64000000-0000-0000-0000-000000000002', '54000000-0000-0000-0000-000000000001', '44000000-0000-0000-0000-000000000002', 'P4-A', 'P04 Assignee', 'employee', 'active'),
  ('64000000-0000-0000-0000-000000000003', '54000000-0000-0000-0000-000000000001', '44000000-0000-0000-0000-000000000003', 'P4-R', 'P04 Replacement', 'employee', 'active'),
  ('64000000-0000-0000-0000-000000000004', '54000000-0000-0000-0000-000000000001', '44000000-0000-0000-0000-000000000004', 'P4-X', 'P04 Inactive', 'employee', 'inactive');

update public.organizations
set owner_member_id = '64000000-0000-0000-0000-000000000001'
where id = '54000000-0000-0000-0000-000000000001';

insert into public.sellers (id, organization_id, code, name, platform)
values ('74000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001', 'P4-S', 'P04 Seller', 'shopee');

insert into public.seller_members (organization_id, seller_id, member_id, is_manager, active_from)
values
  ('54000000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000002', false, current_date - 30),
  ('54000000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000003', false, current_date - 30),
  ('54000000-0000-0000-0000-000000000001', '74000000-0000-0000-0000-000000000001', '64000000-0000-0000-0000-000000000004', false, current_date - 30);

-- DAILY-01: a normal non-recurring task remains exactly one task with no occurrence link.
set local role authenticated;
select set_config('request.jwt.claim.sub', '44000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_create_task(
    '54000000-0000-0000-0000-000000000001',
    jsonb_build_object(
      'title', 'DAILY-01 one-off task',
      'seller_id', '74000000-0000-0000-0000-000000000001',
      'assignee_member_id', '64000000-0000-0000-0000-000000000002',
      'planned_date', current_date,
      'due_at', timezone('utc', now()) + interval '1 day'
    ),
    'daily-01-one-off'
  )$$,
  'DAILY-01: non-Daily create succeeds once'
);
reset role;
select is((select count(*)::integer from public.tasks where title = 'DAILY-01 one-off task'), 1, 'DAILY-01: one-off creates one task');
select ok((select template_occurrence_id is null from public.tasks where title = 'DAILY-01 one-off task'), 'DAILY-01: one-off task is not linked to recurrence');

-- DAILY-02 and DAILY-14: schedule matching follows ISO work_date semantics.
select ok(
  private.recurring_schedule_matches('working_days', '{}'::smallint[], current_date - 30, null, date '2026-10-05'),
  'DAILY-02: working_days includes a Monday'
);
select ok(
  not private.recurring_schedule_matches('working_days', '{}'::smallint[], current_date - 30, null, date '2026-10-04'),
  'DAILY-02: working_days excludes a Sunday'
);
select ok(
  private.recurring_schedule_matches('weekdays', array[1]::smallint[], date '2026-10-05', null, date '2026-10-05'),
  'DAILY-14: weekday matching uses ISO Monday=1 work_date semantics'
);

-- Historical fixture used by DAILY-03/04/05/11/12.
insert into public.recurring_task_templates (
  id, organization_id, status, current_version_number, generation_floor_date, created_by_member_id
) values (
  '94000000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001',
  'active', 1, current_date - 10, '64000000-0000-0000-0000-000000000001'
);

insert into public.recurring_task_template_versions (
  id, organization_id, template_id, version_number, effective_from, title, description,
  schedule_kind, weekdays, start_date, due_time, priority, requires_result, checklist,
  created_by_member_id
) values (
  '94100000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000001', 1, current_date - 10,
  'DAILY delayed recurring', '', 'every_day', '{}'::smallint[], current_date - 10, time '09:00',
  'normal', true, '[]'::jsonb, '64000000-0000-0000-0000-000000000001'
);

insert into public.recurring_task_targets (
  id, organization_id, template_id, version_id, target_key, seller_id, assignment_mode, assignee_member_id
) values (
  '94200000-0000-0000-0000-000000000001', '54000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000001', '94100000-0000-0000-0000-000000000001', 'primary',
  '74000000-0000-0000-0000-000000000001', 'fixed', '64000000-0000-0000-0000-000000000002'
);

select lives_ok(
  $$select private.materialize_recurring_occurrences('54000000-0000-0000-0000-000000000001', current_date, 3)$$,
  'DAILY-12: bounded delayed catch-up materializes safely'
);
select is(
  (select count(*)::integer from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000001'),
  3,
  'DAILY-12: catch-up is bounded to requested three-day window'
);
select is(
  (select count(*)::integer from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000001' and generation_kind = 'system_delay'),
  2,
  'DAILY-12: delayed historical occurrences are marked system_delay'
);
select is(
  (select attention_code from public.recurring_task_templates where id = '94000000-0000-0000-0000-000000000001'),
  'SYSTEM_DELAY_CATCHUP_LIMITED',
  'DAILY-12: bounded catch-up leaves an explicit manager attention signal'
);
select is(
  (select count(*)::integer from public.tasks where template_occurrence_id in (
    select id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000001'
  )),
  3,
  'DAILY-04: each generated work_date has a fresh task row'
);
select ok(
  (select count(*) = 2 from public.tasks where template_occurrence_id in (
    select id from public.recurring_task_occurrences
    where template_id = '94000000-0000-0000-0000-000000000001' and work_date < current_date
  ) and status = 'todo'),
  'DAILY-05: prior overdue work remains alongside today task instead of being replaced'
);
select is(
  (select count(*)::integer from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000001' and work_date = current_date),
  1,
  'DAILY-11: a valid template can generate the current work_date'
);

select private.materialize_recurring_occurrences('54000000-0000-0000-0000-000000000001', current_date, 3);
select is(
  (select count(*)::integer from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000001'),
  3,
  'DAILY-03: rerunning generator for the same dates creates no duplicate occurrence'
);
select is(
  (select count(*)::integer from public.tasks where template_occurrence_id in (
    select id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000001'
  )),
  3,
  'DAILY-03: rerunning generator creates no duplicate task'
);

-- DAILY-06 / DAILY-10: assignee becomes inactive after template creation.
insert into public.recurring_task_templates (
  id, organization_id, status, current_version_number, generation_floor_date, created_by_member_id
) values (
  '94000000-0000-0000-0000-000000000002', '54000000-0000-0000-0000-000000000001',
  'active', 1, current_date, '64000000-0000-0000-0000-000000000001'
);
insert into public.recurring_task_template_versions (
  id, organization_id, template_id, version_number, effective_from, title, description,
  schedule_kind, weekdays, start_date, due_time, priority, requires_result, checklist,
  created_by_member_id
) values (
  '94100000-0000-0000-0000-000000000002', '54000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000002', 1, current_date,
  'DAILY unavailable recurring', '', 'every_day', '{}'::smallint[], current_date, time '10:00',
  'normal', true, '[]'::jsonb, '64000000-0000-0000-0000-000000000001'
);
insert into public.recurring_task_targets (
  id, organization_id, template_id, version_id, target_key, seller_id, assignment_mode, assignee_member_id
) values (
  '94200000-0000-0000-0000-000000000002', '54000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000002', '94100000-0000-0000-0000-000000000002', 'primary',
  '74000000-0000-0000-0000-000000000001', 'fixed', '64000000-0000-0000-0000-000000000004'
);
select private.materialize_recurring_occurrences('54000000-0000-0000-0000-000000000001', current_date, 1);
select is(
  (select state from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000002'),
  'needs_assignment',
  'DAILY-06: unavailable fixed assignee becomes needs_assignment'
);
select is(
  (select task_id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000002'),
  null::uuid,
  'DAILY-06: unavailable assignee is never force-assigned or silently dropped'
);
select is(
  (select attention_code from public.recurring_task_templates where id = '94000000-0000-0000-0000-000000000002'),
  'ASSIGNEE_UNAVAILABLE',
  'DAILY-10: inactive assignee creates a manager-visible issue'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '44000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_assign_recurring_occurrence(
    (select id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000002'),
    '64000000-0000-0000-0000-000000000003',
    'Coverage replacement for unavailable assignee',
    'daily-06-assign'
  )$$,
  'DAILY-06: manager can resolve the coverage issue with an eligible replacement'
);
select is(
  (public.rpc_assign_recurring_occurrence(
    (select id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000002'),
    '64000000-0000-0000-0000-000000000003',
    'Coverage replacement for unavailable assignee',
    'daily-06-assign'
  ) ->> 'task_id')::uuid,
  (select task_id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000002'),
  'DAILY-06: assignment retry is idempotent and returns the same task'
);
reset role;
select is(
  (select count(*)::integer from public.tasks where template_occurrence_id = (
    select id from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000002'
  )),
  1,
  'DAILY-06: resolved occurrence materializes exactly one task'
);

-- DAILY-08: pause/resume moves generation floor forward, preventing paused-window backfill.
insert into public.recurring_task_templates (
  id, organization_id, status, current_version_number, generation_floor_date, created_by_member_id
) values (
  '94000000-0000-0000-0000-000000000003', '54000000-0000-0000-0000-000000000001',
  'active', 1, current_date - 5, '64000000-0000-0000-0000-000000000001'
);
insert into public.recurring_task_template_versions (
  id, organization_id, template_id, version_number, effective_from, title, description,
  schedule_kind, weekdays, start_date, due_time, priority, requires_result, checklist,
  created_by_member_id
) values (
  '94100000-0000-0000-0000-000000000003', '54000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000003', 1, current_date - 5,
  'DAILY pause resume', '', 'every_day', '{}'::smallint[], current_date - 5, time '11:00',
  'normal', true, '[]'::jsonb, '64000000-0000-0000-0000-000000000001'
);
insert into public.recurring_task_targets (
  id, organization_id, template_id, version_id, target_key, seller_id, assignment_mode, assignee_member_id
) values (
  '94200000-0000-0000-0000-000000000003', '54000000-0000-0000-0000-000000000001',
  '94000000-0000-0000-0000-000000000003', '94100000-0000-0000-0000-000000000003', 'primary',
  '74000000-0000-0000-0000-000000000001', 'fixed', '64000000-0000-0000-0000-000000000002'
);
set local role authenticated;
select set_config('request.jwt.claim.sub', '44000000-0000-0000-0000-000000000001', true);
select public.rpc_recurring_template_command('94000000-0000-0000-0000-000000000003', 'pause', 'Pause for test', 1, 'daily-08-pause');
select public.rpc_recurring_template_command('94000000-0000-0000-0000-000000000003', 'resume', 'Resume for test', 2, 'daily-08-resume');
reset role;
select is(
  (select generation_floor_date from public.recurring_task_templates where id = '94000000-0000-0000-0000-000000000003'),
  private.organization_local_date('54000000-0000-0000-0000-000000000001'),
  'DAILY-08: resume advances floor to today so paused dates are not backfilled'
);
select private.materialize_recurring_occurrences('54000000-0000-0000-0000-000000000001', current_date, 7);
select is(
  (select count(*)::integer from public.recurring_task_occurrences where template_id = '94000000-0000-0000-0000-000000000003' and work_date < current_date),
  0,
  'DAILY-08: no paused-window historical occurrence appears after resume'
);

-- DAILY-09: a new version is additive; already-materialized occurrence remains on its original version.
set local role authenticated;
select set_config('request.jwt.claim.sub', '44000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_update_recurring_template(
    '94000000-0000-0000-0000-000000000003',
    jsonb_build_object(
      'title', 'DAILY pause resume v2',
      'schedule', jsonb_build_object('kind', 'every_day', 'weekdays', jsonb_build_array(), 'start_date', current_date, 'due_time', '12:00'),
      'target', jsonb_build_object('seller_id', '74000000-0000-0000-0000-000000000001', 'assignment_mode', 'fixed', 'assignee_member_id', '64000000-0000-0000-0000-000000000002')
    ),
    current_date,
    'Future definition change',
    3,
    'daily-09-update'
  )$$,
  'DAILY-09: version-forward edit succeeds'
);
reset role;
select is((select count(*)::integer from public.recurring_task_template_versions where template_id = '94000000-0000-0000-0000-000000000003'), 2, 'DAILY-09: edit appends an immutable version');
select is(
  (select version_number from public.recurring_task_template_versions where id = (
    select version_id from public.recurring_task_occurrences
    where template_id = '94000000-0000-0000-0000-000000000003' and work_date = current_date
  )),
  1,
  'DAILY-09: existing occurrence remains pinned to version 1'
);

-- DAILY-07 depends on approved leave/attendance data which is intentionally not fabricated in P04.
select todo_start('DAILY-07: approved full-day leave suppression/handoff requires the later attendance/leave backend');
select fail('DAILY-07: runtime leave integration pending by design');
select todo_end();

-- DAILY-13 is a UI projection contract: virtual future rows are not persisted as completable tasks.
select is(
  (select count(*)::integer from public.recurring_task_occurrences where work_date > current_date),
  0,
  'DAILY-13: database contains no future projected occurrence before materialization'
);

select * from finish();
rollback;
