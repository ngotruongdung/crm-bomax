import { randomUUID } from 'node:crypto';
import { csvDocument, safeJsonCell } from '../../../../../lib/files/export-csv';
import { automationSecretMatches } from '../../../../../lib/notifications/crypto';
import { createSupabasePrivilegedServerClient } from '../../../../../lib/supabase/admin';

export const runtime = 'nodejs';
export const maxDuration = 60;

type ExportScope =
  | { kind: 'organization' }
  | { kind: 'sellers'; seller_ids: string[] }
  | { kind: 'personal'; member_id: string };

type ClaimedExport = {
  id: string;
  organization_id: string;
  requested_by: string;
  export_kind: 'tasks' | 'timesheet' | 'report' | 'audit';
  format: 'csv';
  scope_snapshot: ExportScope;
  parameters: Record<string, unknown>;
  expires_at: string | null;
};

type RetentionCandidate = {
  file_id: string;
  organization_id: string;
  bucket_id: string;
  object_path: string;
};

function response(status: number, body: unknown) {
  return Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
}

async function memberIdsForScope(
  admin: ReturnType<typeof createSupabasePrivilegedServerClient>,
  organizationId: string,
  scope: ExportScope,
) {
  if (scope.kind === 'personal') return [scope.member_id];
  if (scope.kind === 'organization') return null;
  const { data, error } = await admin
    .from('seller_members')
    .select('member_id')
    .eq('organization_id', organizationId)
    .in('seller_id', scope.seller_ids);
  if (error) throw new Error('EXPORT_SCOPE_RESOLVE_FAILED');
  return [...new Set((data ?? []).map((row) => row.member_id as string))];
}

async function taskCsv(
  admin: ReturnType<typeof createSupabasePrivilegedServerClient>,
  job: ClaimedExport,
) {
  let query = admin
    .from('tasks')
    .select(
      'task_number,title,status,priority,seller_id,assignee_member_id,planned_date,due_at,completed_at',
    )
    .eq('organization_id', job.organization_id)
    .order('task_number');
  if (job.scope_snapshot.kind === 'sellers') {
    query = query.in('seller_id', job.scope_snapshot.seller_ids);
  } else if (job.scope_snapshot.kind === 'personal') {
    query = query.eq('assignee_member_id', job.scope_snapshot.member_id);
  }
  const { data, error } = await query;
  if (error) throw new Error('TASK_EXPORT_QUERY_FAILED');
  return csvDocument(
    [
      'Mã việc',
      'Tiêu đề',
      'Trạng thái',
      'Ưu tiên',
      'Seller ID',
      'Nhân sự ID',
      'Ngày',
      'Deadline',
      'Hoàn thành',
    ],
    (data ?? []).map((row) => [
      row.task_number,
      row.title,
      row.status,
      row.priority,
      row.seller_id,
      row.assignee_member_id,
      row.planned_date,
      row.due_at,
      row.completed_at,
    ]),
  );
}

async function timesheetCsv(
  admin: ReturnType<typeof createSupabasePrivilegedServerClient>,
  job: ClaimedExport,
) {
  const memberIds = await memberIdsForScope(admin, job.organization_id, job.scope_snapshot);
  const header = [
    'Nhân sự ID',
    'Ngày',
    'Lịch',
    'Office',
    'Remote',
    'Nghỉ hưởng lương',
    'Nghỉ không lương',
    'Chưa xác định',
    'Trạng thái',
  ];
  if (memberIds?.length === 0) return csvDocument(header, []);

  const exportSource = job.parameters.source === 'snapshot' ? 'snapshot' : 'live';
  if (exportSource === 'snapshot') {
    const periodId = typeof job.parameters.period_id === 'string' ? job.parameters.period_id : null;
    const revision =
      typeof job.parameters.revision === 'number' && Number.isInteger(job.parameters.revision)
        ? job.parameters.revision
        : null;
    if (!periodId || !revision) throw new Error('TIMESHEET_SNAPSHOT_EXPORT_PARAMETERS_INVALID');

    let snapshotQuery = admin
      .from('timesheet_snapshots')
      .select('member_id,daily_rows')
      .eq('organization_id', job.organization_id)
      .eq('period_id', periodId)
      .eq('revision', revision)
      .order('member_id');
    if (memberIds) snapshotQuery = snapshotQuery.in('member_id', memberIds);
    const { data: snapshots, error: snapshotError } = await snapshotQuery;
    if (snapshotError) throw new Error('TIMESHEET_SNAPSHOT_EXPORT_QUERY_FAILED');
    if (!snapshots?.length) throw new Error('TIMESHEET_SNAPSHOT_EXPORT_NOT_FOUND');

    const rows: Array<Array<string | number | null>> = [];
    for (const snapshot of snapshots) {
      if (
        !snapshot.daily_rows ||
        typeof snapshot.daily_rows !== 'object' ||
        Array.isArray(snapshot.daily_rows)
      ) {
        throw new Error('TIMESHEET_SNAPSHOT_EXPORT_INVALID');
      }
      const payload = snapshot.daily_rows as Record<string, unknown>;
      if (!Array.isArray(payload.rows)) throw new Error('TIMESHEET_SNAPSHOT_EXPORT_INVALID');
      for (const item of payload.rows) {
        if (!item || typeof item !== 'object' || Array.isArray(item)) {
          throw new Error('TIMESHEET_SNAPSHOT_EXPORT_INVALID');
        }
        const row = item as Record<string, unknown>;
        rows.push([
          snapshot.member_id,
          typeof row.work_date === 'string' ? row.work_date : null,
          typeof row.scheduled_seconds === 'number' ? row.scheduled_seconds : 0,
          typeof row.worked_office_seconds === 'number' ? row.worked_office_seconds : 0,
          typeof row.worked_remote_seconds === 'number' ? row.worked_remote_seconds : 0,
          typeof row.paid_leave_seconds === 'number' ? row.paid_leave_seconds : 0,
          typeof row.unpaid_leave_seconds === 'number' ? row.unpaid_leave_seconds : 0,
          typeof row.unknown_seconds === 'number' ? row.unknown_seconds : 0,
          typeof row.state === 'string' ? row.state : 'unknown',
        ]);
      }
    }
    return csvDocument(header, rows);
  }

  let query = admin
    .from('attendance_day_summaries')
    .select(
      'member_id,work_date,scheduled_seconds,worked_office_seconds,worked_remote_seconds,paid_leave_seconds,unpaid_leave_seconds,unknown_seconds,state',
    )
    .eq('organization_id', job.organization_id)
    .order('work_date');
  if (memberIds) {
    query = query.in('member_id', memberIds);
  }
  const monthStart =
    typeof job.parameters.month_start === 'string' ? job.parameters.month_start : null;
  if (monthStart && /^\d{4}-\d{2}-01$/.test(monthStart)) {
    const next = new Date(`${monthStart}T00:00:00.000Z`);
    next.setUTCMonth(next.getUTCMonth() + 1);
    query = query.gte('work_date', monthStart).lt('work_date', next.toISOString().slice(0, 10));
  }
  const { data, error } = await query;
  if (error) throw new Error('TIMESHEET_EXPORT_QUERY_FAILED');
  return csvDocument(
    header,
    (data ?? []).map((row) => [
      row.member_id,
      row.work_date,
      row.scheduled_seconds,
      row.worked_office_seconds,
      row.worked_remote_seconds,
      row.paid_leave_seconds,
      row.unpaid_leave_seconds,
      row.unknown_seconds,
      row.state,
    ]),
  );
}

async function reportCsv(
  admin: ReturnType<typeof createSupabasePrivilegedServerClient>,
  job: ClaimedExport,
) {
  let query = admin
    .from('report_recipient_snapshots')
    .select('run_id,created_at,scope,facts,summary_template,source_hash')
    .eq('organization_id', job.organization_id)
    .eq('recipient_member_id', job.requested_by)
    .order('created_at', { ascending: false });
  const runId = typeof job.parameters.run_id === 'string' ? job.parameters.run_id : null;
  if (runId) query = query.eq('run_id', runId);
  const { data, error } = await query;
  if (error) throw new Error('REPORT_EXPORT_QUERY_FAILED');
  return csvDocument(
    ['Report ID', 'Tạo lúc', 'Phạm vi', 'Tóm tắt', 'Facts', 'Source hash'],
    (data ?? []).map((row) => [
      row.run_id,
      row.created_at,
      safeJsonCell(row.scope),
      row.summary_template,
      safeJsonCell(row.facts),
      row.source_hash,
    ]),
  );
}

async function auditCsv(
  admin: ReturnType<typeof createSupabasePrivilegedServerClient>,
  job: ClaimedExport,
) {
  if (job.scope_snapshot.kind !== 'organization') throw new Error('AUDIT_EXPORT_SCOPE_DENIED');
  const { data, error } = await admin
    .from('audit_logs')
    .select(
      'recorded_at,actor_member_id,actor_kind,action,entity_type,entity_id,request_id,safe_metadata',
    )
    .eq('organization_id', job.organization_id)
    .order('recorded_at', { ascending: false })
    .limit(10000);
  if (error) throw new Error('AUDIT_EXPORT_QUERY_FAILED');
  return csvDocument(
    [
      'Thời gian',
      'Actor ID',
      'Actor kind',
      'Hành động',
      'Đối tượng',
      'Entity ID',
      'Request ID',
      'Metadata an toàn',
    ],
    (data ?? []).map((row) => [
      row.recorded_at,
      row.actor_member_id,
      row.actor_kind,
      row.action,
      row.entity_type,
      row.entity_id,
      row.request_id,
      safeJsonCell(row.safe_metadata),
    ]),
  );
}

async function buildExportCsv(
  admin: ReturnType<typeof createSupabasePrivilegedServerClient>,
  job: ClaimedExport,
) {
  if (job.export_kind === 'tasks') return taskCsv(admin, job);
  if (job.export_kind === 'timesheet') return timesheetCsv(admin, job);
  if (job.export_kind === 'report') return reportCsv(admin, job);
  return auditCsv(admin, job);
}

export async function POST(request: Request) {
  if (!automationSecretMatches(request.headers.get('x-opsdesk-automation-secret'))) {
    return response(401, { ok: false, error: { code: 'AUTOMATION_AUTH_REQUIRED' } });
  }

  const admin = createSupabasePrivilegedServerClient();
  const workerId = randomUUID();
  const counters = { exports_ready: 0, exports_failed: 0, files_deleted: 0, cleanup_failed: 0 };

  const claim = await admin.rpc('rpc_internal_claim_export_jobs', {
    p_worker_id: workerId,
    p_limit: 10,
    p_now: new Date().toISOString(),
  });
  if (claim.error) return response(503, { ok: false, error: { code: 'EXPORT_CLAIM_FAILED' } });
  const jobs = (Array.isArray(claim.data) ? claim.data : []) as ClaimedExport[];

  for (const job of jobs) {
    try {
      const csv = await buildExportCsv(admin, job);
      const bytes = Buffer.from(csv, 'utf8');
      const objectPath = `${job.organization_id}/export/${job.id}/${randomUUID()}.csv`;
      const retentionUntil = job.expires_at ?? new Date(Date.now() + 7 * 86400000).toISOString();
      const { data: fileRow, error: fileError } = await admin
        .from('files')
        .insert({
          organization_id: job.organization_id,
          uploaded_by_member_id: job.requested_by,
          bucket_id: 'exports',
          object_path: objectPath,
          original_name: `${job.export_kind}-${new Date().toISOString().slice(0, 10)}.csv`,
          mime_type: 'text/csv',
          size_bytes: bytes.length,
          purpose: 'export',
          state: 'pending',
          retention_until: retentionUntil,
        })
        .select('id')
        .single();
      if (fileError || !fileRow) throw new Error('EXPORT_FILE_METADATA_FAILED');

      const { error: uploadError } = await admin.storage.from('exports').upload(objectPath, bytes, {
        contentType: 'text/csv; charset=utf-8',
        cacheControl: '0',
        upsert: false,
      });
      if (uploadError) throw new Error('EXPORT_STORAGE_UPLOAD_FAILED');

      const { error: readyError } = await admin
        .from('files')
        .update({
          state: 'ready',
          verified_at: new Date().toISOString(),
          verification_code: 'SERVER_GENERATED_EXPORT',
        })
        .eq('id', fileRow.id)
        .eq('state', 'pending');
      if (readyError) throw new Error('EXPORT_FILE_READY_FAILED');

      const complete = await admin.rpc('rpc_internal_complete_export_job', {
        p_job_id: job.id,
        p_worker_id: workerId,
        p_file_id: fileRow.id,
        p_completed_at: new Date().toISOString(),
      });
      if (complete.error) throw new Error('EXPORT_COMPLETE_FAILED');
      counters.exports_ready += 1;
    } catch (error) {
      await admin.rpc('rpc_internal_fail_export_job', {
        p_job_id: job.id,
        p_worker_id: workerId,
        p_error_code: error instanceof Error ? error.message : 'EXPORT_FAILED',
      });
      counters.exports_failed += 1;
    }
  }

  const cleanup = await admin.rpc('rpc_internal_claim_retention_cleanup', {
    p_now: new Date().toISOString(),
    p_limit: 100,
  });
  if (!cleanup.error) {
    const candidates = (Array.isArray(cleanup.data) ? cleanup.data : []) as RetentionCandidate[];
    for (const file of candidates) {
      const removed = await admin.storage.from(file.bucket_id).remove([file.object_path]);
      if (removed.error) {
        counters.cleanup_failed += 1;
        continue;
      }
      const marked = await admin.rpc('rpc_internal_mark_file_deleted', { p_file_id: file.file_id });
      if (marked.error) counters.cleanup_failed += 1;
      else counters.files_deleted += 1;
    }
  } else {
    counters.cleanup_failed += 1;
  }

  return response(200, { ok: true, data: counters });
}
