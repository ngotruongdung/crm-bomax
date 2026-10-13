import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import type { TaskDetail } from '@opsdesk/contracts';
import {
  createTaskMutationGuard,
  taskCreateMutationId,
  taskDetailUiPolicy,
  taskMutationErrorState,
  taskSubmitPreflight,
  validateTaskCreateDraft,
} from '../app/tasks/task-ui-policy';

const ids = {
  task: '83000000-0000-0000-0000-000000000001',
  assignee: '63000000-0000-0000-0000-000000000003',
  creator: '63000000-0000-0000-0000-000000000001',
  reviewer: '63000000-0000-0000-0000-000000000002',
  seller: '73000000-0000-0000-0000-000000000001',
  checklist: '93000000-0000-0000-0000-000000000001',
};

function makeTask(patch: Partial<TaskDetail> = {}): TaskDetail {
  return {
    id: ids.task,
    task_number: 'TASK-0001',
    batch_id: null,
    title: 'Kiểm tra tồn kho',
    description: null,
    seller_id: ids.seller,
    seller_name: 'Seller A',
    assignee_member_id: ids.assignee,
    assignee_name: 'Nhân viên A',
    created_by_member_id: ids.creator,
    created_by_name: 'Admin A',
    reviewer_member_id: ids.reviewer,
    reviewer_name: 'Manager A',
    priority: 'normal',
    status: 'todo',
    planned_date: '2026-10-04',
    original_due_at: '2026-10-04T11:00:00.000Z',
    due_at: '2026-10-04T11:00:00.000Z',
    assigned_at: '2026-10-04T01:00:00.000Z',
    visible_from: null,
    acknowledged_at: null,
    started_at: null,
    submitted_at: null,
    completed_at: null,
    requires_review: true,
    requires_result: true,
    requires_attachment: false,
    allow_no_incident: false,
    estimated_minutes: 30,
    blocked_at: null,
    blocker_reason: null,
    blocker_owner_member_id: null,
    current_submission_id: null,
    version: 1,
    checklist: [
      {
        id: ids.checklist,
        title: 'Đối chiếu tồn',
        sort_order: 0,
        is_required: true,
        checked_at: null,
        checked_by_member_id: null,
      },
    ],
    submissions: [],
    events: [],
    permissions: { is_assignee: true, can_review: false, can_manage: false },
    ...patch,
  };
}

describe('Task create UI policy', () => {
  it('UI-06 keeps invalid draft data untouched and identifies the first field to focus', () => {
    const draft = {
      assignee_member_id: '',
      reviewer_member_id: null,
      seller_id: ids.seller,
      title: 'Nội dung người dùng đang nhập',
      description: 'Không được xóa khi validation fail',
      priority: 'normal',
      planned_date: '2026-10-04',
      due_at: '2026-10-04T11:00:00.000Z',
      visible_from: null,
      requires_review: false,
      requires_result: true,
      requires_attachment: false,
      allow_no_incident: false,
      estimated_minutes: null,
      checklist: [],
      participant_member_ids: [],
    };
    const before = structuredClone(draft);

    const result = validateTaskCreateDraft(draft);

    expect(result.ok).toBe(false);
    if (result.ok) throw new Error('Expected invalid draft');
    expect(result.firstInvalidField).toBe('assignee_member_id');
    expect(result.errors.assignee_member_id).toBeTruthy();
    expect(draft).toEqual(before);
  });

  it('UI-12 allows only one mutation to enter until the slow request settles', () => {
    const guard = createTaskMutationGuard();

    expect(guard.tryEnter()).toBe(true);
    expect(guard.isLocked()).toBe(true);
    expect(guard.tryEnter()).toBe(false);

    guard.leave();
    expect(guard.isLocked()).toBe(false);
    expect(guard.tryEnter()).toBe(true);
  });

  it('UI-12 does not treat malformed server output as a successful create', () => {
    expect(taskCreateMutationId(null)).toBeNull();
    expect(taskCreateMutationId({ status: 'todo' })).toBeNull();
    expect(taskCreateMutationId({ task_id: ids.task, version: 1, status: 'todo' })).toBe(ids.task);
  });
});

describe('Task detail UI policy', () => {
  it('shows only assignee actions that are valid in todo', () => {
    const policy = taskDetailUiPolicy(makeTask());

    expect(policy.checklistEditable).toBe(true);
    expect(policy.submitAllowed).toBe(true);
    expect(policy.showAck).toBe(true);
    expect(policy.showStart).toBe(true);
    expect(policy.showReportBlocker).toBe(true);
    expect(policy.showReviewActions).toBe(false);
  });

  it('freezes assignee editing while the task is in review', () => {
    const policy = taskDetailUiPolicy(makeTask({ status: 'in_review' }));

    expect(policy.checklistEditable).toBe(false);
    expect(policy.submitAllowed).toBe(false);
    expect(policy.showWithdrawSubmission).toBe(true);
    expect(policy.showReportBlocker).toBe(false);
  });

  it('exposes review actions to the reviewer in review state', () => {
    const policy = taskDetailUiPolicy(
      makeTask({
        status: 'in_review',
        permissions: { is_assignee: false, can_review: true, can_manage: true },
      }),
    );

    expect(policy.showReviewActions).toBe(true);
    expect(policy.showEdit).toBe(false);
    expect(policy.showManageActiveActions).toBe(false);
  });

  it('shows blocker state without changing task status and permits resolving it', () => {
    const task = makeTask({
      status: 'in_progress',
      blocked_at: '2026-10-04T04:00:00.000Z',
      blocker_reason: 'Chờ xác nhận tồn kho',
    });
    const policy = taskDetailUiPolicy(task);

    expect(task.status).toBe('in_progress');
    expect(policy.showBlockerBanner).toBe(true);
    expect(policy.showReportBlocker).toBe(false);
    expect(policy.canResolveBlocker).toBe(true);
  });

  it('only offers reopen for a terminal task to a manager/admin', () => {
    const policy = taskDetailUiPolicy(
      makeTask({
        status: 'done',
        permissions: { is_assignee: false, can_review: false, can_manage: true },
      }),
    );

    expect(policy.checklistEditable).toBe(false);
    expect(policy.showManageActiveActions).toBe(false);
    expect(policy.showReopen).toBe(true);
  });
});

describe('Task submission and conflict feedback', () => {
  it('blocks submit until required checklist, result and evidence gates pass', () => {
    const task = makeTask({ requires_attachment: true });

    expect(
      taskSubmitPreflight(task, { resultText: '', evidenceText: '', noIncident: false }).error,
    ).toContain('checklist');

    const checklistDone = makeTask({
      requires_attachment: true,
      checklist: [
        {
          ...task.checklist[0]!,
          checked_at: '2026-10-04T05:00:00.000Z',
          checked_by_member_id: ids.assignee,
        },
      ],
    });
    expect(
      taskSubmitPreflight(checklistDone, {
        resultText: '',
        evidenceText: '',
        noIncident: false,
      }).error,
    ).toContain('kết quả');
    expect(
      taskSubmitPreflight(checklistDone, {
        resultText: 'Đã hoàn tất',
        evidenceText: '',
        noIncident: false,
      }).error,
    ).toContain('bằng chứng');

    const passed = taskSubmitPreflight(checklistDone, {
      resultText: 'Đã hoàn tất',
      evidenceText: ' https://example.test/evidence-1 \n\nhttps://example.test/evidence-2 ',
      noIncident: false,
    });
    expect(passed.error).toBeNull();
    expect(passed.evidence).toEqual([
      { url: 'https://example.test/evidence-1' },
      { url: 'https://example.test/evidence-2' },
    ]);
  });

  it('makes version conflicts explicitly reloadable instead of treating them as success', () => {
    const conflict = taskMutationErrorState(
      { message: 'VERSION_CONFLICT' },
      'Không thể cập nhật công việc.',
    );
    const generic = taskMutationErrorState({ message: 'NETWORK_DOWN' }, 'Không thể cập nhật.');

    expect(conflict.versionConflict).toBe(true);
    expect(conflict.message).toContain('tải phiên bản mới');
    expect(generic.versionConflict).toBe(false);
    expect(generic.message).toBe('Không thể cập nhật.');
  });
});

describe('Task no-avatar regression', () => {
  it('UI-03 keeps task surfaces and PersonLabel text-only', () => {
    const files = [
      '../app/tasks/task-create-form.tsx',
      '../app/tasks/task-list-panel.tsx',
      '../app/tasks/task-detail-panel.tsx',
      '../components/ui.tsx',
    ];
    const source = files
      .map((relativePath) =>
        readFileSync(fileURLToPath(new URL(relativePath, import.meta.url)), 'utf8'),
      )
      .join('\n');

    expect(source).not.toMatch(/\bAvatar\b/i);
    expect(source).not.toMatch(/className=["'][^"']*avatar/i);
    expect(source).not.toMatch(/task-avatar|ui-avatar/i);
  });
});
