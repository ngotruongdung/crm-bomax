import type { OrganizationContext, TaskListItem } from '@opsdesk/contracts';
import type { WorkspaceTaskItem } from '../../lib/demo/opsdesk-demo';
import { localDateInTimeZone, localDateTimeToIso } from './task-timezone';

export type TodayGroupId = 'waiting' | 'overdue' | 'new' | 'today' | 'completed';

export type TodayTaskGroups = Record<TodayGroupId, WorkspaceTaskItem[]>;

export type MyTasksTabId = 'assigned' | 'collaborating' | 'review' | 'created';

export type TaskListFilters = {
  assignee: string;
  due: '' | 'today' | 'next7' | 'overdue';
  group: 'none' | 'status' | 'seller' | 'assignee' | 'due' | 'priority';
  month: string;
  priority: '' | TaskListItem['priority'];
  query: string;
  reviewer: string;
  saved: 'all' | 'unacknowledged' | 'due_soon' | 'overdue' | 'review' | 'blocked';
  seller: string;
  sort: 'default' | 'due_asc' | 'due_desc' | 'priority';
  status: '' | TaskListItem['status'];
  view: 'list' | 'board' | 'calendar';
};

const terminalStatuses = new Set<TaskListItem['status']>(['done', 'canceled', 'waived']);
const priorityOrder: Record<TaskListItem['priority'], number> = {
  urgent: 0,
  high: 1,
  normal: 2,
  low: 3,
};

function sortTodayTasks(tasks: WorkspaceTaskItem[]) {
  return [...tasks].sort((left, right) => {
    const byPriority = priorityOrder[left.priority] - priorityOrder[right.priority];
    if (byPriority !== 0) return byPriority;
    const byDue = new Date(left.due_at).getTime() - new Date(right.due_at).getTime();
    if (byDue !== 0) return byDue;
    return (
      new Date(left.assigned_at ?? left.due_at).getTime() -
      new Date(right.assigned_at ?? right.due_at).getTime()
    );
  });
}

function visibleByNow(task: WorkspaceTaskItem, nowMs: number) {
  const assignedAt = task.assigned_at ? new Date(task.assigned_at).getTime() : nowMs;
  const visibleFrom = task.visible_from ? new Date(task.visible_from).getTime() : assignedAt;
  return assignedAt <= nowMs && visibleFrom <= nowMs;
}

function isCurrentUserActionable(task: WorkspaceTaskItem, context: OrganizationContext) {
  return task.assignee_member_id === context.member_id && !terminalStatuses.has(task.status);
}

export function groupTodayTasks(
  tasks: WorkspaceTaskItem[],
  context: OrganizationContext,
): TodayTaskGroups {
  const today = localDateInTimeZone(context.server_now, context.timezone);
  const nowMs = new Date(context.server_now).getTime();
  const startTodayMs = new Date(localDateTimeToIso(`${today}T00:00`, context.timezone)).getTime();
  const groups: TodayTaskGroups = {
    waiting: [],
    overdue: [],
    new: [],
    today: [],
    completed: [],
  };
  const grouped = new Set<string>();

  const add = (group: TodayGroupId, task: WorkspaceTaskItem) => {
    if (grouped.has(task.id)) return;
    grouped.add(task.id);
    groups[group].push(task);
  };

  for (const task of tasks) {
    if (task.status === 'in_review' || Boolean(task.blocked_at)) add('waiting', task);
  }
  for (const task of tasks) {
    if (isCurrentUserActionable(task, context) && new Date(task.due_at).getTime() < startTodayMs) {
      add('overdue', task);
    }
  }
  for (const task of tasks) {
    const visibleToday =
      task.planned_date === today ||
      (!task.planned_date && task.visible_from
        ? localDateInTimeZone(task.visible_from, context.timezone) === today
        : false);
    if (
      task.assignee_member_id === context.member_id &&
      task.status === 'todo' &&
      !task.acknowledged_at &&
      visibleByNow(task, nowMs) &&
      visibleToday
    ) {
      add('new', task);
    }
  }
  for (const task of tasks) {
    const dueToday = localDateInTimeZone(task.due_at, context.timezone) === today;
    if (
      isCurrentUserActionable(task, context) &&
      (task.planned_date === today || dueToday || task.status === 'in_progress')
    ) {
      add('today', task);
    }
  }
  for (const task of tasks) {
    if (
      task.assignee_member_id === context.member_id &&
      task.status === 'done' &&
      task.completed_at &&
      localDateInTimeZone(task.completed_at, context.timezone) === today
    ) {
      add('completed', task);
    }
  }

  return {
    waiting: sortTodayTasks(groups.waiting),
    overdue: sortTodayTasks(groups.overdue),
    new: sortTodayTasks(groups.new),
    today: sortTodayTasks(groups.today),
    completed: sortTodayTasks(groups.completed),
  };
}

export function projectMyTasks(tasks: WorkspaceTaskItem[], context: OrganizationContext) {
  const currentMemberId = context.member_id;
  return {
    assigned: tasks.filter((task) => task.assignee_member_id === currentMemberId),
    collaborating: tasks.filter((task) => task.participant_member_ids?.includes(currentMemberId)),
    review: tasks.filter((task) => task.reviewer_member_id === currentMemberId),
    created:
      context.role === 'employee'
        ? []
        : tasks.filter((task) => task.created_by_member_id === currentMemberId),
  } satisfies Record<MyTasksTabId, WorkspaceTaskItem[]>;
}

export function overviewMetrics(tasks: WorkspaceTaskItem[], context: OrganizationContext) {
  const today = localDateInTimeZone(context.server_now, context.timezone);
  const nowMs = new Date(context.server_now).getTime();
  return {
    dueToday: tasks.filter(
      (task) =>
        !terminalStatuses.has(task.status) &&
        localDateInTimeZone(task.due_at, context.timezone) === today,
    ).length,
    unacknowledged: tasks.filter((task) => task.status === 'todo' && !task.acknowledged_at).length,
    needsAttention: tasks.filter((task) => task.status === 'in_review' || Boolean(task.blocked_at))
      .length,
    overdue: tasks.filter(
      (task) => !terminalStatuses.has(task.status) && new Date(task.due_at).getTime() < nowMs,
    ).length,
  };
}

export type OverviewSellerSummary = {
  sellerId: string;
  sellerName: string;
  active: number;
  dueToday: number;
  needsAttention: number;
  overdue: number;
};

export function overviewAttentionTasks(tasks: WorkspaceTaskItem[], context: OrganizationContext) {
  const nowMs = new Date(context.server_now).getTime();
  const attentionRank = (task: WorkspaceTaskItem) => {
    if (task.blocked_at) return 0;
    if (task.status === 'in_review') return 1;
    return 2;
  };

  return tasks
    .filter(
      (task) =>
        !terminalStatuses.has(task.status) &&
        (Boolean(task.blocked_at) ||
          task.status === 'in_review' ||
          new Date(task.due_at).getTime() < nowMs),
    )
    .sort((left, right) => {
      const byAttention = attentionRank(left) - attentionRank(right);
      if (byAttention !== 0) return byAttention;
      const byPriority = priorityOrder[left.priority] - priorityOrder[right.priority];
      if (byPriority !== 0) return byPriority;
      return new Date(left.due_at).getTime() - new Date(right.due_at).getTime();
    });
}

export function overviewSellerSummary(
  tasks: WorkspaceTaskItem[],
  context: OrganizationContext,
): OverviewSellerSummary[] {
  const today = localDateInTimeZone(context.server_now, context.timezone);
  const nowMs = new Date(context.server_now).getTime();
  const grouped = new Map<string, OverviewSellerSummary>();

  for (const task of tasks) {
    if (!task.seller_id || !task.seller_name) continue;
    const row = grouped.get(task.seller_id) ?? {
      sellerId: task.seller_id,
      sellerName: task.seller_name,
      active: 0,
      dueToday: 0,
      needsAttention: 0,
      overdue: 0,
    };
    const isTerminal = terminalStatuses.has(task.status);
    if (!isTerminal) row.active += 1;
    if (!isTerminal && localDateInTimeZone(task.due_at, context.timezone) === today) {
      row.dueToday += 1;
    }
    if (!isTerminal && (task.status === 'in_review' || Boolean(task.blocked_at))) {
      row.needsAttention += 1;
    }
    if (!isTerminal && new Date(task.due_at).getTime() < nowMs) {
      row.overdue += 1;
    }
    grouped.set(task.seller_id, row);
  }

  return [...grouped.values()].sort((left, right) => {
    const byAttention = right.needsAttention + right.overdue - (left.needsAttention + left.overdue);
    if (byAttention !== 0) return byAttention;
    const byActive = right.active - left.active;
    if (byActive !== 0) return byActive;
    return left.sellerName.localeCompare(right.sellerName, 'vi');
  });
}

export function parseTaskListFilters(
  input: Record<string, string | string[] | undefined> = {},
): TaskListFilters {
  const one = (value: string | string[] | undefined) =>
    typeof value === 'string' ? value : (value?.[0] ?? '');
  const savedValues: TaskListFilters['saved'][] = [
    'all',
    'unacknowledged',
    'due_soon',
    'overdue',
    'review',
    'blocked',
  ];
  const dueValues: TaskListFilters['due'][] = ['', 'today', 'next7', 'overdue'];
  const groupValues: TaskListFilters['group'][] = [
    'none',
    'status',
    'seller',
    'assignee',
    'due',
    'priority',
  ];
  const priorityValues: TaskListFilters['priority'][] = ['', 'low', 'normal', 'high', 'urgent'];
  const sortValues: TaskListFilters['sort'][] = ['default', 'due_asc', 'due_desc', 'priority'];
  const statusValues: TaskListFilters['status'][] = [
    '',
    'todo',
    'in_progress',
    'in_review',
    'done',
    'canceled',
    'waived',
  ];
  const viewValues: TaskListFilters['view'][] = ['list', 'board', 'calendar'];
  const legacySaved = one(input.view) as TaskListFilters['saved'];
  const saved = one(input.saved) as TaskListFilters['saved'];
  const due = one(input.due) as TaskListFilters['due'];
  const group = one(input.group) as TaskListFilters['group'];
  const month = one(input.month);
  const priority = one(input.priority) as TaskListFilters['priority'];
  const sort = one(input.sort) as TaskListFilters['sort'];
  const status = one(input.status) as TaskListFilters['status'];
  const view = one(input.view) as TaskListFilters['view'];
  return {
    query: one(input.q),
    seller: one(input.seller),
    assignee: one(input.assignee),
    reviewer: one(input.reviewer),
    saved: savedValues.includes(saved)
      ? saved
      : savedValues.includes(legacySaved)
        ? legacySaved
        : 'all',
    due: dueValues.includes(due) ? due : '',
    group: groupValues.includes(group) ? group : 'none',
    month: /^\d{4}-(0[1-9]|1[0-2])$/.test(month) ? month : '',
    priority: priorityValues.includes(priority) ? priority : '',
    sort: sortValues.includes(sort) ? sort : 'default',
    status: statusValues.includes(status) ? status : '',
    view: viewValues.includes(view) ? view : 'list',
  };
}

export function serializeTaskListFilters(filters: TaskListFilters) {
  const params = new URLSearchParams();
  if (filters.query.trim()) params.set('q', filters.query.trim());
  if (filters.seller) params.set('seller', filters.seller);
  if (filters.assignee) params.set('assignee', filters.assignee);
  if (filters.reviewer) params.set('reviewer', filters.reviewer);
  if (filters.saved !== 'all') params.set('saved', filters.saved);
  if (filters.due) params.set('due', filters.due);
  if (filters.group !== 'none') params.set('group', filters.group);
  if (filters.month) params.set('month', filters.month);
  if (filters.priority) params.set('priority', filters.priority);
  if (filters.sort !== 'default') params.set('sort', filters.sort);
  if (filters.status) params.set('status', filters.status);
  if (filters.view !== 'list') params.set('view', filters.view);
  return params.toString();
}
