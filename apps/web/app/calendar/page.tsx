import Link from 'next/link';
import { loadTaskListData } from '../tasks/task-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import {
  createDemoRecurringTemplates,
  projectTemplateOccurrences,
} from '../../lib/demo/recurring-demo';
import { createDemoHrWorkspace } from '../../lib/demo/hr-demo';

function addDays(date: string, amount: number) {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year!, month! - 1, day! + amount)).toISOString().slice(0, 10);
}

function weekStart(date: string) {
  const [year, month, day] = date.split('-').map(Number);
  const value = new Date(Date.UTC(year!, month! - 1, day!));
  const weekday = value.getUTCDay();
  return addDays(date, weekday === 0 ? -6 : 1 - weekday);
}

function formatDay(date: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    weekday: 'short',
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(`${date}T00:00:00+07:00`));
}

function dateInHoChiMinh(value: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Ho_Chi_Minh',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(value));
  const fields = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${fields.year}-${fields.month}-${fields.day}`;
}

export default async function CalendarPage() {
  try {
    const { context, source, tasks } = await loadTaskListData({ includeTerminal: true });
    const today = context.server_now.slice(0, 10);
    const start = weekStart(today);
    const days = Array.from({ length: 7 }, (_, index) => addDays(start, index));
    const templates = createDemoRecurringTemplates(context);
    const hrDemo = source === 'demo' ? createDemoHrWorkspace(context) : null;
    const projected = templates.flatMap((template) =>
      projectTemplateOccurrences(template, start, 14).filter((item) => days.includes(item.date)),
    );

    return (
      <WorkspaceShell
        activeSection="calendar"
        context={context}
        description="Xem công việc thật và các lần Daily Task dự kiến trong cùng một tuần."
        eyebrow="Lịch vận hành"
        source={source}
        title="Lịch"
      >
        <section className="calendar-toolbar-card">
          <div className="calendar-toolbar-actions" aria-label="Điều hướng tuần">
            <button disabled type="button">
              ←
            </button>
            <button disabled type="button">
              Hôm nay
            </button>
            <button disabled type="button">
              →
            </button>
          </div>
          <div className="calendar-legend">
            <span>
              <i className="calendar-legend-solid" /> Công việc
            </span>
            <span>
              <i className="calendar-legend-dashed" /> Dự kiến
            </span>
            {hrDemo ? (
              <span>
                <i className="calendar-legend-availability" /> Availability
              </span>
            ) : null}
          </div>
        </section>

        <section className="calendar-week-grid" aria-label="Lịch tuần">
          {days.map((date) => {
            const dayTasks = tasks.filter((task) => task.planned_date === date);
            const dayProjected = projected.filter((item) => item.date === date);
            const dayAvailability = (hrDemo?.availability ?? []).filter(
              (item) => dateInHoChiMinh(item.starts_at) === date,
            );
            return (
              <article
                className={date === today ? 'calendar-day calendar-day-today' : 'calendar-day'}
                key={date}
              >
                <header>
                  <strong>{formatDay(date)}</strong>
                  {date === today ? <span>Hôm nay</span> : null}
                </header>
                <div className="calendar-day-items">
                  {dayTasks.map((task) => (
                    <Link
                      className="calendar-item calendar-item-real"
                      href={`/tasks/${task.id}`}
                      key={task.id}
                    >
                      <small>{task.due_at ? task.due_at.slice(11, 16) : '—'}</small>
                      <strong>{task.title}</strong>
                      <span>
                        {task.seller_name ?? 'Nội bộ'} · {task.assignee_name}
                      </span>
                    </Link>
                  ))}
                  {dayProjected.map((item) => (
                    <div className="calendar-item calendar-item-projected" key={item.id}>
                      <small>{item.due_time} · Dự kiến</small>
                      <strong>{item.title}</strong>
                      <span>
                        {item.seller_name ?? 'Nội bộ'} · {item.assignee_name ?? 'Chưa phân công'}
                      </span>
                    </div>
                  ))}
                  {dayAvailability.map((item) => (
                    <div className="calendar-item calendar-item-availability" key={item.request_id}>
                      <small>{item.label}</small>
                      <strong>{item.member_name}</strong>
                      <span>Chỉ hiển thị availability · không lộ lý do riêng tư</span>
                    </div>
                  ))}
                  {dayTasks.length === 0 &&
                  dayProjected.length === 0 &&
                  dayAvailability.length === 0 ? (
                    <span className="calendar-empty-day">Không có lịch</span>
                  ) : null}
                </div>
              </article>
            );
          })}
        </section>

        <p className="calendar-footnote">
          Mục “Dự kiến” là lần chiếu từ lịch lặp, chưa phải công việc thật nên không có thao tác
          hoàn thành.
        </p>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/calendar" />;
  }
}
