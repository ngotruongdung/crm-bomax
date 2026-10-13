begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public', 'report_runs', 'REPORT-01: durable report runs exist independent of clients');
select has_table('public', 'report_recipient_snapshots', 'REPORT-10: recipient-scoped immutable snapshots exist');
select has_table('public', 'report_run_events', 'REPORT-14: report revision/audit events exist');

select has_function(
  'private', 'report_cutoff_at', array['uuid','date'],
  'REPORT-02: cutoff is calculated through organization timezone/policy'
);
select has_function(
  'private', 'report_task_states_at_cutoff', array['uuid','timestamptz'],
  'REPORT-04: task state is reconstructed from event history at cutoff'
);
select has_function(
  'private', 'report_build_facts', array['uuid','date','timestamptz','text','jsonb'],
  'REPORT-05..10: deterministic report facts builder exists'
);
select has_function(
  'public', 'rpc_internal_generate_due_reports', array['timestamptz','integer'],
  'REPORT-01: server worker can generate reports without an open client'
);
select has_function(
  'public', 'rpc_create_report_revision', array['uuid','uuid','text','integer','text'],
  'REPORT-14: explicit revision command exists'
);

select ok(
  not has_function_privilege('authenticated', 'public.rpc_internal_generate_due_reports(timestamptz,integer)', 'EXECUTE'),
  'REPORT-01: authenticated clients cannot manufacture scheduled report runs'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.report_runs'::regclass
      and contype = 'u'
      and position('report_date' in lower(pg_get_constraintdef(oid))) > 0
      and position('cutoff_at' in lower(pg_get_constraintdef(oid))) > 0
      and position('revision' in lower(pg_get_constraintdef(oid))) > 0
  ),
  'REPORT-03: logical report identity is protected by a unique run key so retries do not duplicate version 1'
);

select ok(
  position('at time zone v_timezone' in lower(pg_get_functiondef('private.report_cutoff_at(uuid,date)'::regprocedure))) > 0
  and position('18:00' in pg_get_functiondef('private.report_cutoff_at(uuid,date)'::regprocedure)) > 0,
  'REPORT-02: local cutoff is timezone converted instead of hardcoded UTC'
);

select ok(
  position('occurred_at <= p_cutoff_at' in lower(pg_get_functiondef('private.report_task_states_at_cutoff(uuid,timestamptz)'::regprocedure))) > 0
  and position('task_version desc' in lower(pg_get_functiondef('private.report_task_states_at_cutoff(uuid,timestamptz)'::regprocedure))) > 0,
  'REPORT-04: retry reconstructs latest historical task event at or before cutoff'
);

select ok(
  position('due_at > p_cutoff_at' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0,
  'REPORT-05: due-after-cutoff tasks are separated from the due cohort'
);

select ok(
  position('st = ''in_review''' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0,
  'REPORT-06: in-review state has a dedicated cohort'
);

select ok(
  position('blocked_count' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0
  and position('st in (''todo'', ''in_progress'')' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0,
  'REPORT-07: blocked is counted only inside open work'
);

select ok(
  position('canceled_or_waived_task_ids' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0,
  'REPORT-08: canceled/waived tasks are separated from due totals'
);

select ok(
  position('assignee_member_id' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0,
  'REPORT-09: primary task accountability is keyed by assignee, not collaborators'
);

select ok(
  position('seller_ids' in lower(pg_get_functiondef('private.report_scope_for_recipient(uuid,uuid,date)'::regprocedure))) > 0
  and position('report_scope_still_allowed' in lower(pg_get_functiondef('public.rpc_get_report(uuid)'::regprocedure))) > 0,
  'REPORT-10: manager snapshot scope is stored and rechecked when opened'
);

select ok(
  position('summary_template' in lower(pg_get_functiondef('private.generate_report_run(uuid,date,integer,text,uuid,timestamptz)'::regprocedure))) > 0,
  'REPORT-11: deterministic fallback summary is saved without AI dependency'
);

select ok(
  position('insert into private.outbox_events' in lower(pg_get_functiondef('private.generate_report_run(uuid,date,integer,text,uuid,timestamptz)'::regprocedure))) > 0,
  'REPORT-12/NOTIFY-08: delivery is queued independently after facts are materialized'
);

select ok(
  position('attendance_sessions' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) > 0
  and position('update public.attendance_sessions' in lower(pg_get_functiondef('private.report_build_facts(uuid,date,timestamptz,text,jsonb)'::regprocedure))) = 0,
  'REPORT-13: attendance is projected at cutoff without auto checkout'
);

select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.report_recipient_snapshots'::regclass
      and tgname = 'report_recipient_snapshots_immutable'
      and not tgisinternal
  )
  and position('revision + 1' in lower(pg_get_functiondef('public.rpc_create_report_revision(uuid,uuid,text,integer,text)'::regprocedure))) > 0,
  'REPORT-14: old facts stay immutable and revision creates a new version'
);

rollback;
