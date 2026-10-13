import {
  extractTaskErrorCode,
  memberDirectorySchema,
  taskDetailSchema,
  taskErrorMessage,
  taskListSchema,
  type MemberDirectoryEntry,
  type OrganizationContext,
  type TaskDetail,
} from '@opsdesk/contracts';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@opsdesk/api-client';
import { requireMemberContext } from '../../lib/auth/require-member';
import {
  createDemoTaskDetail,
  createDemoWorkspaceData,
  resolveWorkspaceDataSource,
  type WorkspaceDataSource,
  type WorkspaceTaskItem,
} from '../../lib/demo/opsdesk-demo';
import { createSupabaseServerClient } from '../../lib/supabase/server';

export type TaskSellerOption = {
  id: string;
  code: string;
  name: string;
  platform: string;
};

type TaskCreateOptions = {
  members: MemberDirectoryEntry[];
  sellers: TaskSellerOption[];
};

async function loadCreateOptions(
  client: SupabaseClient<Database>,
  context: OrganizationContext,
): Promise<TaskCreateOptions> {
  if (context.role === 'employee') return { members: [], sellers: [] };

  const [{ data: memberRows, error: membersError }, { data: sellerRows, error: sellersError }] =
    await Promise.all([
      client.rpc('rpc_list_members_by_scope', { p_organization_id: context.organization_id }),
      client
        .from('sellers')
        .select('id, code, name, platform')
        .eq('organization_id', context.organization_id)
        .is('archived_at', null)
        .order('name'),
    ]);

  if (membersError || sellersError) throw new Error('TASK_CREATE_OPTIONS_LOAD_FAILED');
  const members = memberDirectorySchema.safeParse(memberRows);
  if (!members.success) throw new Error('TASK_MEMBER_CONTRACT_INVALID');

  return {
    members: members.data.filter((member) => member.status === 'active'),
    sellers: sellerRows ?? [],
  };
}

export async function loadTaskCreateData(): Promise<{
  context: OrganizationContext;
  members: MemberDirectoryEntry[];
  sellers: TaskSellerOption[];
  source: WorkspaceDataSource;
}> {
  if (resolveWorkspaceDataSource() === 'demo') {
    const demo = createDemoWorkspaceData();
    return {
      context: demo.context,
      members: demo.members,
      sellers: demo.sellers,
      source: demo.source,
    };
  }

  const context = await requireMemberContext();
  const client = await createSupabaseServerClient();
  const options = await loadCreateOptions(client, context);
  return { context, source: 'supabase', ...options };
}

export async function loadTaskListData(listOptions: { includeTerminal?: boolean } = {}): Promise<{
  context: OrganizationContext;
  members: MemberDirectoryEntry[];
  sellers: TaskSellerOption[];
  tasks: WorkspaceTaskItem[];
  source: WorkspaceDataSource;
}> {
  if (resolveWorkspaceDataSource() === 'demo') {
    const demo = createDemoWorkspaceData();
    return demo;
  }

  const context = await requireMemberContext();
  const client = await createSupabaseServerClient();
  const [{ data: taskRows, error: tasksError }, createOptions] = await Promise.all([
    client.rpc('rpc_list_tasks', {
      p_organization_id: context.organization_id,
      p_include_terminal: listOptions.includeTerminal ?? false,
    }),
    loadCreateOptions(client, context),
  ]);

  if (tasksError) throw new Error('TASK_LIST_LOAD_FAILED');
  const tasks = taskListSchema.safeParse(taskRows);
  if (!tasks.success) {
    if (process.env.NODE_ENV === 'development') {
      console.error('[OpsDesk] rpc_list_tasks contract mismatch:', tasks.error.issues);
    }
    throw new Error('TASK_LIST_CONTRACT_INVALID');
  }

  return { context, tasks: tasks.data, source: 'supabase', ...createOptions };
}

export async function loadTaskDetailData(taskId: string): Promise<{
  context: OrganizationContext;
  members: MemberDirectoryEntry[];
  sellers: TaskSellerOption[];
  task: TaskDetail | null;
  taskError: string | null;
  taskErrorCode: string | null;
  source: WorkspaceDataSource;
}> {
  if (resolveWorkspaceDataSource() === 'demo') {
    const demo = createDemoWorkspaceData();
    const task = createDemoTaskDetail(taskId, demo.context);
    return {
      context: demo.context,
      members: demo.members,
      sellers: demo.sellers,
      task,
      taskError: task ? null : 'Công việc demo không tồn tại.',
      taskErrorCode: task ? null : 'TASK_NOT_FOUND',
      source: demo.source,
    };
  }

  const context = await requireMemberContext();
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc('rpc_get_task', { p_task_id: taskId });

  if (error) {
    return {
      context,
      members: [],
      sellers: [],
      task: null,
      taskError: taskErrorMessage(error, 'Không thể tải công việc này.'),
      taskErrorCode: extractTaskErrorCode(error),
      source: 'supabase',
    };
  }

  const parsed = taskDetailSchema.safeParse(data);
  if (!parsed.success) {
    return {
      context,
      members: [],
      sellers: [],
      task: null,
      taskError: 'Dữ liệu công việc không đúng hợp đồng hiện tại.',
      taskErrorCode: 'TASK_DETAIL_CONTRACT_INVALID',
      source: 'supabase',
    };
  }

  const options = parsed.data.permissions.can_manage
    ? await loadCreateOptions(client, context)
    : { members: [], sellers: [] };

  return {
    context,
    task: parsed.data,
    taskError: null,
    taskErrorCode: null,
    source: 'supabase',
    ...options,
  };
}
