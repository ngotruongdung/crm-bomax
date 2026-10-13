import { z } from 'zod';

export const notificationKindSchema = z.enum([
  'task_assigned',
  'task_unacknowledged',
  'task_due_soon',
  'task_overdue',
  'task_blocked',
  'task_review_requested',
  'request_result',
  'report_ready',
  'digest',
  'system',
]);
export type NotificationKind = z.infer<typeof notificationKindSchema>;

export const notificationTargetTypeSchema = z.enum(['task', 'request', 'report', 'system']);
export type NotificationTargetType = z.infer<typeof notificationTargetTypeSchema>;

export const notificationSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  recipient_member_id: z.string().uuid(),
  kind: notificationKindSchema,
  title: z.string().min(1).max(180),
  body: z.string().min(1).max(500),
  target_type: notificationTargetTypeSchema,
  target_id: z.string().uuid().nullable(),
  safe_payload: z.record(z.string(), z.unknown()),
  created_at: z.string().datetime({ offset: true }),
  read_at: z.string().datetime({ offset: true }).nullable(),
  expires_at: z.string().datetime({ offset: true }).nullable(),
});
export type Notification = z.infer<typeof notificationSchema>;

export const notificationListSchema = z.array(notificationSchema);

export const markNotificationReadCommandSchema = z.object({
  organization_id: z.string().uuid(),
  notification_id: z.string().uuid(),
});

export const markAllNotificationsReadCommandSchema = z.object({
  organization_id: z.string().uuid(),
  cutoff: z.string().datetime({ offset: true }),
});

export const snoozeReminderCommandSchema = z.object({
  task_id: z.string().uuid(),
  rule_key: z.string().trim().min(1).max(80),
  until: z.string().datetime({ offset: true }),
  expected_version: z.number().int().nonnegative(),
  idempotency_key: z.string().trim().min(8).max(240),
});

export const pushRegistrationRequestSchema = z.object({
  organization_id: z.string().uuid(),
  device_id: z.string().uuid(),
  provider: z.enum(['expo', 'webpush']),
  token: z.string().trim().min(16).max(4096),
});

export const pushRegistrationResponseSchema = z.object({
  endpoint_id: z.string().uuid(),
  registered_at: z.string().datetime({ offset: true }),
});
