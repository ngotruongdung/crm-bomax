import { createDemoHrWorkspace } from '../../lib/demo/hr-demo';
import { loadWorkspaceContext } from '../../lib/data/workspace-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';

function formatDate(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(`${value}T00:00:00+07:00`));
}

function localDate(value: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(value));
  const fields = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${fields.year}-${fields.month}-${fields.day}`;
}

export default async function SchedulePage() {
  try {
    const { context, source } = await loadWorkspaceContext();
    const demo = createDemoHrWorkspace(context);
    const dates = [...new Set(demo.shifts.map((shift) => shift.work_date))];
    const members = [...new Map(demo.shifts.map((shift) => [shift.member_id, shift.member_name]))];

    if (source !== 'demo') {
      return (
        <WorkspaceShell
          activeSection="schedule"
          context={context}
          description="Ca làm việc là nền cho nghỉ theo giờ, availability và chấm công ở phase tiếp theo."
          eyebrow="Work schedule"
          source={source}
          title="Lịch làm việc"
        >
          <section className="hr-empty-card">
            P05 đã sẵn migration/RPC nhưng chưa nối lịch ca Supabase vào giao diện. Không hiển thị
            ca mẫu khi workspace đang dùng nguồn thật.
          </section>
        </WorkspaceShell>
      );
    }

    return (
      <WorkspaceShell
        activeSection="schedule"
        context={context}
        description="Ca làm việc là nền cho nghỉ theo giờ, availability và chấm công ở phase tiếp theo."
        eyebrow="Work schedule"
        source={source}
        title="Lịch làm việc"
      >
        <section className="hr-toolbar-card">
          <div>
            <strong>Ca hành chính mẫu</strong>
            <p>09:00–18:00 · nghỉ 12:00–13:00 · 480 phút làm việc · hình thức hybrid</p>
          </div>
          <span className="recurring-readonly-pill">ISO weekday · Asia/Ho_Chi_Minh</span>
        </section>

        <section className="hr-schedule-card">
          <div className="hr-schedule-head">
            <span>Nhân sự</span>
            {dates.map((date) => (
              <span key={date}>{formatDate(date)}</span>
            ))}
          </div>
          {members.map(([memberId, memberName]) => (
            <div className="hr-schedule-row" key={memberId}>
              <strong>{memberName}</strong>
              {dates.map((date) => {
                const shift = demo.shifts.find(
                  (row) => row.member_id === memberId && row.work_date === date,
                );
                const availability = demo.availability.find(
                  (row) => row.member_id === memberId && localDate(row.starts_at) === date,
                );
                return (
                  <div className="hr-shift-cell" key={date}>
                    <span>{shift ? '09:00–18:00' : 'Nghỉ'}</span>
                    {availability ? (
                      <small className={`hr-availability hr-availability-${availability.status}`}>
                        {availability.label}
                      </small>
                    ) : (
                      <small>{shift?.allowed_mode ?? '—'}</small>
                    )}
                  </div>
                );
              })}
            </div>
          ))}
        </section>

        <section className="hr-privacy-note">
          <strong>Privacy boundary</strong>
          <p>
            Lịch quản lý chỉ nhận trạng thái khả dụng tối thiểu. Lý do riêng tư, file bằng chứng và
            dữ liệu chấm công không được đưa vào availability row.
          </p>
        </section>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/schedule" />;
  }
}
