import { beforeEach, describe, expect, it, vi } from 'vitest';
import { requireMemberContext } from '../lib/auth/require-member';
import { createSupabaseServerClient } from '../lib/supabase/server';
import { loadManagementData } from '../app/management/management-data';

vi.mock('../lib/auth/require-member', () => ({
  requireMemberContext: vi.fn(),
}));

vi.mock('../lib/supabase/server', () => ({
  createSupabaseServerClient: vi.fn(),
}));

const requireMemberContextMock = vi.mocked(requireMemberContext);
const createSupabaseServerClientMock = vi.mocked(createSupabaseServerClient);

beforeEach(() => {
  vi.clearAllMocks();
  delete process.env.NEXT_PUBLIC_SUPABASE_URL;
  delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
});

describe('loadManagementData', () => {
  it('uses deterministic demo sellers and members without touching Supabase when public config is absent', async () => {
    const result = await loadManagementData();

    expect(result.source).toBe('demo');
    expect(result.context.employee_code).toBe('NV0002');
    expect(result.members.map((member) => member.employee_code)).toEqual([
      'NV0001',
      'NV0002',
      'NV0003',
      'NV0004',
    ]);
    expect(result.sellers.map((seller) => seller.code)).toEqual([
      'BM-SHOPEE',
      'BM-TIKTOK',
      'BY-SUNI',
    ]);
    expect(requireMemberContextMock).not.toHaveBeenCalled();
    expect(createSupabaseServerClientMock).not.toHaveBeenCalled();
  });
});
