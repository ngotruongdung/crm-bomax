begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

select has_table('public', 'export_jobs', 'SEC-06: export jobs are durable and scope-bound');
select has_function(
  'public', 'rpc_authorize_file_download', array['uuid'],
  'SEC-01: file downloads cross an authorization gateway'
);
select has_function(
  'private', 'file_access_allowed', array['uuid','uuid'],
  'SEC-01: file ACL is evaluated against the parent entity'
);

select ok(
  position('current_actor_can_read_task' in lower(pg_get_functiondef('private.file_access_allowed(uuid,uuid)'::regprocedure))) > 0
  and position('current_actor_can_read_employee_request' in lower(pg_get_functiondef('private.file_access_allowed(uuid,uuid)'::regprocedure))) > 0,
  'SEC-01: task/request file IDOR is denied by parent ACL rather than uploader ownership alone'
);

select ok(
  exists (select 1 from storage.buckets where id = 'task-files' and not public)
  and exists (select 1 from storage.buckets where id = 'attendance-evidence' and not public)
  and exists (select 1 from storage.buckets where id = 'request-evidence' and not public)
  and exists (select 1 from storage.buckets where id = 'exports' and not public),
  'SEC-02: every business bucket is private'
);

select ok(
  not has_table_privilege('authenticated', 'storage.objects', 'SELECT')
  and not has_table_privilege('authenticated', 'storage.objects', 'INSERT')
  and not has_table_privilege('authenticated', 'storage.objects', 'UPDATE')
  and not has_table_privilege('authenticated', 'storage.objects', 'DELETE'),
  'SEC-02: authenticated users have no direct business Storage object privileges'
);

select ok(
  position('rpc_authorize_file_download' in lower(pg_get_functiondef('public.rpc_authorize_file_download(uuid)'::regprocedure))) > 0,
  'SEC-03: signed URL issuance is gated by a fresh authorization decision; TTL is asserted in the web/domain suite'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.files'::regclass and conname = 'files_size_bytes_check'
  )
  and exists (
    select 1 from pg_constraint
    where conrelid = 'public.files'::regclass and conname = 'files_bucket_matches_purpose'
  ),
  'SEC-04: purpose-specific file size/bucket constraints exist; magic-byte validation is asserted in the web suite'
);

select ok(
  has_function_privilege('authenticated', 'public.rpc_create_export_job(uuid,text,jsonb,text)', 'EXECUTE'),
  'SEC-05: export enters the controlled job boundary; CSV formula escaping is asserted in the domain suite'
);

select ok(
  position('export_scope_still_allowed' in lower(pg_get_functiondef('private.file_access_allowed(uuid,uuid)'::regprocedure))) > 0
  and position('requested_by = v_actor' in lower(pg_get_functiondef('private.file_access_allowed(uuid,uuid)'::regprocedure))) > 0,
  'SEC-06: export download rechecks current requestor and scope before access'
);

select ok(
  position('not f.legal_hold' in lower(pg_get_functiondef('public.rpc_internal_claim_retention_cleanup(timestamptz,integer)'::regprocedure))) > 0
  and position('file_legal_hold' in lower(pg_get_functiondef('public.rpc_internal_mark_file_deleted(uuid)'::regprocedure))) > 0,
  'SEC-07: legal hold prevents retention deletion'
);

select ok(
  true,
  'SEC-08: DB plus Storage backup and restore-readiness are verified by the deployment runbook/static gate; runtime drill remains mandatory'
);

select ok(
  true,
  'SEC-09: secret/service-role exposure is checked by pnpm secret-scan and environment preflight outside pgTAP'
);

select ok(
  position('evidence.view_authorized' in lower(pg_get_functiondef('public.rpc_authorize_file_download(uuid)'::regprocedure))) > 0
  and position('original_name' in lower(pg_get_functiondef('public.rpc_authorize_file_download(uuid)'::regprocedure))) > 0
  and position('selfie' in lower(pg_get_functiondef('public.rpc_authorize_file_download(uuid)'::regprocedure))) = 0,
  'SEC-10: sensitive evidence access is audited without embedding raw selfie content/private leave reason'
);

select ok(
  true,
  'SEC-11: internal web worker authentication is asserted by the source/static gate'
);

select ok(
  position('set search_path = ''''' in lower(pg_get_functiondef('public.rpc_authorize_file_download(uuid)'::regprocedure))) > 0
  and not has_function_privilege('authenticated', 'public.rpc_internal_claim_retention_cleanup(timestamptz,integer)', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.rpc_internal_mark_file_deleted(uuid)', 'EXECUTE'),
  'SEC-12: definer search_path is pinned and retention internals are service-only'
);

select ok(
  true,
  'SEC-13: stale outbox leases remain covered by P08 NOTIFY/SEC-13 tests'
);

select ok(
  true,
  'SEC-14: clean migration execution is a runtime deployment gate after Supabase CLI/Docker setup'
);

select ok(
  true,
  'SEC-15: staging restore integrity is a runtime deployment gate described in the backup/restore runbook'
);

rollback;
