import { describe, expect, it } from 'vitest';
import {
  canAckLease,
  isPermanentPushEndpointError,
  logicalDeliveryKey,
  markNotificationRead,
  notificationRefreshFallback,
  outboxRetryDelaySeconds,
  pushDisposition,
  safeNotificationPayload,
  selectReminderTarget,
  shouldDeadLetter,
  snoozeReminder,
  workingSecondsBetween,
} from '../src/notification';

const at = (value: string) => new Date(value);

describe('P08 notification policy', () => {
  it('NOTIFY-01 marks the inbox record read without acknowledging a task', () => {
    const task = { acknowledgedAt: null as Date | null };
    const notification = markNotificationRead(
      { readAt: null as Date | null },
      at('2026-10-05T03:00:00Z'),
    );
    expect(notification.readAt?.toISOString()).toBe('2026-10-05T03:00:00.000Z');
    expect(task.acknowledgedAt).toBeNull();
  });

  it('NOTIFY-02 counts only working intervals for unacknowledged reminders', () => {
    const seconds = workingSecondsBetween(at('2026-10-04T11:00:00Z'), at('2026-10-05T02:15:00Z'), [
      { start: at('2026-10-05T02:00:00Z'), end: at('2026-10-05T05:00:00Z') },
    ]);
    expect(seconds).toBe(15 * 60);
  });

  it('NOTIFY-03 suppresses push while assignee is on approved leave but keeps inbox semantics', () => {
    expect(
      pushDisposition({
        approvedLeave: true,
        dailyPushCount: 0,
        dailyPushLimit: 8,
        now: at('2026-10-05T03:00:00Z'),
      }),
    ).toBe('inbox_only_leave');
  });

  it('NOTIFY-04 routes in-review work to the reviewer', () => {
    expect(
      selectReminderTarget(
        {
          status: 'in_review',
          assigneeMemberId: 'employee',
          reviewerMemberId: 'reviewer',
          blockerOwnerMemberId: null,
          blockedAt: null,
          acknowledgedAt: at('2026-10-05T02:00:00Z'),
          dueAt: at('2026-10-05T10:00:00Z'),
        },
        at('2026-10-05T03:00:00Z'),
        3600,
      ),
    ).toEqual({ recipientMemberId: 'reviewer', ruleKey: 'reviewer' });
  });

  it('NOTIFY-05 routes blocked work to the blocker owner before assignee reminders', () => {
    expect(
      selectReminderTarget(
        {
          status: 'in_progress',
          assigneeMemberId: 'employee',
          reviewerMemberId: null,
          blockerOwnerMemberId: 'owner',
          blockedAt: at('2026-10-05T02:30:00Z'),
          acknowledgedAt: null,
          dueAt: at('2026-10-05T04:00:00Z'),
        },
        at('2026-10-05T03:00:00Z'),
        3600,
      ),
    ).toEqual({ recipientMemberId: 'owner', ruleKey: 'blocked' });
  });

  it('NOTIFY-06 switches to digest after the daily push limit', () => {
    expect(
      pushDisposition({
        approvedLeave: false,
        dailyPushCount: 8,
        dailyPushLimit: 8,
        now: at('2026-10-05T03:00:00Z'),
      }),
    ).toBe('digest');
  });

  it('NOTIFY-07 snooze never changes task deadline', () => {
    const dueAt = at('2026-10-05T10:00:00Z');
    const result = snoozeReminder({ dueAt }, at('2026-10-05T04:00:00Z'));
    expect(result.task.dueAt).toBe(dueAt);
    expect(result.snoozedUntil.toISOString()).toBe('2026-10-05T04:00:00.000Z');
  });

  it('NOTIFY-08 keeps one logical delivery key across provider retries', () => {
    expect(logicalDeliveryKey('notification', 'endpoint')).toBe('notification:push:endpoint');
    expect(outboxRetryDelaySeconds(1)).toBe(60);
    expect(outboxRetryDelaySeconds(4)).toBe(3600);
    expect(shouldDeadLetter(5, true)).toBe(true);
  });

  it('NOTIFY-09 treats invalid push tokens as permanent endpoint failures', () => {
    expect(isPermanentPushEndpointError('DeviceNotRegistered')).toBe(true);
    expect(isPermanentPushEndpointError('NETWORK_TIMEOUT')).toBe(false);
    expect(shouldDeadLetter(1, false)).toBe(true);
  });

  it('NOTIFY-10 reduces realtime/push payloads to identifiers only', () => {
    expect(
      safeNotificationPayload({
        kind: 'request_result',
        notificationId: 'n1',
        organizationId: 'o1',
        targetId: 'r1',
        targetType: 'request',
        privateReason: 'must-not-leak',
      }),
    ).toEqual({
      kind: 'request_result',
      notification_id: 'n1',
      organization_id: 'o1',
      target_id: 'r1',
      target_type: 'request',
    });
  });

  it('NOTIFY-11 keeps focus and polling fallbacks when realtime disconnects', () => {
    expect(notificationRefreshFallback).toEqual({
      realtimeInvalidation: true,
      refreshOnFocus: true,
      pollIntervalMs: 60_000,
    });
  });

  it('SEC-13 rejects stale worker acknowledgements after a lease changes owner', () => {
    expect(canAckLease('worker-b', 'worker-a')).toBe(false);
    expect(canAckLease('worker-b', 'worker-b')).toBe(true);
  });
});
