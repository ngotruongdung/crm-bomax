import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createSupabaseServerClient } from '../lib/supabase/server';
import {
  ActiveMembershipRequiredError,
  AuthenticationRequiredError,
  requireMemberContext,
} from '../lib/auth/require-member';

vi.mock('../lib/supabase/server', () => ({
  createSupabaseServerClient: vi.fn(),
}));

type ServerClient = Awaited<ReturnType<typeof createSupabaseServerClient>>;

const getUserMock = vi.fn<ServerClient['auth']['getUser']>();
const rpcMock = vi.fn<ServerClient['rpc']>();
const serverClientMock = vi.mocked(createSupabaseServerClient);

const validContext = {
  organization_id: '10000000-0000-0000-0000-000000000001',
  organization_name: 'OpsDesk Demo A',
  organization_slug: 'opsdesk-demo-a',
  timezone: 'Asia/Ho_Chi_Minh',
  member_id: '30000000-0000-0000-0000-000000000001',
  user_id: '40000000-0000-0000-0000-000000000001',
  employee_code: 'ADM-A',
  display_name: 'Admin Demo A',
  role: 'admin',
  status: 'active',
  is_owner: true,
  capabilities: ['can_manage_attendance', 'can_approve_requests', 'can_view_attendance_evidence'],
  seller_scope: [],
  scope_version: 1,
  server_now: '2026-10-04T00:00:00.000Z',
};

beforeEach(() => {
  vi.clearAllMocks();
  serverClientMock.mockResolvedValue({
    auth: { getUser: getUserMock },
    rpc: rpcMock,
  } as unknown as ServerClient);
  getUserMock.mockResolvedValue({ data: { user: null }, error: null } as never);
});

describe('requireMemberContext', () => {
  it('rejects an unauthenticated request before loading context', async () => {
    await expect(requireMemberContext()).rejects.toBeInstanceOf(AuthenticationRequiredError);
    expect(rpcMock).not.toHaveBeenCalled();
  });

  it('returns the validated context for an active member', async () => {
    getUserMock.mockResolvedValue({
      data: { user: { id: validContext.user_id } },
      error: null,
    } as never);
    rpcMock.mockResolvedValue({ data: validContext, error: null } as never);

    await expect(requireMemberContext(validContext.organization_id)).resolves.toMatchObject({
      organization_id: validContext.organization_id,
      role: 'admin',
    });
    expect(rpcMock).toHaveBeenCalledWith('rpc_get_context', {
      p_organization_id: validContext.organization_id,
    });
  });

  it('maps an inactive membership error to a typed application error', async () => {
    getUserMock.mockResolvedValue({
      data: { user: { id: validContext.user_id } },
      error: null,
    } as never);
    rpcMock.mockResolvedValue({
      data: null,
      error: { message: 'ACTIVE_MEMBERSHIP_REQUIRED' },
    } as never);

    await expect(
      requireMemberContext('10000000-0000-0000-0000-000000000002'),
    ).rejects.toBeInstanceOf(ActiveMembershipRequiredError);
  });

  it('rejects an RPC payload that violates the shared contract', async () => {
    getUserMock.mockResolvedValue({
      data: { user: { id: validContext.user_id } },
      error: null,
    } as never);
    rpcMock.mockResolvedValue({
      data: { ...validContext, status: 'inactive' },
      error: null,
    } as never);

    await expect(requireMemberContext()).rejects.toThrow('CONTEXT_CONTRACT_INVALID');
  });
});
