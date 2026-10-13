import type { OrganizationContext } from '@opsdesk/contracts';
import Link from 'next/link';
import {
  currentMonthStart,
  loadTimesheetRoster,
  normalizeTimesheetMonth,
  shiftTimesheetMonth,
} from '../../lib/data/timesheet-data';
import { loadWorkspaceContext } from '../../lib/data/workspace-data';
import { createDemoTimesheetViews } from '../../lib/demo/timesheet-demo';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { TimesheetPeriodActions } from './timesheet-period-actions';

function units(value: number) {
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 4 }).format(value);
}

function minutes(seconds: number) {
  return Math.round(seconds / 60).toLocaleString('vi-VN');
}

export default async function TimesheetsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  try {
    const [{ context, source }, params] = await Promise.all([loadWorkspaceContext(), searchParams]);
    const monthStart = normalizeTimesheetMonth(context, params.month);
    const canManage =
      context.role === 'admin' || context.capabilities.includes('can_manage_attendance');

    return (
      <WorkspaceShell
        activeSection="timesheets"
        context={context}
        description="Đối soát công tháng theo lịch lịch sử, attendance đã xác minh và loại nghỉ được duyệt."
        eyebrow="Timesheet · Reconciliation"
        source={source}
        title="Bảng công tháng"
      >
        {!canManage ? (
          <section className="hr-empty-card">
            Bạn không có quyền xem bảng công của nhân sự khác.
          </section>
        ) : (
          <TimesheetPreview context={context} demo={source === 'demo'} monthStart={monthStart} />
        )}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/timesheets" />;
  }
}

async function TimesheetPreview({
  context,
  demo,
  monthStart,
}: {
  context: OrganizationContext;
  demo: boolean;
  monthStart: string;
}) {
  const views = demo
    ? createDemoTimesheetViews(context)
    : await loadTimesheetRoster(context, monthStart);
  const representative = views[0];
  const displayedMonthStart = demo
    ? (representative?.month_start ?? currentMonthStart(context))
    : monthStart;
  const month = displayedMonthStart.slice(0, 7).split('-').reverse().join('/');
  const previousMonth = shiftTimesheetMonth(displayedMonthStart, -1);
  const nextMonth = shiftTimesheetMonth(displayedMonthStart, 1);
  const canGoNext = nextMonth <= currentMonthStart(context);
  const hasBlockingExceptions = views.some((view) => view.totals.requires_reconciliation_days > 0);

  return (
    <>
      <section className="timesheet-toolbar">
        <div className="timesheet-month-block">
          <span>Kỳ đối soát</span>
          <div className="timesheet-month-switch">
            <Link aria-label="Tháng trước" href={`/timesheets?month=${previousMonth.slice(0, 7)}`}>
              ←
            </Link>
            <strong>{month}</strong>
            {canGoNext ? (
              <Link aria-label="Tháng sau" href={`/timesheets?month=${nextMonth.slice(0, 7)}`}>
                →
              </Link>
            ) : (
              <span aria-hidden="true" className="timesheet-month-switch-disabled">
                →
              </span>
            )}
          </div>
        </div>
        <TimesheetPeriodActions
          demo={demo}
          hasBlockingExceptions={hasBlockingExceptions}
          isAdmin={context.role === 'admin'}
          monthStart={displayedMonthStart}
          organizationId={context.organization_id}
          periodId={representative?.period_id ?? null}
          periodRevision={representative?.revision ?? 1}
          periodStatus={representative?.period_status ?? 'open'}
          periodVersion={representative?.period_version ?? 1}
        />
      </section>

      {demo ? (
        <section className="timesheet-preview-note">
          <strong>Preview read-only</strong>
          <p>
            Đây là dữ liệu mô phỏng P07. Các nút ghi/chốt bị khóa cho đến khi migration, RLS và
            runtime Supabase được xác minh; chốt công không đồng nghĩa tính hay chi trả lương.
          </p>
        </section>
      ) : null}

      {views.length === 0 ? (
        <section className="hr-empty-card">Chưa có nhân sự active trong phạm vi bảng công.</section>
      ) : (
        <section className="timesheet-people-card">
          <div className="timesheet-people-head">
            <span>Mã</span>
            <span>Nhân sự</span>
            <span>Theo lịch</span>
            <span>Văn phòng</span>
            <span>Online</span>
            <span>Thực làm</span>
            <span>Paid</span>
            <span>Unpaid</span>
            <span>Thiếu data</span>
            <span>Trạng thái</span>
          </div>
          {views.map((view) => (
            <div className="timesheet-people-row" key={view.member_id}>
              <span>{view.employee_code}</span>
              <strong>{view.member_name}</strong>
              <span>{units(view.totals.scheduled_units)}</span>
              <span>{units(view.totals.worked_office_seconds / (480 * 60))}</span>
              <span>{units(view.totals.worked_remote_seconds / (480 * 60))}</span>
              <span>{units(view.totals.worked_units)}</span>
              <span>{units(view.totals.paid_leave_units)}</span>
              <span>{units(view.totals.unpaid_leave_units)}</span>
              <span>
                {view.totals.unknown_seconds ? `${minutes(view.totals.unknown_seconds)}p` : '—'}
              </span>
              <span className="timesheet-status-pill">
                {view.totals.requires_reconciliation_days > 0
                  ? `${view.totals.requires_reconciliation_days} ngày cần xem`
                  : 'Sẵn sàng'}
              </span>
            </div>
          ))}
        </section>
      )}
    </>
  );
}
