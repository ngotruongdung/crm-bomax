import {
  memberDirectorySchema,
  taskListSchema,
  type OrganizationContext,
} from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../../lib/supabase/server';
import { requireMemberContext } from '../../lib/auth/require-member';
import {
  createDemoOrganizationContext,
  createDemoTasks,
  demoMembers,
  demoSellers,
  resolveWorkspaceDataSource,
  type WorkspaceTaskItem,
  type WorkspaceDataSource,
} from '../../lib/demo/opsdesk-demo';
import type { SellerSummary } from './management-panels';

export async function loadManagementData(): Promise<{
  source: WorkspaceDataSource;
  context: OrganizationContext;
  members: ReturnType<typeof memberDirectorySchema.parse>;
  sellers: SellerSummary[];
  tasks: WorkspaceTaskItem[];
}> {
  if (resolveWorkspaceDataSource() === 'demo') {
    const context = createDemoOrganizationContext();
    return {
      source: 'demo',
      context,
      members: demoMembers,
      tasks: createDemoTasks(context),
      sellers: demoSellers.map((seller) => ({
        id: seller.id,
        code: seller.code,
        name: seller.name,
        platform: seller.platform,
        brand_label: seller.brand_label ?? null,
        shop_url: seller.shop_url ?? null,
        archived_at: seller.archived_at ?? null,
        version: seller.version ?? 1,
      })),
    };
  }

  const context = await requireMemberContext();
  const client = await createSupabaseServerClient();
  const [
    { data: sellerRows, error: sellersError },
    { data: memberRows, error: membersError },
    { data: taskRows, error: tasksError },
  ] = await Promise.all([
    client
      .from('sellers')
      .select('id, code, name, platform, brand_label, shop_url, archived_at, version')
      .order('name'),
    client.rpc('rpc_list_members_by_scope', { p_organization_id: context.organization_id }),
    client.rpc('rpc_list_tasks', {
      p_organization_id: context.organization_id,
      p_include_terminal: true,
    }),
  ]);

  if (sellersError || membersError || tasksError) {
    throw new Error('MANAGEMENT_DATA_LOAD_FAILED');
  }

  const members = memberDirectorySchema.safeParse(memberRows);
  if (!members.success) {
    throw new Error('MANAGEMENT_MEMBER_CONTRACT_INVALID');
  }

  const tasks = taskListSchema.safeParse(taskRows);
  if (!tasks.success) {
    throw new Error('MANAGEMENT_TASK_CONTRACT_INVALID');
  }

  return {
    source: 'supabase',
    context,
    members: members.data,
    sellers: sellerRows ?? [],
    tasks: tasks.data,
  };
}
