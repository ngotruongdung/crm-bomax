import Link from 'next/link';
import { loadAttendanceMonitorData } from '../../../lib/data/attendance-monitor-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';

function time(value: string | null, timezone: string) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('vi-VN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
    timeZone: timezone,
  }).format(new Date(value));
}

function rowMode(sessions: Array<{ mode: 'office' | 'remote' }>) {
  const modes = new Set(sessions.map((item) => item.mode));
  if (modes.has('office') && modes.has('remote')) return 'Hybrid';
  if (modes.has('remote')) return 'Online';
  if (modes.has('office')) return 'Văn phòng';
  return '—';
}

function rowState(
  day: Awaited<ReturnType<typeof loadAttendanceMonitorData>>['rows'][number]['day'],
) {
  if (!day.shift) return 'Không có ca';
  if (day.sessions.some((item) => item.status === 'open')) return 'Đang trong ca';
  if (day.sessions.some((item) => item.status === 'closed')) return 'Đã kết thúc';
  return 'Chưa chấm vào';
}

function rowExceptions(
  day: Awaited<ReturnType<typeof loadAttendanceMonitorData>>['rows'][number]['day'],
) {
  const issues: string[] = [];
  if (day.events.some((event) => event.verification_status === 'flagged'))
    issues.push('Event bị đánh dấu');
  if (day.sessions.some((session) => session.status === 'open')) issues.push('Chưa checkout');
  return issues;
}

export default async function AttendanceMonitorPage() {
  try {
    const { context, source, rows } = await loadAttendanceMonitorData();
    const canManageAttendance = context.capabilities.includes('can_manage_attendance');
    const scheduledRows = rows.filter((item) => Boolean(item.day.shift));
    const activeCount = rows.filter((item) =>
      item.day.sessions.some((session) => session.status === 'open'),
    ).length;
    const endedCount = rows.filter(
      (item) =>
        item.day.sessions.some((session) => session.status === 'closed') &&
        !item.day.sessions.some((session) => session.status === 'open'),
    ).length;
    const reviewCount = rows.filter((item) => rowExceptions(item.day).length > 0).length;

    return (
      <WorkspaceShell
        activeSection="attendance-monitor"
        context={context}
        description="Theo dõi trạng thái chấm công đã được xác thực, không dùng trạng thái online để suy diễn thời gian làm việc."
        eyebrow="Attendance monitor"
        source={source}
        title="Theo dõi chấm công"
      >
        {!canManageAttendance ? (
          <section className="hr-empty-card">Bạn không có capability theo dõi chấm công.</section>
        ) : (
          <>
            <section className="attendance-monitor-grid attendance-monitor-strip">
              <article>
                <span>Có ca</span>
                <strong>{scheduledRows.length}</strong>
                <small>Ca hôm nay trong scope</small>
              </article>
              <article>
                <span>Đang trong ca</span>
                <strong>{activeCount}</strong>
                <small>Chỉ từ session đã ghi</small>
              </article>
              <article>
                <span>Đã kết thúc</span>
                <strong>{endedCount}</strong>
                <small>Session đã đóng</small>
              </article>
              <article>
                <span>Cần đối soát</span>
                <strong>{reviewCount}</strong>
                <small>Thiếu checkout / event bị đánh dấu</small>
              </article>
            </section>

            {rows.length > 0 ? (
              <section className="attendance-monitor-table">
                <div className="attendance-monitor-head">
                  <span>Nhân sự</span>
                  <span>Hình thức</span>
                  <span>Chấm vào</span>
                  <span>Chấm ra</span>
                  <span>Trạng thái</span>
                  <span>Ngoại lệ</span>
                </div>
                {rows.map(({ member_id, member_name, employee_code, day }) => {
                  const firstSession = day.sessions[0];
                  const closedSessions = day.sessions.filter((session) => session.ends_at);
                  const lastSession = closedSessions.at(-1);
                  const exceptions = rowExceptions(day);
                  return (
                    <div className="attendance-monitor-row" key={member_id}>
                      <div>
                        <strong>{member_name}</strong>
                        <small>{employee_code}</small>
                      </div>
                      <span>{rowMode(day.sessions)}</span>
                      <span>{time(firstSession?.starts_at ?? null, context.timezone)}</span>
                      <span>{time(lastSession?.ends_at ?? null, context.timezone)}</span>
                      <span className="attendance-row-state">{rowState(day)}</span>
                      <span>{exceptions.join(', ') || '—'}</span>
                    </div>
                  );
                })}
              </section>
            ) : (
              <section className="attendance-empty-state">
                <strong>Chưa có dữ liệu chấm công để hiển thị</strong>
                <p>
                  Bảng này chỉ đọc ca, event và session thật trong Supabase. Evidence selfie vẫn mở
                  riêng theo capability và không hiển thị trực tiếp trong danh sách.
                </p>
                <Link href="/attendance">Xem trạng thái check-in an toàn →</Link>
              </section>
            )}
          </>
        )}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/attendance/monitor" />;
  }
}
