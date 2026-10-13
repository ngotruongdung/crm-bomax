import Link from 'next/link';
import {
  currentMonthStart,
  loadTimesheetView,
  normalizeTimesheetMonth,
  shiftTimesheetMonth,
} from '../../../lib/data/timesheet-data';
import { loadWorkspaceContext } from '../../../lib/data/workspace-data';
import { createDemoTimesheetViews } from '../../../lib/demo/timesheet-demo';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';

function units(value: number) {
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 4 }).format(value);
}

function duration(seconds: number) {
  const minutes = Math.round(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const remaining = minutes % 60;
  return hours > 0 ? `${hours}h ${String(remaining).padStart(2, '0')}p` : `${remaining}p`;
}

function time(value: string | null) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(value));
}

function date(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(`${value}T00:00:00+07:00`));
}

function stateLabel(state: 'ready' | 'provisional' | 'needs_review') {
  if (state === 'ready') return 'Đã phân loại';
  if (state === 'provisional') return 'Thiếu dữ liệu';
  return 'Cần đối soát';
}

function periodLabel(view: Awaited<ReturnType<typeof loadTimesheetView>>) {
  if (view.source === 'snapshot' || view.period_status === 'closed') {
    return `Đã chốt · revision ${view.revision}`;
  }
  if (view.period_status === 'reconciling') return `Đang đối soát · revision ${view.revision}`;
  if (view.period_status === 'reopened') return `Đã mở lại · revision ${view.revision}`;
  return `Tạm tính · revision ${view.revision}`;
}

export default async function MyTimesheetPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  try {
    const [{ context, source }, params] = await Promise.all([loadWorkspaceContext(), searchParams]);
    const monthStart = normalizeTimesheetMonth(context, params.month);

    const view =
      source === 'demo'
        ? createDemoTimesheetViews(context).find((item) => item.member_id === context.member_id)
        : await loadTimesheetView(context, context.member_id, monthStart);
    if (!view) throw new Error('DEMO_TIMESHEET_NOT_FOUND');
    const displayedMonthStart = source === 'demo' ? view.month_start : monthStart;
    const currentMonth = currentMonthStart(context);
    const previousMonth = shiftTimesheetMonth(displayedMonthStart, -1);
    const nextMonth = shiftTimesheetMonth(displayedMonthStart, 1);
    const canGoNext = nextMonth <= currentMonth;

    return (
      <WorkspaceShell
        activeSection="timesheet-me"
        context={context}
        description="Theo dõi công thực làm, nghỉ hưởng lương và các ngày cần đối soát theo dữ liệu đã xác minh."
        eyebrow="Timesheet"
        source={source}
        title="Công tháng của tôi"
      >
        <section className="timesheet-toolbar">
          <div className="timesheet-month-block">
            <span>Tháng</span>
            <div className="timesheet-month-switch">
              <Link
                aria-label="Tháng trước"
                href={`/timesheet/me?month=${previousMonth.slice(0, 7)}`}
              >
                ←
              </Link>
              <strong>{displayedMonthStart.slice(0, 7).split('-').reverse().join('/')}</strong>
              {canGoNext ? (
                <Link aria-label="Tháng sau" href={`/timesheet/me?month=${nextMonth.slice(0, 7)}`}>
                  →
                </Link>
              ) : (
                <span aria-hidden="true" className="timesheet-month-switch-disabled">
                  →
                </span>
              )}
            </div>
          </div>
          <span className="timesheet-status-pill">{periodLabel(view)}</span>
        </section>

        {source === 'demo' ? (
          <section className="timesheet-preview-note">
            <strong>Bản xem trước công thức P07</strong>
            <p>
              Số liệu bên dưới là dữ liệu mô phỏng để kiểm tra giao diện và phép tính, không phải
              lịch sử chấm công thật và không dùng để tính lương.
            </p>
          </section>
        ) : null}

        <section className="timesheet-summary-grid" aria-label="Tổng hợp công tháng">
          <article>
            <span>Công theo lịch</span>
            <strong>{units(view.totals.scheduled_units)}</strong>
            <small>{view.totals.scheduled_days} ngày có lịch</small>
          </article>
          <article>
            <span>Công thực làm</span>
            <strong>{units(view.totals.worked_units)}</strong>
            <small>{duration(view.totals.worked_seconds)}</small>
          </article>
          <article>
            <span>Nghỉ hưởng lương</span>
            <strong>{units(view.totals.paid_leave_units)}</strong>
            <small>Không gộp vào thực làm</small>
          </article>
          <article>
            <span>Nghỉ không lương</span>
            <strong>{units(view.totals.unpaid_leave_units)}</strong>
            <small>Không tự suy ra từ đơn nghỉ</small>
          </article>
          <article>
            <span>Cần đối soát</span>
            <strong>{view.totals.requires_reconciliation_days}</strong>
            <small>Thiếu data / conflict</small>
          </article>
        </section>

        <section className="timesheet-table-card">
          <div className="timesheet-day-head">
            <span>Ngày</span>
            <span>Ca</span>
            <span>Vào / Ra</span>
            <span>Thực làm</span>
            <span>Nghỉ</span>
            <span>Trạng thái</span>
            <span>Action</span>
          </div>
          {view.rows.map((row) => (
            <div className="timesheet-day-row" key={row.work_date}>
              <strong>{date(row.work_date)}</strong>
              <div>
                <span>{row.shift_label}</span>
                <small>{row.allowed_mode}</small>
              </div>
              <div>
                <span>
                  {time(row.first_check_in_at)} → {time(row.last_check_out_at)}
                </span>
                <small>{row.worked_remote_seconds > 0 ? 'Có giờ online' : 'Văn phòng'}</small>
              </div>
              <div>
                <span>{duration(row.worked_seconds)}</span>
                <small>{units(row.worked_units)} công</small>
              </div>
              <div>
                <span>
                  {row.paid_leave_seconds ? `${duration(row.paid_leave_seconds)} paid` : '—'}
                </span>
                <small>
                  {row.unpaid_leave_seconds ? `${duration(row.unpaid_leave_seconds)} unpaid` : '—'}
                </small>
              </div>
              <div>
                <span className={`timesheet-row-state timesheet-row-state-${row.state}`}>
                  {stateLabel(row.state)}
                </span>
                <small>
                  {row.exceptions.map((item) => item.code).join(', ') || 'Không có ngoại lệ'}
                </small>
              </div>
              <Link href={`/requests?type=attendance_correction&date=${row.work_date}`}>
                Điều chỉnh →
              </Link>
            </div>
          ))}
        </section>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/timesheet/me" />;
  }
}
