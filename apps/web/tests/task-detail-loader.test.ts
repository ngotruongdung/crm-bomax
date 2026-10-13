import { beforeEach, describe, expect, it, vi } from 'vitest';
import { requireMemberContext } from '../lib/auth/require-member';
import { createSupabaseServerClient } from '../lib/supabase/server';
import { loadTaskDetailData } from '../app/tasks/task-data';

vi.mock('../lib/auth/require-member', () => ({
  requireMemberContext: vi.fn(),
}));

vi.mock('../lib/supabase/server', () => ({
  createSupabaseServerClient: vi.fn(),
}));

const requireMemberContextMock = vi.mocked(requireMemberContext);
const createSupabaseServerClientMock = vi.mocked(createSupabaseServerClient);
const rpcMock = vi.fn();

const context = {
  organization_id: '53000000-0000-0000-0000-000000000001',
  organization_name: 'OpsDesk Demo',
  organization_slug: 'opsdesk-demo',
  timezone: 'Asia/Ho_Chi_Minh',
  member_id: '63000000-0000-0000-0000-000000000003',
  user_id: '43000000-0000-0000-0000-000000000003',
  employee_code: 'EMP-A',
  display_name: 'Nhân viên A',
  role: 'employee',
  status: 'active',
  is_owner: false,
  capabilities: [],
  seller_scope: [],
  scope_version: 1,
  server_now: '2026-10-04T00:00:00.000Z',
} as const;

const taskIds = [
  '83000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000002',
] as const;

function taskPayload(id: string, title: string) {
  return {
    id,
    task_number: id === taskIds[0] ? 'TASK-0001' : 'TASK-0002',
    batch_id: null,
    title,
    description: null,
    seller_id: '73000000-0000-0000-0000-000000000001',
    seller_name: 'Seller A',
    assignee_member_id: context.member_id,
    assignee_name: context.display_name,
    created_by_member_id: '63000000-0000-0000-0000-000000000001',
    created_by_name: 'Admin A',
    reviewer_member_id: '63000000-0000-0000-0000-000000000002',
    reviewer_name: 'Manager A',
    priority: 'normal',
    status: 'in_progress',
    planned_date: '2026-10-04',
    original_due_at: '2026-10-04T11:00:00.000Z',
    due_at: '2026-10-04T11:00:00.000Z',
    assigned_at: '2026-10-04T01:00:00.000Z',
    visible_from: null,
    acknowledged_at: '2026-10-04T02:00:00.000Z',
    started_at: '2026-10-04T02:05:00.000Z',
    submitted_at: null,
    completed_at: null,
    requires_review: true,
    requires_result: true,
    requires_attachment: false,
    allow_no_incident: false,
    estimated_minutes: 30,
    blocked_at: null,
    blocker_reason: null,
    blocker_owner_member_id: null,
    current_submission_id: null,
    version: 2,
    checklist: [],
    submissions: [],
    events: [],
    permissions: { is_assignee: true, can_review: false, can_manage: false },
  };
}

beforeEach(() => {
  vi.clearAllMocks();
  process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://opsdesk-test.supabase.co';
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = 'test-anon-key';
  requireMemberContextMock.mockResolvedValue(context as never);
  createSupabaseServerClientMock.mockResolvedValue({ rpc: rpcMock } as never);
});

describe('loadTaskDetailData', () => {
  it('loads each deep-linked task fresh by its route id', async () => {
    rpcMock.mockImplementation(async (_name, args) => {
      const taskId = (args as { p_task_id: string }).p_task_id;
      return taskId === taskIds[0]
        ? { data: taskPayload(taskIds[0], 'Công việc A'), error: null }
        : { data: taskPayload(taskIds[1], 'Công việc B'), error: null };
    });

    const first = await loadTaskDetailData(taskIds[0]);
    const second = await loadTaskDetailData(taskIds[1]);

    expect(first.task?.title).toBe('Công việc A');
    expect(second.task?.title).toBe('Công việc B');
    expect(rpcMock).toHaveBeenNthCalledWith(1, 'rpc_get_task', { p_task_id: taskIds[0] });
    expect(rpcMock).toHaveBeenNthCalledWith(2, 'rpc_get_task', { p_task_id: taskIds[1] });
  });

  it('returns an explicit permission error instead of a stale or empty task', async () => {
    rpcMock.mockResolvedValue({ data: null, error: { message: 'TASK_ACCESS_DENIED' } });

    const result = await loadTaskDetailData(taskIds[0]);

    expect(result.task).toBeNull();
    expect(result.taskErrorCode).toBe('TASK_ACCESS_DENIED');
    expect(result.taskError).toContain('không có quyền truy cập');
  });

  it('rejects a malformed task payload with a clear contract error', async () => {
    rpcMock.mockResolvedValue({ data: { id: taskIds[0] }, error: null });

    const result = await loadTaskDetailData(taskIds[0]);

    expect(result.task).toBeNull();
    expect(result.taskErrorCode).toBe('TASK_DETAIL_CONTRACT_INVALID');
    expect(result.taskError).toContain('không đúng hợp đồng');
  });
});
