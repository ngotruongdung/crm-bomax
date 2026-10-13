begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public', 'notifications', 'NOTIFY-01: durable inbox table exists');
select has_table('public', 'notification_deliveries', 'NOTIFY-06: channel delivery records exist');
select has_table('public', 'push_endpoints', 'NOTIFY-09: push endpoints have an explicit lifecycle');
select has_table('public', 'task_reminder_snoozes', 'NOTIFY-07: reminder snoozes are stored separately from task deadlines');

select has_function(
  'public', 'rpc_mark_notification_read', array['uuid'],
  'NOTIFY-01: read state is changed through a notification-specific command'
);
select has_function(
  'private', 'notification_working_seconds_between', array['uuid','uuid','timestamptz','timestamptz'],
  'NOTIFY-02: working-time accounting helper exists'
);
select has_function(
  'private', 'notification_member_on_approved_leave', array['uuid','uuid','timestamptz'],
  'NOTIFY-03: approved-leave suppression helper exists'
);
select has_function(
  'private', 'enqueue_task_reminders', array['timestamptz'],
  'NOTIFY-04/05: server reminder materializer exists'
);
select has_function(
  'public', 'rpc_internal_enqueue_task_reminders', array['timestamptz'],
  'NOTIFY-02/03: service worker can trigger reminder evaluation without a browser'
);
select has_function(
  'public', 'rpc_snooze_reminder', array['uuid','text','timestamptz','integer','text'],
  'NOTIFY-07: bounded self-snooze command exists'
);
select has_function(
  'public', 'rpc_internal_claim_outbox', array['uuid','integer'],
  'SEC-13: leased outbox claim function exists'
);
select has_function(
  'public', 'rpc_internal_ack_outbox', array['uuid','uuid'],
  'SEC-13: leased outbox acknowledgement function exists'
);
select has_function(
  'public', 'rpc_internal_fail_outbox', array['uuid','uuid','text','boolean'],
  'NOTIFY-08: retry/dead-letter failure boundary exists'
);
select has_function(
  'public', 'rpc_internal_materialize_notification', array['uuid','uuid'],
  'NOTIFY-06/08: outbox events materialize into deduplicated inbox/delivery rows'
);
select has_function(
  'public', 'rpc_revoke_device', array['uuid'],
  'NOTIFY-09: self device revocation command exists'
);

select ok(
  not has_function_privilege('authenticated', 'public.rpc_internal_claim_outbox(uuid,integer)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rpc_internal_enqueue_task_reminders(timestamptz)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rpc_internal_ack_outbox(uuid,uuid)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rpc_internal_fail_outbox(uuid,uuid,text,boolean)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rpc_internal_materialize_notification(uuid,uuid)', 'EXECUTE'),
  'SEC-13: clients cannot claim, ack, fail or materialize worker events'
);

select ok(
  not has_table_privilege('authenticated', 'public.notifications', 'INSERT')
  and not has_table_privilege('authenticated', 'public.notifications', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.notification_deliveries', 'INSERT'),
  'NOTIFY-01/08: browser clients cannot manufacture inbox or delivery success'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.notifications'::regclass),
  true,
  'NOTIFY-10: notification inbox is protected by RLS'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.push_endpoints'::regclass),
  true,
  'NOTIFY-09: push endpoints are protected by RLS'
);

select ok(
  position('status = ''in_review''' in lower(pg_get_functiondef('private.enqueue_task_reminders(timestamptz)'::regprocedure))) > 0
  and position('reviewer_member_id' in lower(pg_get_functiondef('private.enqueue_task_reminders(timestamptz)'::regprocedure))) > 0,
  'NOTIFY-04: in-review tasks route reminder attention to the reviewer'
);

select ok(
  position('blocker_owner_member_id' in lower(pg_get_functiondef('private.enqueue_task_reminders(timestamptz)'::regprocedure))) > 0
  and position('v_rule := ''blocked''' in lower(pg_get_functiondef('private.enqueue_task_reminders(timestamptz)'::regprocedure))) > 0,
  'NOTIFY-05: blocked tasks route reminder attention to the blocker owner'
);

select ok(
  position('daily_push_limit' in lower(pg_get_functiondef('public.rpc_internal_materialize_notification(uuid,uuid)'::regprocedure))) > 0
  and position('''digest''' in lower(pg_get_functiondef('public.rpc_internal_materialize_notification(uuid,uuid)'::regprocedure))) > 0,
  'NOTIFY-06: push limit falls back to durable digest/inbox semantics'
);

select ok(
  position('snoozed_until' in lower(pg_get_functiondef('public.rpc_snooze_reminder(uuid,text,timestamptz,integer,text)'::regprocedure))) > 0
  and position('update public.tasks' in lower(pg_get_functiondef('public.rpc_snooze_reminder(uuid,text,timestamptz,integer,text)'::regprocedure))) = 0,
  'NOTIFY-07: snooze never rewrites the task deadline'
);

select ok(
  position('lease_owner = p_worker_id' in lower(pg_get_functiondef('public.rpc_internal_ack_outbox(uuid,uuid)'::regprocedure))) > 0
  and position('for update skip locked' in lower(pg_get_functiondef('public.rpc_internal_claim_outbox(uuid,integer)'::regprocedure))) > 0,
  'SEC-13: stale workers cannot ack a lease held by another worker'
);

select ok(
  position('attempts >= 5' in lower(pg_get_functiondef('public.rpc_internal_fail_outbox(uuid,uuid,text,boolean)'::regprocedure))) > 0
  and position('dead_lettered_at' in lower(pg_get_functiondef('public.rpc_internal_fail_outbox(uuid,uuid,text,boolean)'::regprocedure))) > 0,
  'NOTIFY-08: retry stops at a dead-letter state instead of retrying forever'
);

select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.user_devices'::regclass
      and tgname = 'user_devices_deactivate_push_endpoints'
      and not tgisinternal
  ),
  'NOTIFY-09: revoking a device deactivates its push endpoints'
);

select ok(
  position('safe_payload' in lower(pg_get_functiondef('public.rpc_internal_materialize_notification(uuid,uuid)'::regprocedure))) > 0
  and position('reason_private' in lower(pg_get_functiondef('public.rpc_internal_materialize_notification(uuid,uuid)'::regprocedure))) = 0,
  'NOTIFY-10: worker payload is identifier-oriented and excludes private HR reason text'
);

-- NOTIFY-11 is covered by the frontend notification policy test: realtime invalidation has focus/poll fallback.

rollback;
