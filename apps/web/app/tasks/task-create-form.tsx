'use client';

import { useMemo, useRef, useState } from 'react';
import type { FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import {
  taskErrorMessage,
  type MemberDirectoryEntry,
  type OrganizationContext,
  type TaskCreateDraft,
} from '@opsdesk/contracts';
import { Button, Checkbox, DailyTaskCheckbox, Input, Select, Textarea } from '../../components/ui';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import { projectScheduleDates, type RecurrenceScheduleKind } from '../../lib/demo/recurring-demo';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';
import type { TaskSellerOption } from './task-data';
import { localDateInTimeZone, localDateTimeToIso } from './task-timezone';
import {
  createTaskMutationGuard,
  taskCreateMutationId,
  type TaskFieldErrors,
  validateTaskCreateDraft,
} from './task-ui-policy';

type ChecklistDraft = {
  id: string;
  title: string;
  isRequired: boolean;
};

type TaskCreateFormProps = {
  context: OrganizationContext;
  members: MemberDirectoryEntry[];
  sellers: TaskSellerOption[];
  source: WorkspaceDataSource;
  mode?: 'drawer' | 'page';
  onCancel?: () => void;
  onCreated?: (taskId: string) => void;
};

const priorityOptions = [
  { value: 'low', label: 'Thấp' },
  { value: 'normal', label: 'Bình thường' },
  { value: 'high', label: 'Cao' },
  { value: 'urgent', label: 'Khẩn cấp' },
];

function memberHasSeller(member: MemberDirectoryEntry, sellerId: string) {
  return member.seller_scope.some((scope) => scope.seller_id === sellerId);
}

function taskFingerprint(task: TaskCreateDraft) {
  return JSON.stringify(task);
}

export function TaskCreateForm({
  context,
  members,
  sellers,
  source,
  mode = 'page',
  onCancel,
  onCreated,
}: TaskCreateFormProps) {
  const router = useRouter();
  const initialDate = localDateInTimeZone(context.server_now, context.timezone);
  const [sellerId, setSellerId] = useState('');
  const [assigneeId, setAssigneeId] = useState(context.role === 'manager' ? context.member_id : '');
  const [reviewerId, setReviewerId] = useState('');
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState<'low' | 'normal' | 'high' | 'urgent'>('normal');
  const [plannedDate, setPlannedDate] = useState(initialDate);
  const [dueAtLocal, setDueAtLocal] = useState(`${initialDate}T18:00`);
  const [estimatedMinutes, setEstimatedMinutes] = useState('');
  const [requiresReview, setRequiresReview] = useState(false);
  const [requiresResult, setRequiresResult] = useState(true);
  const [requiresAttachment, setRequiresAttachment] = useState(false);
  const [allowNoIncident, setAllowNoIncident] = useState(false);
  const [isDailyTask, setIsDailyTask] = useState(false);
  const [recurrenceKind, setRecurrenceKind] = useState<RecurrenceScheduleKind>('working_days');
  const [recurrenceWeekdays, setRecurrenceWeekdays] = useState<number[]>([1, 2, 3, 4, 5]);
  const [recurrenceStartDate, setRecurrenceStartDate] = useState(initialDate);
  const [recurrenceHasEnd, setRecurrenceHasEnd] = useState(false);
  const [recurrenceEndDate, setRecurrenceEndDate] = useState('');
  const [recurrenceDueTime, setRecurrenceDueTime] = useState('18:00');
  const [assignmentMode, setAssignmentMode] = useState<'fixed' | 'seller_owner'>('fixed');
  const [checklist, setChecklist] = useState<ChecklistDraft[]>([]);
  const [showAdvanced, setShowAdvanced] = useState(mode === 'page');
  const [fieldErrors, setFieldErrors] = useState<TaskFieldErrors>({});
  const [serverError, setServerError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);
  const idempotencyRef = useRef<{ fingerprint: string; key: string } | null>(null);
  const submitGuardRef = useRef(createTaskMutationGuard());

  const eligibleAssignees = useMemo(() => {
    if (!sellerId) {
      if (context.role === 'manager') {
        return members.filter((member) => member.member_id === context.member_id);
      }
      return members;
    }
    return members.filter((member) => memberHasSeller(member, sellerId));
  }, [context.member_id, context.role, members, sellerId]);

  const eligibleReviewers = useMemo(() => {
    if (!sellerId && context.role !== 'admin') return [];
    return members.filter((member) => {
      if (member.member_id === assigneeId) return false;
      if (member.role === 'employee') return false;
      if (!sellerId) return true;
      return memberHasSeller(member, sellerId);
    });
  }, [assigneeId, context.role, members, sellerId]);

  const recurrencePreview = useMemo(() => {
    if (!isDailyTask) return [];
    return projectScheduleDates(
      {
        kind: recurrenceKind,
        weekdays: recurrenceKind === 'weekdays' ? recurrenceWeekdays : [],
        start_date: recurrenceStartDate,
        end_date: recurrenceHasEnd && recurrenceEndDate ? recurrenceEndDate : null,
        due_time: recurrenceDueTime,
      },
      recurrenceStartDate || initialDate,
      7,
    );
  }, [
    initialDate,
    isDailyTask,
    recurrenceDueTime,
    recurrenceEndDate,
    recurrenceHasEnd,
    recurrenceKind,
    recurrenceStartDate,
    recurrenceWeekdays,
  ]);

  function focusFirstInvalid(firstField: string | null) {
    if (!firstField) return;
    window.requestAnimationFrame(() => {
      const target = document.querySelector<HTMLElement>(`[data-task-field="${firstField}"]`);
      target?.focus();
    });
  }

  function addChecklistItem() {
    setChecklist((items) => [...items, { id: crypto.randomUUID(), title: '', isRequired: true }]);
  }

  function removeChecklistItem(id: string) {
    setChecklist((items) => items.filter((item) => item.id !== id));
  }

  function updateChecklistItem(id: string, patch: Partial<ChecklistDraft>) {
    setChecklist((items) => items.map((item) => (item.id === id ? { ...item, ...patch } : item)));
  }

  function handleSellerChange(nextSellerId: string) {
    setSellerId(nextSellerId);
    const nextEligible = nextSellerId
      ? members.filter((member) => memberHasSeller(member, nextSellerId))
      : context.role === 'manager'
        ? members.filter((member) => member.member_id === context.member_id)
        : members;
    if (!nextEligible.some((member) => member.member_id === assigneeId)) {
      setAssigneeId(context.role === 'manager' && !nextSellerId ? context.member_id : '');
    }
    setReviewerId('');
    if (!nextSellerId && context.role !== 'admin') setRequiresReview(false);
  }

  async function submitTask(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (source === 'demo') {
      setServerError(
        'Đang dùng dữ liệu demo. Kết nối Supabase sau để bật thao tác giao việc thật.',
      );
      return;
    }
    if (isDailyTask) {
      setServerError(
        'Phần giao diện Daily Task đã sẵn sàng. Việc ghi lịch lặp sẽ được bật khi backend P04 được kết nối.',
      );
      return;
    }
    if (isSubmitting) return;

    setServerError(null);
    const draft = {
      assignee_member_id: assigneeId,
      reviewer_member_id: requiresReview ? reviewerId || null : null,
      seller_id: sellerId || null,
      title,
      description: description.trim() || null,
      priority,
      planned_date: plannedDate,
      due_at: localDateTimeToIso(dueAtLocal, context.timezone),
      visible_from: null,
      requires_review: requiresReview,
      requires_result: requiresResult,
      requires_attachment: requiresAttachment,
      allow_no_incident: allowNoIncident,
      estimated_minutes: estimatedMinutes ? Number(estimatedMinutes) : null,
      checklist: checklist.map((item, index) => ({
        title: item.title,
        sort_order: index,
        is_required: item.isRequired,
      })),
      participant_member_ids: [],
    };
    const validation = validateTaskCreateDraft(draft);
    if (!validation.ok) {
      setFieldErrors(validation.errors);
      focusFirstInvalid(validation.firstInvalidField);
      return;
    }

    setFieldErrors({});
    const fingerprint = taskFingerprint(validation.data);
    if (!idempotencyRef.current || idempotencyRef.current.fingerprint !== fingerprint) {
      idempotencyRef.current = { fingerprint, key: crypto.randomUUID() };
    }
    if (!submitGuardRef.current.tryEnter()) return;

    setSubmitting(true);
    try {
      const supabase = createSupabaseBrowserClient();
      const { data, error } = await supabase.rpc('rpc_create_task', {
        p_organization_id: context.organization_id,
        p_task: validation.data,
        p_idempotency_key: idempotencyRef.current.key,
      });
      if (error) {
        setServerError(taskErrorMessage(error, 'Không thể giao công việc.'));
        return;
      }
      const taskId = taskCreateMutationId(data);
      if (!taskId) {
        setServerError('Server đã phản hồi nhưng không trả về mã công việc hợp lệ.');
        return;
      }

      idempotencyRef.current = null;
      router.refresh();
      if (onCreated) {
        onCreated(taskId);
      } else {
        router.push(`/tasks/${taskId}`);
      }
    } catch {
      setServerError('Không thể kết nối để giao công việc. Dữ liệu bạn nhập vẫn được giữ lại.');
    } finally {
      submitGuardRef.current.leave();
      setSubmitting(false);
    }
  }

  const assigneeOptions = eligibleAssignees.map((member) => ({
    value: member.member_id,
    label: `${member.display_name} · ${member.employee_code}`,
  }));
  const reviewerOptions = eligibleReviewers.map((member) => ({
    value: member.member_id,
    label: `${member.display_name} · ${member.employee_code}`,
  }));

  function toggleRecurrenceWeekday(day: number, checked: boolean) {
    setRecurrenceWeekdays((current) => {
      if (checked) return Array.from(new Set([...current, day])).sort((a, b) => a - b);
      return current.filter((item) => item !== day);
    });
  }

  function formatPreviewDate(date: string) {
    const value = new Date(`${date}T00:00:00+07:00`);
    return new Intl.DateTimeFormat('vi-VN', {
      weekday: 'short',
      day: '2-digit',
      month: '2-digit',
    }).format(value);
  }

  return (
    <form className="task-create-form" onSubmit={submitTask} noValidate>
      {source === 'demo' ? (
        <div className="task-demo-readonly-note" role="note">
          <strong>Chế độ demo</strong>
          <span>Bạn có thể thử form và rule nghiệp vụ, nhưng dữ liệu sẽ chưa được ghi.</span>
        </div>
      ) : null}
      {serverError ? (
        <div className="task-form-alert" role="alert">
          {serverError}
        </div>
      ) : null}

      <div className="task-form-grid">
        <Select
          data-task-field="seller_id"
          error={fieldErrors.seller_id}
          label="Seller"
          onChange={(event) => handleSellerChange(event.target.value)}
          options={sellers.map((seller) => ({
            value: seller.id,
            label: `${seller.name} · ${seller.code}`,
          }))}
          placeholder="Công việc nội bộ"
          value={sellerId}
        />
        <Select
          data-task-field="assignee_member_id"
          error={fieldErrors.assignee_member_id}
          label="Người thực hiện *"
          onChange={(event) => {
            setAssigneeId(event.target.value);
            if (event.target.value === reviewerId) setReviewerId('');
          }}
          options={assigneeOptions}
          placeholder="Chọn nhân sự"
          value={assigneeId}
        />
      </div>

      <Input
        data-task-field="title"
        error={fieldErrors.title}
        label="Tên công việc *"
        maxLength={240}
        onChange={(event) => setTitle(event.target.value)}
        placeholder="Ví dụ: Kiểm tra tồn kho và cập nhật chương trình 10.10"
        value={title}
      />

      <div className="task-form-grid task-form-grid-three">
        <Select
          data-task-field="priority"
          error={fieldErrors.priority}
          label="Mức ưu tiên"
          onChange={(event) =>
            setPriority(event.target.value as 'low' | 'normal' | 'high' | 'urgent')
          }
          options={priorityOptions}
          value={priority}
        />
        <Input
          data-task-field="planned_date"
          error={fieldErrors.planned_date}
          label="Ngày thực hiện *"
          onChange={(event) => setPlannedDate(event.target.value)}
          type="date"
          value={plannedDate}
        />
        <Input
          data-task-field="due_at"
          error={fieldErrors.due_at}
          hint={`Theo múi giờ ${context.timezone}`}
          label="Hạn hoàn thành *"
          onChange={(event) => setDueAtLocal(event.target.value)}
          type="datetime-local"
          value={dueAtLocal}
        />
      </div>

      {mode === 'drawer' ? (
        <Button
          className="task-advanced-toggle"
          onClick={() => setShowAdvanced((value) => !value)}
          variant="ghost"
        >
          {showAdvanced ? 'Ẩn tùy chọn' : 'Thêm tùy chọn'}
        </Button>
      ) : null}

      {showAdvanced ? (
        <div className="task-advanced-section">
          <Textarea
            data-task-field="description"
            error={fieldErrors.description}
            label="Mô tả"
            onChange={(event) => setDescription(event.target.value)}
            placeholder="Kết quả mong đợi, lưu ý hoặc đường dẫn liên quan."
            rows={4}
            value={description}
          />

          <div className="task-checklist-block">
            <div className="task-checklist-heading">
              <div>
                <strong>Checklist</strong>
                <p>Các bước bắt buộc phải xong trước khi nộp.</p>
              </div>
              <Button onClick={addChecklistItem} variant="secondary">
                + Thêm bước
              </Button>
            </div>
            {checklist.length === 0 ? (
              <p className="task-checklist-empty">Chưa có bước checklist.</p>
            ) : (
              <div className="task-checklist-editor">
                {checklist.map((item, index) => (
                  <div className="task-checklist-edit-row" key={item.id}>
                    <Input
                      data-task-field={`checklist.${index}.title`}
                      error={fieldErrors[`checklist.${index}.title`]}
                      label={`Bước ${index + 1}`}
                      onChange={(event) =>
                        updateChecklistItem(item.id, { title: event.target.value })
                      }
                      placeholder="Nội dung cần hoàn tất"
                      value={item.title}
                    />
                    <Checkbox
                      checked={item.isRequired}
                      label="Bắt buộc"
                      onChange={(event) =>
                        updateChecklistItem(item.id, { isRequired: event.target.checked })
                      }
                    />
                    <Button onClick={() => removeChecklistItem(item.id)} variant="ghost">
                      Xóa
                    </Button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="task-rule-grid">
            <Checkbox
              checked={requiresResult}
              label="Yêu cầu nhập kết quả"
              onChange={(event) => setRequiresResult(event.target.checked)}
            />
            <Checkbox
              checked={requiresAttachment}
              label="Yêu cầu bằng chứng đính kèm"
              onChange={(event) => setRequiresAttachment(event.target.checked)}
            />
            <Checkbox
              checked={allowNoIncident}
              label="Cho phép xác nhận không phát sinh"
              onChange={(event) => setAllowNoIncident(event.target.checked)}
            />
            <Checkbox
              checked={requiresReview}
              disabled={!sellerId && context.role !== 'admin'}
              label="Cần người duyệt"
              onChange={(event) => {
                setRequiresReview(event.target.checked);
                if (!event.target.checked) setReviewerId('');
              }}
            />
          </div>

          {requiresReview ? (
            <Select
              data-task-field="reviewer_member_id"
              error={fieldErrors.reviewer_member_id}
              label="Người duyệt *"
              onChange={(event) => setReviewerId(event.target.value)}
              options={reviewerOptions}
              placeholder="Chọn người duyệt"
              value={reviewerId}
            />
          ) : null}

          <Input
            data-task-field="estimated_minutes"
            error={fieldErrors.estimated_minutes}
            inputMode="numeric"
            label="Thời lượng dự kiến (phút)"
            min={1}
            onChange={(event) => setEstimatedMinutes(event.target.value)}
            placeholder="Ví dụ: 30"
            type="number"
            value={estimatedMinutes}
          />

          <div className="daily-task-block">
            <DailyTaskCheckbox
              checked={isDailyTask}
              label="Daily task — Tự động lặp lại"
              onChange={(event) => setIsDailyTask(event.target.checked)}
            />
            <p className="daily-task-description">
              Mỗi ngày phù hợp sẽ tạo một công việc riêng, có kết quả và lịch sử độc lập.
            </p>

            {isDailyTask ? (
              <div className="daily-task-settings">
                <div className="task-form-grid">
                  <Select
                    label="Lịch lặp"
                    onChange={(event) =>
                      setRecurrenceKind(event.target.value as RecurrenceScheduleKind)
                    }
                    options={[
                      { value: 'working_days', label: 'Theo lịch làm việc' },
                      { value: 'every_day', label: 'Mỗi ngày (7 ngày)' },
                      { value: 'weekdays', label: 'Chọn ngày trong tuần' },
                    ]}
                    value={recurrenceKind}
                  />
                  <Input
                    label="Ngày bắt đầu"
                    onChange={(event) => setRecurrenceStartDate(event.target.value)}
                    type="date"
                    value={recurrenceStartDate}
                  />
                </div>

                {recurrenceKind === 'weekdays' ? (
                  <div className="daily-weekday-picker">
                    <span>Ngày trong tuần</span>
                    <div>
                      {[
                        [1, 'T2'],
                        [2, 'T3'],
                        [3, 'T4'],
                        [4, 'T5'],
                        [5, 'T6'],
                        [6, 'T7'],
                        [0, 'CN'],
                      ].map(([day, label]) => (
                        <Checkbox
                          checked={recurrenceWeekdays.includes(day as number)}
                          key={label}
                          label={String(label)}
                          onChange={(event) =>
                            toggleRecurrenceWeekday(day as number, event.target.checked)
                          }
                        />
                      ))}
                    </div>
                    {recurrenceWeekdays.length === 0 ? (
                      <small>Chọn ít nhất 1 ngày để tạo lịch.</small>
                    ) : null}
                  </div>
                ) : null}

                <div className="task-form-grid task-form-grid-three">
                  <Input
                    label="Giờ đến hạn"
                    onChange={(event) => setRecurrenceDueTime(event.target.value)}
                    type="time"
                    value={recurrenceDueTime}
                  />
                  <Select
                    label="Kết thúc"
                    onChange={(event) => setRecurrenceHasEnd(event.target.value === 'date')}
                    options={[
                      { value: 'never', label: 'Không giới hạn' },
                      { value: 'date', label: 'Theo ngày' },
                    ]}
                    value={recurrenceHasEnd ? 'date' : 'never'}
                  />
                  <Input
                    disabled={!recurrenceHasEnd}
                    label="Ngày kết thúc"
                    min={recurrenceStartDate}
                    onChange={(event) => setRecurrenceEndDate(event.target.value)}
                    type="date"
                    value={recurrenceEndDate}
                  />
                </div>

                <Select
                  label="Phân công"
                  onChange={(event) =>
                    setAssignmentMode(event.target.value as 'fixed' | 'seller_owner')
                  }
                  options={[
                    { value: 'fixed', label: 'Cố định người đã chọn' },
                    { value: 'seller_owner', label: 'Theo người phụ trách seller/lịch trực' },
                  ]}
                  value={assignmentMode}
                />

                <div className="daily-coverage-note">
                  <strong>Khi người phụ trách nghỉ</strong>
                  <span>
                    Yêu cầu quản lý chọn người thay. Không tự giao việc cho người đang nghỉ.
                  </span>
                </div>

                <div className="daily-preview">
                  <div>
                    <strong>7 lần tiếp theo</strong>
                    <span>Dự kiến theo cấu hình hiện tại</span>
                  </div>
                  {recurrencePreview.length > 0 ? (
                    <ul>
                      {recurrencePreview.map((date) => (
                        <li key={date}>
                          <span>{formatPreviewDate(date)}</span>
                          <span>{recurrenceDueTime}</span>
                          <span>
                            {assignmentMode === 'fixed'
                              ? (members.find((member) => member.member_id === assigneeId)
                                  ?.display_name ?? 'Chưa chọn người')
                              : 'Theo seller/lịch trực'}
                          </span>
                          <span>
                            {sellers.find((seller) => seller.id === sellerId)?.name ?? 'Nội bộ'}
                          </span>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p>Chưa có lần phù hợp với cấu hình hiện tại.</p>
                  )}
                </div>

                <p className="daily-task-reminder">
                  Việc chưa xong hôm trước vẫn được giữ lại. Lần mới không tự đánh dấu hoàn thành
                  theo lần cũ.
                </p>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      <div className="task-form-actions">
        {onCancel ? (
          <Button disabled={isSubmitting} onClick={onCancel} variant="secondary">
            Hủy
          </Button>
        ) : null}
        <Button disabled={isSubmitting || source === 'demo'} type="submit">
          {source === 'demo'
            ? isDailyTask
              ? 'Tạo lịch công việc · Demo'
              : 'Giao việc · Demo'
            : isSubmitting
              ? 'Đang giao việc…'
              : isDailyTask
                ? 'Tạo lịch công việc'
                : 'Giao việc'}
        </Button>
      </div>
    </form>
  );
}
