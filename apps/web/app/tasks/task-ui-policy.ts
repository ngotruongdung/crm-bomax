import {
  extractTaskErrorCode,
  taskCreateDraftSchema,
  taskErrorMessage,
  taskMutationResultSchema,
  type TaskCreateDraft,
  type TaskDetail,
} from '@opsdesk/contracts';

export type TaskFieldErrors = Record<string, string>;

export type TaskCreateValidationResult =
  | { ok: true; data: TaskCreateDraft }
  | { ok: false; errors: TaskFieldErrors; firstInvalidField: string | null };

export function validateTaskCreateDraft(draft: unknown): TaskCreateValidationResult {
  const parsed = taskCreateDraftSchema.safeParse(draft);
  if (parsed.success) return { ok: true, data: parsed.data };

  const errors: TaskFieldErrors = {};
  for (const issue of parsed.error.issues) {
    const path = issue.path.join('.');
    if (path && !errors[path]) errors[path] = issue.message;
  }

  return {
    ok: false,
    errors,
    firstInvalidField: Object.keys(errors)[0] ?? null,
  };
}

export function taskCreateMutationId(data: unknown): string | null {
  const result = taskMutationResultSchema.safeParse(data);
  if (!result.success) return null;
  return result.data.task_id ?? result.data.id ?? null;
}

export type TaskMutationGuard = ReturnType<typeof createTaskMutationGuard>;

export function createTaskMutationGuard() {
  let locked = false;
  return {
    tryEnter() {
      if (locked) return false;
      locked = true;
      return true;
    },
    leave() {
      locked = false;
    },
    isLocked() {
      return locked;
    },
  };
}

export function taskMutationErrorState(error: unknown, fallback: string) {
  return {
    message: taskErrorMessage(error, fallback),
    versionConflict: extractTaskErrorCode(error) === 'VERSION_CONFLICT',
  };
}

export function taskDetailUiPolicy(task: TaskDetail) {
  const isTerminal = ['done', 'canceled', 'waived'].includes(task.status);
  const activeAssignee =
    task.permissions.is_assignee && ['todo', 'in_progress'].includes(task.status);
  const blocked = Boolean(task.blocked_at);

  return {
    isTerminal,
    checklistEditable: activeAssignee,
    submitAllowed: activeAssignee,
    showEdit: task.permissions.can_manage && !isTerminal && task.status !== 'in_review',
    showAck: task.permissions.is_assignee && task.status === 'todo' && !task.acknowledged_at,
    showStart: task.permissions.is_assignee && task.status === 'todo',
    showReportBlocker: activeAssignee && !blocked,
    showWithdrawSubmission: task.permissions.is_assignee && task.status === 'in_review',
    showReviewActions: task.permissions.can_review && task.status === 'in_review',
    showBlockerBanner: blocked,
    canResolveBlocker:
      blocked && (task.permissions.is_assignee || task.permissions.can_manage) && !isTerminal,
    showManageActiveActions:
      task.permissions.can_manage && !isTerminal && task.status !== 'in_review',
    showReopen: task.permissions.can_manage && isTerminal,
  };
}

export function taskEvidenceFromText(value: string): Array<{ url: string }> {
  return value
    .split('\n')
    .map((item) => item.trim())
    .filter(Boolean)
    .map((url) => ({ url }));
}

export function taskSubmitPreflight(
  task: TaskDetail,
  input: { resultText: string; evidenceText: string; noIncident: boolean },
): { error: string | null; evidence: Array<{ url: string }> } {
  const evidence = taskEvidenceFromText(input.evidenceText);
  const missingRequired = task.checklist.filter((item) => item.is_required && !item.checked_at);
  if (missingRequired.length > 0) {
    return {
      error: `Còn ${missingRequired.length} mục checklist bắt buộc chưa hoàn tất.`,
      evidence,
    };
  }
  if (
    task.requires_result &&
    !input.resultText.trim() &&
    !(task.allow_no_incident && input.noIncident)
  ) {
    return {
      error: 'Công việc này bắt buộc nhập kết quả hoặc xác nhận không phát sinh.',
      evidence,
    };
  }
  if (task.requires_attachment && evidence.length === 0) {
    return { error: 'Công việc này bắt buộc có ít nhất một bằng chứng.', evidence };
  }
  return { error: null, evidence };
}
