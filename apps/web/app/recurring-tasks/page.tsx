import { loadTaskListData } from '../tasks/task-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import {
  createDemoRecurringTemplates,
  formatScheduleLabel,
  projectTemplateOccurrences,
  type RecurringTaskTemplate,
} from '../../lib/demo/recurring-demo';
import { StatusBadge } from '../../components/ui';

function statusLabel(template: RecurringTaskTemplate) {
  if (template.status === 'active') return { label: 'Đang chạy', tone: 'success' as const };
  if (template.status === 'paused') return { label: 'Tạm dừng', tone: 'warning' as const };
  if (template.status === 'needs_attention') return { label: 'Cần xử lý', tone: 'danger' as const };
  return { label: 'Đã kết thúc', tone: 'neutral' as const };
}

function formatDateTime(date: string, time: string) {
  const formatted = new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
  }).format(new Date(`${date}T00:00:00+07:00`));
  return `${formatted} · ${time}`;
}

export default async function RecurringTasksPage() {
  try {
    const { context, source } = await loadTaskListData({ includeTerminal: true });
    const templates = createDemoRecurringTemplates(context);
    const today = context.server_now.slice(0, 10);

    return (
      <WorkspaceShell
        activeSection="recurring-tasks"
        context={context}
        description="Quản lý các mẫu Daily Task. Mỗi lần chạy sẽ tạo một công việc độc lập với kết quả và lịch sử riêng."
        eyebrow="Daily Task"
        source={source}
        title="Lịch công việc"
      >
        <section className="recurring-toolbar-card">
          <div>
            <strong>{templates.length} mẫu lịch</strong>
            <p>Tạm dừng chỉ ngừng tạo lần mới; các công việc đã tạo vẫn được giữ nguyên.</p>
          </div>
          <span className="recurring-readonly-pill">Demo · chỉ xem</span>
        </section>

        <section className="recurring-table-card" aria-label="Danh sách lịch công việc">
          <div className="recurring-table-head">
            <span>Tên mẫu</span>
            <span>Seller</span>
            <span>Lịch lặp</span>
            <span>Người phụ trách</span>
            <span>Lần tiếp theo</span>
            <span>Trạng thái</span>
          </div>
          {templates.map((template) => {
            const status = statusLabel(template);
            const nextOccurrence = projectTemplateOccurrences(template, today, 1)[0];
            return (
              <article className="recurring-table-row" key={template.id}>
                <div className="recurring-title-cell">
                  <strong>{template.title}</strong>
                  <small>Mỗi lần thực hiện là một task riêng</small>
                </div>
                <span>{template.seller_name ?? 'Nội bộ'}</span>
                <span>{formatScheduleLabel(template.schedule)}</span>
                <span>{template.assignee_name ?? 'Theo người phụ trách seller'}</span>
                <span>
                  {nextOccurrence
                    ? formatDateTime(nextOccurrence.date, nextOccurrence.due_time)
                    : '—'}
                </span>
                <StatusBadge tone={status.tone}>{status.label}</StatusBadge>
              </article>
            );
          })}
        </section>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/recurring-tasks" />;
  }
}
