import type { OrganizationContext, TaskListItem } from '@opsdesk/contracts';
import Link from 'next/link';
import { PriorityBadge, StatusBadge } from '../../components/ui';
import type { WorkspaceTaskItem } from '../../lib/demo/opsdesk-demo';
import {
  overviewAttentionTasks,
  overviewMetrics,
  overviewSellerSummary,
} from '../tasks/task-projections';

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

function attentionReason(task: WorkspaceTaskItem, nowMs: number) {
  if (task.blocked_at) return 'Đang bị vướng';
  if (task.status === 'in_review') return 'Đang chờ duyệt';
  if (new Date(task.due_at).getTime() < nowMs) return 'Đã quá hạn';
  return 'Cần theo dõi';
}

export function OverviewPanel({
  context,
  tasks,
}: {
  context: OrganizationContext;
  tasks: WorkspaceTaskItem[];
}) {
  const metrics = overviewMetrics(tasks, context);
  const attention = overviewAttentionTasks(tasks, context).slice(0, 6);
  const sellers = overviewSellerSummary(tasks, context);
  const nowMs = new Date(context.server_now).getTime();
  const cards = [
    {
      label: 'Hạn hôm nay',
      value: metrics.dueToday,
      note: 'Công việc chưa kết thúc có hạn trong ngày',
      href: '/tasks?due=today',
    },
    {
      label: 'Chưa xác nhận',
      value: metrics.unacknowledged,
      note: 'Công việc đang chờ người phụ trách nhận việc',
      href: '/tasks?view=unacknowledged',
    },
    {
      label: 'Cần xử lý',
      value: metrics.needsAttention,
      note: 'Đang chờ duyệt hoặc có vướng mắc',
      href: '/tasks',
    },
    {
      label: 'Quá hạn',
      value: metrics.overdue,
      note: 'Công việc chưa kết thúc đã quá thời hạn',
      href: '/tasks?view=overdue',
    },
  ];

  return (
    <section className="overview-stack" aria-labelledby="overview-operational-title">
      <div className="operational-section-heading">
        <div>
          <p className="workspace-eyebrow">Operational snapshot</p>
          <h2 id="overview-operational-title">Nhịp vận hành hiện tại</h2>
          <p>Tóm tắt trực tiếp từ công việc trong phạm vi quyền hiện tại.</p>
        </div>
        <Link className="text-link" href="/tasks">
          Mở tất cả công việc →
        </Link>
      </div>

      <div className="overview-kpi-grid">
        {cards.map((card) => (
          <Link className="overview-kpi-card" href={card.href} key={card.label}>
            <span>{card.label}</span>
            <strong>{card.value}</strong>
            <small>{card.note}</small>
          </Link>
        ))}
      </div>

      <div className="overview-main-grid">
        <section className="overview-card" aria-labelledby="overview-attention-title">
          <div className="overview-card-header">
            <div>
              <h3 id="overview-attention-title">Cần quản lý chú ý</h3>
              <p>Ưu tiên vướng mắc, chờ duyệt và công việc đã quá hạn.</p>
            </div>
            <span>{attention.length}</span>
          </div>

          {attention.length === 0 ? (
            <p className="overview-empty-copy">Chưa có công việc cần escalated trong lúc này.</p>
          ) : (
            <div className="overview-attention-list">
              {attention.map((task) => (
                <Link className="overview-attention-row" href={`/tasks/${task.id}`} key={task.id}>
                  <div className="overview-attention-main">
                    <span className="overview-task-kicker">
                      {task.task_number} · {task.seller_name ?? 'Nội bộ'}
                    </span>
                    <strong>{task.title}</strong>
                    <small>
                      {attentionReason(task, nowMs)} · Hạn {dueLabel(task.due_at, context.timezone)}
                    </small>
                  </div>
                  <div className="overview-attention-badges">
                    <PriorityBadge priority={task.priority} />
                    <StatusBadge tone={statusTone(task.status)}>
                      {statusLabels[task.status]}
                    </StatusBadge>
                  </div>
                </Link>
              ))}
            </div>
          )}
        </section>

        <section className="overview-card" aria-labelledby="overview-seller-title">
          <div className="overview-card-header">
            <div>
              <h3 id="overview-seller-title">Khối lượng theo seller</h3>
              <p>Chỉ dùng dữ liệu công việc thật/demo hiện có, không suy diễn doanh thu.</p>
            </div>
            <span>{sellers.length}</span>
          </div>

          <div className="overview-seller-list">
            {sellers.map((seller) => (
              <Link
                className="overview-seller-row"
                href={`/tasks?seller=${encodeURIComponent(seller.sellerId)}`}
                key={seller.sellerId}
              >
                <div>
                  <strong>{seller.sellerName}</strong>
                  <small>{seller.active} việc đang mở</small>
                </div>
                <div
                  className="overview-seller-stats"
                  aria-label={`Tình trạng ${seller.sellerName}`}
                >
                  <span>
                    <b>{seller.dueToday}</b>
                    <small>Hôm nay</small>
                  </span>
                  <span>
                    <b>{seller.needsAttention}</b>
                    <small>Cần xử lý</small>
                  </span>
                  <span>
                    <b>{seller.overdue}</b>
                    <small>Quá hạn</small>
                  </span>
                </div>
              </Link>
            ))}
          </div>
        </section>
      </div>

      <p className="overview-footnote">
        Dashboard hiện chỉ phản ánh trạng thái task. Doanh thu và chấm công sẽ chỉ xuất hiện khi có
        nguồn dữ liệu thật tương ứng.
      </p>
    </section>
  );
}
