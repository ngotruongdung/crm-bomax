begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public', 'attendance_day_summaries', 'TIME-01: day summaries exist for raw-second calculations');
select has_table('public', 'timesheet_periods', 'TIME-10: monthly periods exist without a hard-coded working-day count');
select has_table('public', 'timesheet_snapshots', 'TIME-12: immutable closed snapshots exist');
select has_table('public', 'timesheet_period_events', 'TIME-12: close/reopen audit events exist');

select has_function(
  'public', 'rpc_get_timesheet', array['uuid','date','uuid'],
  'TIME-10: scoped monthly timesheet query exists'
);
select has_function(
  'public', 'rpc_begin_timesheet_reconciliation', array['uuid','date','integer','text'],
  'TIME-11: reconciliation command exists'
);
select has_function(
  'public', 'rpc_close_timesheet', array['uuid','date','integer','text'],
  'TIME-11: close command exists'
);
select has_function(
  'public', 'rpc_reopen_timesheet', array['uuid','uuid','text','integer','text'],
  'TIME-12: reopen command exists'
);
select has_function(
  'public', 'rpc_internal_upsert_attendance_day_summary', array['uuid','uuid','date','jsonb','text'],
  'TIME-14: deterministic server/worker summary boundary exists'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.rpc_internal_upsert_attendance_day_summary(uuid,uuid,date,jsonb,text)',
    'EXECUTE'
  ),
  'TIME-14: clients cannot write calculated summaries directly'
);
select ok(
  not has_table_privilege('authenticated', 'public.attendance_day_summaries', 'INSERT')
  and not has_table_privilege('authenticated', 'public.attendance_day_summaries', 'UPDATE'),
  'TIME-06: client cannot manufacture provisional/verified timesheet rows'
);
select ok(
  not has_table_privilege('authenticated', 'public.timesheet_snapshots', 'INSERT')
  and not has_table_privilege('authenticated', 'public.timesheet_snapshots', 'UPDATE'),
  'TIME-12: client cannot manufacture or rewrite closed snapshots'
);

select is(
  (select relrowsecurity from pg_class where oid = 'public.attendance_day_summaries'::regclass),
  true,
  'TIME-10: day summaries are protected by RLS'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.timesheet_snapshots'::regclass),
  true,
  'TIME-12: snapshots are protected by RLS'
);

select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.timesheet_snapshots'::regclass
      and tgname = 'timesheet_snapshots_immutable'
      and not tgisinternal
  ),
  'TIME-12: old closed snapshots are immutable'
);
select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.timesheet_period_events'::regclass
      and tgname = 'timesheet_period_events_immutable'
      and not tgisinternal
  ),
  'TIME-12: close/reopen audit history is immutable'
);

select ok(
  position(
    'TIMESHEET_BLOCKING_EXCEPTIONS' in
    pg_get_functiondef('public.rpc_close_timesheet(uuid,date,integer,text)'::regprocedure)
  ) > 0
  and position(
    's.state <> ''verified''' in lower(
      pg_get_functiondef('public.rpc_close_timesheet(uuid,date,integer,text)'::regprocedure)
    )
  ) > 0,
  'TIME-11: close is blocked while required days are missing or unresolved'
);

select ok(
  position(
    'insert into public.timesheet_snapshots' in lower(
      pg_get_functiondef('public.rpc_close_timesheet(uuid,date,integer,text)'::regprocedure)
    )
  ) > 0
  and position(
    'revision = revision + 1' in lower(
      pg_get_functiondef('public.rpc_reopen_timesheet(uuid,uuid,text,integer,text)'::regprocedure)
    )
  ) > 0
  and position(
    '''reopened''' in lower(
      pg_get_functiondef('public.rpc_reopen_timesheet(uuid,uuid,text,integer,text)'::regprocedure)
    )
  ) > 0,
  'TIME-12: reopen creates a new revision while preserving the previous snapshot'
);

select ok(
  position(
    'standard_day_minutes' in lower(
      pg_get_functiondef('public.rpc_internal_upsert_attendance_day_summary(uuid,uuid,date,jsonb,text)'::regprocedure)
    )
  ) > 0,
  'TIME-09: work units retain the historical standard-day denominator'
);
select ok(
  position(
    'source_revision_hash' in lower(
      pg_get_functiondef('public.rpc_internal_upsert_attendance_day_summary(uuid,uuid,date,jsonb,text)'::regprocedure)
    )
  ) > 0
  and position(
    'si.version' in lower(
      pg_get_functiondef('private.timesheet_live_member_json(uuid,uuid,date)'::regprocedure)
    )
  ) > 0,
  'TIME-14: historical source identity and shift version are retained'
);

-- TIME-01: arithmetic engine test proves a 09:00-18:00 shift with 12:00-13:00 break = 480 worked minutes.
-- TIME-02: arithmetic engine test keeps 0.75 worked + 0.25 unpaid separate.
-- TIME-03: arithmetic engine test keeps 0.75 worked + 0.25 paid separate.
-- TIME-04: arithmetic engine marks attendance/approved-leave overlap as a blocking conflict.
-- TIME-05: late minutes reduce worked time once; no second deduction is applied.
-- TIME-06: missing checkout stays provisional/unknown rather than auto-zero or auto-full-day.
-- TIME-07: overlapping sessions are unioned before summing and remain a review exception.
-- TIME-08: outside-schedule seconds remain separate and are not treated as payable overtime.
-- TIME-09: short shifts divide by historical standard_day_minutes rather than one shift = one day.
-- TIME-10: month totals come from actual rows, never a fixed 26-day assumption.
-- TIME-13: domain arithmetic sums raw seconds before converting to units; DB stores raw bigint seconds.

rollback;
