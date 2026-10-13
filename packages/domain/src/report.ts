export type ReportTaskFact = {
  task_id: string;
  seller_id: string | null;
  assignee_member_id: string;
  status: 'todo' | 'in_progress' | 'in_review' | 'done' | 'canceled' | 'waived';
  due_at: string;
  completed_at: string | null;
  blocked: boolean;
};

export type ReportCounts = {
  due_count: number;
  done_count: number;
  review_count: number;
  open_count: number;
  blocked_count: number;
};

export type ReportTaskBucket =
  | 'due_done'
  | 'due_review'
  | 'due_open'
  | 'overdue_previous_days'
  | 'due_after_cutoff'
  | 'canceled_or_waived'
  | 'outside';

function localDate(value: string, timeZone: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(value));
}

export function classifyReportTask(
  task: ReportTaskFact,
  input: { reportDate: string; cutoffAt: string; timeZone: string },
): ReportTaskBucket {
  const dueDate = localDate(task.due_at, input.timeZone);
  const dueAt = new Date(task.due_at).valueOf();
  const cutoffAt = new Date(input.cutoffAt).valueOf();

  if (task.status === 'canceled' || task.status === 'waived') {
    return dueDate === input.reportDate ? 'canceled_or_waived' : 'outside';
  }

  if (dueDate < input.reportDate && ['todo', 'in_progress', 'in_review'].includes(task.status)) {
    return 'overdue_previous_days';
  }

  if (dueDate !== input.reportDate) return 'outside';
  if (dueAt > cutoffAt) return 'due_after_cutoff';
  if (task.status === 'done') return 'due_done';
  if (task.status === 'in_review') return 'due_review';
  if (task.status === 'todo' || task.status === 'in_progress') return 'due_open';
  return 'outside';
}

export function reportCountsForTasks(
  tasks: ReportTaskFact[],
  input: { reportDate: string; cutoffAt: string; timeZone: string },
): ReportCounts {
  const counts: ReportCounts = {
    due_count: 0,
    done_count: 0,
    review_count: 0,
    open_count: 0,
    blocked_count: 0,
  };

  for (const task of tasks) {
    const bucket = classifyReportTask(task, input);
    if (bucket === 'due_done') counts.done_count += 1;
    if (bucket === 'due_review') counts.review_count += 1;
    if (bucket === 'due_open') {
      counts.open_count += 1;
      if (task.blocked) counts.blocked_count += 1;
    }
  }
  counts.due_count = counts.done_count + counts.review_count + counts.open_count;
  return counts;
}

export function reportTaskVisibleToRecipient(input: {
  task: Pick<ReportTaskFact, 'seller_id' | 'assignee_member_id'>;
  recipientMemberId: string;
  role: 'admin' | 'manager' | 'employee';
  sellerIds: string[];
}) {
  if (input.role === 'admin') return true;
  if (input.role === 'employee') return input.task.assignee_member_id === input.recipientMemberId;
  if (input.sellerIds.length === 0) {
    return input.task.assignee_member_id === input.recipientMemberId;
  }
  return input.task.seller_id !== null && input.sellerIds.includes(input.task.seller_id);
}

export function nextReportRevision(currentVersion: number, reason: string) {
  const normalizedReason = reason.trim();
  if (!Number.isInteger(currentVersion) || currentVersion < 1)
    throw new Error('REPORT_VERSION_INVALID');
  if (normalizedReason.length < 3) throw new Error('REPORT_REVISION_REASON_REQUIRED');
  return { version: currentVersion + 1, reason: normalizedReason };
}
