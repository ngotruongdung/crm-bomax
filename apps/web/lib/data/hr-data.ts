import { memberDirectorySchema, type OrganizationContext } from '@opsdesk/contracts';
import {
  createDemoHrWorkspace,
  type DemoEmployeeRequest,
  type DemoLeaveType,
  type DemoPayTreatment,
  type DemoRequestStatus,
  type DemoRequestType,
} from '../demo/hr-demo';
import type { WorkspaceDataSource } from '../demo/opsdesk-demo';
import { createSupabaseServerClient } from '../supabase/server';
import { loadWorkspaceContext } from './workspace-data';

const requestTypes = new Set<DemoRequestType>([
  'leave',
  'early_leave',
  'late_arrival',
  'remote_work',
  'attendance_correction',
  'cancel_approved_request',
]);

const requestStatuses = new Set<DemoRequestStatus>([
  'pending',
  'approved',
  'rejected',
  'withdrawn',
  'canceled',
]);

const payTreatments = new Set<DemoPayTreatment>(['paid', 'unpaid', 'pending_hr', 'not_applicable']);

type RequestRow = {
  id: string;
  version: number;
  member_id: string;
  request_type: string;
  status: string;
  starts_at: string;
  ends_at: string;
  leave_type_id: string | null;
  pay_treatment_snapshot: string;
  reason_private: string;
  handover_note: string | null;
  submitted_at: string;
};

type SegmentRow = { request_id: string; affected_seconds: number };
type HandoverRow = { request_id: string; action: string };

export type HrWorkspaceData = {
  context: OrganizationContext;
  source: WorkspaceDataSource;
  schemaReady: boolean;
  leaveTypes: DemoLeaveType[];
  requests: DemoEmployeeRequest[];
};

function isMissingHrSchemaError(error: { code?: string; message?: string } | null) {
  if (!error) return false;
  return (
    error.code === '42P01' ||
    error.code === 'PGRST205' ||
    error.message?.includes("Could not find the table 'public.employee_requests'") ||
    error.message?.includes("Could not find the table 'public.leave_types'")
  );
}

function asRequestType(value: string): DemoRequestType {
  if (!requestTypes.has(value as DemoRequestType)) throw new Error('HR_REQUEST_TYPE_INVALID');
  return value as DemoRequestType;
}

function asRequestStatus(value: string): DemoRequestStatus {
  if (!requestStatuses.has(value as DemoRequestStatus))
    throw new Error('HR_REQUEST_STATUS_INVALID');
  return value as DemoRequestStatus;
}

function asPayTreatment(value: string): DemoPayTreatment {
  if (!payTreatments.has(value as DemoPayTreatment)) throw new Error('HR_PAY_TREATMENT_INVALID');
  return value as DemoPayTreatment;
}

function projectRequests({
  rows,
  leaveTypes,
  segments,
  handovers,
  memberNames,
}: {
  rows: RequestRow[];
  leaveTypes: DemoLeaveType[];
  segments: SegmentRow[];
  handovers: HandoverRow[];
  memberNames: Map<string, string>;
}) {
  const leaveTypeById = new Map(leaveTypes.map((item) => [item.id, item]));
  const affectedSeconds = new Map<string, number>();
  const handoversByRequest = new Map<string, HandoverRow[]>();

  for (const segment of segments) {
    affectedSeconds.set(
      segment.request_id,
      (affectedSeconds.get(segment.request_id) ?? 0) + Number(segment.affected_seconds || 0),
    );
  }
  for (const handover of handovers) {
    const current = handoversByRequest.get(handover.request_id) ?? [];
    current.push(handover);
    handoversByRequest.set(handover.request_id, current);
  }

  return rows.map((row): DemoEmployeeRequest => {
    const requestHandovers = handoversByRequest.get(row.id) ?? [];
    const leaveType = row.leave_type_id ? leaveTypeById.get(row.leave_type_id) : undefined;
    const hasPendingCoverage = requestHandovers.some((item) => item.action === 'pending');

    return {
      id: row.id,
      version: row.version,
      member_id: row.member_id,
      member_name: memberNames.get(row.member_id) ?? `Nhân sự ${row.member_id.slice(0, 8)}`,
      request_type: asRequestType(row.request_type),
      status: asRequestStatus(row.status),
      starts_at: row.starts_at,
      ends_at: row.ends_at,
      leave_type_id: row.leave_type_id,
      leave_type_name: leaveType?.name ?? null,
      pay_treatment: asPayTreatment(row.pay_treatment_snapshot),
      affected_minutes: Math.round((affectedSeconds.get(row.id) ?? 0) / 60),
      submitted_at: row.submitted_at,
      reason_private: row.reason_private,
      handover_note: row.handover_note,
      impacted_task_count: requestHandovers.length,
      coverage_state:
        requestHandovers.length === 0
          ? 'not_required'
          : hasPendingCoverage
            ? 'pending'
            : 'resolved',
    };
  });
}

async function loadSupabaseHrData(
  context: OrganizationContext,
  includeMemberDirectory: boolean,
): Promise<Pick<HrWorkspaceData, 'schemaReady' | 'leaveTypes' | 'requests'>> {
  const client = await createSupabaseServerClient();
  const [{ data: leaveRows, error: leaveError }, { data: requestRows, error: requestError }] =
    await Promise.all([
      client
        .from('leave_types')
        .select('id, code, name, pay_treatment, consumes_balance')
        .eq('organization_id', context.organization_id)
        .eq('active', true)
        .order('name'),
      client
        .from('employee_requests')
        .select(
          'id, version, member_id, request_type, status, starts_at, ends_at, leave_type_id, pay_treatment_snapshot, reason_private, handover_note, submitted_at',
        )
        .eq('organization_id', context.organization_id)
        .order('submitted_at', { ascending: false })
        .limit(500),
    ]);

  if (isMissingHrSchemaError(leaveError) || isMissingHrSchemaError(requestError)) {
    return { schemaReady: false, leaveTypes: [], requests: [] };
  }
  if (leaveError || requestError) throw new Error('HR_DATA_LOAD_FAILED');

  const leaveTypes: DemoLeaveType[] = (leaveRows ?? []).map((row) => ({
    id: row.id,
    code: row.code,
    name: row.name,
    pay_treatment: asPayTreatment(row.pay_treatment) as DemoLeaveType['pay_treatment'],
    consumes_balance: row.consumes_balance,
  }));
  const rows = (requestRows ?? []) as RequestRow[];
  const requestIds = rows.map((row) => row.id);

  let segments: SegmentRow[] = [];
  let handovers: HandoverRow[] = [];
  if (requestIds.length > 0) {
    const [
      { data: segmentRows, error: segmentError },
      { data: handoverRows, error: handoverError },
    ] = await Promise.all([
      client
        .from('request_segments')
        .select('request_id, affected_seconds')
        .in('request_id', requestIds),
      client
        .from('task_handover_actions')
        .select('request_id, action')
        .in('request_id', requestIds),
    ]);
    if (segmentError || handoverError) throw new Error('HR_REQUEST_DETAILS_LOAD_FAILED');
    segments = (segmentRows ?? []) as SegmentRow[];
    handovers = (handoverRows ?? []) as HandoverRow[];
  }

  const memberNames = new Map<string, string>([[context.member_id, context.display_name]]);
  if (includeMemberDirectory) {
    const { data: memberRows, error: memberError } = await client.rpc('rpc_list_members_by_scope', {
      p_organization_id: context.organization_id,
    });
    if (memberError) throw new Error('HR_MEMBER_DIRECTORY_LOAD_FAILED');
    const parsed = memberDirectorySchema.safeParse(memberRows);
    if (!parsed.success) throw new Error('HR_MEMBER_DIRECTORY_INVALID');
    for (const member of parsed.data) memberNames.set(member.member_id, member.display_name);
  }

  return {
    schemaReady: true,
    leaveTypes,
    requests: projectRequests({ rows, leaveTypes, segments, handovers, memberNames }),
  };
}

export async function loadRequestsData(): Promise<HrWorkspaceData> {
  const { context, source } = await loadWorkspaceContext();
  if (source === 'demo') {
    const demo = createDemoHrWorkspace(context);
    return {
      context,
      source,
      schemaReady: true,
      leaveTypes: demo.leaveTypes,
      requests: demo.requests.filter((request) => request.member_id === context.member_id),
    };
  }

  const data = await loadSupabaseHrData(context, false);
  return {
    context,
    source,
    ...data,
    requests: data.requests.filter((request) => request.member_id === context.member_id),
  };
}

export async function loadApprovalsData(): Promise<HrWorkspaceData> {
  const { context, source } = await loadWorkspaceContext();
  if (source === 'demo') {
    const demo = createDemoHrWorkspace(context);
    return {
      context,
      source,
      schemaReady: true,
      leaveTypes: demo.leaveTypes,
      requests: demo.requests,
    };
  }

  if (!context.capabilities.includes('can_approve_requests')) {
    return { context, source, schemaReady: true, leaveTypes: [], requests: [] };
  }

  const data = await loadSupabaseHrData(context, true);
  return { context, source, ...data };
}
