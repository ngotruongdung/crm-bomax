import { z } from 'zod';
import { taskStatusSchema } from './task';

export const reportScopeSchema = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('organization') }),
  z.object({ kind: z.literal('sellers'), seller_ids: z.array(z.string().uuid()).min(1) }),
  z.object({ kind: z.literal('personal'), member_id: z.string().uuid() }),
]);
export type ReportScope = z.infer<typeof reportScopeSchema>;

export const reportTaskFactSchema = z.object({
  task_id: z.string().uuid(),
  seller_id: z.string().uuid().nullable(),
  assignee_member_id: z.string().uuid(),
  status: taskStatusSchema,
  due_at: z.string().datetime({ offset: true }),
  completed_at: z.string().datetime({ offset: true }).nullable(),
  blocked: z.boolean(),
});
export type ReportTaskFact = z.infer<typeof reportTaskFactSchema>;

export const reportCountsSchema = z.object({
  due_count: z.number().int().nonnegative(),
  done_count: z.number().int().nonnegative(),
  review_count: z.number().int().nonnegative(),
  open_count: z.number().int().nonnegative(),
  blocked_count: z.number().int().nonnegative(),
});
export type ReportCounts = z.infer<typeof reportCountsSchema>;

export const reportPersonFactSchema = z.object({
  member_id: z.string().uuid(),
  display_name: z.string().min(1),
  counts: reportCountsSchema,
  due_task_ids: z.array(z.string().uuid()),
  overdue_previous_day_task_ids: z.array(z.string().uuid()),
  due_after_cutoff_task_ids: z.array(z.string().uuid()),
  canceled_or_waived_task_ids: z.array(z.string().uuid()),
  availability: z.enum(['working', 'away', 'unknown']),
});

export const reportSnapshotSchema = z.object({
  schema_version: z.literal(1),
  report_date: z.string().date(),
  cutoff_at: z.string().datetime({ offset: true }),
  timezone: z.string().min(1),
  scope: reportScopeSchema,
  totals: reportCountsSchema,
  people: z.array(reportPersonFactSchema),
  warnings: z.array(z.string()),
});
export type ReportSnapshot = z.infer<typeof reportSnapshotSchema>;

export const reportRevisionCommandSchema = z.object({
  organization_id: z.string().uuid(),
  run_id: z.string().uuid(),
  expected_version: z.number().int().positive(),
  reason: z.string().trim().min(3).max(500),
  idempotency_key: z.string().trim().min(8).max(240),
});

export const reportListItemSchema = z.object({
  run_id: z.string().uuid(),
  snapshot_id: z.string().uuid(),
  report_date: z.string().date(),
  cutoff_at: z.string().datetime({ offset: true }),
  generated_at: z.string().datetime({ offset: true }).nullable(),
  timezone: z.string().min(1),
  revision: z.number().int().positive(),
  is_late: z.boolean(),
  scope: reportScopeSchema,
  totals: reportCountsSchema,
  people_count: z.number().int().nonnegative(),
  warnings: z.array(z.string()),
});
export const reportListSchema = z.array(reportListItemSchema);
export type ReportListItem = z.infer<typeof reportListItemSchema>;

export const reportDetailSchema = z.object({
  run_id: z.string().uuid(),
  snapshot_id: z.string().uuid(),
  report_date: z.string().date(),
  cutoff_at: z.string().datetime({ offset: true }),
  generated_at: z.string().datetime({ offset: true }).nullable(),
  timezone: z.string().min(1),
  revision: z.number().int().positive(),
  is_late: z.boolean(),
  revision_reason: z.string().nullable(),
  scope: reportScopeSchema,
  facts: reportSnapshotSchema,
  summary_template: z.string().min(1),
  source_hash: z.string().length(64),
});
export type ReportDetail = z.infer<typeof reportDetailSchema>;
