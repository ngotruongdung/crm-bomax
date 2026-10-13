export type Interval = { start: Date; end: Date };

export type ReminderTaskState = {
  status: 'todo' | 'in_progress' | 'in_review' | 'done' | 'canceled' | 'waived';
  assigneeMemberId: string;
  reviewerMemberId: string | null;
  blockerOwnerMemberId: string | null;
  blockedAt: Date | null;
  acknowledgedAt: Date | null;
  dueAt: Date;
};

export type ReminderTarget = {
  recipientMemberId: string;
  ruleKey: 'blocked' | 'reviewer' | 'unack' | 'overdue' | 'due_soon';
} | null;

const MINUTE_MS = 60_000;

function overlapMs(a: Interval, b: Interval) {
  return Math.max(
    0,
    Math.min(a.end.getTime(), b.end.getTime()) - Math.max(a.start.getTime(), b.start.getTime()),
  );
}

export function workingSecondsBetween(
  start: Date,
  end: Date,
  workingIntervals: Interval[],
  approvedLeave: Interval[] = [],
) {
  if (end <= start) return 0;
  const window = { start, end };
  let totalMs = 0;
  for (const interval of workingIntervals) {
    const clippedStart = new Date(Math.max(interval.start.getTime(), start.getTime()));
    const clippedEnd = new Date(Math.min(interval.end.getTime(), end.getTime()));
    if (clippedEnd <= clippedStart) continue;
    let intervalMs = overlapMs({ start: clippedStart, end: clippedEnd }, window);
    for (const leave of approvedLeave) {
      intervalMs -= overlapMs({ start: clippedStart, end: clippedEnd }, leave);
    }
    totalMs += Math.max(0, intervalMs);
  }
  return Math.floor(totalMs / 1000);
}

export function selectReminderTarget(
  task: ReminderTaskState,
  now: Date,
  workingSecondsSinceAssignment: number,
): ReminderTarget {
  if (task.status === 'done' || task.status === 'canceled' || task.status === 'waived') return null;
  if (task.blockedAt && task.blockerOwnerMemberId) {
    return { recipientMemberId: task.blockerOwnerMemberId, ruleKey: 'blocked' };
  }
  if (task.status === 'in_review' && task.reviewerMemberId) {
    return { recipientMemberId: task.reviewerMemberId, ruleKey: 'reviewer' };
  }
  if (!task.acknowledgedAt && workingSecondsSinceAssignment >= 30 * 60) {
    return { recipientMemberId: task.assigneeMemberId, ruleKey: 'unack' };
  }
  if (task.dueAt <= now) return { recipientMemberId: task.assigneeMemberId, ruleKey: 'overdue' };
  if (task.dueAt.getTime() - now.getTime() <= 60 * MINUTE_MS) {
    return { recipientMemberId: task.assigneeMemberId, ruleKey: 'due_soon' };
  }
  return null;
}

export function pushDisposition(input: {
  approvedLeave: boolean;
  dailyPushCount: number;
  dailyPushLimit: number;
  now: Date;
  snoozedUntil?: Date | null;
}) {
  if (input.snoozedUntil && input.snoozedUntil > input.now) return 'snoozed' as const;
  if (input.approvedLeave) return 'inbox_only_leave' as const;
  if (input.dailyPushCount >= input.dailyPushLimit) return 'digest' as const;
  return 'push' as const;
}

export function snoozeReminder<T extends { dueAt: Date }>(task: T, until: Date) {
  return { task, snoozedUntil: until };
}

export function outboxRetryDelaySeconds(attempt: number) {
  if (attempt <= 1) return 60;
  if (attempt === 2) return 5 * 60;
  if (attempt === 3) return 15 * 60;
  return 60 * 60;
}

export function shouldDeadLetter(attempt: number, retryable: boolean) {
  return !retryable || attempt >= 5;
}

export function isPermanentPushEndpointError(code: string) {
  return ['DeviceNotRegistered', 'DEVICE_NOT_REGISTERED', 'INVALID_PUSH_TOKEN'].includes(code);
}

export function logicalDeliveryKey(notificationId: string, endpointId: string) {
  return `${notificationId}:push:${endpointId}`;
}

export function markNotificationRead<T extends { readAt: Date | null }>(
  notification: T,
  at: Date,
): T {
  return { ...notification, readAt: notification.readAt ?? at };
}

export function canAckLease(currentLeaseOwner: string | null, workerId: string) {
  return currentLeaseOwner === workerId;
}

export function safeNotificationPayload(input: {
  kind: string;
  notificationId: string;
  organizationId: string;
  targetId?: string | null;
  targetType: string;
  [key: string]: unknown;
}) {
  return {
    kind: input.kind,
    notification_id: input.notificationId,
    organization_id: input.organizationId,
    target_id: input.targetId ?? null,
    target_type: input.targetType,
  };
}

export const notificationRefreshFallback = {
  realtimeInvalidation: true,
  refreshOnFocus: true,
  pollIntervalMs: 60_000,
} as const;
