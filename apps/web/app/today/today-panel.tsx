import Link from 'next/link';
import type { OrganizationContext, TaskListItem } from '@opsdesk/contracts';
import { PriorityBadge, StatusBadge } from '../../components/ui';
import type { WorkspaceTaskItem } from '../../lib/demo/opsdesk-demo';
import type { TodayGroupId, TodayTaskGroups } from '../tasks/task-projections';

const groupMeta: Array<{
  id: TodayGroupId;
  title: string;
  description: string;
}> = [
  {
    id: 'new',
    title: 'Việc mới cần nhận',
    description: 'Việc mới đã hiển thị và cần xác nhận trước khi bắt đầu.',
  },
  {
    id: 'today',
    title: 'Cần xử lý hôm nay',
    description: 'Việc còn lại theo lịch hôm nay, hạn hôm nay hoặc đang thực hiện.',
  },
  {
    id: 'overdue',
    title: 'Quá hạn từ trước',
    description: 'Việc của bạn đã qua hạn và chưa ở trạng thái kết thúc.',
  },
  {
    id: 'waiting',
    title: 'Đang chờ / Bị vướng',
    description: 'Việc đang chờ duyệt hoặc có vướng mắc cần xử lý trước.',
  },
  {
    id: 'completed',
    title: 'Đã hoàn thành hôm nay',
    description: 'Thu gọn để bạn tập trung vào phần còn đang mở.',
  },
];

const statusLabels: Record<TaskListItem['status'], string> = {
  todo: 'Chờ thực hiện',
  in_progress: 'Đang làm',
  in_review: 'Chờ duyệt',
  done: 'Hoàn thành',
  canceled: 'Đã hủy',
  waived: 'Đã miễn',
};

function statusTone(status: TaskListItem['status']) {
  if (status === 'done') return 'success' as const;
  if (status === 'in_review') return 'warning' as const;
  if (status === 'canceled' || status === 'waived') return 'danger' as const;
  return 'neutral' as const;
}

function dueLabel(value: string, timeZone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function todayDateLabel(value: string, timeZone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    weekday: 'long',
    day: '2-digit',
    month: 'long',
    timeZone,
  }).format(new Date(value));
}

function quickActionLabel(task: WorkspaceTaskItem, context: OrganizationContext) {
  if (task.status === 'in_review') return 'Xem chờ duyệt';
  if (task.blocked_at) return 'Cập nhật';
  if (
    task.assignee_member_id === context.member_id &&
    task.status === 'todo' &&
    !task.acknowledged_at
  ) {
    return 'Nhận việc';
  }
  if (task.assignee_member_id === context.member_id && task.status === 'todo') return 'Bắt đầu';
  return 'Cập nhật';
}

function TodayTaskCard({
  task,
  context,
}: {
  task: WorkspaceTaskItem;
  context: OrganizationContext;
}) {
  return (
    <article className="today-task-card">
      <span
        className={
          task.status === 'done' ? 'today-task-state today-task-state-done' : 'today-task-state'
        }
        aria-hidden="true"
      />
      <div className="today-task-card-main">
        <div className="today-task-primary-line">
          <Link className="today-task-title" href={`/tasks/${task.id}`}>
            {task.title}
          </Link>
          <span className="task-number">{task.task_number}</span>
        </div>
        <div className="today-task-meta">
          <span>{task.seller_name ?? 'Nội bộ'}</span>
          <span>Hạn {dueLabel(task.due_at, context.timezone)}</span>
          <span>
            Checklist {task.checklist_checked}/{task.checklist_total}
          </span>
        </div>
      </div>

      <div className="today-task-card-side">
        <div className="today-task-badges">
          <PriorityBadge priority={task.priority} />
          <StatusBadge tone={statusTone(task.status)}>{statusLabels[task.status]}</StatusBadge>
        </div>
        <Link className="today-task-action" href={`/tasks/${task.id}`}>
          {quickActionLabel(task, context)}
        </Link>
      </div>
    </article>
  );
}

export function TodayPanel({
  context,
  groups,
}: {
  context: OrganizationContext;
  groups: TodayTaskGroups;
}) {
  const openCount = groupMeta
    .filter((group) => group.id !== 'completed')
    .reduce((total, group) => total + groups[group.id].length, 0);
  const urgentCount = [...groups.overdue, ...groups.today, ...groups.new].filter(
    (task) => task.priority === 'urgent' || task.priority === 'high',
  ).length;

  return (
    <div className="today-layout">
      <header className="today-focus-header">
        <div>
          <p className="workspace-eyebrow">My work</p>
          <p className="today-date-label">
            <time dateTime={context.server_now}>
              {todayDateLabel(context.server_now, context.timezone)}
            </time>
          </p>
        </div>
        <div className="today-focus-actions">
          <Link className="today-focus-link" href="/attendance">
            Chấm công
          </Link>
          <Link className="today-focus-link" href="/my-tasks">
            Tất cả việc của tôi →
          </Link>
        </div>
      </header>

      <div className="today-summary-strip" aria-label="Tóm tắt công việc hôm nay">
        <div>
          <strong>{openCount}</strong>
          <span>Cần làm</span>
        </div>
        <div>
          <strong>{groups.overdue.length}</strong>
          <span>Quá hạn</span>
        </div>
        <div>
          <strong>{groups.waiting.length}</strong>
          <span>Chờ duyệt / vướng</span>
        </div>
        <div>
          <strong>{urgentCount}</strong>
          <span>Ưu tiên cao</span>
        </div>
      </div>

      <div className="today-main-column">
        <div className="operational-section-heading">
          <div>
            <h2>Việc cần xử lý</h2>
            <p>Sắp theo nhóm hành động để bạn biết việc nào cần ưu tiên trước.</p>
          </div>
          <Link className="text-link" href="/my-tasks">
            Xem toàn bộ →
          </Link>
        </div>

        {openCount === 0 && groups.completed.length === 0 ? (
          <section className="workspace-empty-state operational-empty-state">
            <h2>Bạn chưa có công việc cần xử lý hôm nay.</h2>
            <p>Các công việc mới và lịch lặp sẽ xuất hiện tại đây.</p>
          </section>
        ) : (
          <div className="today-groups">
            {groupMeta.map((group) => {
              const items = groups[group.id];
              if (items.length === 0) return null;
              const content = (
                <div className="today-task-list">
                  {items.map((task) => (
                    <TodayTaskCard context={context} key={task.id} task={task} />
                  ))}
                </div>
              );

              if (group.id === 'completed') {
                return (
                  <details className="today-group today-group-collapsible" key={group.id}>
                    <summary>
                      <span>
                        <strong>{group.title}</strong>
                        <small>{group.description}</small>
                      </span>
                      <span>{items.length}</span>
                    </summary>
                    {content}
                  </details>
                );
              }

              return (
                <section className="today-group" key={group.id}>
                  <div className="today-group-heading">
                    <div>
                      <h3>{group.title}</h3>
                      <p>{group.description}</p>
                    </div>
                    <span>{items.length}</span>
                  </div>
                  {content}
                </section>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
