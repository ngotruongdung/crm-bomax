begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

select has_table('public', 'offices', 'P05: offices exist');
select has_table('public', 'shift_templates', 'P05: shift templates exist');
select has_table('public', 'shift_assignments', 'P05: shift assignments exist');
select has_table('public', 'calendar_overrides', 'P05: calendar overrides exist');
select has_table('public', 'shift_instances', 'P05: shift instances exist');
select has_table('public', 'leave_types', 'P05: leave types exist');
select has_table('public', 'employee_requests', 'P05: employee requests exist');
select has_table('public', 'request_segments', 'P05: request segments exist');
select has_table('public', 'request_decisions', 'P05: immutable request decisions exist');
select has_table('public', 'leave_balance_entries', 'P05: leave balance ledger exists');
select has_table('public', 'task_handover_actions', 'P05: task handover queue exists');
select has_function('public', 'rpc_create_employee_request', array['uuid', 'jsonb', 'text'], 'P05: request submit RPC exists');
select has_function('public', 'rpc_decide_employee_request', array['uuid', 'text', 'text', 'integer', 'text'], 'P05: request decision RPC exists');
select has_function('public', 'rpc_withdraw_employee_request', array['uuid', 'integer', 'text'], 'P05: pending withdraw RPC exists');
select has_function('public', 'rpc_list_request_availability', array['uuid', 'date', 'date'], 'P05: redacted availability RPC exists');
select has_function('private', 'request_affected_seconds', array['jsonb', 'timestamp with time zone', 'timestamp with time zone'], 'P05: server-side working-time calculator exists');
select has_function('private', 'recurring_member_on_approved_full_day_leave', array['uuid', 'uuid', 'date'], 'P05: Daily leave helper exists');

select is((select relrowsecurity from pg_class where oid = 'public.employee_requests'::regclass), true, 'P05: employee request RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.request_decisions'::regclass), true, 'P05: request decision RLS enabled');
select ok(not has_table_privilege('authenticated', 'public.employee_requests', 'INSERT'), 'P05: authenticated cannot insert requests directly');
select ok(not has_table_privilege('authenticated', 'public.request_decisions', 'UPDATE'), 'P05: authenticated cannot update immutable decisions directly');

insert into auth.users (id, aud, role, email)
values
  ('45000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'p05.admin@opsdesk.local'),
  ('45000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'p05.hr@opsdesk.local'),
  ('45000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'p05.employee.a@opsdesk.local'),
  ('45000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'p05.employee.b@opsdesk.local'),
  ('45000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'p05.manager@opsdesk.local');

insert into public.organizations (id, name, slug, timezone)
values ('55000000-0000-0000-0000-000000000001', 'pgTAP P05', 'pgtap-p05', 'Asia/Ho_Chi_Minh');

insert into public.organization_members (
  id, organization_id, user_id, employee_code, display_name, role, status, can_approve_requests
) values
  ('65000000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', '45000000-0000-0000-0000-000000000001', 'P5-ADM', 'P05 Admin', 'admin', 'active', true),
  ('65000000-0000-0000-0000-000000000002', '55000000-0000-0000-0000-000000000001', '45000000-0000-0000-0000-000000000002', 'P5-HR', 'P05 HR', 'employee', 'active', true),
  ('65000000-0000-0000-0000-000000000003', '55000000-0000-0000-0000-000000000001', '45000000-0000-0000-0000-000000000003', 'P5-A', 'P05 Employee A', 'employee', 'active', false),
  ('65000000-0000-0000-0000-000000000004', '55000000-0000-0000-0000-000000000001', '45000000-0000-0000-0000-000000000004', 'P5-B', 'P05 Employee B', 'employee', 'active', false),
  ('65000000-0000-0000-0000-000000000005', '55000000-0000-0000-0000-000000000001', '45000000-0000-0000-0000-000000000005', 'P5-MGR', 'P05 Manager', 'manager', 'active', false);

update public.organizations set owner_member_id = '65000000-0000-0000-0000-000000000001'
where id = '55000000-0000-0000-0000-000000000001';

insert into public.offices (id, organization_id, name, timezone)
values ('a5500000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', 'P05 Office', 'Asia/Ho_Chi_Minh');
insert into public.shift_templates (
  id, organization_id, office_id, name, start_local, end_local, breaks, allowed_mode, standard_day_minutes
) values (
  'a5500000-0000-0000-0000-000000000002', '55000000-0000-0000-0000-000000000001',
  'a5500000-0000-0000-0000-000000000001', 'P05 Office Shift', time '09:00', time '18:00',
  jsonb_build_array(jsonb_build_object('start', '12:00', 'end', '13:00')), 'hybrid', 480
);
insert into public.leave_types (id, organization_id, code, name, pay_treatment, consumes_balance)
values
  ('a5500000-0000-0000-0000-000000000003', '55000000-0000-0000-0000-000000000001', 'P05-PAID', 'P05 Paid', 'paid', true),
  ('a5500000-0000-0000-0000-000000000004', '55000000-0000-0000-0000-000000000001', 'P05-UNPAID', 'P05 Unpaid', 'unpaid', false);

insert into public.shift_instances (
  id, organization_id, member_id, template_id, work_date, starts_at, ends_at, working_segments,
  scheduled_seconds, standard_day_minutes, allowed_mode, office_id, policy_snapshot
) values
  ('b5500000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000003', 'a5500000-0000-0000-0000-000000000002', current_date,
    (current_date::text || ' 09:00:00+07')::timestamptz, (current_date::text || ' 18:00:00+07')::timestamptz,
    jsonb_build_array(jsonb_build_object('start', current_date::text || 'T09:00:00+07', 'end', current_date::text || 'T12:00:00+07'), jsonb_build_object('start', current_date::text || 'T13:00:00+07', 'end', current_date::text || 'T18:00:00+07')),
    28800, 480, 'hybrid', 'a5500000-0000-0000-0000-000000000001', '{}'::jsonb),
  ('b5500000-0000-0000-0000-000000000002', '55000000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000003', 'a5500000-0000-0000-0000-000000000002', current_date + 1,
    ((current_date + 1)::text || ' 09:00:00+07')::timestamptz, ((current_date + 1)::text || ' 18:00:00+07')::timestamptz,
    jsonb_build_array(jsonb_build_object('start', (current_date + 1)::text || 'T09:00:00+07', 'end', (current_date + 1)::text || 'T12:00:00+07'), jsonb_build_object('start', (current_date + 1)::text || 'T13:00:00+07', 'end', (current_date + 1)::text || 'T18:00:00+07')),
    28800, 480, 'hybrid', 'a5500000-0000-0000-0000-000000000001', '{}'::jsonb);

-- REQ-07: only the configured working intervals count, never the noon break.
select is(
  private.request_affected_seconds(
    jsonb_build_array(jsonb_build_object('start', current_date::text || 'T09:00:00+07', 'end', current_date::text || 'T12:00:00+07'), jsonb_build_object('start', current_date::text || 'T13:00:00+07', 'end', current_date::text || 'T18:00:00+07')),
    (current_date::text || ' 12:00:00+07')::timestamptz, (current_date::text || ' 13:00:00+07')::timestamptz
  ), 0::bigint, 'REQ-07: break-only leave affects zero working seconds'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000003', true);

-- REQ-01: submission remains pending and cannot change work/leave credit yet.
select lives_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'early_leave', 'starts_at', (current_date::text || ' 16:00:00+07')::timestamptz, 'ends_at', (current_date::text || ' 18:00:00+07')::timestamptz, 'leave_type_id', 'a5500000-0000-0000-0000-000000000004', 'reason_private', 'Personal appointment near end of working shift.'),
    'p05-req-unpaid-early-leave'
  )$$,
  'REQ-01: employee submits pending leave request'
);
select is(
  (select status from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave'),
  'pending', 'REQ-01: request remains pending before approval'
);

-- REQ-10: owner can withdraw a pending request, with history rather than deletion.
select lives_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'remote_work', 'starts_at', ((current_date + 2)::text || ' 09:00:00+07')::timestamptz, 'ends_at', ((current_date + 2)::text || ' 18:00:00+07')::timestamptz, 'reason_private', 'Need to work remotely for a planned home appointment.'),
    'p05-req-withdraw-pending'
  )$$,
  'REQ-10: employee creates a pending request that can be withdrawn'
);
select lives_ok(
  $$select public.rpc_withdraw_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-withdraw-pending'), 1, 'p05-withdraw-decision'
  )$$,
  'REQ-10: owner withdraws own pending request'
);
select is((select status from public.employee_requests where idempotency_key = 'p05-req-withdraw-pending'), 'withdrawn', 'REQ-10: withdrawn request remains as history');

-- REQ-04: a manager without the explicit HR approval capability is denied.
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000005', true);
select throws_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave'), 'approved', null, 1, 'p05-manager-denied'
  )$$,
  '42501', 'REQUEST_APPROVAL_DENIED', 'REQ-04: non-HR manager cannot approve request'
);

-- REQ-05: an HR-capable member cannot approve their own request.
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000002', true);
select lives_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'remote_work', 'starts_at', ((current_date + 3)::text || ' 09:00:00+07')::timestamptz, 'ends_at', ((current_date + 3)::text || ' 18:00:00+07')::timestamptz, 'reason_private', 'Need a remote work day for a scheduled appointment.'),
    'p05-req-self-approval'
  )$$,
  'REQ-05: HR user can submit their own request'
);
select throws_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-self-approval'), 'approved', null, 1, 'p05-self-denied'
  )$$,
  '42501', 'REQUEST_SELF_APPROVAL_DENIED', 'REQ-05: self approval is denied'
);

-- REQ-02/03/06: partial leave keeps only the intersected duration; a second decision sees a version conflict.
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave'), 'approved', null, 1, 'p05-admin-approve-unpaid'
  )$$,
  'REQ-02: HR approves unpaid early leave'
);
select is(
  (select affected_seconds from public.request_segments where request_id = (select id from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave')),
  7200::bigint, 'REQ-02: approval records only two affected working hours'
);
select is(
  (select count(*)::integer from public.leave_balance_entries where source_request_id = (select id from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave')),
  0, 'REQ-02: unpaid leave does not create paid leave credit'
);
select throws_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave'), 'approved', null, 1, 'p05-second-hr-decision'
  )$$,
  '40901', 'REQUEST_ALREADY_DECIDED', 'REQ-06: a second HR decision cannot create another outcome'
);

-- REQ-08 and DAILY-07: approved full-day leave blocks overlap, creates coverage work and preserves the task.
insert into public.tasks (
  id, organization_id, task_number, title, assignee_member_id, created_by_member_id, planned_date,
  original_due_at, due_at, visible_from, requires_result
) values (
  'd5500000-0000-0000-0000-000000000001', '55000000-0000-0000-0000-000000000001', 550001,
  'P05 coverage task', '65000000-0000-0000-0000-000000000003', '65000000-0000-0000-0000-000000000001', current_date + 1,
  ((current_date + 1)::text || ' 17:00:00+07')::timestamptz, ((current_date + 1)::text || ' 17:00:00+07')::timestamptz,
  timezone('utc', now()), true
);
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000003', true);
select lives_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'leave', 'starts_at', ((current_date + 1)::text || ' 09:00:00+07')::timestamptz, 'ends_at', ((current_date + 1)::text || ' 18:00:00+07')::timestamptz, 'leave_type_id', 'a5500000-0000-0000-0000-000000000003', 'reason_private', 'Need a full day away from work for a family commitment.'),
    'p05-req-paid-full-day'
  )$$,
  'REQ-03: employee submits paid full-day leave'
);
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-paid-full-day'), 'approved', null, 1, 'p05-admin-approve-paid'
  )$$,
  'REQ-03: HR approves paid leave'
);
select is(
  (select delta_seconds from public.leave_balance_entries where source_request_id = (select id from public.employee_requests where idempotency_key = 'p05-req-paid-full-day')),
  -28800::bigint, 'REQ-03: paid leave is represented separately in ledger seconds'
);
select ok(
  private.recurring_member_on_approved_full_day_leave('55000000-0000-0000-0000-000000000001', '65000000-0000-0000-0000-000000000003', current_date + 1),
  'DAILY-07: full-day approved leave is available to recurrence coverage logic'
);
select is(
  (select count(*)::integer from public.task_handover_actions where task_id = 'd5500000-0000-0000-0000-000000000001'),
  1, 'REQ-09: approved leave creates a handover queue item'
);
select is((select status from public.tasks where id = 'd5500000-0000-0000-0000-000000000001'), 'todo', 'REQ-09: approved leave does not delete or auto-complete the task');

select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000003', true);
select throws_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'leave', 'starts_at', ((current_date + 1)::text || ' 10:00:00+07')::timestamptz, 'ends_at', ((current_date + 1)::text || ' 12:00:00+07')::timestamptz, 'leave_type_id', 'a5500000-0000-0000-0000-000000000003', 'reason_private', 'An overlapping leave should be blocked by the approved request.'),
    'p05-req-overlap-denied'
  )$$,
  '23505', 'REQUEST_APPROVED_OVERLAP', 'REQ-08: approved leave overlaps are blocked'
);

-- REQ-11: cancellation is a new approved request that retains both histories and reverses the paid ledger.
select lives_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'cancel_approved_request', 'starts_at', ((current_date + 1)::text || ' 09:00:00+07')::timestamptz, 'ends_at', ((current_date + 1)::text || ' 18:00:00+07')::timestamptz, 'target_request_id', (select id from public.employee_requests where idempotency_key = 'p05-req-paid-full-day'), 'reason_private', 'The family appointment was moved and the approved leave is no longer needed.'),
    'p05-req-cancel-approved'
  )$$,
  'REQ-11: owner requests cancellation of approved leave'
);
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-cancel-approved'), 'approved', null, 1, 'p05-admin-approve-cancel'
  )$$,
  'REQ-11: HR approves cancellation with a separate decision'
);
select is((select status from public.employee_requests where idempotency_key = 'p05-req-paid-full-day'), 'canceled', 'REQ-11: original approved request is canceled with history retained');

-- REQ-12: correction is an approval queue claim; it produces an outbox event, not a mutable raw event.
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000004', true);
select lives_ok(
  $$select public.rpc_create_employee_request(
    '55000000-0000-0000-0000-000000000001',
    jsonb_build_object('request_type', 'attendance_correction', 'starts_at', (current_date::text || ' 09:00:00+07')::timestamptz, 'ends_at', (current_date::text || ' 18:00:00+07')::timestamptz, 'reason_private', 'Forgot to record a check out due to a network interruption.', 'correction_payload', jsonb_build_object('issue', 'forgot_check_out', 'claimed_at', current_date::text || 'T18:00:00+07')),
    'p05-req-correction'
  )$$,
  'REQ-12: employee submits correction claim without altering attendance raw data'
);
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000001', true);
select lives_ok(
  $$select public.rpc_decide_employee_request(
    (select id from public.employee_requests where idempotency_key = 'p05-req-correction'), 'approved', null, 1, 'p05-admin-approve-correction'
  )$$,
  'REQ-12: HR approves correction as a later adjustment workflow'
);
select ok(exists (
  select 1 from private.outbox_events where dedupe_key = 'request:' || (select id::text from public.employee_requests where idempotency_key = 'p05-req-correction') || ':attendance-correction'
), 'REQ-12: approval emits an adjustment request without inserting an attendance event');

-- REQ-13: manager can retrieve availability, but cannot select private request reason.
select set_config('request.jwt.claim.sub', '45000000-0000-0000-0000-000000000005', true);
select ok(not exists (
  select 1
  from jsonb_array_elements(public.rpc_list_request_availability('55000000-0000-0000-0000-000000000001', current_date, current_date + 7)) as item(value)
  where value ? 'reason_private' or value ? 'handover_note'
), 'REQ-13: availability RPC exposes no private reason or handover note');
select is(
  (select count(*)::integer from public.employee_requests where idempotency_key = 'p05-req-unpaid-early-leave'),
  0, 'REQ-13: non-HR manager cannot read another member private request row'
);

reset role;

rollback;
