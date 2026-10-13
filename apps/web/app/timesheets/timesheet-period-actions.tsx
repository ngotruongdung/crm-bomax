'use client';

import type { TimesheetPeriodStatus } from '@opsdesk/contracts';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Textarea } from '../../components/ui';

type PendingAction = 'close' | 'reopen' | null;
type BusyAction = 'reconcile' | 'close' | 'reopen' | null;
type ErrorPayload = { error?: { code?: unknown } };
type ExportJobPayload = {
  ok?: boolean;
  data?: {
    id?: string;
    file_id?: string | null;
    status?: 'queued' | 'processing' | 'ready' | 'failed' | 'expired';
  };
  error?: { code?: unknown };
};

const statusLabels: Record<TimesheetPeriodStatus, string> = {
  open: 'Đang mở',
  reconciling: 'Đang đối soát',
  closed: 'Đã chốt',
  reopened: 'Đã mở lại',
};

function responseErrorMessage(payload: ErrorPayload, fallback: string) {
  const code = typeof payload.error?.code === 'string' ? payload.error.code : '';
  if (code.includes('VERSION_CONFLICT')) {
    return 'Kỳ công vừa thay đổi. Hãy tải lại dữ liệu rồi thực hiện lại.';
  }
  if (code.includes('TIMESHEET_BLOCKING_EXCEPTIONS')) {
    return 'Chưa thể chốt vì vẫn còn ngày thiếu dữ liệu hoặc cần đối soát.';
  }
  if (code.includes('TIMESHEET_ADMIN_PERMISSION_REQUIRED')) {
    return 'Chỉ quản trị viên mới được chốt hoặc mở lại kỳ công.';
  }
  if (code.includes('TIMESHEET_HR_PERMISSION_REQUIRED')) {
    return 'Bạn không có quyền bắt đầu đối soát kỳ công này.';
  }
  if (code.includes('TIMESHEET_NOT_RECONCILING')) {
    return 'Kỳ công chưa ở trạng thái có thể chốt.';
  }
  if (code.includes('PERIOD_CLOSED')) return 'Kỳ công này đã được chốt.';
  if (code.includes('TIMESHEET_NOT_CLOSED')) return 'Chỉ kỳ công đã chốt mới có thể mở lại.';
  return fallback;
}

export function TimesheetPeriodActions({
  demo,
  hasBlockingExceptions,
  isAdmin,
  monthStart,
  organizationId,
  periodId,
  periodRevision,
  periodStatus,
  periodVersion,
}: {
  demo: boolean;
  hasBlockingExceptions: boolean;
  isAdmin: boolean;
  monthStart: string;
  organizationId: string;
  periodId: string | null;
  periodRevision: number;
  periodStatus: TimesheetPeriodStatus;
  periodVersion: number;
}) {
  const router = useRouter();
  const inFlightRef = useRef(false);
  const idempotencyRef = useRef<{ fingerprint: string; key: string } | null>(null);
  const [busyAction, setBusyAction] = useState<BusyAction>(null);
  const [pendingAction, setPendingAction] = useState<PendingAction>(null);
  const [reopenReason, setReopenReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [awaitingRefresh, setAwaitingRefresh] = useState(false);
  const [exportBusy, setExportBusy] = useState(false);

  useEffect(() => {
    setAwaitingRefresh(false);
  }, [periodStatus, periodVersion]);

  const actionsLocked = demo || Boolean(busyAction) || awaitingRefresh || exportBusy;
  const canReconcile = !actionsLocked && (periodStatus === 'open' || periodStatus === 'reopened');
  const canClose =
    !actionsLocked &&
    isAdmin &&
    !hasBlockingExceptions &&
    (periodStatus === 'reconciling' || periodStatus === 'reopened');
  const canReopen = !actionsLocked && isAdmin && periodStatus === 'closed' && Boolean(periodId);

  async function runCommand(action: Exclude<BusyAction, null>, reason?: string) {
    if (demo || inFlightRef.current) return;
    if (action === 'reopen' && !periodId) {
      setError('Kỳ công chưa có định danh để mở lại.');
      return;
    }

    const normalizedReason = reason?.trim() ?? '';
    const fingerprint = JSON.stringify({ action, periodVersion, normalizedReason });
    if (!idempotencyRef.current || idempotencyRef.current.fingerprint !== fingerprint) {
      idempotencyRef.current = { fingerprint, key: crypto.randomUUID() };
    }

    inFlightRef.current = true;
    setBusyAction(action);
    setError(null);
    setNotice(null);
    try {
      const endpoint =
        action === 'reconcile'
          ? '/api/timesheets/reconcile'
          : action === 'close'
            ? '/api/timesheets/close'
            : '/api/timesheets/reopen';
      const body =
        action === 'reopen'
          ? {
              organization_id: organizationId,
              period_id: periodId,
              reason: normalizedReason,
              expected_version: periodVersion,
              idempotency_key: idempotencyRef.current.key,
            }
          : {
              organization_id: organizationId,
              month_start: monthStart,
              expected_version: periodVersion,
              idempotency_key: idempotencyRef.current.key,
            };
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      const payload = (await response.json().catch(() => ({}))) as ErrorPayload;
      if (!response.ok) {
        setError(
          responseErrorMessage(
            payload,
            action === 'reconcile'
              ? 'Không thể bắt đầu đối soát kỳ công.'
              : action === 'close'
                ? 'Không thể chốt kỳ công.'
                : 'Không thể mở lại kỳ công.',
          ),
        );
        return;
      }

      idempotencyRef.current = null;
      setPendingAction(null);
      setReopenReason('');
      setAwaitingRefresh(true);
      setNotice(
        action === 'reconcile'
          ? 'Đã chuyển kỳ công sang trạng thái đối soát.'
          : action === 'close'
            ? 'Đã chốt kỳ công. Dữ liệu nguồn không bị sửa.'
            : 'Đã mở lại kỳ công để tiếp tục đối soát.',
      );
      router.refresh();
    } catch {
      setError('Không thể kết nối tới server timesheet. Vui lòng thử lại.');
    } finally {
      inFlightRef.current = false;
      setBusyAction(null);
    }
  }

  async function exportTimesheet() {
    if (demo || exportBusy) return;
    setExportBusy(true);
    setError(null);
    setNotice(null);
    try {
      const response = await fetch('/api/exports', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          organization_id: organizationId,
          export_kind: 'timesheet',
          format: 'csv',
          parameters: {
            month_start: monthStart,
            period_id: periodId,
            revision: periodRevision,
            source: periodStatus === 'closed' ? 'snapshot' : 'live',
          },
          idempotency_key: crypto.randomUUID(),
        }),
      });
      const created = (await response.json().catch(() => ({}))) as ExportJobPayload;
      const jobId = created.data?.id;
      if (!response.ok || !jobId) {
        const code = typeof created.error?.code === 'string' ? created.error.code : '';
        setError(
          code === 'EXPORT_SCOPE_DENIED'
            ? 'Bạn không có quyền xuất dữ liệu trong phạm vi này.'
            : code === 'RETENTION_POLICY_REQUIRED'
              ? 'Workspace chưa cấu hình retention cho file export.'
              : 'Không thể tạo yêu cầu xuất bảng công.',
        );
        return;
      }

      for (let attempt = 0; attempt < 8; attempt += 1) {
        if (attempt > 0) await new Promise((resolve) => setTimeout(resolve, 1200));
        const statusResponse = await fetch(`/api/exports/${jobId}`, { cache: 'no-store' });
        const statusPayload = (await statusResponse.json().catch(() => ({}))) as ExportJobPayload;
        if (!statusResponse.ok) break;
        if (statusPayload.data?.status === 'failed' || statusPayload.data?.status === 'expired') {
          setError('Job export không hoàn tất. Vui lòng thử lại sau.');
          return;
        }
        if (statusPayload.data?.status === 'ready' && statusPayload.data.file_id) {
          const downloadResponse = await fetch(
            `/api/files/${statusPayload.data.file_id}/download`,
            { cache: 'no-store' },
          );
          const downloadPayload = (await downloadResponse.json().catch(() => ({}))) as {
            data?: { url?: string };
          };
          if (!downloadResponse.ok || !downloadPayload.data?.url) {
            setError('File đã tạo nhưng chưa thể cấp link tải an toàn.');
            return;
          }
          setNotice('File bảng công đã sẵn sàng. Trình duyệt đang tải xuống.');
          window.location.assign(downloadPayload.data.url);
          return;
        }
      }

      setNotice('Đã xếp hàng xuất bảng công. File sẽ sẵn sàng khi worker xử lý job.');
    } catch {
      setError('Không thể kết nối tới dịch vụ export. Vui lòng thử lại.');
    } finally {
      setExportBusy(false);
    }
  }

  return (
    <div className="timesheet-period-actions-wrap">
      <div className="timesheet-period-meta">
        <span>Trạng thái</span>
        <strong>{statusLabels[periodStatus]}</strong>
      </div>
      <div className="timesheet-toolbar-actions">
        <button disabled={actionsLocked} onClick={() => void exportTimesheet()} type="button">
          {exportBusy ? 'Đang chuẩn bị…' : 'Xuất CSV'}
        </button>
        <button disabled={!canReconcile} onClick={() => void runCommand('reconcile')} type="button">
          {busyAction === 'reconcile'
            ? 'Đang xử lý…'
            : periodStatus === 'reopened'
              ? 'Đối soát lại'
              : 'Đối soát'}
        </button>
        {periodStatus === 'closed' ? (
          <button disabled={!canReopen} onClick={() => setPendingAction('reopen')} type="button">
            Mở lại tháng
          </button>
        ) : (
          <button
            data-emphasis="primary"
            disabled={!canClose}
            onClick={() => setPendingAction('close')}
            title={hasBlockingExceptions ? 'Còn ngày cần đối soát' : undefined}
            type="button"
          >
            Chốt tháng
          </button>
        )}
      </div>

      {pendingAction === 'close' ? (
        <div className="timesheet-action-panel" role="dialog" aria-label="Xác nhận chốt kỳ công">
          <div>
            <strong>Chốt kỳ công tháng này?</strong>
            <p>
              Hệ thống sẽ tạo snapshot bất biến cho revision hiện tại. Đây chỉ là chốt công, không
              phải tính hoặc chi trả lương.
            </p>
          </div>
          <div className="timesheet-action-panel-buttons">
            <button onClick={() => setPendingAction(null)} type="button">
              Hủy
            </button>
            <button
              data-emphasis="primary"
              disabled={Boolean(busyAction)}
              onClick={() => void runCommand('close')}
              type="button"
            >
              {busyAction === 'close' ? 'Đang chốt…' : 'Xác nhận chốt'}
            </button>
          </div>
        </div>
      ) : null}

      {pendingAction === 'reopen' ? (
        <div className="timesheet-action-panel" role="dialog" aria-label="Mở lại kỳ công">
          <div>
            <strong>Mở lại kỳ công</strong>
            <p>
              Nhập lý do để lưu vào lịch sử audit. Snapshot đã chốt trước đó vẫn được giữ nguyên.
            </p>
          </div>
          <Textarea
            label="Lý do mở lại"
            maxLength={1000}
            onChange={(event) => setReopenReason(event.target.value)}
            rows={3}
            value={reopenReason}
          />
          <div className="timesheet-action-panel-buttons">
            <button onClick={() => setPendingAction(null)} type="button">
              Hủy
            </button>
            <button
              data-emphasis="primary"
              disabled={Boolean(busyAction) || reopenReason.trim().length < 3}
              onClick={() => void runCommand('reopen', reopenReason)}
              type="button"
            >
              {busyAction === 'reopen' ? 'Đang mở lại…' : 'Xác nhận mở lại'}
            </button>
          </div>
        </div>
      ) : null}

      {error ? (
        <p className="timesheet-action-feedback timesheet-action-feedback-error" role="alert">
          {error}
        </p>
      ) : null}
      {notice ? (
        <p className="timesheet-action-feedback" role="status">
          {notice}
        </p>
      ) : null}
    </div>
  );
}
