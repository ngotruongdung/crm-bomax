import type {
  MemberDirectoryEntry,
  OrganizationContext,
  TaskDetail,
  TaskEvent,
  TaskListItem,
  TaskSubmission,
} from '@opsdesk/contracts';

export type WorkspaceDataSource = 'demo' | 'supabase';

export type WorkspaceTaskItem = TaskListItem & {
  assigned_at?: string | null;
  completed_at?: string | null;
  created_by_member_id?: string | null;
  participant_member_ids?: string[];
  started_at?: string | null;
  visible_from?: string | null;
};

export type DemoSellerOption = {
  id: string;
  code: string;
  name: string;
  platform: string;
  brand_label?: string | null;
  shop_url?: string | null;
  archived_at?: string | null;
  version?: number;
};

export const demoIds = {
  organization: '53000000-0000-0000-0000-000000000001',
  adminMember: '63000000-0000-0000-0000-000000000001',
  managerMember: '63000000-0000-0000-0000-000000000002',
  employeeAMember: '63000000-0000-0000-0000-000000000003',
  employeeBMember: '63000000-0000-0000-0000-000000000004',
  adminUser: '43000000-0000-0000-0000-000000000001',
  managerUser: '43000000-0000-0000-0000-000000000002',
  employeeAUser: '43000000-0000-0000-0000-000000000003',
  employeeBUser: '43000000-0000-0000-0000-000000000004',
  sellerA: '73000000-0000-0000-0000-000000000001',
  sellerB: '73000000-0000-0000-0000-000000000002',
  sellerC: '73000000-0000-0000-0000-000000000003',
} as const;

const timezone = 'Asia/Ho_Chi_Minh';

const sellerScopes = [
  {
    seller_id: demoIds.sellerA,
    code: 'BM-SHOPEE',
    name: 'Bomax Shopee',
    platform: 'shopee' as const,
    is_manager: true,
  },
  {
    seller_id: demoIds.sellerB,
    code: 'BM-TIKTOK',
    name: 'Bomax TikTok Shop',
    platform: 'tiktok_shop' as const,
    is_manager: true,
  },
  {
    seller_id: demoIds.sellerC,
    code: 'BY-SUNI',
    name: 'By Suni',
    platform: 'shopee' as const,
    is_manager: true,
  },
];

export const demoSellers: DemoSellerOption[] = sellerScopes.map((seller, index) => ({
  id: seller.seller_id,
  code: seller.code,
  name: seller.name,
  platform: seller.platform,
  brand_label: index === 2 ? 'By Suni' : 'BOMAX',
  shop_url: null,
  archived_at: null,
  version: 1,
}));

export const demoMembers: MemberDirectoryEntry[] = [
  {
    member_id: demoIds.adminMember,
    employee_code: 'NV0001',
    display_name: 'Admin OpsDesk',
    role: 'admin',
    status: 'active',
    is_owner: true,
    capabilities: {
      can_manage_attendance: true,
      can_approve_requests: true,
      can_view_attendance_evidence: true,
    },
    seller_scope: sellerScopes,
    scope_version: 1,
    version: 1,
  },
  {
    member_id: demoIds.managerMember,
    employee_code: 'NV0002',
    display_name: 'Nguyễn Minh Anh',
    role: 'manager',
    status: 'active',
    is_owner: false,
    capabilities: {
      can_manage_attendance: true,
      can_approve_requests: true,
      can_view_attendance_evidence: true,
    },
    seller_scope: sellerScopes,
    scope_version: 1,
    version: 1,
  },
  {
    member_id: demoIds.employeeAMember,
    employee_code: 'NV0003',
    display_name: 'Trần Ngọc Linh',
    role: 'employee',
    status: 'active',
    is_owner: false,
    capabilities: {},
    seller_scope: sellerScopes.slice(0, 2).map((scope) => ({
      ...scope,
      is_manager: false,
    })),
    scope_version: 1,
    version: 1,
  },
  {
    member_id: demoIds.employeeBMember,
    employee_code: 'NV0004',
    display_name: 'Lê Quốc Huy',
    role: 'employee',
    status: 'active',
    is_owner: false,
    capabilities: {},
    seller_scope: [{ ...sellerScopes[0]!, is_manager: false }],
    scope_version: 1,
    version: 1,
  },
];

function dateInTimezone(iso: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(iso));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function offsetDate(date: string, offsetDays: number) {
  const [yearText, monthText, dayText] = date.split('-');
  if (!yearText || !monthText || !dayText) {
    throw new Error(`Invalid demo date: ${date}`);
  }
  const year = Number(yearText);
  const month = Number(monthText);
  const day = Number(dayText);
  const next = new Date(Date.UTC(year, month - 1, day + offsetDays));
  return next.toISOString().slice(0, 10);
}

function isoAt(date: string, hour: number, minute = 0) {
  const hh = String(hour).padStart(2, '0');
  const mm = String(minute).padStart(2, '0');
  return new Date(`${date}T${hh}:${mm}:00+07:00`).toISOString();
}

function taskId(index: number) {
  return `83000000-0000-0000-0000-${String(index).padStart(12, '0')}`;
}

export function isSupabasePublicConfigured() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim() ?? '';
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim() ?? '';
  if (!url || !key) return false;
  if (/placeholder|your[-_ ]?project|example/i.test(url)) return false;
  if (/placeholder|your[-_ ]?key|example/i.test(key)) return false;
  return true;
}

export function demoWorkspaceAllowed(
  options: {
    nodeEnv?: string;
    demoMode?: string;
  } = {},
) {
  const nodeEnv = options.nodeEnv ?? process.env.NODE_ENV;
  const demoMode = options.demoMode ?? process.env.NEXT_PUBLIC_DEMO_MODE;

  if (nodeEnv === 'production') return false;

  const normalized = demoMode?.trim().toLowerCase();
  return !['false', '0', 'off', 'no'].includes(normalized ?? '');
}

export function workspaceDataSourceFor(options: {
  supabaseConfigured: boolean;
  nodeEnv?: string;
  demoMode?: string;
}): WorkspaceDataSource {
  if (options.supabaseConfigured) return 'supabase';
  if (demoWorkspaceAllowed(options)) return 'demo';

  throw new Error(
    'Workspace chưa được cấu hình: thiếu Supabase public environment và demo mode đang bị tắt.',
  );
}

export function resolveWorkspaceDataSource(): WorkspaceDataSource {
  return workspaceDataSourceFor({
    supabaseConfigured: isSupabasePublicConfigured(),
    nodeEnv: process.env.NODE_ENV,
    demoMode: process.env.NEXT_PUBLIC_DEMO_MODE,
  });
}

export function createDemoOrganizationContext(
  serverNow = new Date().toISOString(),
): OrganizationContext {
  return {
    organization_id: demoIds.organization,
    organization_name: 'BOMAX Digital',
    organization_slug: 'bomax-digital',
    timezone,
    member_id: demoIds.managerMember,
    user_id: demoIds.managerUser,
    employee_code: 'NV0002',
    display_name: 'Nguyễn Minh Anh',
    role: 'manager',
    status: 'active',
    is_owner: false,
    capabilities: ['can_manage_attendance', 'can_approve_requests', 'can_view_attendance_evidence'],
    seller_scope: sellerScopes,
    scope_version: 1,
    server_now: serverNow,
  };
}

export function createDemoTasks(context: OrganizationContext): WorkspaceTaskItem[] {
  const today = dateInTimezone(context.server_now);
  const yesterday = offsetDate(today, -1);
  const tomorrow = offsetDate(today, 1);
  const inTwoDays = offsetDate(today, 2);
  const manager = demoIds.managerMember;
  const employeeA = demoIds.employeeAMember;
  const employeeB = demoIds.employeeBMember;

  return [
    {
      id: taskId(1),
      task_number: 'TASK-1028',
      title: 'Kiểm tra tồn kho trước khung sale tối',
      description: 'Đối chiếu tồn thực tế và các SKU đang chạy quảng cáo.',
      seller_id: demoIds.sellerA,
      seller_name: 'Bomax Shopee',
      assignee_member_id: manager,
      assignee_name: 'Nguyễn Minh Anh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'high',
      status: 'todo',
      planned_date: today,
      original_due_at: isoAt(today, 21, 30),
      due_at: isoAt(today, 21, 30),
      acknowledged_at: null,
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 1,
      checklist_total: 3,
      checklist_checked: 0,
      assigned_at: isoAt(today, 8, 10),
      visible_from: isoAt(today, 8, 0),
      started_at: null,
      completed_at: null,
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [],
    },
    {
      id: taskId(2),
      task_number: 'TASK-1029',
      title: 'Tối ưu ngân sách quảng cáo TikTok Shop',
      description: 'Rà lại nhóm ads có ROAS thấp và ghi nhận thay đổi ngân sách.',
      seller_id: demoIds.sellerB,
      seller_name: 'Bomax TikTok Shop',
      assignee_member_id: manager,
      assignee_name: 'Nguyễn Minh Anh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'normal',
      status: 'in_progress',
      planned_date: today,
      original_due_at: isoAt(today, 22, 0),
      due_at: isoAt(today, 22, 0),
      acknowledged_at: isoAt(today, 9, 4),
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 3,
      checklist_total: 2,
      checklist_checked: 1,
      assigned_at: isoAt(today, 8, 20),
      visible_from: isoAt(today, 8, 0),
      started_at: isoAt(today, 9, 6),
      completed_at: null,
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [employeeA],
    },
    {
      id: taskId(3),
      task_number: 'TASK-1024',
      title: 'Xử lý đơn giao trễ còn tồn từ hôm qua',
      description: 'Chốt nguyên nhân và hướng xử lý cho từng đơn chưa bàn giao.',
      seller_id: demoIds.sellerA,
      seller_name: 'Bomax Shopee',
      assignee_member_id: manager,
      assignee_name: 'Nguyễn Minh Anh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'urgent',
      status: 'in_progress',
      planned_date: yesterday,
      original_due_at: isoAt(yesterday, 17, 30),
      due_at: isoAt(yesterday, 17, 30),
      acknowledged_at: isoAt(yesterday, 10, 10),
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 4,
      checklist_total: 4,
      checklist_checked: 2,
      assigned_at: isoAt(yesterday, 9, 0),
      visible_from: isoAt(yesterday, 9, 0),
      started_at: isoAt(yesterday, 10, 12),
      completed_at: null,
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [],
    },
    {
      id: taskId(4),
      task_number: 'TASK-1030',
      title: 'Đối soát voucher seller và voucher sàn',
      description: 'Đang chờ quyền truy cập báo cáo voucher để hoàn tất đối soát.',
      seller_id: demoIds.sellerC,
      seller_name: 'By Suni',
      assignee_member_id: manager,
      assignee_name: 'Nguyễn Minh Anh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'high',
      status: 'in_progress',
      planned_date: today,
      original_due_at: isoAt(today, 20, 30),
      due_at: isoAt(today, 20, 30),
      acknowledged_at: isoAt(today, 8, 40),
      blocked_at: isoAt(today, 14, 25),
      blocker_reason: 'Chưa được cấp quyền tải báo cáo voucher của seller.',
      requires_review: false,
      version: 5,
      checklist_total: 3,
      checklist_checked: 1,
      assigned_at: isoAt(today, 8, 30),
      visible_from: isoAt(today, 8, 0),
      started_at: isoAt(today, 8, 42),
      completed_at: null,
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [],
    },
    {
      id: taskId(5),
      task_number: 'TASK-1031',
      title: 'Duyệt nội dung campaign cuối tuần',
      description: 'Kiểm tra caption, mã giảm giá và lịch phát hành trước khi lên lịch.',
      seller_id: demoIds.sellerB,
      seller_name: 'Bomax TikTok Shop',
      assignee_member_id: employeeA,
      assignee_name: 'Trần Ngọc Linh',
      reviewer_member_id: manager,
      reviewer_name: 'Nguyễn Minh Anh',
      priority: 'high',
      status: 'in_review',
      planned_date: today,
      original_due_at: isoAt(today, 21, 0),
      due_at: isoAt(today, 21, 0),
      acknowledged_at: isoAt(today, 9, 15),
      blocked_at: null,
      blocker_reason: null,
      requires_review: true,
      version: 6,
      checklist_total: 3,
      checklist_checked: 3,
      assigned_at: isoAt(today, 8, 0),
      visible_from: isoAt(today, 8, 0),
      started_at: isoAt(today, 9, 20),
      completed_at: null,
      created_by_member_id: manager,
      participant_member_ids: [],
    },
    {
      id: taskId(6),
      task_number: 'TASK-1027',
      title: 'Cập nhật giá flash sale buổi sáng',
      description: 'Đã cập nhật và kiểm tra giá hiển thị sau khi đồng bộ.',
      seller_id: demoIds.sellerA,
      seller_name: 'Bomax Shopee',
      assignee_member_id: manager,
      assignee_name: 'Nguyễn Minh Anh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'normal',
      status: 'done',
      planned_date: today,
      original_due_at: isoAt(today, 10, 30),
      due_at: isoAt(today, 10, 30),
      acknowledged_at: isoAt(today, 8, 5),
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 5,
      checklist_total: 2,
      checklist_checked: 2,
      assigned_at: isoAt(today, 7, 55),
      visible_from: isoAt(today, 7, 50),
      started_at: isoAt(today, 8, 7),
      completed_at: isoAt(today, 9, 45),
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [],
    },
    {
      id: taskId(7),
      task_number: 'TASK-1034',
      title: 'Chuẩn bị checklist campaign 10/10',
      description: 'Việc tương lai chỉ xuất hiện ở My Tasks, không chen vào Today.',
      seller_id: demoIds.sellerC,
      seller_name: 'By Suni',
      assignee_member_id: manager,
      assignee_name: 'Nguyễn Minh Anh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'normal',
      status: 'todo',
      planned_date: inTwoDays,
      original_due_at: isoAt(inTwoDays, 17, 0),
      due_at: isoAt(inTwoDays, 17, 0),
      acknowledged_at: null,
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 1,
      checklist_total: 4,
      checklist_checked: 0,
      assigned_at: isoAt(today, 15, 0),
      visible_from: isoAt(today, 15, 0),
      started_at: null,
      completed_at: null,
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [],
    },
    {
      id: taskId(8),
      task_number: 'TASK-1032',
      title: 'Chuẩn hóa template báo cáo cuối ngày',
      description: 'Công việc nội bộ, không gắn seller.',
      seller_id: null,
      seller_name: null,
      assignee_member_id: employeeB,
      assignee_name: 'Lê Quốc Huy',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'low',
      status: 'todo',
      planned_date: tomorrow,
      original_due_at: isoAt(tomorrow, 16, 30),
      due_at: isoAt(tomorrow, 16, 30),
      acknowledged_at: null,
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 1,
      checklist_total: 2,
      checklist_checked: 0,
      assigned_at: isoAt(today, 13, 0),
      visible_from: isoAt(today, 13, 0),
      started_at: null,
      completed_at: null,
      created_by_member_id: manager,
      participant_member_ids: [],
    },
    {
      id: taskId(9),
      task_number: 'TASK-1033',
      title: 'Rà nội dung FAQ cho CSKH',
      description: 'Người dùng hiện tại tham gia phối hợp nhưng không phải người thực hiện chính.',
      seller_id: demoIds.sellerA,
      seller_name: 'Bomax Shopee',
      assignee_member_id: employeeA,
      assignee_name: 'Trần Ngọc Linh',
      reviewer_member_id: null,
      reviewer_name: null,
      priority: 'normal',
      status: 'in_progress',
      planned_date: today,
      original_due_at: isoAt(today, 22, 15),
      due_at: isoAt(today, 22, 15),
      acknowledged_at: isoAt(today, 10, 0),
      blocked_at: null,
      blocker_reason: null,
      requires_review: false,
      version: 2,
      checklist_total: 2,
      checklist_checked: 1,
      assigned_at: isoAt(today, 9, 30),
      visible_from: isoAt(today, 9, 30),
      started_at: isoAt(today, 10, 5),
      completed_at: null,
      created_by_member_id: demoIds.adminMember,
      participant_member_ids: [manager],
    },
  ];
}

function memberName(memberId: string | null | undefined) {
  if (!memberId) return null;
  return demoMembers.find((member) => member.member_id === memberId)?.display_name ?? 'Thành viên';
}

function createEvents(task: WorkspaceTaskItem): TaskEvent[] {
  const events: TaskEvent[] = [
    {
      id: `93000000-0000-0000-0000-${task.id.slice(-12)}`,
      task_version: 1,
      event_type: 'created',
      actor_member_id: task.created_by_member_id ?? demoIds.adminMember,
      actor_name: memberName(task.created_by_member_id ?? demoIds.adminMember),
      event_payload: {},
      occurred_at: task.assigned_at ?? task.original_due_at,
    },
  ];
  if (task.acknowledged_at) {
    events.push({
      id: `94000000-0000-0000-0000-${task.id.slice(-12)}`,
      task_version: Math.max(2, task.version - 2),
      event_type: 'acknowledged',
      actor_member_id: task.assignee_member_id,
      actor_name: task.assignee_name,
      event_payload: {},
      occurred_at: task.acknowledged_at,
    });
  }
  if (task.started_at) {
    events.push({
      id: `95000000-0000-0000-0000-${task.id.slice(-12)}`,
      task_version: Math.max(2, task.version - 1),
      event_type: 'started',
      actor_member_id: task.assignee_member_id,
      actor_name: task.assignee_name,
      event_payload: {},
      occurred_at: task.started_at,
    });
  }
  if (task.blocked_at) {
    events.push({
      id: `96000000-0000-0000-0000-${task.id.slice(-12)}`,
      task_version: task.version,
      event_type: 'blocker_reported',
      actor_member_id: task.assignee_member_id,
      actor_name: task.assignee_name,
      event_payload: { reason: task.blocker_reason },
      occurred_at: task.blocked_at,
    });
  }
  if (task.status === 'done' && task.completed_at) {
    events.push({
      id: `97000000-0000-0000-0000-${task.id.slice(-12)}`,
      task_version: task.version,
      event_type: 'completed',
      actor_member_id: task.assignee_member_id,
      actor_name: task.assignee_name,
      event_payload: {},
      occurred_at: task.completed_at,
    });
  }
  return events;
}

function createSubmission(task: WorkspaceTaskItem): TaskSubmission[] {
  if (task.status !== 'in_review' && task.status !== 'done') return [];
  const submittedAt = task.started_at
    ? new Date(new Date(task.started_at).getTime() + 45 * 60 * 1000).toISOString()
    : task.due_at;
  return [
    {
      id: `98000000-0000-0000-0000-${task.id.slice(-12)}`,
      revision: 1,
      submitted_by_member_id: task.assignee_member_id,
      result_text:
        task.status === 'done'
          ? 'Đã hoàn tất và kiểm tra lại dữ liệu hiển thị.'
          : 'Đã hoàn tất nội dung, chờ người duyệt xác nhận.',
      no_incident: false,
      evidence: [],
      review_state: task.status === 'done' ? 'approved' : 'pending',
      reviewed_by_member_id: task.status === 'done' ? task.reviewer_member_id : null,
      reviewed_at: task.status === 'done' ? (task.completed_at ?? null) : null,
      review_reason: null,
      revision_due_at: null,
      submitted_at: submittedAt,
    },
  ];
}

export function createDemoTaskDetail(
  taskIdValue: string,
  context: OrganizationContext,
): TaskDetail | null {
  const task = createDemoTasks(context).find((item) => item.id === taskIdValue);
  if (!task) return null;
  const checklist = Array.from({ length: task.checklist_total }, (_, index) => {
    const checked = index < task.checklist_checked;
    return {
      id: `99000000-0000-0000-${String(index + 1).padStart(4, '0')}-${task.id.slice(-12)}`,
      title:
        ['Kiểm tra dữ liệu đầu vào', 'Thực hiện và đối chiếu kết quả', 'Ghi chú kết quả cuối'][
          index
        ] ?? `Bước ${index + 1}`,
      sort_order: index,
      is_required: true,
      checked_at: checked
        ? (task.started_at ?? task.acknowledged_at ?? task.assigned_at ?? null)
        : null,
      checked_by_member_id: checked ? task.assignee_member_id : null,
    };
  });
  const submissions = createSubmission(task);
  const createdBy = task.created_by_member_id ?? demoIds.adminMember;
  return {
    id: task.id,
    task_number: task.task_number,
    batch_id: null,
    title: task.title,
    description: task.description,
    seller_id: task.seller_id,
    seller_name: task.seller_name,
    assignee_member_id: task.assignee_member_id,
    assignee_name: task.assignee_name,
    created_by_member_id: createdBy,
    created_by_name: memberName(createdBy) ?? 'Admin OpsDesk',
    reviewer_member_id: task.reviewer_member_id,
    reviewer_name: task.reviewer_name,
    priority: task.priority,
    status: task.status,
    planned_date: task.planned_date,
    original_due_at: task.original_due_at,
    due_at: task.due_at,
    assigned_at: task.assigned_at ?? task.original_due_at,
    visible_from: task.visible_from ?? null,
    acknowledged_at: task.acknowledged_at,
    started_at: task.started_at ?? null,
    submitted_at: submissions[0]?.submitted_at ?? null,
    completed_at: task.completed_at ?? null,
    requires_review: task.requires_review,
    requires_result: true,
    requires_attachment: false,
    allow_no_incident: true,
    estimated_minutes: 45,
    blocked_at: task.blocked_at,
    blocker_reason: task.blocker_reason,
    blocker_owner_member_id: task.blocked_at ? task.assignee_member_id : null,
    current_submission_id: submissions[0]?.id ?? null,
    version: task.version,
    checklist,
    submissions,
    events: createEvents(task),
    permissions: {
      is_assignee: task.assignee_member_id === context.member_id,
      can_review: task.reviewer_member_id === context.member_id && task.status === 'in_review',
      can_manage: context.role === 'admin' || context.role === 'manager',
    },
  };
}

export function createDemoWorkspaceData(serverNow = new Date().toISOString()) {
  const context = createDemoOrganizationContext(serverNow);
  return {
    source: 'demo' as const,
    context,
    members: demoMembers,
    sellers: demoSellers,
    tasks: createDemoTasks(context),
  };
}
