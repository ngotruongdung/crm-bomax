begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public', 'office_networks', 'ATT-01: office network allowlist exists');
select has_table('public', 'office_ip_ranges', 'ATT-03: trusted source IP ranges exist');
select has_table('public', 'attendance_challenges', 'ATT-09: one-time challenge table exists');
select has_table('public', 'attendance_events', 'ATT-10: immutable attendance event table exists');
select has_table('public', 'attendance_sessions', 'ATT-11: attendance sessions exist');
select has_table('public', 'attendance_evidence', 'ATT-14: private attendance evidence is separated');
select has_table('public', 'files', 'ATT-18: private file metadata exists');
select has_table('public', 'upload_intents', 'ATT-18: upload intents exist');
select has_table('public', 'user_devices', 'ATT-21: registered device table exists');
select has_table('public', 'remote_laptop_sessions', 'ATT-23: remote laptop sessions exist');
select ok(
  exists (select 1 from storage.buckets where id = 'attendance-evidence' and not public),
  'ATT-18: attendance evidence bucket is private'
);

select has_function(
  'public', 'rpc_internal_create_attendance_challenge',
  array['uuid','uuid','uuid','text','text','uuid','text'],
  'ATT-09: server challenge function exists'
);
select has_function(
  'public', 'rpc_internal_finalize_attendance',
  array['uuid','text','text','inet','uuid','uuid','text'],
  'ATT-17: server finalize function exists'
);
select has_function(
  'public', 'rpc_internal_create_remote_laptop_session',
  array['uuid','uuid','uuid','text'],
  'ATT-14: server laptop-session function exists'
);
select has_function(
  'public', 'rpc_internal_resolve_remote_laptop_session',
  array['uuid','uuid','uuid','text'],
  'ATT-27: server laptop-session resolver exists'
);
select has_function(
  'public', 'rpc_get_attendance_day',
  array['uuid','uuid','date'],
  'ATT-19: scoped attendance day query exists'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.rpc_internal_create_attendance_challenge(uuid,uuid,uuid,text,text,uuid,text)',
    'EXECUTE'
  ),
  'ATT-20: authenticated cannot invoke internal challenge function directly'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.rpc_internal_finalize_attendance(uuid,text,text,inet,uuid,uuid,text)',
    'EXECUTE'
  ),
  'ATT-20: authenticated cannot invoke internal finalize function directly'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.rpc_internal_create_remote_laptop_session(uuid,uuid,uuid,text)',
    'EXECUTE'
  ),
  'ATT-24: authenticated cannot create laptop sessions directly'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.rpc_internal_resolve_remote_laptop_session(uuid,uuid,uuid,text)',
    'EXECUTE'
  ),
  'ATT-28: authenticated cannot invoke laptop resolver directly'
);
select ok(
  position(
    'LAPTOP_SESSION_REQUIRED' in
    pg_get_functiondef('public.rpc_internal_finalize_attendance(uuid,text,text,inet,uuid,uuid,text)'::regprocedure)
  ) > 0,
  'ATT-25: remote finalization requires a laptop session'
);
select ok(
  position(
    'from public.upload_intents ui' in lower(
      pg_get_functiondef('public.rpc_internal_finalize_attendance(uuid,text,text,inet,uuid,uuid,text)'::regprocedure)
    )
  ) > 0
  and position(
    'ui.challenge_id = v_challenge.id' in lower(
      pg_get_functiondef('public.rpc_internal_finalize_attendance(uuid,text,text,inet,uuid,uuid,text)'::regprocedure)
    )
  ) > 0
  and position(
    'update public.upload_intents' in lower(
      pg_get_functiondef('public.rpc_internal_finalize_attendance(uuid,text,text,inet,uuid,uuid,text)'::regprocedure)
    )
  ) > 0,
  'ATT-26: remote evidence upload intent is challenge-bound and one-time'
);
select ok(
  position(
    'resolve_attempt_count >= 5' in lower(
      pg_get_functiondef('public.rpc_internal_resolve_remote_laptop_session(uuid,uuid,uuid,text)'::regprocedure)
    )
  ) > 0
  and position(
    'locked_at = case when v_attempts >= 5' in lower(
      pg_get_functiondef('public.rpc_internal_resolve_remote_laptop_session(uuid,uuid,uuid,text)'::regprocedure)
    )
  ) > 0,
  'ATT-29: laptop code locks after five failed resolve attempts'
);
select ok(
  not has_table_privilege('authenticated', 'public.attendance_events', 'INSERT'),
  'ATT-17: client cannot insert official events directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.attendance_events', 'UPDATE'),
  'ATT-22: client cannot rewrite raw events'
);
select ok(
  not has_table_privilege('authenticated', 'public.attendance_evidence', 'INSERT'),
  'ATT-18: client cannot attach evidence outside server flow'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.attendance_events'::regclass),
  true,
  'ATT-19: attendance event RLS is enabled'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.attendance_evidence'::regclass),
  true,
  'ATT-19: attendance evidence RLS is enabled'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'attendance_one_open_session_idx'
      and indexdef ilike '%where (status = ''open''%'
  ),
  'ATT-11: only one open attendance session is allowed per member'
);

-- ATT-02: same SSID with a different BSSID is rejected by finalize because matching uses BSSID.
-- ATT-04: shift/member/action are revalidated during finalization.
-- ATT-05: office finalization requires both BSSID and trusted source IP.
-- ATT-06: official effective_at/recorded_at use DB clock_timestamp().
-- ATT-07: native permission behavior requires real Android/iOS device verification.
-- ATT-08: iOS fetchCurrent nil requires real iOS verification and must remain unavailable.
-- ATT-12: check-out without an open session raises ATTENDANCE_CHECK_IN_REQUIRED.
-- ATT-13: remote finalization rechecks approved remote eligibility.
-- ATT-14: remote mode requires a ready attendance-purpose file owned by the member.
-- ATT-14: laptop session must belong to the same member/shift and be unexpired.
-- ATT-15: idempotency returns an existing event instead of creating a duplicate.
-- ATT-16: direct camera behavior remains a native device test; gallery success is not accepted by policy.
-- ATT-21: device id must resolve to the same active member during challenge creation.
-- ATT-22: raw events are protected by immutable trigger and correction remains a separate adjustment flow.

rollback;
