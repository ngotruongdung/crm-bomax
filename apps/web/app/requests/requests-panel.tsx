'use client';

import type { OrganizationContext } from '@opsdesk/contracts';
import { useRouter } from 'next/navigation';
import { type FormEvent, useMemo, useState } from 'react';
import { Button, Drawer, StatusBadge } from '../../components/ui';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import {
  payTreatmentLabel,
  requestTypeLabel,
  type DemoEmployeeRequest,
  type DemoLeaveType,
  type DemoRequestType,
} from '../../lib/demo/hr-demo';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';
import { localDateInTimeZone, localDateTimeToIso } from '../tasks/task-timezone';

type RequestFilter = 'all' | DemoRequestType;

const requestTabs: Array<{ value: RequestFilter; label: string }> = [
  { value: 'all', label: 'Tất cả' },
  { value: 'leave', label: 'Nghỉ phép' },
  { value: 'early_leave', label: 'Về sớm' },
  { value: 'late_arrival', label: 'Đi muộn' },
  { value: 'remote_work', label: 'Làm online' },
  { value: 'attendance_correction', label: 'Bổ sung chấm công' },
];

const createRequestTypes: Array<{ value: DemoRequestType; label: string }> = [
  { value: 'leave', label: 'Nghỉ theo giờ / cả ngày' },
  { value: 'early_leave', label: 'Về sớm' },
  { value: 'late_arrival', label: 'Đi muộn' },
  { value: 'remote_work', label: 'Làm online' },
  { value: 'attendance_correction', label: 'Bổ sung chấm công' },
];

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(value));
}

function statusMeta(status: DemoEmployeeRequest['status']) {
  if (status === 'pending') return { label: 'Chờ duyệt', tone: 'warning' as const };
  if (status === 'approved') return { label: 'Đã duyệt', tone: 'success' as const };
  if (status === 'rejected') return { label: 'Từ chối', tone: 'danger' as const };
  if (status === 'withdrawn') return { label: 'Đã rút', tone: 'neutral' as const };
  return { label: 'Đã hủy', tone: 'neutral' as const };
}

function requestErrorMessage(error: { message?: string } | null, fallback: string) {
  const message = error?.message ?? '';
  if (message.includes('REQUEST_APPROVED_OVERLAP'))
    return 'Khoảng thời gian này trùng với đơn nghỉ đã được duyệt.';
  if (message.includes('REQUEST_LEAVE_TYPE_INVALID'))
    return 'Loại nghỉ không hợp lệ hoặc đã ngưng sử dụng.';
  if (message.includes('REQUEST_REASON_INVALID')) return 'Lý do cần có ít nhất 10 ký tự.';
  if (message.includes('REQUEST_INTERVAL_INVALID'))
    return 'Thời gian kết thúc phải sau thời gian bắt đầu.';
  if (message.includes('REQUEST_VERSION_CONFLICT'))
    return 'Đơn đã thay đổi ở nơi khác. Tải lại trang rồi thử lại.';
  if (message.includes('REQUEST_WITHDRAW_NOT_PENDING')) return 'Chỉ có thể rút đơn đang chờ duyệt.';
  if (message.includes('ACTIVE_MEMBERSHIP_REQUIRED'))
    return 'Phiên đăng nhập không còn membership hoạt động.';
  return fallback;
}

export function RequestsPanel({
  context,
  leaveTypes,
  requests,
  source,
}: {
  context: OrganizationContext;
  leaveTypes: DemoLeaveType[];
  requests: DemoEmployeeRequest[];
  source: WorkspaceDataSource;
}) {
  const router = useRouter();
  const today = localDateInTimeZone(context.server_now, context.timezone);
  const [activeTab, setActiveTab] = useState<RequestFilter>('all');
  const [selectedRequest, setSelectedRequest] = useState<DemoEmployeeRequest | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [requestType, setRequestType] = useState<DemoRequestType>('leave');
  const [leaveTypeId, setLeaveTypeId] = useState(leaveTypes[0]?.id ?? '');
  const [startsAtLocal, setStartsAtLocal] = useState(`${today}T09:00`);
  const [endsAtLocal, setEndsAtLocal] = useState(`${today}T18:00`);
  const [reason, setReason] = useState('');
  const [handoverNote, setHandoverNote] = useState('');
  const [formError, setFormError] = useState<string | null>(null);
  const [isSubmitting, setSubmitting] = useState(false);
  const [withdrawingId, setWithdrawingId] = useState<string | null>(null);

  const visibleRequests = useMemo(
    () => requests.filter((request) => activeTab === 'all' || request.request_type === activeTab),
    [activeTab, requests],
  );
  const requiresLeaveType = ['leave', 'early_leave', 'late_arrival'].includes(requestType);
  const selectedLeaveType = leaveTypes.find((item) => item.id === leaveTypeId);

  async function submitRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (source === 'demo' || isSubmitting) return;
    setFormError(null);

    const trimmedReason = reason.trim();
    if (trimmedReason.length < 10) {
      setFormError('Lý do cần có ít nhất 10 ký tự.');
      return;
    }
    if (requiresLeaveType && !leaveTypeId) {
      setFormError('Chọn loại nghỉ trước khi gửi yêu cầu.');
      return;
    }

    const startsAt = localDateTimeToIso(startsAtLocal, context.timezone);
    const endsAt = localDateTimeToIso(endsAtLocal, context.timezone);
    if (!startsAt || !endsAt || Date.parse(endsAt) <= Date.parse(startsAt)) {
      setFormError('Thời gian kết thúc phải sau thời gian bắt đầu.');
      return;
    }

    setSubmitting(true);
    try {
      const client = createSupabaseBrowserClient();
      const { error } = await client.rpc('rpc_create_employee_request', {
        p_organization_id: context.organization_id,
        p_payload: {
          request_type: requestType,
          starts_at: startsAt,
          ends_at: endsAt,
          leave_type_id: requiresLeaveType ? leaveTypeId : null,
          reason_private: trimmedReason,
          handover_note: handoverNote.trim() || null,
          correction_payload:
            requestType === 'attendance_correction'
              ? { requested_starts_at: startsAt, requested_ends_at: endsAt }
              : null,
        },
        p_idempotency_key: `request-create-${crypto.randomUUID()}`,
      });
      if (error) {
        setFormError(requestErrorMessage(error, 'Không thể gửi yêu cầu. Vui lòng thử lại.'));
        return;
      }

      setReason('');
      setHandoverNote('');
      setShowForm(false);
      router.refresh();
    } catch {
      setFormError('Không thể kết nối Supabase để gửi yêu cầu.');
    } finally {
      setSubmitting(false);
    }
  }

  async function withdrawRequest(request: DemoEmployeeRequest) {
    if (source === 'demo' || request.status !== 'pending' || withdrawingId) return;
    setFormError(null);
    setWithdrawingId(request.id);
    try {
      const client = createSupabaseBrowserClient();
      const { error } = await client.rpc('rpc_withdraw_employee_request', {
        p_request_id: request.id,
        p_expected_version: request.version,
        p_idempotency_key: `request-withdraw-${crypto.randomUUID()}`,
      });
      if (error) {
        setFormError(requestErrorMessage(error, 'Không thể rút yêu cầu. Vui lòng thử lại.'));
        return;
      }
      setSelectedRequest(null);
      router.refresh();
    } catch {
      setFormError('Không thể kết nối Supabase để rút yêu cầu.');
    } finally {
      setWithdrawingId(null);
    }
  }

  return (
    <>
      <section className="hr-toolbar-card hr-toolbar-compact">
        <div>
          <strong>Đơn từ của bạn</strong>
          <p>Chỉ yêu cầu đã duyệt mới ảnh hưởng lịch làm việc và dữ liệu tính công.</p>
        </div>
        <button
          className="hr-primary-button"
          disabled={source === 'demo'}
          onClick={() => {
            setFormError(null);
            setShowForm((value) => !value);
          }}
          type="button"
        >
          {showForm ? 'Đóng form' : '+ Tạo yêu cầu'}
        </button>
      </section>

      {source === 'demo' ? (
        <div className="hr-inline-note">
          Dữ liệu demo chỉ để xem. Kết nối Supabase thật để tạo hoặc rút đơn.
        </div>
      ) : null}
      {formError ? (
        <div className="hr-form-alert" role="alert">
          {formError}
        </div>
      ) : null}

      {showForm ? (
        <form className="hr-form-preview hr-form-preview-compact" onSubmit={submitRequest}>
          <div className="hr-section-heading">
            <div>
              <p className="workspace-eyebrow">Yêu cầu mới</p>
              <h2>Tạo yêu cầu</h2>
            </div>
            <span>Giờ hiển thị theo {context.timezone}</span>
          </div>
          <div className="hr-form-grid">
            <label>
              <span>Loại yêu cầu</span>
              <select
                disabled={isSubmitting}
                onChange={(event) => setRequestType(event.target.value as DemoRequestType)}
                value={requestType}
              >
                {createRequestTypes.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Loại nghỉ</span>
              <select
                disabled={isSubmitting || !requiresLeaveType}
                onChange={(event) => setLeaveTypeId(event.target.value)}
                value={leaveTypeId}
              >
                {leaveTypes.map((leaveType) => (
                  <option key={leaveType.id} value={leaveType.id}>
                    {leaveType.name} · {payTreatmentLabel(leaveType.pay_treatment)}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Bắt đầu</span>
              <input
                disabled={isSubmitting}
                onChange={(event) => setStartsAtLocal(event.target.value)}
                type="datetime-local"
                value={startsAtLocal}
              />
            </label>
            <label>
              <span>Kết thúc</span>
              <input
                disabled={isSubmitting}
                onChange={(event) => setEndsAtLocal(event.target.value)}
                type="datetime-local"
                value={endsAtLocal}
              />
            </label>
          </div>
          <label className="hr-form-wide-field">
            <span>Lý do *</span>
            <textarea
              disabled={isSubmitting}
              maxLength={2000}
              onChange={(event) => setReason(event.target.value)}
              placeholder="Nhập lý do tối thiểu 10 ký tự. Nội dung này chỉ hiển thị trong phạm vi HR phù hợp."
              rows={3}
              value={reason}
            />
          </label>
          <label className="hr-form-wide-field">
            <span>Ghi chú bàn giao</span>
            <textarea
              disabled={isSubmitting}
              onChange={(event) => setHandoverNote(event.target.value)}
              placeholder="Task nào cần theo dõi, ai đang nhận bàn giao..."
              rows={2}
              value={handoverNote}
            />
          </label>
          <div className="hr-impact-preview">
            <strong>
              {requiresLeaveType && selectedLeaveType
                ? payTreatmentLabel(selectedLeaveType.pay_treatment)
                : 'Không áp dụng loại công nghỉ'}
            </strong>
            <span>Phút ảnh hưởng sẽ được RPC tính theo ca làm việc/working segments hiện có.</span>
          </div>
          <div className="hr-form-actions">
            <Button disabled={isSubmitting} onClick={() => setShowForm(false)} variant="secondary">
              Hủy
            </Button>
            <Button
              disabled={isSubmitting || (requiresLeaveType && leaveTypes.length === 0)}
              type="submit"
            >
              {isSubmitting ? 'Đang gửi…' : 'Gửi yêu cầu'}
            </Button>
          </div>
        </form>
      ) : null}

      <nav className="hr-tabs hr-request-type-tabs" aria-label="Lọc yêu cầu theo loại">
        {requestTabs.map((tab) => (
          <button
            aria-pressed={activeTab === tab.value}
            className={`hr-tab${activeTab === tab.value ? ' hr-tab-active' : ''}`}
            key={tab.value}
            onClick={() => setActiveTab(tab.value)}
            type="button"
          >
            {tab.label}
          </button>
        ))}
      </nav>

      <section className="hr-request-table" aria-label="Danh sách yêu cầu">
        <div className="hr-request-table-head">
          <span>Loại yêu cầu</span>
          <span>Thời gian</span>
          <span>Trạng thái</span>
          <span>Gửi lúc</span>
          <span>Ảnh hưởng</span>
        </div>
        {visibleRequests.length === 0 ? (
          <div className="hr-empty-card hr-request-table-empty">Không có yêu cầu phù hợp.</div>
        ) : (
          visibleRequests.map((request) => {
            const status = statusMeta(request.status);
            return (
              <button
                className="hr-request-table-row"
                key={request.id}
                onClick={() => setSelectedRequest(request)}
                type="button"
              >
                <div>
                  <strong>{requestTypeLabel(request.request_type)}</strong>
                  <small>{payTreatmentLabel(request.pay_treatment)}</small>
                </div>
                <span className="hr-request-row-time">
                  {formatDateTime(request.starts_at)} → {formatDateTime(request.ends_at)}
                </span>
                <StatusBadge tone={status.tone}>{status.label}</StatusBadge>
                <span className="hr-request-row-submitted">
                  {formatDateTime(request.submitted_at)}
                </span>
                <span className="hr-request-row-impact">
                  {request.affected_minutes
                    ? `${request.affected_minutes} phút`
                    : 'Không ảnh hưởng'}
                </span>
              </button>
            );
          })
        )}
      </section>

      <Drawer
        footer={
          selectedRequest?.status === 'pending' ? (
            <Button
              disabled={source === 'demo' || withdrawingId === selectedRequest.id}
              onClick={() => withdrawRequest(selectedRequest)}
              variant="secondary"
            >
              {withdrawingId === selectedRequest.id ? 'Đang rút…' : 'Rút yêu cầu'}
            </Button>
          ) : undefined
        }
        onClose={() => setSelectedRequest(null)}
        open={Boolean(selectedRequest)}
        size="compact"
        title={
          selectedRequest ? requestTypeLabel(selectedRequest.request_type) : 'Chi tiết yêu cầu'
        }
      >
        {selectedRequest ? (
          <div className="hr-request-detail-drawer">
            <div className="hr-request-detail-status">
              <StatusBadge tone={statusMeta(selectedRequest.status).tone}>
                {statusMeta(selectedRequest.status).label}
              </StatusBadge>
              <span>Gửi {formatDateTime(selectedRequest.submitted_at)}</span>
            </div>
            <dl>
              <div>
                <dt>Thời gian</dt>
                <dd>
                  {formatDateTime(selectedRequest.starts_at)} →{' '}
                  {formatDateTime(selectedRequest.ends_at)}
                </dd>
              </div>
              <div>
                <dt>Loại công</dt>
                <dd>{payTreatmentLabel(selectedRequest.pay_treatment)}</dd>
              </div>
              <div>
                <dt>Ảnh hưởng</dt>
                <dd>{selectedRequest.affected_minutes} phút làm việc</dd>
              </div>
              <div>
                <dt>Task ảnh hưởng</dt>
                <dd>{selectedRequest.impacted_task_count}</dd>
              </div>
            </dl>
            <section>
              <small>Lý do</small>
              <p>{selectedRequest.reason_private}</p>
            </section>
            <section>
              <small>Ghi chú bàn giao</small>
              <p>{selectedRequest.handover_note ?? 'Không có ghi chú'}</p>
            </section>
          </div>
        ) : null}
      </Drawer>
    </>
  );
}
