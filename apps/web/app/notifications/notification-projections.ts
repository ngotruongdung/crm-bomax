import type { Notification } from '@opsdesk/contracts';

export const notificationTabs = [
  { id: 'all', label: 'Tất cả' },
  { id: 'unread', label: 'Chưa đọc' },
  { id: 'tasks', label: 'Công việc' },
  { id: 'hr', label: 'Nhân sự' },
  { id: 'reports', label: 'Báo cáo' },
] as const;

export type NotificationInboxTab = (typeof notificationTabs)[number]['id'];

const actionInboxKinds = new Set<Notification['kind']>([
  'task_assigned',
  'task_unacknowledged',
  'task_due_soon',
  'task_overdue',
  'task_blocked',
  'task_review_requested',
  'request_result',
  'report_ready',
]);

export function parseNotificationInboxTab(value: string | null | undefined): NotificationInboxTab {
  return notificationTabs.some((tab) => tab.id === value) ? (value as NotificationInboxTab) : 'all';
}

export function isActionInboxItem(item: Notification) {
  return actionInboxKinds.has(item.kind) && item.target_type !== 'system';
}
