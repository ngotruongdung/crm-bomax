import { z } from 'zod';

export const taskStatusSchema = z.enum([
  'todo',
  'in_progress',
  'in_review',
  'done',
  'canceled',
  'waived',
]);
export type TaskStatus = z.infer<typeof taskStatusSchema>;

export const taskPrioritySchema = z.enum(['low', 'normal', 'high', 'urgent']);
export type TaskPriority = z.infer<typeof taskPrioritySchema>;

const nullableUuidSchema = z.string().uuid().nullable();
const nullableDateTimeSchema = z.string().datetime({ offset: true }).nullable();
const taskNumberSchema = z.union([
  z.string().trim().min(1),
  z
    .number()
    .int()
    .positive()
    .transform((value) => String(value)),
]);

export const taskChecklistItemSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  sort_order: z.number().int(),
  is_required: z.boolean(),
  checked_at: nullableDateTimeSchema,
  checked_by_member_id: nullableUuidSchema,
});
export type TaskChecklistItem = z.infer<typeof taskChecklistItemSchema>;

export const taskSubmissionSchema = z.object({
  id: z.string().uuid(),
  revision: z.number().int().positive(),
  submitted_by_member_id: z.string().uuid(),
  result_text: z.string().nullable(),
  no_incident: z.boolean(),
  evidence: z.unknown(),
  review_state: z.string(),
  reviewed_by_member_id: nullableUuidSchema,
  reviewed_at: nullableDateTimeSchema,
  review_reason: z.string().nullable(),
  revision_due_at: nullableDateTimeSchema,
  submitted_at: z.string().datetime({ offset: true }),
});
export type TaskSubmission = z.infer<typeof taskSubmissionSchema>;

export const taskEventSchema = z.object({
  id: z.string().uuid(),
  task_version: z.number().int().nonnegative(),
  event_type: z.string(),
  actor_member_id: nullableUuidSchema,
  actor_name: z.string().nullable(),
  event_payload: z.unknown(),
  occurred_at: z.string().datetime({ offset: true }),
});
export type TaskEvent = z.infer<typeof taskEventSchema>;

export const taskPermissionsSchema = z.object({
  is_assignee: z.boolean(),
  can_review: z.boolean(),
  can_manage: z.boolean(),
});
export type TaskPermissions = z.infer<typeof taskPermissionsSchema>;

export const taskListItemSchema = z.object({
  id: z.string().uuid(),
  task_number: taskNumberSchema,
  title: z.string(),
  description: z.string().nullable(),
  seller_id: nullableUuidSchema,
  seller_name: z.string().nullable(),
  assignee_member_id: z.string().uuid(),
  assignee_name: z.string(),
  reviewer_member_id: nullableUuidSchema,
  reviewer_name: z.string().nullable(),
  priority: taskPrioritySchema,
  status: taskStatusSchema,
  planned_date: z.string().date(),
  original_due_at: z.string().datetime({ offset: true }),
  due_at: z.string().datetime({ offset: true }),
  acknowledged_at: nullableDateTimeSchema,
  blocked_at: nullableDateTimeSchema,
  blocker_reason: z.string().nullable(),
  requires_review: z.boolean(),
  version: z.number().int().positive(),
  checklist_total: z.number().int().nonnegative(),
  checklist_checked: z.number().int().nonnegative(),
});
export type TaskListItem = z.infer<typeof taskListItemSchema>;
export const taskListSchema = z.array(taskListItemSchema);

export const taskDetailSchema = z.object({
  id: z.string().uuid(),
  task_number: taskNumberSchema,
  batch_id: nullableUuidSchema.optional(),
  title: z.string(),
  description: z.string().nullable(),
  seller_id: nullableUuidSchema,
  seller_name: z.string().nullable(),
  assignee_member_id: z.string().uuid(),
  assignee_name: z.string(),
  created_by_member_id: z.string().uuid(),
  created_by_name: z.string(),
  reviewer_member_id: nullableUuidSchema,
  reviewer_name: z.string().nullable(),
  priority: taskPrioritySchema,
  status: taskStatusSchema,
  planned_date: z.string().date(),
  original_due_at: z.string().datetime({ offset: true }),
  due_at: z.string().datetime({ offset: true }),
  assigned_at: z.string().datetime({ offset: true }),
  visible_from: nullableDateTimeSchema,
  acknowledged_at: nullableDateTimeSchema,
  started_at: nullableDateTimeSchema,
  submitted_at: nullableDateTimeSchema,
  completed_at: nullableDateTimeSchema,
  requires_review: z.boolean(),
  requires_result: z.boolean(),
  requires_attachment: z.boolean(),
  allow_no_incident: z.boolean(),
  estimated_minutes: z.number().int().positive().nullable().optional(),
  blocked_at: nullableDateTimeSchema,
  blocker_reason: z.string().nullable(),
  blocker_owner_member_id: nullableUuidSchema,
  current_submission_id: nullableUuidSchema,
  version: z.number().int().positive(),
  checklist: z.array(taskChecklistItemSchema),
  submissions: z.array(taskSubmissionSchema),
  events: z.array(taskEventSchema),
  permissions: taskPermissionsSchema,
});
export type TaskDetail = z.infer<typeof taskDetailSchema>;

export const taskChecklistDraftSchema = z.object({
  title: z.string().trim().min(1, 'Nhập nội dung checklist.'),
  sort_order: z.number().int().nonnegative(),
  is_required: z.boolean().default(true),
});

export const taskCreateDraftSchema = z
  .object({
    assignee_member_id: z.string().uuid('Chọn người thực hiện.'),
    reviewer_member_id: z.string().uuid().nullable().optional(),
    seller_id: z.string().uuid().nullable().optional(),
    title: z.string().trim().min(1, 'Nhập tên công việc.').max(240),
    description: z.string().trim().max(4000).nullable().optional(),
    priority: taskPrioritySchema.default('normal'),
    planned_date: z.string().date('Chọn ngày thực hiện.'),
    due_at: z.string().datetime({ offset: true }),
    visible_from: z.string().datetime({ offset: true }).nullable().optional(),
    requires_review: z.boolean().default(false),
    requires_result: z.boolean().default(true),
    requires_attachment: z.boolean().default(false),
    allow_no_incident: z.boolean().default(false),
    estimated_minutes: z.number().int().positive().nullable().optional(),
    checklist: z.array(taskChecklistDraftSchema).default([]),
    participant_member_ids: z.array(z.string().uuid()).default([]),
  })
  .superRefine((value, context) => {
    if (value.requires_review && !value.reviewer_member_id) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Chọn người duyệt.',
        path: ['reviewer_member_id'],
      });
    }
    if (value.reviewer_member_id && value.reviewer_member_id === value.assignee_member_id) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Người duyệt phải khác người thực hiện.',
        path: ['reviewer_member_id'],
      });
    }
    if (new Date(value.due_at).getTime() < new Date(`${value.planned_date}T00:00:00Z`).getTime()) {
      context.addIssue({
        code: z.ZodIssueCode.custom,
        message: 'Hạn hoàn thành không thể trước ngày thực hiện.',
        path: ['due_at'],
      });
    }
  });
export type TaskCreateDraft = z.infer<typeof taskCreateDraftSchema>;

export const taskCommandActionSchema = z.enum([
  'ack',
  'start',
  'checklist',
  'submit',
  'withdraw_submission',
  'approve',
  'request_changes',
  'report_blocker',
  'resolve_blocker',
  'reassign',
  'change_deadline',
  'cancel',
  'waive',
  'reopen',
]);
export type TaskCommandAction = z.infer<typeof taskCommandActionSchema>;

export const taskMutationResultSchema = z
  .object({
    task_id: z.string().uuid().optional(),
    id: z.string().uuid().optional(),
    version: z.number().int().positive().optional(),
    status: taskStatusSchema.optional(),
  })
  .passthrough();
export type TaskMutationResult = z.infer<typeof taskMutationResultSchema>;

export const taskBatchResultSchema = z
  .object({
    batch_id: z.string().uuid().optional(),
    created_count: z.number().int().nonnegative().optional(),
    skipped_count: z.number().int().nonnegative().optional(),
    results: z.array(z.unknown()).optional(),
  })
  .passthrough();

const taskErrorMessages: Record<string, string> = {
  VERSION_CONFLICT: 'Dữ liệu vừa thay đổi. Hãy tải phiên bản mới trước khi thử lại.',
  TASK_REQUIRED_FIELDS_MISSING: 'Vui lòng nhập đủ thông tin bắt buộc.',
  TASK_REVIEWER_REQUIRED: 'Công việc cần duyệt phải có người duyệt.',
  TASK_REVIEWER_CANNOT_BE_ASSIGNEE: 'Người duyệt phải khác người thực hiện.',
  TASK_REVIEWER_ROLE_DENIED: 'Người duyệt phải là quản lý hoặc admin trong phạm vi được phép.',
  TASK_ASSIGNMENT_SCOPE_DENIED: 'Bạn không thể giao công việc cho phạm vi seller này.',
  INTERNAL_TASK_REVIEW_ASSIGNMENT_DENIED: 'Phân công công việc nội bộ này không hợp lệ.',
  TASK_ACCESS_DENIED: 'Bạn không có quyền truy cập công việc này.',
  TASK_ACK_NOT_ALLOWED: 'Không thể xác nhận công việc ở trạng thái hiện tại.',
  TASK_START_NOT_ALLOWED: 'Không thể bắt đầu công việc ở trạng thái hiện tại.',
  TASK_CHECKLIST_NOT_EDITABLE: 'Checklist đang bị khóa ở trạng thái hiện tại.',
  TASK_REQUIRED_CHECKLIST_INCOMPLETE: 'Hãy hoàn tất toàn bộ checklist bắt buộc trước khi nộp.',
  TASK_RESULT_REQUIRED: 'Công việc này yêu cầu nhập kết quả.',
  TASK_EVIDENCE_REQUIRED: 'Công việc này yêu cầu bằng chứng trước khi nộp.',
  TASK_SELF_APPROVAL_DENIED: 'Người thực hiện không thể tự duyệt công việc của mình.',
  TASK_REVIEW_DENIED: 'Bạn không có quyền duyệt công việc này.',
  TASK_CHANGE_REASON_REQUIRED: 'Vui lòng nhập lý do yêu cầu chỉnh sửa.',
  TASK_BLOCKER_REASON_REQUIRED: 'Vui lòng nhập lý do đang bị chặn.',
  TASK_REASSIGN_REASON_REQUIRED: 'Vui lòng nhập lý do đổi người thực hiện.',
  TASK_DEADLINE_CHANGE_REASON_REQUIRED: 'Vui lòng nhập lý do đổi hạn.',
  TASK_CANCEL_REASON_REQUIRED: 'Vui lòng nhập lý do hủy công việc.',
  TASK_WAIVE_REASON_REQUIRED: 'Vui lòng nhập lý do miễn công việc.',
  TASK_REOPEN_REASON_REQUIRED: 'Vui lòng nhập lý do mở lại công việc.',
  IDEMPOTENCY_KEY_REUSED: 'Nội dung đã thay đổi sau lần gửi trước. Hãy thử gửi lại.',
};

export function extractTaskErrorCode(error: unknown): string | null {
  if (!error) return null;
  if (typeof error === 'string') {
    const match = error.match(/[A-Z][A-Z0-9_]{3,}/);
    return match?.[0] ?? null;
  }
  if (typeof error === 'object') {
    const candidate = error as { code?: unknown; message?: unknown; error?: unknown };
    if (typeof candidate.code === 'string' && candidate.code.includes('TASK_'))
      return candidate.code;
    if (candidate.code === 'VERSION_CONFLICT' || candidate.code === 'IDEMPOTENCY_KEY_REUSED') {
      return candidate.code;
    }
    return extractTaskErrorCode(candidate.error) ?? extractTaskErrorCode(candidate.message);
  }
  return null;
}

export function taskErrorMessage(error: unknown, fallback = 'Không thể thực hiện thao tác.') {
  const code = extractTaskErrorCode(error);
  return code ? (taskErrorMessages[code] ?? fallback) : fallback;
}
