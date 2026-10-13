import type { TimesheetView } from '@opsdesk/contracts';
import Link from 'next/link';
import { attendanceDiagnosticFor } from '../../lib/attendance/attendance-policy';
import { loadTimesheetView } from '../../lib/data/timesheet-data';
import { loadWorkspaceContext } from '../../lib/data/workspace-data';
import { createDemoTimesheetViews } from '../../lib/demo/timesheet-demo';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { WebOfficeAttendance } from './web-office-attendance';

function dateInTimezone(value: string, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(value));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function formatDay(value: string, timezone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
    timeZone: timezone,
  }).format(new Date(`${value}T00:00:00+07:00`));
}

function formatTime(value: string | null, timezone: string) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: timezone,
  }).format(new Date(value));
}

function duration(seconds: number) {
  const minutes = Math.round(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const remaining = minutes % 60;
  return hours > 0 ? `${hours}h ${String(remaining).padStart(2, '0')}p` : `${remaining}p`;
}

function units(value: number) {
  return new Intl.NumberFormat('vi-VN', { maximumFractionDigits: 2 }).format(value);
}

function rowMode(row: TimesheetView['rows'][number]) {
  if (row.worked_office_seconds > 0 && row.worked_remote_seconds > 0) return 'Hybrid';
  if (row.worked_remote_seconds > 0) return 'Online';
  if (row.worked_office_seconds > 0) return 'Văn phòng';
  return 'Chưa xác định';
}

function rowState(row: TimesheetView['rows'][number] | undefined) {
  if (!row?.first_check_in_at) return { label: 'Chưa chấm vào', tone: 'warning' };
  if (!row.last_check_out_at) return { label: 'Đang trong ca', tone: 'active' };
  if (row.state === 'needs_review' || row.state === 'provisional') {
    return { label: 'Cần đối soát', tone: 'warning' };
  }
  return { label: 'Đã kết thúc', tone: 'ready' };
}

export default async function AttendancePage() {
  try {
    const { context, source } = await loadWorkspaceContext();
    const view =
      source === 'demo'
        ? createDemoTimesheetViews(context).find((item) => item.member_id === context.member_id)
        : await loadTimesheetView(context);
    if (!view) throw new Error('ATTENDANCE_TIMESHEET_NOT_FOUND');

    const today = dateInTimezone(context.server_now, context.timezone);
    const todayRow = view.rows.find((row) => row.work_date === today);
    const state = rowState(todayRow);
    const recentRows = view.rows
      .filter((row) => row.work_date <= today)
      .slice(-7)
      .reverse();
    const serverDiagnostic = attendanceDiagnosticFor('SERVER_UNAVAILABLE');

    return (
      <WorkspaceShell
        activeSection="attendance"
        context={context}
        description="Ca hôm nay, trạng thái chấm công đã xác minh và lịch sử gần đây trong một màn hình."
        eyebrow="Attendance"
        source={source}
        title="Chấm công"
      >
        <section className="attendance-today-card">
          <div className="attendance-today-heading">
            <div>
              <p className="workspace-eyebrow">Ca hôm nay</p>
              <h2>{todayRow?.shift_label ?? 'Chưa có ca được ghi nhận'}</h2>
              <p>{formatDay(today, context.timezone)} · Timestamp do máy chủ xác nhận</p>
            </div>
            <span className={`attendance-state-pill attendance-state-pill-${state.tone}`}>
              {state.label}
            </span>
          </div>
          <div className="attendance-today-stats">
            <div>
              <span>Hình thức</span>
              <strong>{todayRow ? rowMode(todayRow) : '—'}</strong>
            </div>
            <div>
              <span>Chấm vào</span>
              <strong>{formatTime(todayRow?.first_check_in_at ?? null, context.timezone)}</strong>
            </div>
            <div>
              <span>Chấm ra</span>
              <strong>{formatTime(todayRow?.last_check_out_at ?? null, context.timezone)}</strong>
            </div>
            <div>
              <span>Thực làm</span>
              <strong>{todayRow ? duration(todayRow.worked_seconds) : '—'}</strong>
            </div>
          </div>
        </section>

        <section className="attendance-action-list" aria-label="Phương thức chấm công">
          <article>
            <div>
              <strong>Tại văn phòng</strong>
              <span>Wi‑Fi công ty + public IP tin cậy + timestamp máy chủ</span>
            </div>
            <WebOfficeAttendance
              enabled={source === 'supabase'}
              organizationId={context.organization_id}
              timezone={context.timezone}
            />
          </article>
          <article>
            <div>
              <strong>Làm online</strong>
              <span>
                Yêu cầu remote đã duyệt + ảnh camera điện thoại được tải lên private storage
              </span>
            </div>
            <div className="attendance-action-buttons">
              <span className="attendance-mobile-note">
                Mở OpsDesk trên điện thoại để chụp và tải ảnh lên
              </span>
            </div>
          </article>
        </section>

        <section className="attendance-month-strip" aria-label="Tạm tính công tháng">
          <article>
            <span>Công thực làm</span>
            <strong>{units(view.totals.worked_units)}</strong>
          </article>
          <article>
            <span>Nghỉ hưởng lương</span>
            <strong>{units(view.totals.paid_leave_units)}</strong>
          </article>
          <article>
            <span>Nghỉ không lương</span>
            <strong>{units(view.totals.unpaid_leave_units)}</strong>
          </article>
          <article>
            <span>Cần đối soát</span>
            <strong>{view.totals.requires_reconciliation_days}</strong>
          </article>
        </section>

        <section className="attendance-history-card">
          <div className="attendance-history-title">
            <div>
              <strong>Lịch sử gần đây</strong>
              <span>Tối đa 7 ngày có dữ liệu trong kỳ hiện tại</span>
            </div>
            <Link href="/timesheet/me">Xem bảng công tháng →</Link>
          </div>
          <div className="attendance-history-head">
            <span>Ngày</span>
            <span>Hình thức</span>
            <span>Chấm vào</span>
            <span>Chấm ra</span>
            <span>Thực làm</span>
            <span>Trạng thái</span>
          </div>
          {recentRows.length === 0 ? (
            <div className="attendance-history-empty">Chưa có lịch sử chấm công trong kỳ này.</div>
          ) : (
            recentRows.map((row) => {
              const historyState = rowState(row);
              return (
                <div className="attendance-history-row" key={row.work_date}>
                  <strong>{formatDay(row.work_date, context.timezone)}</strong>
                  <span>{rowMode(row)}</span>
                  <span>{formatTime(row.first_check_in_at, context.timezone)}</span>
                  <span>{formatTime(row.last_check_out_at, context.timezone)}</span>
                  <span>{duration(row.worked_seconds)}</span>
                  <span
                    className={`attendance-row-state attendance-row-state-${historyState.tone}`}
                  >
                    {historyState.label}
                  </span>
                </div>
              );
            })
          )}
        </section>

        <section className="attendance-safety-note">
          <div>
            <strong>Chấm công Wi‑Fi trên web</strong>
            <span>
              Cần admin bật tính năng, cấu hình public IP/CIDR của Wi‑Fi văn phòng và triển khai qua
              ingress tin cậy. Website không tự đọc SSID/BSSID.
            </span>
          </div>
          <div>
            <strong>{serverDiagnostic.title}</strong>
            <span>{serverDiagnostic.description}</span>
            <Link href="/requests">{serverDiagnostic.action} →</Link>
          </div>
        </section>

        {source === 'demo' ? (
          <p className="calendar-footnote">
            Dữ liệu trên là preview read-only. Nút ghi chấm công vẫn khóa cho đến khi flow Wi‑Fi,
            camera private và challenge/finalize được nối runtime thật.
          </p>
        ) : null}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/attendance" />;
  }
}
