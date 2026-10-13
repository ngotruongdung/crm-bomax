'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { Button, Drawer, StatusBadge } from '../../components/ui';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import {
  payTreatmentLabel,
  requestTypeLabel,
  type DemoEmployeeRequest,
} from '../../lib/demo/hr-demo';
import { createSupabaseBrowserClient } from '../../lib/supabase/browser';

function formatDateTime(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(value));
}

function approvalErrorMessage(error: { message?: string } | null) {
  const message = error?.message ?? '';
  if (message.includes('REQUEST_VERSION_CONFLICT'))
    return 'Đơn đã thay đổi ở nơi khác. Tải lại danh sách rồi quyết định lại.';
  if (message.includes('REQUEST_ALREADY_DECIDED')) return 'Đơn này đã được xử lý trước đó.';
  if (message.includes('REQUEST_SELF_APPROVAL_DENIED'))
    return 'Không thể tự duyệt đơn của chính mình.';
  if (message.includes('REQUEST_APPROVAL_DENIED')) return 'Tài khoản này không có quyền duyệt đơn.';
  if (message.includes('REQUEST_APPROVED_OVERLAP'))
    return 'Không thể duyệt vì thời gian nghỉ trùng với đơn đã duyệt khác.';
  if (message.includes('REQUEST_REJECTION_REASON_REQUIRED'))
    return 'Khi từ chối, lý do cần có ít nhất 10 ký tự.';
  return 'Không thể cập nhật quyết định. Vui lòng thử lại.';
}

export function ApprovalsPanel({
  allRequests,
  pending,
  source,
}: {
  allRequests: DemoEmployeeRequest[];
  pending: DemoEmployeeRequest[];
  source: WorkspaceDataSource;
}) {
  const router = useRouter();
  const [selectedRequest, setSelectedRequest] = useState<DemoEmployeeRequest | null>(null);
  const [decisionReason, setDecisionReason] = useState('');
  const [actionError, setActionError] = useState<string | null>(null);
  const [submittingDecision, setSubmittingDecision] = useState<'approved' | 'rejected' | null>(
    null,
  );

  async function decide(decision: 'approved' | 'rejected') {
    if (!selectedRequest || source === 'demo' || submittingDecision) return;
    const reason = decisionReason.trim();
    if (decision === 'rejected' && reason.length < 10) {
      setActionError('Khi từ chối, lý do cần có ít nhất 10 ký tự.');
      return;
    }

    setActionError(null);
    setSubmittingDecision(decision);
    try {
      const client = createSupabaseBrowserClient();
      const { error } = await client.rpc('rpc_decide_employee_request', {
        p_request_id: selectedRequest.id,
        p_decision: decision,
        p_reason_private: reason,
        p_expected_version: selectedRequest.version,
        p_idempotency_key: `request-decision-${crypto.randomUUID()}`,
      });
      if (error) {
        setActionError(approvalErrorMessage(error));
        return;
      }
      setSelectedRequest(null);
      setDecisionReason('');
      router.refresh();
    } catch {
      setActionError('Không thể kết nối Supabase để cập nhật quyết định.');
    } finally {
      setSubmittingDecision(null);
    }
  }

  return (
    <>
      <section className="hr-summary-grid hr-summary-strip">
        <article>
          <span>Đang chờ</span>
          <strong>{pending.length}</strong>
          <small>Cần quyết định</small>
        </article>
        <article>
          <span>Cần bàn giao</span>
          <strong>
            {allRequests.filter((request) => request.coverage_state === 'pending').length}
          </strong>
          <small>Không chặn duyệt nghỉ</small>
        </article>
        <article>
          <span>Đã duyệt</span>
          <strong>{allRequests.filter((request) => request.status === 'approved').length}</strong>
          <small>Đã phản ánh availability</small>
        </article>
      </section>

      {source === 'demo' ? (
        <div className="hr-inline-note">Dữ liệu demo chỉ để xem; nút duyệt/từ chối được khóa.</div>
      ) : null}

      <section className="hr-approval-table-card hr-approval-table-compact">
        <div className="hr-approval-head">
          <span>Nhân sự</span>
          <span>Loại yêu cầu</span>
          <span>Thời gian</span>
          <span>Ảnh hưởng</span>
          <span>Trạng thái</span>
        </div>
        {pending.length === 0 ? (
          <div className="hr-empty-card hr-request-table-empty">Không có yêu cầu đang chờ.</div>
        ) : (
          pending.map((request) => (
            <button
              className="hr-approval-row hr-approval-row-button"
              key={request.id}
              onClick={() => {
                setActionError(null);
                setDecisionReason('');
                setSelectedRequest(request);
              }}
              type="button"
            >
              <div>
                <strong>{request.member_name}</strong>
                <small>Gửi {formatDateTime(request.submitted_at)}</small>
              </div>
              <span className="hr-approval-row-type">{requestTypeLabel(request.request_type)}</span>
              <span className="hr-approval-row-time">
                {formatDateTime(request.starts_at)} → {formatDateTime(request.ends_at)}
              </span>
              <span className="hr-approval-row-impact">{request.affected_minutes} phút</span>
              <StatusBadge tone="warning">Chờ duyệt</StatusBadge>
            </button>
          ))
        )}
      </section>

      <Drawer
        footer={
          <div className="hr-approval-drawer-actions">
            <Button
              disabled={source === 'demo' || Boolean(submittingDecision)}
              onClick={() => decide('rejected')}
              variant="danger"
            >
              {submittingDecision === 'rejected' ? 'Đang từ chối…' : 'Từ chối'}
            </Button>
            <Button
              disabled={source === 'demo' || Boolean(submittingDecision)}
              onClick={() => decide('approved')}
            >
              {submittingDecision === 'approved' ? 'Đang duyệt…' : 'Duyệt'}
            </Button>
          </div>
        }
        onClose={() => setSelectedRequest(null)}
        open={Boolean(selectedRequest)}
        size="compact"
        title={selectedRequest ? selectedRequest.member_name : 'Chi tiết phê duyệt'}
      >
        {selectedRequest ? (
          <div className="hr-request-detail-drawer">
            <div className="hr-request-detail-status">
              <StatusBadge tone="warning">Chờ duyệt</StatusBadge>
              <span>{requestTypeLabel(selectedRequest.request_type)}</span>
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
                <dt>Ảnh hưởng</dt>
                <dd>{selectedRequest.affected_minutes} phút</dd>
              </div>
              <div>
                <dt>Loại công</dt>
                <dd>{payTreatmentLabel(selectedRequest.pay_treatment)}</dd>
              </div>
              <div>
                <dt>Task ảnh hưởng</dt>
                <dd>{selectedRequest.impacted_task_count}</dd>
              </div>
            </dl>
            <section>
              <small>Lý do riêng tư · chỉ HR/capability phù hợp</small>
              <p>{selectedRequest.reason_private}</p>
            </section>
            <section>
              <small>Ghi chú bàn giao</small>
              <p>{selectedRequest.handover_note ?? 'Không có ghi chú'}</p>
            </section>
            <label className="hr-form-wide-field">
              <span>Lý do quyết định</span>
              <textarea
                disabled={Boolean(submittingDecision) || source === 'demo'}
                maxLength={2000}
                onChange={(event) => setDecisionReason(event.target.value)}
                placeholder="Bắt buộc tối thiểu 10 ký tự khi từ chối; có thể để trống khi duyệt."
                rows={3}
                value={decisionReason}
              />
            </label>
            {actionError ? (
              <div className="hr-form-alert" role="alert">
                {actionError}
              </div>
            ) : null}
          </div>
        ) : null}
      </Drawer>
    </>
  );
}
