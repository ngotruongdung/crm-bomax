'use client';

import { useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import type { Json } from '@opsdesk/api-client';
import {
  type MemberDirectoryEntry,
  type OrganizationContext,
  type TaskCommandAction,
  type TaskDetail,
} from '@opsdesk/contracts';
import {
  Button,
  Checkbox,
  Dialog,
  Input,
  PersonLabel,
  PriorityBadge,
  Select,
  StatusBadge,
  Textarea,
} from '../../components/ui';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';
import { localDateTimeToIso, localDateTimeValue } from './task-timezone';
import {
  createTaskMutationGuard,
  taskDetailUiPolicy,
  taskMutationErrorState,
  taskSubmitPreflight,
} from './task-ui-policy';

type TaskDialog =
  | 'edit'
  | 'submit'
  | 'request_changes'
  | 'report_blocker'
  | 'reassign'
  | 'change_deadline'
  | 'cancel'
  | 'waive'
  | 'reopen'
  | null;

const statusLabels: Record<TaskDetail['status'], string> = {
  todo: 'Chờ thực hiện',
  in_progress: 'Đang làm',
  in_review: 'Chờ duyệt',
  done: 'Hoàn thành',
  canceled: 'Đã hủy',
  waived: 'Đã miễn',
};

const eventLabels: Record<string, string> = {
  created: 'Đã tạo công việc',
  acknowledged: 'Đã nhận việc',
  started: 'Đã bắt đầu',
  checklist_updated: 'Đã cập nhật checklist',
  submitted_for_review: 'Đã nộp để duyệt',
  completed: 'Đã hoàn thành',
  submission_withdrawn: 'Đã rút kết quả',
  approved: 'Đã duyệt',
  changes_requested: 'Yêu cầu làm lại',
  blocker_reported: 'Đã báo vướng',
  blocker_resolved: 'Đã gỡ vướng',
  reassigned: 'Đã đổi người thực hiện',
  deadline_changed: 'Đã đổi thời hạn',
  details_updated: 'Đã cập nhật công việc',
  canceled: 'Đã hủy công việc',
  waived: 'Đã miễn công việc',
  reopened: 'Đã mở lại công việc',
};

function statusTone(status: TaskDetail['status']) {
  if (status === 'done') return 'success' as const;
  if (status === 'in_review') return 'warning' as const;
  if (status === 'canceled' || status === 'waived') return 'danger' as const;
  return 'neutral' as const;
}

function dateTimeLabel(value: string | null | undefined, timeZone: string) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function dateLabel(value: string, timeZone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(`${value}T12:00:00Z`));
}

function evidenceItems(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.map((item) => {
      if (typeof item === 'string') return item;
      if (item && typeof item === 'object' && 'url' in item)
        return String((item as { url: unknown }).url);
      return JSON.stringify(item);
    });
  }
  if (value && typeof value === 'object') return [JSON.stringify(value)];
  return [];
}

function payloadPreview(value: unknown) {
  if (!value || typeof value !== 'object') return null;
  const payload = value as Record<string, unknown>;
  const parts: string[] = [];
  if (typeof payload.reason === 'string' && payload.reason.trim())
    parts.push(payload.reason.trim());
  if (typeof payload.revision === 'number') parts.push(`Lần nộp ${payload.revision}`);
  if (typeof payload.due_at === 'string') parts.push('Đã cập nhật deadline');
  return parts.join(' · ') || null;
}

export function TaskDetailPanel({
  context,
  members,
  source,
  task,
}: {
  context: OrganizationContext;
  members: MemberDirectoryEntry[];
  source: WorkspaceDataSource;
  task: TaskDetail;
}) {
  const router = useRouter();
  const [isExpanded, setIsExpanded] = useState(false);
  const [dialog, setDialog] = useState<TaskDialog>(null);
  const [reason, setReason] = useState('');
  const [resultText, setResultText] = useState('');
  const [evidenceText, setEvidenceText] = useState('');
  const [noIncident, setNoIncident] = useState(false);
  const [selectedMemberId, setSelectedMemberId] = useState('');
  const [dateTimeValue, setDateTimeValue] = useState(
    localDateTimeValue(task.due_at, context.timezone),
  );
  const [editTitle, setEditTitle] = useState(task.title);
  const [editDescription, setEditDescription] = useState(task.description ?? '');
  const [editPriority, setEditPriority] = useState<TaskDetail['priority']>(task.priority);
  const [editPlannedDate, setEditPlannedDate] = useState(task.planned_date);
  const [editReviewerMemberId, setEditReviewerMemberId] = useState(task.reviewer_member_id ?? '');
  const [editRequiresReview, setEditRequiresReview] = useState(task.requires_review);
  const [editRequiresResult, setEditRequiresResult] = useState(task.requires_result);
  const [editRequiresAttachment, setEditRequiresAttachment] = useState(task.requires_attachment);
  const [editAllowNoIncident, setEditAllowNoIncident] = useState(task.allow_no_incident);
  const [editEstimatedMinutes, setEditEstimatedMinutes] = useState(
    task.estimated_minutes ? String(task.estimated_minutes) : '',
  );
  const [error, setError] = useState<string | null>(null);
  const [versionConflict, setVersionConflict] = useState(false);
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const idempotencyRef = useRef<{ fingerprint: string; key: string } | null>(null);
  const mutationGuardRef = useRef(createTaskMutationGuard());

  const {
    checklistEditable,
    submitAllowed,
    showEdit,
    showAck,
    showStart,
    showReportBlocker,
    showWithdrawSubmission,
    showReviewActions,
    showBlockerBanner,
    canResolveBlocker,
    showManageActiveActions,
    showReopen,
  } = taskDetailUiPolicy(task);
  const isDemo = source === 'demo';

  function openDialog(nextDialog: TaskDialog) {
    if (isDemo) {
      setError(
        'Đang dùng dữ liệu demo. Thao tác ghi dữ liệu sẽ được bật sau khi kết nối Supabase.',
      );
      return;
    }
    setDialog(nextDialog);
    setReason('');
    setResultText('');
    setEvidenceText('');
    setNoIncident(false);
    setSelectedMemberId(nextDialog === 'reassign' ? task.assignee_member_id : '');
    setDateTimeValue(localDateTimeValue(task.due_at, context.timezone));
    if (nextDialog === 'edit') {
      setEditTitle(task.title);
      setEditDescription(task.description ?? '');
      setEditPriority(task.priority);
      setEditPlannedDate(task.planned_date);
      setEditReviewerMemberId(task.reviewer_member_id ?? '');
      setEditRequiresReview(task.requires_review);
      setEditRequiresResult(task.requires_result);
      setEditRequiresAttachment(task.requires_attachment);
      setEditAllowNoIncident(task.allow_no_incident);
      setEditEstimatedMinutes(task.estimated_minutes ? String(task.estimated_minutes) : '');
    }
    setError(null);
  }

  async function command(
    action: TaskCommandAction,
    payload: Record<string, Json | undefined> = {},
  ) {
    if (isDemo) {
      setError('Đang dùng dữ liệu demo. Thao tác này chưa ghi dữ liệu thật.');
      return false;
    }
    if (busyAction) return false;
    const fingerprint = JSON.stringify({ action, payload, version: task.version });
    if (!idempotencyRef.current || idempotencyRef.current.fingerprint !== fingerprint) {
      idempotencyRef.current = { fingerprint, key: crypto.randomUUID() };
    }
    if (!mutationGuardRef.current.tryEnter()) return false;

    setBusyAction(action);
    setError(null);
    setVersionConflict(false);
    try {
      const supabase = createSupabaseBrowserClient();
      const { error: rpcError } = await supabase.rpc('rpc_task_command', {
        p_task_id: task.id,
        p_action: action,
        p_payload: payload,
        p_expected_version: task.version,
        p_idempotency_key: idempotencyRef.current.key,
      });
      if (rpcError) {
        const feedback = taskMutationErrorState(rpcError, 'Không thể cập nhật công việc.');
        setError(feedback.message);
        setVersionConflict(feedback.versionConflict);
        return false;
      }
      idempotencyRef.current = null;
      setDialog(null);
      router.refresh();
      return true;
    } catch {
      setError('Không thể kết nối để cập nhật công việc. Vui lòng thử lại.');
      return false;
    } finally {
      mutationGuardRef.current.leave();
      setBusyAction(null);
    }
  }

  async function submitDialogAction() {
    if (isDemo) {
      setError('Đang dùng dữ liệu demo. Thao tác này chưa ghi dữ liệu thật.');
      return;
    }
    if (!dialog) return;
    if (dialog === 'edit') {
      const title = editTitle.trim();
      if (!title) return setError('Nhập tiêu đề công việc.');
      if (editRequiresReview && !editReviewerMemberId) {
        return setError('Chọn người duyệt khi bật yêu cầu duyệt.');
      }
      if (editReviewerMemberId && editReviewerMemberId === task.assignee_member_id) {
        return setError('Người duyệt không thể là người thực hiện.');
      }

      const estimatedMinutes = editEstimatedMinutes.trim()
        ? Number(editEstimatedMinutes.trim())
        : null;
      if (
        estimatedMinutes !== null &&
        (!Number.isInteger(estimatedMinutes) || estimatedMinutes <= 0)
      ) {
        return setError('Thời lượng dự kiến phải là số phút nguyên lớn hơn 0.');
      }

      const nextDescription = editDescription.trim() || null;
      const nextReviewer = editRequiresReview ? editReviewerMemberId || null : null;
      const patch: Record<string, Json | undefined> = {};
      if (title !== task.title) patch.title = title;
      if (nextDescription !== task.description) patch.description = nextDescription;
      if (editPriority !== task.priority) patch.priority = editPriority;
      if (editPlannedDate !== task.planned_date) patch.planned_date = editPlannedDate;
      if (nextReviewer !== task.reviewer_member_id) patch.reviewer_member_id = nextReviewer;
      if (editRequiresReview !== task.requires_review) patch.requires_review = editRequiresReview;
      if (editRequiresResult !== task.requires_result) patch.requires_result = editRequiresResult;
      if (editRequiresAttachment !== task.requires_attachment) {
        patch.requires_attachment = editRequiresAttachment;
      }
      if (editAllowNoIncident !== task.allow_no_incident)
        patch.allow_no_incident = editAllowNoIncident;
      if (estimatedMinutes !== (task.estimated_minutes ?? null)) {
        patch.estimated_minutes = estimatedMinutes;
      }
      if (Object.keys(patch).length === 0) return setError('Chưa có thay đổi để lưu.');

      const fingerprint = JSON.stringify({ action: 'update', patch, version: task.version });
      if (!idempotencyRef.current || idempotencyRef.current.fingerprint !== fingerprint) {
        idempotencyRef.current = { fingerprint, key: crypto.randomUUID() };
      }
      if (busyAction || !mutationGuardRef.current.tryEnter()) return;

      setBusyAction('update');
      setError(null);
      setVersionConflict(false);
      try {
        const supabase = createSupabaseBrowserClient();
        const { error: rpcError } = await supabase.rpc('rpc_update_task', {
          p_task_id: task.id,
          p_patch: patch,
          p_expected_version: task.version,
          p_idempotency_key: idempotencyRef.current.key,
        });
        if (rpcError) {
          const feedback = taskMutationErrorState(rpcError, 'Không thể lưu thay đổi công việc.');
          setError(feedback.message);
          setVersionConflict(feedback.versionConflict);
          return;
        }
        idempotencyRef.current = null;
        setDialog(null);
        router.refresh();
      } catch {
        setError('Không thể kết nối để lưu thay đổi. Vui lòng thử lại.');
      } finally {
        mutationGuardRef.current.leave();
        setBusyAction(null);
      }
      return;
    }
    if (dialog === 'submit') {
      const preflight = taskSubmitPreflight(task, { resultText, evidenceText, noIncident });
      if (preflight.error) return setError(preflight.error);
      await command('submit', {
        result_text: resultText.trim() || null,
        no_incident: noIncident,
        evidence: preflight.evidence,
      });
      return;
    }
    if (dialog === 'request_changes') {
      if (!reason.trim()) return setError('Nhập lý do cần làm lại.');
      await command('request_changes', { reason: reason.trim() });
      return;
    }
    if (dialog === 'report_blocker') {
      if (!reason.trim()) return setError('Nhập nội dung đang bị vướng.');
      await command('report_blocker', {
        reason: reason.trim(),
        owner_member_id: selectedMemberId || null,
      });
      return;
    }
    if (dialog === 'reassign') {
      if (!selectedMemberId) return setError('Chọn người thực hiện mới.');
      if (!reason.trim()) return setError('Nhập lý do đổi người thực hiện.');
      await command('reassign', { assignee_member_id: selectedMemberId, reason: reason.trim() });
      return;
    }
    if (dialog === 'change_deadline') {
      if (!dateTimeValue) return setError('Chọn thời hạn mới.');
      if (!reason.trim()) return setError('Nhập lý do đổi thời hạn.');
      const dueAt = localDateTimeToIso(dateTimeValue, context.timezone);
      if (!dueAt) return setError('Thời hạn mới không hợp lệ.');
      await command('change_deadline', {
        due_at: dueAt,
        reason: reason.trim(),
      });
      return;
    }
    if (!reason.trim()) return setError('Nhập lý do để tiếp tục.');
    await command(dialog, { reason: reason.trim() });
  }

  const memberOptions = members.map((member) => ({
    value: member.member_id,
    label: `${member.display_name} · ${member.employee_code}`,
  }));
  const reviewerOptions = members
    .filter((member) => member.member_id !== task.assignee_member_id)
    .filter((member) => member.role !== 'employee')
    .filter((member) =>
      task.seller_id
        ? member.seller_scope.some((scope) => scope.seller_id === task.seller_id)
        : context.role === 'admin',
    )
    .map((member) => ({
      value: member.member_id,
      label: `${member.display_name} · ${member.employee_code}`,
    }));

  return (
    <>
      <button
        aria-label="Đóng chi tiết công việc từ nền"
        className="task-detail-route-backdrop"
        onClick={() => router.push('/tasks')}
        tabIndex={-1}
        type="button"
      />
      <section
        aria-label={`Chi tiết ${task.task_number}`}
        className={`task-detail-shell task-detail-route-drawer${isExpanded ? ' is-expanded' : ''}`}
        role="dialog"
      >
        <div className="task-detail-drawer-toolbar">
          <span>Chi tiết công việc</span>
          <div className="task-detail-drawer-toolbar-actions">
            <Button
              aria-label={isExpanded ? 'Thu gọn chi tiết công việc' : 'Mở rộng chi tiết công việc'}
              onClick={() => setIsExpanded((value) => !value)}
              variant="ghost"
            >
              {isExpanded ? 'Thu gọn' : 'Mở rộng'}
            </Button>
            <Button
              aria-label="Đóng chi tiết công việc"
              onClick={() => router.push('/tasks')}
              variant="ghost"
            >
              ×
            </Button>
          </div>
        </div>

        <div className="task-detail-drawer-content">
          {isDemo ? (
            <div className="task-demo-readonly-note" role="note">
              <strong>Chế độ demo · chỉ đọc</strong>
              <span>
                Trạng thái, lịch sử và checklist bên dưới là dữ liệu mẫu; mọi thao tác ghi đang
                khóa.
              </span>
            </div>
          ) : null}

          {error ? (
            <div
              className={
                versionConflict
                  ? 'task-detail-alert task-detail-alert-conflict'
                  : 'task-detail-alert'
              }
              role="alert"
            >
              <span>{error}</span>
              {versionConflict ? (
                <Button onClick={() => router.refresh()} variant="secondary">
                  Tải phiên bản mới
                </Button>
              ) : null}
            </div>
          ) : null}

          <header className="task-detail-hero">
            <div className="task-detail-title-block">
              <div className="task-detail-kicker">
                <span className="task-number">{task.task_number}</span>
                <span className="task-seller-chip">{task.seller_name ?? 'Nội bộ'}</span>
                <StatusBadge tone={statusTone(task.status)}>
                  {statusLabels[task.status]}
                </StatusBadge>
              </div>
              <h2>{task.title}</h2>
              {task.blocked_at ? (
                <span className="task-blocked-chip">Đang có vướng mắc</span>
              ) : null}
            </div>

            <div className="task-action-bar" aria-label="Thao tác công việc">
              {showEdit ? (
                <Button
                  disabled={isDemo || Boolean(busyAction)}
                  onClick={() => openDialog('edit')}
                  variant="ghost"
                >
                  Chỉnh sửa
                </Button>
              ) : null}
              {showAck ? (
                <Button disabled={isDemo || Boolean(busyAction)} onClick={() => command('ack')}>
                  Nhận việc
                </Button>
              ) : null}
              {showStart ? (
                <Button
                  disabled={isDemo || Boolean(busyAction)}
                  onClick={() => command('start')}
                  variant="secondary"
                >
                  Bắt đầu
                </Button>
              ) : null}
              {submitAllowed ? (
                <Button
                  disabled={isDemo || Boolean(busyAction)}
                  onClick={() => openDialog('submit')}
                  variant="secondary"
                >
                  Nộp kết quả
                </Button>
              ) : null}
              {showReportBlocker ? (
                <Button
                  disabled={isDemo || Boolean(busyAction)}
                  onClick={() => openDialog('report_blocker')}
                  variant="ghost"
                >
                  Báo vướng
                </Button>
              ) : null}
              {showWithdrawSubmission ? (
                <Button
                  disabled={isDemo || Boolean(busyAction)}
                  onClick={() => command('withdraw_submission')}
                  variant="ghost"
                >
                  Rút kết quả
                </Button>
              ) : null}
              {showReviewActions ? (
                <>
                  <Button
                    disabled={isDemo || Boolean(busyAction)}
                    onClick={() => command('approve')}
                  >
                    Duyệt
                  </Button>
                  <Button
                    disabled={isDemo || Boolean(busyAction)}
                    onClick={() => openDialog('request_changes')}
                    variant="secondary"
                  >
                    Yêu cầu làm lại
                  </Button>
                </>
              ) : null}
            </div>
          </header>

          {showBlockerBanner ? (
            <section className="task-blocker-banner" aria-labelledby="task-blocker-title">
              <div>
                <strong id="task-blocker-title">Công việc đang bị vướng</strong>
                <p>{task.blocker_reason}</p>
                <small>
                  Đã báo lúc {dateTimeLabel(task.blocked_at, context.timezone)}. Deadline không tự
                  thay đổi.
                </small>
              </div>
              {canResolveBlocker ? (
                <Button
                  disabled={isDemo || Boolean(busyAction)}
                  onClick={() => command('resolve_blocker')}
                  variant="secondary"
                >
                  Đã gỡ vướng
                </Button>
              ) : null}
            </section>
          ) : null}

          <div className="task-detail-grid">
            <main className="task-detail-main">
              <section className="task-detail-card">
                <div className="task-card-heading">
                  <h3>Mô tả công việc</h3>
                </div>
                <p
                  className={task.description ? 'task-description' : 'task-description task-muted'}
                >
                  {task.description || 'Chưa có mô tả chi tiết.'}
                </p>
              </section>

              <section className="task-detail-card">
                <div className="task-card-heading">
                  <div>
                    <h3>Checklist</h3>
                    <p>Hoàn tất các mục bắt buộc trước khi nộp kết quả.</p>
                  </div>
                  <span>
                    {task.checklist.filter((item) => item.checked_at).length}/
                    {task.checklist.length}
                  </span>
                </div>
                {task.checklist.length === 0 ? (
                  <p className="task-muted">Công việc này không có checklist.</p>
                ) : (
                  <div className="task-detail-checklist">
                    {task.checklist.map((item) => {
                      const checkedBy = members.find(
                        (member) => member.member_id === item.checked_by_member_id,
                      );
                      return (
                        <div className="task-detail-check-row" key={item.id}>
                          <Checkbox
                            aria-label={item.title}
                            checked={Boolean(item.checked_at)}
                            className="task-checkbox-only"
                            disabled={isDemo || !checklistEditable || Boolean(busyAction)}
                            label={item.title}
                            onChange={(event) =>
                              command('checklist', {
                                item_id: item.id,
                                checked: event.target.checked,
                              })
                            }
                          />
                          <div>
                            <div className="task-check-title">
                              <span>{item.title}</span>
                              <small>{item.is_required ? 'Bắt buộc' : 'Tùy chọn'}</small>
                            </div>
                            {item.checked_at ? (
                              <p>
                                {checkedBy?.display_name ?? 'Người thực hiện'} ·{' '}
                                {dateTimeLabel(item.checked_at, context.timezone)}
                              </p>
                            ) : null}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
                {task.status === 'in_review' ? (
                  <p className="task-freeze-note">Checklist đang khóa trong thời gian chờ duyệt.</p>
                ) : null}
              </section>

              <section className="task-detail-card">
                <div className="task-card-heading">
                  <div>
                    <h3>Kết quả & nghiệm thu</h3>
                    <p>Các lần nộp được lưu bất biến theo lịch sử.</p>
                  </div>
                </div>
                {task.submissions.length === 0 ? (
                  <p className="task-muted">Chưa có kết quả nào được nộp.</p>
                ) : (
                  <div className="task-submission-list">
                    {task.submissions.map((submission) => {
                      const evidence = evidenceItems(submission.evidence);
                      return (
                        <article className="task-submission-card" key={submission.id}>
                          <div className="task-submission-header">
                            <strong>Lần nộp {submission.revision}</strong>
                            <StatusBadge
                              tone={
                                submission.review_state === 'approved'
                                  ? 'success'
                                  : submission.review_state === 'changes_requested'
                                    ? 'danger'
                                    : 'neutral'
                              }
                            >
                              {submission.review_state === 'pending'
                                ? 'Chờ duyệt'
                                : submission.review_state === 'approved'
                                  ? 'Đã duyệt'
                                  : submission.review_state === 'changes_requested'
                                    ? 'Cần làm lại'
                                    : 'Đã rút'}
                            </StatusBadge>
                          </div>
                          <p className="task-submission-time">
                            {dateTimeLabel(submission.submitted_at, context.timezone)}
                          </p>
                          {submission.no_incident ? (
                            <p className="task-no-incident">Đã xác nhận không phát sinh.</p>
                          ) : null}
                          {submission.result_text ? <p>{submission.result_text}</p> : null}
                          {evidence.length > 0 ? (
                            <div className="task-evidence-list">
                              {evidence.map((item, index) => (
                                <span key={`${submission.id}-${index}`}>{item}</span>
                              ))}
                            </div>
                          ) : null}
                          {submission.review_reason ? (
                            <div className="task-review-reason">
                              <strong>Phản hồi:</strong> {submission.review_reason}
                            </div>
                          ) : null}
                        </article>
                      );
                    })}
                  </div>
                )}
              </section>

              <section className="task-detail-card">
                <div className="task-card-heading">
                  <div>
                    <h3>Lịch sử hoạt động</h3>
                    <p>Sự kiện được lưu theo version của công việc.</p>
                  </div>
                </div>
                <ol className="task-timeline">
                  {task.events.map((event) => {
                    const preview = payloadPreview(event.event_payload);
                    return (
                      <li key={event.id}>
                        <span className="task-timeline-dot" aria-hidden="true" />
                        <div>
                          <strong>{eventLabels[event.event_type] ?? event.event_type}</strong>
                          <p>
                            {event.actor_name ?? 'Hệ thống'} ·{' '}
                            {dateTimeLabel(event.occurred_at, context.timezone)} · v
                            {event.task_version}
                          </p>
                          {preview ? <small>{preview}</small> : null}
                        </div>
                      </li>
                    );
                  })}
                </ol>
              </section>
            </main>

            <aside className="task-detail-sidebar">
              <section className="task-detail-card task-meta-card">
                <h3>Thông tin</h3>
                <dl>
                  <div>
                    <dt>Người thực hiện</dt>
                    <dd>
                      <PersonLabel name={task.assignee_name} />
                    </dd>
                  </div>
                  <div>
                    <dt>Người giao</dt>
                    <dd>{task.created_by_name}</dd>
                  </div>
                  <div>
                    <dt>Người duyệt</dt>
                    <dd>{task.reviewer_name ?? 'Không yêu cầu'}</dd>
                  </div>
                  <div>
                    <dt>Ngày thực hiện</dt>
                    <dd>{dateLabel(task.planned_date, context.timezone)}</dd>
                  </div>
                  <div>
                    <dt>Hạn hiện tại</dt>
                    <dd>{dateTimeLabel(task.due_at, context.timezone)}</dd>
                  </div>
                  <div>
                    <dt>Hạn ban đầu</dt>
                    <dd>{dateTimeLabel(task.original_due_at, context.timezone)}</dd>
                  </div>
                  <div>
                    <dt>Ưu tiên</dt>
                    <dd>
                      <PriorityBadge priority={task.priority} />
                    </dd>
                  </div>
                  {task.estimated_minutes ? (
                    <div>
                      <dt>Thời lượng dự kiến</dt>
                      <dd>{task.estimated_minutes} phút</dd>
                    </div>
                  ) : null}
                </dl>
              </section>

              <section className="task-detail-card task-rules-card">
                <h3>Điều kiện nghiệm thu</h3>
                <ul>
                  <li>
                    {task.requires_result ? 'Bắt buộc nhập kết quả' : 'Không bắt buộc kết quả'}
                  </li>
                  <li>
                    {task.requires_attachment ? 'Bắt buộc bằng chứng' : 'Không bắt buộc bằng chứng'}
                  </li>
                  <li>{task.requires_review ? 'Cần người duyệt' : 'Tự hoàn tất sau khi nộp'}</li>
                  {task.allow_no_incident ? <li>Cho phép xác nhận không phát sinh</li> : null}
                </ul>
              </section>

              {task.permissions.can_manage ? (
                <section className="task-detail-card task-manage-card">
                  <h3>Điều phối</h3>
                  <div className="task-manage-actions">
                    {showManageActiveActions ? (
                      <>
                        <Button
                          disabled={isDemo}
                          onClick={() => openDialog('reassign')}
                          variant="secondary"
                        >
                          Đổi người thực hiện
                        </Button>
                        <Button
                          disabled={isDemo}
                          onClick={() => openDialog('change_deadline')}
                          variant="secondary"
                        >
                          Đổi thời hạn
                        </Button>
                        <Button
                          disabled={isDemo}
                          onClick={() => openDialog('cancel')}
                          variant="ghost"
                        >
                          Hủy công việc
                        </Button>
                        <Button
                          disabled={isDemo}
                          onClick={() => openDialog('waive')}
                          variant="ghost"
                        >
                          Miễn công việc
                        </Button>
                      </>
                    ) : null}
                    {showReopen ? (
                      <Button
                        disabled={isDemo}
                        onClick={() => openDialog('reopen')}
                        variant="secondary"
                      >
                        Mở lại công việc
                      </Button>
                    ) : null}
                  </div>
                </section>
              ) : null}
            </aside>
          </div>
        </div>
      </section>

      <Dialog
        footer={
          <>
            <Button
              disabled={Boolean(busyAction)}
              onClick={() => setDialog(null)}
              variant="secondary"
            >
              Hủy
            </Button>
            <Button disabled={isDemo || Boolean(busyAction)} onClick={submitDialogAction}>
              {busyAction ? 'Đang xử lý…' : 'Xác nhận'}
            </Button>
          </>
        }
        onClose={() => setDialog(null)}
        open={Boolean(dialog)}
        title={
          dialog === 'edit'
            ? 'Chỉnh sửa công việc'
            : dialog === 'submit'
              ? 'Nộp kết quả'
              : dialog === 'request_changes'
                ? 'Yêu cầu làm lại'
                : dialog === 'report_blocker'
                  ? 'Báo vướng'
                  : dialog === 'reassign'
                    ? 'Đổi người thực hiện'
                    : dialog === 'change_deadline'
                      ? 'Đổi thời hạn'
                      : dialog === 'cancel'
                        ? 'Hủy công việc'
                        : dialog === 'waive'
                          ? 'Miễn công việc'
                          : 'Mở lại công việc'
        }
      >
        {dialog === 'edit' ? (
          <div className="task-dialog-form task-edit-dialog-form">
            <Input
              label="Tiêu đề *"
              maxLength={240}
              onChange={(event) => setEditTitle(event.target.value)}
              value={editTitle}
            />
            <Textarea
              label="Mô tả"
              onChange={(event) => setEditDescription(event.target.value)}
              rows={4}
              value={editDescription}
            />
            <div className="task-dialog-grid">
              <Select
                label="Ưu tiên"
                onChange={(event) => setEditPriority(event.target.value as TaskDetail['priority'])}
                options={[
                  { value: 'low', label: 'Thấp' },
                  { value: 'normal', label: 'Bình thường' },
                  { value: 'high', label: 'Cao' },
                  { value: 'urgent', label: 'Khẩn cấp' },
                ]}
                value={editPriority}
              />
              <Input
                label="Ngày thực hiện"
                onChange={(event) => setEditPlannedDate(event.target.value)}
                type="date"
                value={editPlannedDate}
              />
              <Input
                label="Thời lượng dự kiến (phút)"
                min="1"
                onChange={(event) => setEditEstimatedMinutes(event.target.value)}
                type="number"
                value={editEstimatedMinutes}
              />
            </div>
            <div className="task-rule-grid task-edit-rule-grid">
              <Checkbox
                checked={editRequiresResult}
                label="Bắt buộc nhập kết quả"
                onChange={(event) => setEditRequiresResult(event.target.checked)}
              />
              <Checkbox
                checked={editRequiresAttachment}
                label="Bắt buộc bằng chứng"
                onChange={(event) => setEditRequiresAttachment(event.target.checked)}
              />
              <Checkbox
                checked={editAllowNoIncident}
                label="Cho phép xác nhận không phát sinh"
                onChange={(event) => setEditAllowNoIncident(event.target.checked)}
              />
              <Checkbox
                checked={editRequiresReview}
                label="Yêu cầu người duyệt"
                onChange={(event) => {
                  setEditRequiresReview(event.target.checked);
                  if (!event.target.checked) setEditReviewerMemberId('');
                }}
              />
            </div>
            {editRequiresReview ? (
              <Select
                label="Người duyệt *"
                onChange={(event) => setEditReviewerMemberId(event.target.value)}
                options={reviewerOptions}
                placeholder="Chọn người duyệt"
                value={editReviewerMemberId}
              />
            ) : null}
            <p className="task-edit-note">
              Đổi người thực hiện hoặc deadline dùng thao tác Điều phối riêng để bắt buộc ghi lý do
              và lưu audit rõ ràng.
            </p>
          </div>
        ) : null}

        {dialog === 'submit' ? (
          <div className="task-dialog-form">
            <Textarea
              label={task.requires_result ? 'Kết quả *' : 'Kết quả'}
              onChange={(event) => setResultText(event.target.value)}
              placeholder="Mô tả kết quả đã hoàn thành…"
              rows={5}
              value={resultText}
            />
            <Textarea
              hint="Mỗi dòng một đường dẫn hoặc mã bằng chứng."
              label={task.requires_attachment ? 'Bằng chứng *' : 'Bằng chứng'}
              onChange={(event) => setEvidenceText(event.target.value)}
              placeholder="https://…"
              rows={3}
              value={evidenceText}
            />
            {task.allow_no_incident ? (
              <Checkbox
                checked={noIncident}
                label="Xác nhận không phát sinh"
                onChange={(event) => setNoIncident(event.target.checked)}
              />
            ) : null}
          </div>
        ) : null}

        {dialog === 'reassign' ? (
          <div className="task-dialog-form">
            <Select
              label="Người thực hiện mới"
              onChange={(event) => setSelectedMemberId(event.target.value)}
              options={memberOptions}
              placeholder="Chọn nhân sự"
              value={selectedMemberId}
            />
            <Textarea
              label="Lý do *"
              onChange={(event) => setReason(event.target.value)}
              rows={3}
              value={reason}
            />
          </div>
        ) : null}

        {dialog === 'change_deadline' ? (
          <div className="task-dialog-form">
            <Input
              label="Hạn mới *"
              onChange={(event) => setDateTimeValue(event.target.value)}
              type="datetime-local"
              value={dateTimeValue}
            />
            <Textarea
              label="Lý do *"
              onChange={(event) => setReason(event.target.value)}
              rows={3}
              value={reason}
            />
          </div>
        ) : null}

        {dialog === 'report_blocker' ? (
          <div className="task-dialog-form">
            <Textarea
              label="Nội dung đang bị vướng *"
              onChange={(event) => setReason(event.target.value)}
              rows={4}
              value={reason}
            />
            {memberOptions.length > 0 ? (
              <Select
                label="Người hỗ trợ"
                onChange={(event) => setSelectedMemberId(event.target.value)}
                options={memberOptions}
                placeholder="Tự xử lý / chưa xác định"
                value={selectedMemberId}
              />
            ) : null}
          </div>
        ) : null}

        {dialog &&
        !['edit', 'submit', 'reassign', 'change_deadline', 'report_blocker'].includes(dialog) ? (
          <div className="task-dialog-form">
            <Textarea
              label="Lý do *"
              onChange={(event) => setReason(event.target.value)}
              placeholder="Ghi rõ lý do để lưu vào lịch sử…"
              rows={4}
              value={reason}
            />
          </div>
        ) : null}

        {error ? (
          <p className="task-dialog-error" role="alert">
            {error}
          </p>
        ) : null}
      </Dialog>
    </>
  );
}
