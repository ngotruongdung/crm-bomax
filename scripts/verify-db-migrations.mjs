import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

// Keep P01A's focused checks intact, then check the P01B access expansion.
await import('./verify-p01a-migration.mjs');

const root = resolve(import.meta.dirname, '..');
const migrationPath = resolve(root, 'supabase/migrations/00000000000002_p01b_access_scope.sql');
const testPath = resolve(root, 'supabase/tests/0002_p01b_access_scope.sql');
const inviteRoutePath = resolve(root, 'apps/web/app/api/admin/invitations/route.ts');
const adminClientPath = resolve(root, 'apps/web/lib/supabase/admin.ts');
const inviteClientPath = resolve(root, 'apps/web/app/auth/accept-invite/accept-invite-client.tsx');

const [migration, tests, inviteRoute, adminClient, inviteClient] = await Promise.all([
  readFile(migrationPath, 'utf8'),
  readFile(testPath, 'utf8'),
  readFile(inviteRoutePath, 'utf8'),
  readFile(adminClientPath, 'utf8'),
  readFile(inviteClientPath, 'utf8'),
]);

const requiredMigrationFragments = [
  'create extension if not exists btree_gist with schema extensions',
  'create table public.sellers',
  'create table public.seller_members',
  'create table public.invitation_seller_scopes',
  'seller_members_no_overlapping_scope',
  'create or replace function private.normalize_capabilities',
  'create or replace function private.current_actor_is_seller_manager',
  'create or replace function public.rpc_create_invitation',
  'create or replace function public.rpc_validate_invitation',
  'create or replace function public.rpc_accept_invitation',
  'create or replace function public.rpc_internal_create_invited_membership',
  'create or replace function public.rpc_internal_set_invitation_auth_reference',
  'create or replace function public.rpc_update_member_access',
  'create or replace function public.rpc_deactivate_member',
  'create or replace function public.rpc_create_or_update_seller',
  'create or replace function public.rpc_update_seller_members',
  'grant execute on function public.rpc_internal_create_invited_membership(uuid, uuid, text) to service_role',
  'grant execute on function public.rpc_internal_set_invitation_auth_reference(uuid, text) to service_role',
  'grant execute on function private.current_actor_is_seller_manager(uuid, uuid) to authenticated',
  'create policy sellers_read_by_scope',
  'create policy seller_members_read_by_scope',
];

for (const fragment of requiredMigrationFragments) {
  if (!migration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P01B migration is missing: ${fragment}`);
  }
}

for (const table of [
  'public.sellers',
  'public.seller_members',
  'public.invitation_seller_scopes',
]) {
  if (!migration.toLowerCase().includes(`alter table ${table} enable row level security`)) {
    throw new Error(`P01B does not enable RLS for ${table}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(migration)) {
  throw new Error('P01B migration contains an unsafe always-true policy');
}

for (const forbiddenGrant of [
  'grant execute on function public.rpc_internal_create_invited_membership(uuid, uuid, text) to authenticated',
  'grant execute on function public.rpc_internal_set_invitation_auth_reference(uuid, text) to authenticated',
  'grant execute on function private.is_seller_member(uuid, uuid, uuid) to authenticated',
  'grant execute on function private.is_seller_manager(uuid, uuid, uuid) to authenticated',
]) {
  if (migration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P01B exposes a privileged helper: ${forbiddenGrant}`);
  }
}

for (const testId of [
  'AUTH-05',
  'AUTH-06',
  'AUTH-07',
  'AUTH-08',
  'AUTH-09',
  'AUTH-10',
  'AUTH-12',
  'SEC-12',
  'SEC-14',
]) {
  if (!tests.includes(testId)) {
    throw new Error(`P01B database test is missing required case: ${testId}`);
  }
}

for (const fragment of [
  'createSupabaseServerClient',
  'createSupabaseAdminClient',
  'client.auth.getUser()',
  'rpc_create_invitation',
  'inviteUserByEmail',
  'rpc_internal_set_invitation_auth_reference',
  'ORIGIN_NOT_ALLOWED',
]) {
  if (!inviteRoute.includes(fragment)) {
    throw new Error(`Invitation route is missing: ${fragment}`);
  }
}

if (
  !adminClient.includes('SUPABASE_SERVICE_ROLE_KEY') ||
  adminClient.includes('NEXT_PUBLIC_SUPABASE_SERVICE_ROLE_KEY')
) {
  throw new Error('Invitation admin client does not keep the service key server-only');
}

for (const fragment of [
  'rpc_validate_invitation',
  'rpc_accept_invitation',
  'invitationValidationSchema',
]) {
  if (!inviteClient.includes(fragment)) {
    throw new Error(`Invite acceptance client is missing: ${fragment}`);
  }
}

const taskCoreMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000003_p03b_task_core.sql',
);
const taskHardeningMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000004_p03b_task_core_hardening.sql',
);
const taskReviewerPolicyMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000005_p03b_reviewer_policy.sql',
);
const taskTestPath = resolve(root, 'supabase/tests/0003_p03b_task_core.sql');

const [taskCoreMigration, taskHardeningMigration, taskReviewerPolicyMigration, taskTests] =
  await Promise.all([
    readFile(taskCoreMigrationPath, 'utf8'),
    readFile(taskHardeningMigrationPath, 'utf8'),
    readFile(taskReviewerPolicyMigrationPath, 'utf8'),
    readFile(taskTestPath, 'utf8'),
  ]);

for (const fragment of [
  'create table public.tasks',
  'create table public.task_participants',
  'create table public.task_checklist_items',
  'create table public.task_submissions',
  'create table public.task_events',
  'create or replace function public.rpc_list_tasks',
  'create or replace function public.rpc_get_task',
  'alter table public.tasks enable row level security',
  'alter table public.task_participants enable row level security',
  'alter table public.task_checklist_items enable row level security',
  'alter table public.task_submissions enable row level security',
  'alter table public.task_events enable row level security',
  'revoke insert, update, delete, truncate, references, trigger',
  'on public.tasks, public.task_participants, public.task_checklist_items,',
  'public.task_submissions, public.task_events',
  'from authenticated',
]) {
  if (!taskCoreMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P03B core migration is missing: ${fragment}`);
  }
}

for (const fragment of [
  'create or replace function private.assert_task_reviewer_policy',
  "v_reviewer_role not in ('admin', 'manager')",
  "message = 'TASK_REVIEWER_ROLE_DENIED'",
  "message = 'INTERNAL_TASK_REVIEW_ASSIGNMENT_DENIED'",
  'create trigger tasks_reviewer_policy_check',
  'before insert or update on public.tasks',
]) {
  if (!taskReviewerPolicyMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P03B reviewer policy migration is missing: ${fragment}`);
  }
}

for (const fragment of [
  'alter column requires_result set default true',
  'add column report_state_after jsonb not null default',
  'rename to rpc_create_task_p03b_legacy',
  'rename to rpc_task_command_p03b_legacy',
  'create or replace function public.rpc_create_task_batch',
  'create or replace function public.rpc_update_task',
  "where key not in ('target_id', 'seller_id', 'assignee_member_id', 'due_at')",
  "if v_task.status in ('in_review', 'done', 'canceled', 'waived')",
  'TASK_REASSIGN_REASON_REQUIRED',
  'TASK_DEADLINE_CHANGE_REASON_REQUIRED',
  'set assigned_at = timezone',
  "'task.deadline_changed'",
  'grant execute on function public.rpc_create_task_batch',
  'grant execute on function public.rpc_update_task',
]) {
  if (!taskHardeningMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P03B hardening migration is missing: ${fragment}`);
  }
}

for (const legacySignature of [
  'public.rpc_create_task_p03b_legacy(uuid,jsonb,text)',
  'public.rpc_task_command_p03b_legacy(uuid,text,jsonb,integer,text)',
]) {
  const privilegeAssertion = `not has_function_privilege('authenticated', '${legacySignature}', 'EXECUTE')`;
  if (!taskTests.toLowerCase().includes(privilegeAssertion.toLowerCase())) {
    throw new Error(`P03B tests do not prove legacy RPC isolation: ${legacySignature}`);
  }
}

for (const testId of [
  'TASK-01',
  'TASK-02',
  'TASK-03',
  'TASK-04',
  'TASK-05',
  'TASK-06',
  'TASK-07',
  'TASK-08',
  'TASK-09',
  'TASK-10',
  'TASK-11',
  'TASK-12',
  'TASK-13',
  'TASK-14',
  'TASK-15',
  'TASK-16',
  'TASK-18',
  'TASK-19',
  'TASK-20',
  'TASK-21',
]) {
  if (!taskTests.includes(testId)) {
    throw new Error(`P03B database test is missing required case: ${testId}`);
  }
}

const recurringMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000006_p04_recurring_tasks.sql',
);
const recurringTestPath = resolve(root, 'supabase/tests/0004_p04_recurring_tasks.sql');
const hrRequestsMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000007_p05_hr_requests.sql',
);
const hrRequestsTestPath = resolve(root, 'supabase/tests/0005_p05_hr_requests.sql');
const attendanceMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000008_p06_attendance.sql',
);
const attendanceTestPath = resolve(root, 'supabase/tests/0006_p06_attendance.sql');
const timesheetMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000009_p07_timesheets.sql',
);
const timesheetTestPath = resolve(root, 'supabase/tests/0007_p07_timesheets.sql');
const notificationMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000010_p08_notifications.sql',
);
const notificationTestPath = resolve(root, 'supabase/tests/0008_p08_notifications.sql');
const reportMigrationPath = resolve(root, 'supabase/migrations/00000000000011_p09_reports.sql');
const reportTestPath = resolve(root, 'supabase/tests/0009_p09_reports.sql');
const securityMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000012_p10_security_ops.sql',
);
const securityTestPath = resolve(root, 'supabase/tests/0010_p10_security_ops.sql');
const fileDownloadRoutePath = resolve(root, 'apps/web/app/api/files/[id]/download/route.ts');
const attendanceFinalizeRoutePath = resolve(root, 'apps/web/app/api/attendance/finalize/route.ts');
const imageValidationPath = resolve(root, 'apps/web/lib/files/image-validation.ts');
const securityDomainPath = resolve(root, 'packages/domain/src/security.ts');
const notificationWorkerPath = resolve(
  root,
  'apps/web/app/api/internal/notifications/dispatch/route.ts',
);
const backupRunbookPath = resolve(root, 'docs/BACKUP_RESTORE_RUNBOOK.md');
const securityMaintenanceWorkerPath = resolve(
  root,
  'apps/web/app/api/internal/security/maintenance/route.ts',
);
const securitySchedulerPath = resolve(
  root,
  'supabase/manual/p10_security_maintenance_scheduler.sql',
);

const [
  recurringMigration,
  recurringTests,
  hrRequestsMigration,
  hrRequestsTests,
  attendanceMigration,
  attendanceTests,
  timesheetMigration,
  timesheetTests,
  notificationMigration,
  notificationTests,
  reportMigration,
  reportTests,
] = await Promise.all([
  readFile(recurringMigrationPath, 'utf8'),
  readFile(recurringTestPath, 'utf8'),
  readFile(hrRequestsMigrationPath, 'utf8'),
  readFile(hrRequestsTestPath, 'utf8'),
  readFile(attendanceMigrationPath, 'utf8'),
  readFile(attendanceTestPath, 'utf8'),
  readFile(timesheetMigrationPath, 'utf8'),
  readFile(timesheetTestPath, 'utf8'),
  readFile(notificationMigrationPath, 'utf8'),
  readFile(notificationTestPath, 'utf8'),
  readFile(reportMigrationPath, 'utf8'),
  readFile(reportTestPath, 'utf8'),
]);

for (const table of [
  'public.recurring_task_templates',
  'public.recurring_task_template_versions',
  'public.recurring_task_targets',
  'public.recurring_task_occurrences',
]) {
  if (!recurringMigration.toLowerCase().includes(`create table ${table}`)) {
    throw new Error(`P04 migration does not create ${table}`);
  }
  if (
    !recurringMigration.toLowerCase().includes(`alter table ${table} enable row level security`)
  ) {
    throw new Error(`P04 migration does not enable RLS for ${table}`);
  }
}

for (const fragment of [
  'unique (organization_id, template_id, target_key, work_date)',
  'resolved_assignee_member_id uuid',
  'assigned_by_member_id uuid',
  'assignment_reason text',
  'create or replace function private.insert_task_from_recurring_occurrence',
  'create or replace function private.materialize_recurring_occurrences',
  'create or replace function public.rpc_create_recurring_template',
  'create or replace function public.rpc_update_recurring_template',
  'create or replace function public.rpc_recurring_template_command',
  'create or replace function public.rpc_assign_recurring_occurrence',
  'v_assignee_id := coalesce(v_occ.resolved_assignee_member_id, v_target.assignee_member_id)',
  "generation_kind in ('scheduled', 'system_delay', 'manual')",
  "attention_code = 'system_delay_catchup_limited'",
  'generation_floor_date = greatest(generation_floor_date, v_today)',
  'on conflict (organization_id, template_id, target_key, work_date) do nothing',
  'rv.effective_from <= v_work_date',
  "v_occ.state <> 'needs_assignment' or v_occ.task_id is not null",
  "'recurring.assign_occurrence'",
  'grant execute on function private.materialize_recurring_occurrences(uuid, date, integer) to service_role',
  'grant execute on function public.rpc_assign_recurring_occurrence(uuid, uuid, text, text) to authenticated',
  'revoke insert, update, delete, truncate, references, trigger',
]) {
  if (!recurringMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P04 recurring migration is missing: ${fragment}`);
  }
}

for (const forbiddenGrant of [
  'grant execute on function private.materialize_recurring_occurrences(uuid, date, integer) to authenticated',
  'grant insert on public.recurring_task_occurrences to authenticated',
  'grant update on public.recurring_task_occurrences to authenticated',
]) {
  if (recurringMigration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P04 exposes a privileged recurring boundary: ${forbiddenGrant}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(recurringMigration)) {
  throw new Error('P04 recurring migration contains an unsafe always-true policy');
}

for (const testId of [
  'DAILY-01',
  'DAILY-02',
  'DAILY-03',
  'DAILY-04',
  'DAILY-05',
  'DAILY-06',
  'DAILY-07',
  'DAILY-08',
  'DAILY-09',
  'DAILY-10',
  'DAILY-11',
  'DAILY-12',
  'DAILY-13',
  'DAILY-14',
]) {
  if (!recurringTests.includes(testId)) {
    throw new Error(`P04 database test is missing required case: ${testId}`);
  }
}

for (const table of [
  'public.offices',
  'public.shift_templates',
  'public.shift_assignments',
  'public.calendar_overrides',
  'public.shift_instances',
  'public.leave_types',
  'public.employee_requests',
  'public.request_segments',
  'public.request_decisions',
  'public.leave_balance_entries',
  'public.task_handover_actions',
]) {
  if (!hrRequestsMigration.toLowerCase().includes(`create table ${table}`)) {
    throw new Error(`P05 migration does not create ${table}`);
  }
  if (
    !hrRequestsMigration.toLowerCase().includes(`alter table ${table} enable row level security`)
  ) {
    throw new Error(`P05 migration does not enable RLS for ${table}`);
  }
}

for (const fragment of [
  'create or replace function private.assert_shift_instance_segments',
  'create or replace function private.request_affected_seconds',
  'create or replace function private.assert_request_approver',
  'create or replace function private.current_actor_can_read_employee_request',
  'create or replace function private.recurring_member_on_approved_full_day_leave',
  'create or replace function private.create_leave_coverage_actions',
  'create or replace function public.rpc_create_employee_request',
  'create or replace function public.rpc_decide_employee_request',
  'create or replace function public.rpc_withdraw_employee_request',
  'create or replace function public.rpc_list_request_availability',
  "message = 'REQUEST_SELF_APPROVAL_DENIED'",
  "message = 'REQUEST_VERSION_CONFLICT'",
  "message = 'REQUEST_APPROVED_OVERLAP'",
  "message = 'REQUEST_REJECTION_REASON_REQUIRED'",
  "issue_code = 'APPROVED_LEAVE_COVERAGE_REQUIRED'",
  "'leave.coverage_required'",
  "'attendance.correction_approved'",
  'and not private.recurring_member_on_approved_full_day_leave',
  'exclude using gist',
  'grant execute on function public.rpc_create_employee_request(uuid, jsonb, text) to authenticated',
  'grant execute on function public.rpc_decide_employee_request(uuid, text, text, integer, text) to authenticated',
  'revoke insert, update, delete, truncate, references, trigger',
]) {
  if (!hrRequestsMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P05 HR migration is missing: ${fragment}`);
  }
}

for (const forbiddenGrant of [
  'grant insert on public.employee_requests to authenticated',
  'grant update on public.request_decisions to authenticated',
  'grant execute on function private.create_leave_coverage_actions(uuid) to authenticated',
  'grant execute on function private.recurring_member_on_approved_full_day_leave(uuid, uuid, date) to authenticated',
]) {
  if (hrRequestsMigration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P05 exposes a privileged HR boundary: ${forbiddenGrant}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(hrRequestsMigration)) {
  throw new Error('P05 HR migration contains an unsafe always-true policy');
}

for (const testId of [
  'REQ-01',
  'REQ-02',
  'REQ-03',
  'REQ-04',
  'REQ-05',
  'REQ-06',
  'REQ-07',
  'REQ-08',
  'REQ-09',
  'REQ-10',
  'REQ-11',
  'REQ-12',
  'REQ-13',
  'DAILY-07',
]) {
  if (!hrRequestsTests.includes(testId)) {
    throw new Error(`P05 database test is missing required case: ${testId}`);
  }
}

for (const table of [
  'public.office_networks',
  'public.office_ip_ranges',
  'public.user_devices',
  'public.files',
  'public.upload_intents',
  'public.attendance_challenges',
  'public.remote_laptop_sessions',
  'public.attendance_events',
  'public.attendance_evidence',
  'public.attendance_sessions',
]) {
  if (!attendanceMigration.toLowerCase().includes(`create table ${table}`)) {
    throw new Error(`P06 attendance migration does not create ${table}`);
  }
  if (
    !attendanceMigration.toLowerCase().includes(`alter table ${table} enable row level security`)
  ) {
    throw new Error(`P06 attendance migration does not enable RLS for ${table}`);
  }
}

for (const fragment of [
  'create unique index attendance_one_open_session_idx',
  "'attendance-evidence'",
  'insert into storage.buckets',
  'public.rpc_internal_create_remote_laptop_session',
  'public.rpc_internal_resolve_remote_laptop_session',
  'resolve_attempt_count integer not null default 0',
  'invalidated_at timestamptz',
  'set invalidated_at = v_now',
  'v_session.resolve_attempt_count >= 5',
  'locked_at = case when v_attempts >= 5 then v_now else null end',
  "where status = 'open'",
  'create trigger attendance_events_immutable',
  'create or replace function private.member_has_remote_permission',
  'create or replace function public.rpc_internal_create_attendance_challenge',
  'create or replace function public.rpc_internal_finalize_attendance',
  'create or replace function public.rpc_get_attendance_day',
  "message = 'REMOTE_NOT_APPROVED'",
  "message = 'LAPTOP_SESSION_REQUIRED'",
  "message = 'REMOTE_UPLOAD_INTENT_INVALID'",
  "message = 'WIFI_BSSID_MISMATCH'",
  "message = 'SOURCE_IP_MISMATCH'",
  "message = 'ATTENDANCE_CHECK_IN_REQUIRED'",
  'p_source_ip <<= r.ip_range',
  "f.purpose = 'attendance'",
  "f.state = 'ready'",
  'from public.upload_intents ui',
  "ui.target_kind = 'attendance'",
  'ui.challenge_id = v_challenge.id',
  'ui.consumed_at is null',
  'update public.upload_intents',
  'set consumed_at = v_now',
  "v_challenge.action = 'check_in'",
  "v_challenge.action = 'check_out'",
  'v_now timestamptz := clock_timestamp()',
  'grant execute on function public.rpc_internal_create_attendance_challenge',
  'grant execute on function public.rpc_internal_create_remote_laptop_session',
  'grant execute on function public.rpc_internal_resolve_remote_laptop_session',
  'grant execute on function public.rpc_internal_finalize_attendance',
  'to service_role',
  'revoke insert, update, delete, truncate, references, trigger',
]) {
  if (!attendanceMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P06 attendance migration is missing: ${fragment}`);
  }
}

for (const forbiddenGrant of [
  'grant execute on function public.rpc_internal_create_attendance_challenge(uuid, uuid, uuid, text, text, uuid, text) to authenticated',
  'grant execute on function public.rpc_internal_create_remote_laptop_session(uuid, uuid, uuid, text) to authenticated',
  'grant execute on function public.rpc_internal_resolve_remote_laptop_session(uuid, uuid, uuid, text) to authenticated',
  'grant execute on function public.rpc_internal_finalize_attendance(uuid, text, text, inet, uuid, uuid, text) to authenticated',
  'grant insert on public.attendance_events to authenticated',
  'grant update on public.attendance_events to authenticated',
]) {
  if (attendanceMigration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P06 exposes a privileged attendance boundary: ${forbiddenGrant}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(attendanceMigration)) {
  throw new Error('P06 attendance migration contains an unsafe always-true policy');
}

for (const testId of [
  'ATT-01',
  'ATT-02',
  'ATT-03',
  'ATT-04',
  'ATT-05',
  'ATT-06',
  'ATT-07',
  'ATT-08',
  'ATT-09',
  'ATT-10',
  'ATT-11',
  'ATT-12',
  'ATT-13',
  'ATT-14',
  'ATT-15',
  'ATT-16',
  'ATT-17',
  'ATT-18',
  'ATT-19',
  'ATT-20',
  'ATT-21',
  'ATT-22',
  'ATT-23',
  'ATT-24',
  'ATT-25',
  'ATT-26',
  'ATT-27',
  'ATT-28',
  'ATT-29',
]) {
  if (!attendanceTests.includes(testId)) {
    throw new Error(`P06 database test is missing required case: ${testId}`);
  }
}

for (const table of [
  'public.attendance_day_summaries',
  'public.timesheet_periods',
  'public.timesheet_snapshots',
  'public.timesheet_period_events',
]) {
  if (!timesheetMigration.toLowerCase().includes(`create table ${table}`)) {
    throw new Error(`P07 timesheet migration does not create ${table}`);
  }
  if (
    !timesheetMigration.toLowerCase().includes(`alter table ${table} enable row level security`)
  ) {
    throw new Error(`P07 timesheet migration does not enable RLS for ${table}`);
  }
}

for (const fragment of [
  'create trigger timesheet_snapshots_immutable',
  'create trigger timesheet_period_events_immutable',
  'create or replace function private.prevent_closed_timesheet_day_mutation',
  'create or replace function private.timesheet_live_member_json',
  'create or replace function public.rpc_internal_upsert_attendance_day_summary',
  'create or replace function public.rpc_get_timesheet',
  'create or replace function public.rpc_begin_timesheet_reconciliation',
  'create or replace function public.rpc_close_timesheet',
  'create or replace function public.rpc_reopen_timesheet',
  "'period_id', v_period.id",
  "'period_version', coalesce(v_period.version, 1)",
  "'scheduled_days', 0",
  "'requires_reconciliation_days', 0",
  "message = 'PERIOD_CLOSED'",
  "message = 'TIMESHEET_BLOCKING_EXCEPTIONS'",
  'insert into public.timesheet_snapshots',
  'revision = revision + 1',
  'source_revision_hash text not null',
  'standard_day_minutes integer not null',
  'extensions.digest',
  'grant execute on function public.rpc_internal_upsert_attendance_day_summary(uuid, uuid, date, jsonb, text) to service_role',
  'revoke insert, update, delete, truncate, references, trigger',
]) {
  if (!timesheetMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P07 timesheet migration is missing: ${fragment}`);
  }
}

for (const forbiddenGrant of [
  'grant execute on function public.rpc_internal_upsert_attendance_day_summary(uuid, uuid, date, jsonb, text) to authenticated',
  'grant insert on public.timesheet_snapshots to authenticated',
  'grant update on public.timesheet_snapshots to authenticated',
]) {
  if (timesheetMigration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P07 exposes a privileged timesheet boundary: ${forbiddenGrant}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(timesheetMigration)) {
  throw new Error('P07 timesheet migration contains an unsafe always-true policy');
}

for (const testId of [
  'TIME-01',
  'TIME-02',
  'TIME-03',
  'TIME-04',
  'TIME-05',
  'TIME-06',
  'TIME-07',
  'TIME-08',
  'TIME-09',
  'TIME-10',
  'TIME-11',
  'TIME-12',
  'TIME-13',
  'TIME-14',
]) {
  if (!timesheetTests.includes(testId)) {
    throw new Error(`P07 database test is missing required case: ${testId}`);
  }
}

for (const table of [
  'public.push_endpoints',
  'public.notification_preferences',
  'public.notifications',
  'public.notification_deliveries',
  'public.task_reminder_snoozes',
]) {
  if (!notificationMigration.toLowerCase().includes(`create table ${table}`)) {
    throw new Error(`P08 notification migration does not create ${table}`);
  }
  if (
    !notificationMigration.toLowerCase().includes(`alter table ${table} enable row level security`)
  ) {
    throw new Error(`P08 notification migration does not enable RLS for ${table}`);
  }
}

for (const fragment of [
  'add column if not exists lease_owner uuid',
  'add column if not exists lease_until timestamptz',
  'add column if not exists dead_lettered_at timestamptz',
  'create or replace function private.notification_working_seconds_between',
  'create or replace function private.notification_member_on_approved_leave',
  'create or replace function private.enqueue_task_reminders',
  'create or replace function public.rpc_internal_enqueue_task_reminders',
  'create or replace function public.rpc_internal_claim_outbox',
  'for update skip locked',
  'lease_owner = p_worker_id',
  'create or replace function public.rpc_internal_ack_outbox',
  'create or replace function public.rpc_internal_fail_outbox',
  'dead_lettered_at',
  'create or replace function public.rpc_internal_materialize_notification',
  'create or replace function public.rpc_list_notifications',
  'create or replace function public.rpc_mark_notification_read',
  'create or replace function public.rpc_mark_all_notifications_read',
  'create or replace function public.rpc_snooze_reminder',
  'create or replace function public.rpc_revoke_device',
  'user_devices_deactivate_push_endpoints',
  "'digest'",
  'daily_push_limit',
  'grant execute on function public.rpc_internal_claim_outbox(uuid, integer) to service_role',
  'grant execute on function public.rpc_internal_enqueue_task_reminders(timestamptz) to service_role',
  'grant execute on function public.rpc_internal_materialize_notification(uuid, uuid) to service_role',
  'grant execute on function public.rpc_mark_notification_read(uuid) to authenticated',
  'revoke insert, update, delete, truncate, references, trigger',
]) {
  if (!notificationMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P08 notification migration is missing: ${fragment}`);
  }
}

for (const forbiddenGrant of [
  'grant execute on function public.rpc_internal_claim_outbox(uuid, integer) to authenticated',
  'grant execute on function public.rpc_internal_enqueue_task_reminders(timestamptz) to authenticated',
  'grant execute on function public.rpc_internal_ack_outbox(uuid, uuid) to authenticated',
  'grant execute on function public.rpc_internal_fail_outbox(uuid, uuid, text, boolean) to authenticated',
  'grant execute on function public.rpc_internal_materialize_notification(uuid, uuid) to authenticated',
  'grant insert on public.notifications to authenticated',
  'grant update on public.notifications to authenticated',
]) {
  if (notificationMigration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P08 exposes a privileged notification boundary: ${forbiddenGrant}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(notificationMigration)) {
  throw new Error('P08 notification migration contains an unsafe always-true policy');
}

for (const testId of [
  'NOTIFY-01',
  'NOTIFY-02',
  'NOTIFY-03',
  'NOTIFY-04',
  'NOTIFY-05',
  'NOTIFY-06',
  'NOTIFY-07',
  'NOTIFY-08',
  'NOTIFY-09',
  'NOTIFY-10',
  'NOTIFY-11',
  'SEC-13',
]) {
  if (!notificationTests.includes(testId)) {
    throw new Error(`P08 database test is missing required case: ${testId}`);
  }
}

for (const table of [
  'public.report_runs',
  'public.report_recipient_snapshots',
  'public.report_run_events',
]) {
  if (!reportMigration.toLowerCase().includes(`create table ${table}`)) {
    throw new Error(`P09 report migration does not create ${table}`);
  }
  if (!reportMigration.toLowerCase().includes(`alter table ${table} enable row level security`)) {
    throw new Error(`P09 report migration does not enable RLS for ${table}`);
  }
}

for (const fragment of [
  'create trigger report_recipient_snapshots_immutable',
  'create trigger report_run_events_immutable',
  'create or replace function private.report_cutoff_at',
  'create or replace function private.report_task_states_at_cutoff',
  'create or replace function private.report_scope_for_recipient',
  'create or replace function private.report_scope_still_allowed',
  'create or replace function private.report_build_facts',
  'create or replace function private.generate_report_run',
  'create or replace function public.rpc_internal_generate_due_reports',
  'create or replace function public.rpc_list_reports',
  'create or replace function public.rpc_get_report',
  'create or replace function public.rpc_create_report_revision',
  'occurred_at <= p_cutoff_at',
  'task_version desc',
  'insert into private.outbox_events',
  'report_scope_still_allowed',
  'grant execute on function public.rpc_internal_generate_due_reports(timestamptz, integer) to service_role',
  'revoke insert, update, delete, truncate, references, trigger',
]) {
  if (!reportMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P09 report migration is missing: ${fragment}`);
  }
}

for (const forbiddenGrant of [
  'grant execute on function public.rpc_internal_generate_due_reports(timestamptz, integer) to authenticated',
  'grant insert on public.report_recipient_snapshots to authenticated',
  'grant update on public.report_recipient_snapshots to authenticated',
]) {
  if (reportMigration.toLowerCase().includes(forbiddenGrant.toLowerCase())) {
    throw new Error(`P09 exposes a privileged report boundary: ${forbiddenGrant}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(reportMigration)) {
  throw new Error('P09 report migration contains an unsafe always-true policy');
}

for (const testId of [
  'REPORT-01',
  'REPORT-02',
  'REPORT-03',
  'REPORT-04',
  'REPORT-05',
  'REPORT-06',
  'REPORT-07',
  'REPORT-08',
  'REPORT-09',
  'REPORT-10',
  'REPORT-11',
  'REPORT-12',
  'REPORT-13',
  'REPORT-14',
]) {
  if (!reportTests.includes(testId)) {
    throw new Error(`P09 database test is missing required case: ${testId}`);
  }
}

const [
  securityMigration,
  securityTests,
  fileDownloadRoute,
  attendanceFinalizeRoute,
  imageValidation,
  securityDomain,
  notificationWorker,
  backupRunbook,
  securityMaintenanceWorker,
  securityScheduler,
] = await Promise.all([
  readFile(securityMigrationPath, 'utf8'),
  readFile(securityTestPath, 'utf8'),
  readFile(fileDownloadRoutePath, 'utf8'),
  readFile(attendanceFinalizeRoutePath, 'utf8'),
  readFile(imageValidationPath, 'utf8'),
  readFile(securityDomainPath, 'utf8'),
  readFile(notificationWorkerPath, 'utf8'),
  readFile(backupRunbookPath, 'utf8'),
  readFile(securityMaintenanceWorkerPath, 'utf8'),
  readFile(securitySchedulerPath, 'utf8'),
]);

for (const fragment of [
  'create table public.export_jobs',
  "'task-files'",
  "'attendance-evidence'",
  "'request-evidence'",
  "'exports'",
  'revoke all on storage.objects from anon, authenticated',
  'files_size_bytes_check',
  'files_bucket_matches_purpose',
  'files_object_path_server_generated',
  'create or replace function private.current_export_scope',
  'create or replace function private.export_scope_still_allowed',
  'create or replace function private.file_access_allowed',
  'create or replace function public.rpc_authorize_file_download',
  "'evidence.view_authorized'",
  'create or replace function public.rpc_create_export_job',
  'create or replace function public.rpc_list_audit_logs',
  'create or replace function public.rpc_internal_claim_retention_cleanup',
  'create or replace function public.rpc_internal_mark_file_deleted',
  'create or replace function public.rpc_internal_claim_export_jobs',
  'create or replace function public.rpc_internal_complete_export_job',
  'create or replace function public.rpc_internal_fail_export_job',
  'not f.legal_hold',
  "message = 'FILE_LEGAL_HOLD'",
  'grant execute on function public.rpc_internal_claim_retention_cleanup(timestamptz, integer) to service_role',
  'grant execute on function public.rpc_internal_mark_file_deleted(uuid) to service_role',
]) {
  if (!securityMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P10 security migration is missing: ${fragment}`);
  }
}

for (const forbiddenFragment of [
  'grant execute on function public.rpc_internal_claim_retention_cleanup(timestamptz, integer) to authenticated',
  'grant execute on function public.rpc_internal_mark_file_deleted(uuid) to authenticated',
  'grant select on public.files to authenticated',
  'grant select on public.upload_intents to authenticated',
]) {
  if (securityMigration.toLowerCase().includes(forbiddenFragment.toLowerCase())) {
    throw new Error(`P10 exposes a privileged boundary: ${forbiddenFragment}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(securityMigration)) {
  throw new Error('P10 security migration contains an unsafe always-true policy');
}

for (const testId of [
  'SEC-01',
  'SEC-02',
  'SEC-03',
  'SEC-04',
  'SEC-05',
  'SEC-06',
  'SEC-07',
  'SEC-08',
  'SEC-09',
  'SEC-10',
  'SEC-11',
  'SEC-12',
  'SEC-13',
  'SEC-14',
  'SEC-15',
]) {
  if (!securityTests.includes(testId)) {
    throw new Error(`P10 database test is missing required case: ${testId}`);
  }
}

for (const fragment of [
  'rpc_authorize_file_download',
  'createSignedUrl',
  'signedUrlTtlSeconds',
  'Cache-Control',
  'no-store',
]) {
  if (!fileDownloadRoute.includes(fragment)) {
    throw new Error(`P10 file download gateway is missing: ${fragment}`);
  }
}

for (const fragment of ['image/jpeg', 'image/webp', '1920', 'declaredSize', 'bytes.length']) {
  if (!imageValidation.includes(fragment)) {
    throw new Error(`P10 content validation is missing: ${fragment}`);
  }
}

for (const fragment of ['verifyAttendanceImageBytes', "state: 'quarantined'", 'CONTENT_VERIFIED']) {
  if (!attendanceFinalizeRoute.includes(fragment)) {
    throw new Error(`P10 attendance finalize hardening is missing: ${fragment}`);
  }
}

for (const fragment of [
  '/^[=+\\-@]/',
  'exportScopeStillContained',
  'shouldDeleteRetainedFile',
  'signedUrlTtlSeconds',
]) {
  if (!securityDomain.includes(fragment)) {
    throw new Error(`P10 domain security helper is missing: ${fragment}`);
  }
}

if (!notificationWorker.includes('automationSecretMatches')) {
  throw new Error('SEC-11: internal notification worker is not protected by the automation secret');
}

for (const fragment of [
  'automationSecretMatches',
  'rpc_internal_claim_export_jobs',
  'rpc_internal_claim_retention_cleanup',
  "from('exports').upload",
  'from(file.bucket_id).remove',
]) {
  if (!securityMaintenanceWorker.includes(fragment)) {
    throw new Error(`P10 security maintenance worker is missing: ${fragment}`);
  }
}

for (const fragment of [
  '/api/internal/security/maintenance',
  'x-opsdesk-automation-secret',
  'opsdesk-security-maintenance',
]) {
  if (!securityScheduler.includes(fragment)) {
    throw new Error(`P10 maintenance scheduler is missing: ${fragment}`);
  }
}

for (const fragment of [
  'database',
  'Storage',
  'restore drill',
  'legal_hold',
  'IN_PROGRESS_UNVERIFIED',
]) {
  if (!backupRunbook.includes(fragment)) {
    throw new Error(`P10 backup/restore runbook is missing: ${fragment}`);
  }
}

const contextContractMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000013_p11_context_contract.sql',
);
const contextContractManualPath = resolve(
  root,
  'supabase/manual/OPSDesk_P11_Context_Contract_Fix.sql',
);
const [contextContractMigration, contextContractManual] = await Promise.all([
  readFile(contextContractMigrationPath, 'utf8'),
  readFile(contextContractManualPath, 'utf8'),
]);

const attendanceSettingsMigrationPath = resolve(
  root,
  'supabase/migrations/00000000000014_p12_attendance_admin_settings.sql',
);
const attendanceSettingsMigration = await readFile(attendanceSettingsMigrationPath, 'utf8');

for (const fragment of [
  'create table public.attendance_settings',
  'allow_web_office_attendance boolean not null default false',
  'remote_photo_required boolean not null default true',
  "'laptop_session_required', false",
  "message = 'WEB_OFFICE_ATTENDANCE_DISABLED'",
  "jsonb_build_object('verification', 'source_ip')",
  'image/webp',
  'grant select on public.attendance_settings to authenticated',
]) {
  if (!attendanceSettingsMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P12 attendance settings migration is missing: ${fragment}`);
  }
}

for (const fragment of [
  'create or replace function public.rpc_get_context',
  'security definer',
  "'is_owner', coalesce(o.owner_member_id = m.id, false)",
  "message = 'ACTIVE_MEMBERSHIP_REQUIRED'",
  'revoke all on function public.rpc_get_context(uuid) from public, anon',
  'grant execute on function public.rpc_get_context(uuid) to authenticated',
]) {
  if (!contextContractMigration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P11 context-contract migration is missing: ${fragment}`);
  }
  if (!contextContractManual.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P11 hosted context patch is missing: ${fragment}`);
  }
}

console.log(
  'P01A/P01B/P03B/P04/P05/P06/P07/P08/P09/P10/P11/P12 static migration/security checks passed. Runtime DB/RLS/Storage and restore checks still require Supabase CLI, Docker and a staging-equivalent environment.',
);
