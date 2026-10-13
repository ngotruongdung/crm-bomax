import { z } from 'zod';

export const timesheetPeriodStatusSchema = z.enum(['open', 'reconciling', 'closed', 'reopened']);
export type TimesheetPeriodStatus = z.infer<typeof timesheetPeriodStatusSchema>;

export const timesheetDayStateSchema = z.enum(['ready', 'provisional', 'needs_review']);
export type TimesheetDayState = z.infer<typeof timesheetDayStateSchema>;

export const timesheetExceptionSchema = z.object({
  code: z.string().min(1),
  blocking: z.boolean(),
  seconds: z.number().nonnegative().nullable(),
});
export type TimesheetException = z.infer<typeof timesheetExceptionSchema>;

export const timesheetDaySchema = z.object({
  work_date: z.string().date(),
  shift_label: z.string(),
  allowed_mode: z.enum(['office', 'remote', 'hybrid']),
  first_check_in_at: z.string().datetime({ offset: true }).nullable(),
  last_check_out_at: z.string().datetime({ offset: true }).nullable(),
  state: timesheetDayStateSchema,
  scheduled_seconds: z.number().nonnegative(),
  worked_seconds: z.number().nonnegative(),
  worked_office_seconds: z.number().nonnegative(),
  worked_remote_seconds: z.number().nonnegative(),
  paid_leave_seconds: z.number().nonnegative(),
  unpaid_leave_seconds: z.number().nonnegative(),
  unknown_seconds: z.number().nonnegative(),
  unexplained_seconds: z.number().nonnegative(),
  outside_schedule_seconds: z.number().nonnegative(),
  conflict_seconds: z.number().nonnegative(),
  scheduled_units: z.number().nonnegative(),
  worked_units: z.number().nonnegative(),
  paid_leave_units: z.number().nonnegative(),
  unpaid_leave_units: z.number().nonnegative(),
  schedule_snapshot_ref: z.string().min(1),
  policy_snapshot_version: z.number().int().positive(),
  exceptions: z.array(timesheetExceptionSchema),
});
export type TimesheetDay = z.infer<typeof timesheetDaySchema>;

export const timesheetTotalsSchema = z.object({
  scheduled_seconds: z.number().nonnegative(),
  worked_seconds: z.number().nonnegative(),
  worked_office_seconds: z.number().nonnegative(),
  worked_remote_seconds: z.number().nonnegative(),
  paid_leave_seconds: z.number().nonnegative(),
  unpaid_leave_seconds: z.number().nonnegative(),
  unknown_seconds: z.number().nonnegative(),
  unexplained_seconds: z.number().nonnegative(),
  outside_schedule_seconds: z.number().nonnegative(),
  scheduled_units: z.number().nonnegative(),
  worked_units: z.number().nonnegative(),
  paid_leave_units: z.number().nonnegative(),
  unpaid_leave_units: z.number().nonnegative(),
  scheduled_days: z.number().int().nonnegative(),
  requires_reconciliation_days: z.number().int().nonnegative(),
});
export type TimesheetTotals = z.infer<typeof timesheetTotalsSchema>;

export const timesheetViewSchema = z.object({
  organization_id: z.string().uuid(),
  member_id: z.string().uuid(),
  member_name: z.string(),
  employee_code: z.string(),
  month_start: z.string().date(),
  period_id: z.string().uuid().nullable(),
  period_status: timesheetPeriodStatusSchema,
  period_version: z.number().int().positive(),
  revision: z.number().int().positive(),
  source: z.enum(['live', 'snapshot', 'demo_preview']),
  rows: z.array(timesheetDaySchema),
  totals: timesheetTotalsSchema,
});
export type TimesheetView = z.infer<typeof timesheetViewSchema>;

export const timesheetPeriodCommandSchema = z.object({
  organization_id: z.string().uuid(),
  month_start: z.string().date(),
  expected_version: z.number().int().positive(),
  idempotency_key: z.string().trim().min(8).max(240),
});

export const timesheetReopenCommandSchema = z.object({
  organization_id: z.string().uuid(),
  period_id: z.string().uuid(),
  expected_version: z.number().int().positive(),
  reason: z.string().trim().min(3).max(1000),
  idempotency_key: z.string().trim().min(8).max(240),
});
