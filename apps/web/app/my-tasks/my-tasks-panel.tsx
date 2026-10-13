'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import type { OrganizationContext, TaskListItem } from '@opsdesk/contracts';
import {
  Checkbox,
  EmptyState,
  Input,
  PriorityBadge,
  Select,
  StatusBadge,
} from '../../components/ui';
import type { WorkspaceDataSource, WorkspaceTaskItem } from '../../lib/demo/opsdesk-demo';
import { localDateInTimeZone } from '../tasks/task-timezone';
import type { MyTasksTabId } from '../tasks/task-projections';

type MyTaskProjection = Record<MyTasksTabId, WorkspaceTaskItem[]>;

const tabLabels: Record<MyTasksTabId, string> = {
  assigned: 'Được giao',
  collaborating: 'Tôi phối hợp',
  review: 'Cần tôi duyệt',
  created: 'Tôi đã giao',
};

const statusLabels: Record<TaskListItem['status'], string> = {
  todo: 'Chờ thực hiện',
  in_progress: 'Đang làm',
  in_review: 'Chờ duyệt',
  done: 'Hoàn thành',
  canceled: 'Đã hủy',
  waived: 'Đã miễn',
};

const dateOptions = [
  { value: 'today', label: 'Hôm nay' },
  { value: 'next7', label: '7 ngày tới' },
  { value: 'overdue', label: 'Quá hạn' },
  { value: 'future', label: 'Tương lai' },
];

const statusOptions = Object.entries(statusLabels).map(([value, label]) => ({ value, label }));
const priorityOptions = [
  { value: 'urgent', label: 'Khẩn cấp' },
  { value: 'high', label: 'Cao' },
  { value: 'normal', label: 'Bình thường' },
  { value: 'low', label: 'Thấp' },
];

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

function isTerminal(task: WorkspaceTaskItem) {
  return task.status === 'done' || task.status === 'canceled' || task.status === 'waived';
}

function matchesDateFilter(task: WorkspaceTaskItem, value: string, context: OrganizationContext) {
  if (!value) return true;
  const today = localDateInTimeZone(context.server_now, context.timezone);
  const dueDate = localDateInTimeZone(task.due_at, context.timezone);
  const nowMs = new Date(context.server_now).getTime();
  const dueMs = new Date(task.due_at).getTime();
  if (value === 'today') return dueDate === today || task.planned_date === today;
  if (value === 'overdue') return !isTerminal(task) && dueMs < nowMs;
  if (value === 'future') return dueDate > today || task.planned_date > today;
  if (value === 'next7') {
    const end = nowMs + 7 * 24 * 60 * 60 * 1000;
    return dueMs >= nowMs && dueMs <= end;
  }
  return true;
}

function TaskMobileCard({
  task,
  context,
}: {
  task: WorkspaceTaskItem;
  context: OrganizationContext;
}) {
  return (
    <article className="my-task-mobile-card">
      <div className="my-task-mobile-topline">
        <span>{task.task_number}</span>
        <StatusBadge tone={statusTone(task.status)}>{statusLabels[task.status]}</StatusBadge>
      </div>
      <Link href={`/tasks/${task.id}`}>{task.title}</Link>
      <div className="my-task-mobile-meta">
        <span>{task.seller_name ?? 'Nội bộ'}</span>
        <span>Hạn {dueLabel(task.due_at, context.timezone)}</span>
        <span>{task.assignee_name}</span>
      </div>
      <PriorityBadge priority={task.priority} />
    </article>
  );
}

export function MyTasksPanel({
  context,
  projection,
  sellers,
  source,
}: {
  context: OrganizationContext;
  projection: MyTaskProjection;
  sellers: Array<{ id: string; name: string }>;
  source: WorkspaceDataSource;
}) {
  const availableTabs: MyTasksTabId[] =
    context.role === 'employee'
      ? ['assigned', 'collaborating', 'review']
      : ['assigned', 'collaborating', 'review', 'created'];
  const [activeTab, setActiveTab] = useState<MyTasksTabId>('assigned');
  const [query, setQuery] = useState('');
  const [sellerId, setSellerId] = useState('');
  const [dateFilter, setDateFilter] = useState('');
  const [status, setStatus] = useState('');
  const [priority, setPriority] = useState('');
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [showFilters, setShowFilters] = useState(false);

  const filtered = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase('vi');
    return [...projection[activeTab]]
      .filter((task) => !sellerId || task.seller_id === sellerId)
      .filter((task) => !status || task.status === status)
      .filter((task) => !priority || task.priority === priority)
      .filter((task) => matchesDateFilter(task, dateFilter, context))
      .filter((task) => {
        if (!normalized) return true;
        return [
          task.task_number,
          task.title,
          task.seller_name,
          task.assignee_name,
          task.reviewer_name,
        ]
          .filter(Boolean)
          .some((value) => String(value).toLocaleLowerCase('vi').includes(normalized));
      })
      .sort((left, right) => new Date(left.due_at).getTime() - new Date(right.due_at).getTime());
  }, [activeTab, context, dateFilter, priority, projection, query, sellerId, status]);

  const acknowledgeable = filtered.filter(
    (task) =>
      activeTab === 'assigned' &&
      task.assignee_member_id === context.member_id &&
      task.status === 'todo' &&
      !task.acknowledged_at,
  );
  const selectedAcknowledgeable = acknowledgeable.filter((task) => selectedIds.includes(task.id));
  const allVisibleSelected =
    acknowledgeable.length > 0 && acknowledgeable.every((task) => selectedIds.includes(task.id));
  const activeTasks = projection.assigned.filter((task) => !isTerminal(task));
  const overdueCount = activeTasks.filter(
    (task) => new Date(task.due_at).getTime() < new Date(context.server_now).getTime(),
  ).length;
  const todayDate = localDateInTimeZone(context.server_now, context.timezone);
  const dueTodayCount = activeTasks.filter(
    (task) =>
      localDateInTimeZone(task.due_at, context.timezone) === todayDate ||
      task.planned_date === todayDate,
  ).length;

  function changeTab(tab: MyTasksTabId) {
    setActiveTab(tab);
    setSelectedIds([]);
  }

  function toggleAll(checked: boolean) {
    const ids = acknowledgeable.slice(0, 50).map((task) => task.id);
    setSelectedIds(checked ? ids : []);
  }

  return (
    <section className="task-list-section" aria-label="Danh sách công việc của tôi">
      <div className="my-tasks-summary-strip" aria-label="Tóm tắt công việc của tôi">
        <div>
          <strong>{activeTasks.length}</strong>
          <span>Đang mở</span>
        </div>
        <div>
          <strong>{dueTodayCount}</strong>
          <span>Hạn hôm nay</span>
        </div>
        <div>
          <strong>{overdueCount}</strong>
          <span>Quá hạn</span>
        </div>
        <div>
          <strong>{projection.review.length}</strong>
          <span>Cần tôi duyệt</span>
        </div>
      </div>

      <div className="task-filter-tabs" aria-label="Nhóm công việc của tôi">
        {availableTabs.map((tab) => (
          <button
            aria-pressed={activeTab === tab}
            className={
              activeTab === tab ? 'task-filter-tab task-filter-tab-active' : 'task-filter-tab'
            }
            key={tab}
            onClick={() => changeTab(tab)}
            type="button"
          >
            {tabLabels[tab]}
            <span>{projection[tab].length}</span>
          </button>
        ))}
      </div>

      <div className="my-tasks-command-bar">
        <div className="my-tasks-search">
          <Input
            aria-label="Tìm việc của tôi"
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Tìm công việc…"
            value={query}
          />
        </div>
        <button
          aria-expanded={showFilters}
          className={
            showFilters ? 'task-toolbar-button task-toolbar-button-active' : 'task-toolbar-button'
          }
          onClick={() => setShowFilters((value) => !value)}
          type="button"
        >
          Lọc
        </button>
      </div>

      {showFilters ? (
        <div className="my-tasks-filter-bar">
          <Select
            aria-label="Lọc seller"
            onChange={(event) => setSellerId(event.target.value)}
            options={sellers.map((seller) => ({ value: seller.id, label: seller.name }))}
            placeholder="Tất cả seller"
            value={sellerId}
          />
          <Select
            aria-label="Lọc ngày"
            onChange={(event) => setDateFilter(event.target.value)}
            options={dateOptions}
            placeholder="Tất cả ngày"
            value={dateFilter}
          />
          <Select
            aria-label="Lọc trạng thái"
            onChange={(event) => setStatus(event.target.value)}
            options={statusOptions}
            placeholder="Tất cả trạng thái"
            value={status}
          />
          <Select
            aria-label="Lọc ưu tiên"
            onChange={(event) => setPriority(event.target.value)}
            options={priorityOptions}
            placeholder="Tất cả ưu tiên"
            value={priority}
          />
        </div>
      ) : null}

      {selectedIds.length > 0 ? (
        <div className="task-selection-bar" role="status">
          <span>Đã chọn {selectedIds.length} việc.</span>
          <span className="task-selection-note">
            Chỉ các việc chưa nhận ở tab Được giao mới đủ điều kiện nhận hàng loạt; tối đa 50 việc.
          </span>
          <button className="task-inline-action" disabled type="button">
            {source === 'demo' ? 'Nhận việc đã chọn · Demo' : 'Nhận việc đã chọn · chờ DB P03C'}
          </button>
          <button
            className="task-inline-action task-inline-action-ghost"
            onClick={() => setSelectedIds([])}
            type="button"
          >
            Bỏ chọn
          </button>
        </div>
      ) : null}

      {source === 'demo' && activeTab === 'assigned' && acknowledgeable.length > 0 ? (
        <p className="task-demo-inline-note">
          Demo mode: có thể chọn các việc chưa nhận để kiểm tra UX, nhưng hệ thống không ghi trạng
          thái.
        </p>
      ) : null}

      {filtered.length === 0 ? (
        <EmptyState title="Không có công việc phù hợp">
          <p>Thử đổi tab hoặc bộ lọc để xem phạm vi công việc khác.</p>
        </EmptyState>
      ) : (
        <>
          <div className="task-table-wrap my-tasks-desktop-table">
            <table className="task-table">
              <thead>
                <tr>
                  <th className="task-table-check">
                    {activeTab === 'assigned' ? (
                      <Checkbox
                        aria-label="Chọn các việc chưa nhận đang hiển thị"
                        checked={allVisibleSelected}
                        className="task-checkbox-only"
                        label="Chọn các việc chưa nhận đang hiển thị"
                        onChange={(event) => toggleAll(event.target.checked)}
                      />
                    ) : null}
                  </th>
                  <th>Công việc</th>
                  <th>Người thực hiện</th>
                  <th>Seller</th>
                  <th>Hạn</th>
                  <th>Ưu tiên</th>
                  <th>Trạng thái</th>
                </tr>
              </thead>
              <tbody>
                {filtered.map((task) => {
                  const canSelect = acknowledgeable.some((item) => item.id === task.id);
                  return (
                    <tr key={task.id}>
                      <td className="task-table-check">
                        {canSelect ? (
                          <Checkbox
                            aria-label={`Chọn ${task.task_number}`}
                            checked={selectedIds.includes(task.id)}
                            className="task-checkbox-only"
                            label={`Chọn ${task.task_number}`}
                            onChange={(event) =>
                              setSelectedIds((current) =>
                                event.target.checked
                                  ? [...current.filter((id) => id !== task.id), task.id].slice(
                                      0,
                                      50,
                                    )
                                  : current.filter((id) => id !== task.id),
                              )
                            }
                          />
                        ) : null}
                      </td>
                      <td>
                        <Link className="task-title-link" href={`/tasks/${task.id}`}>
                          <span className="task-number">{task.task_number}</span>
                          <strong>{task.title}</strong>
                          <small>
                            Checklist {task.checklist_checked}/{task.checklist_total}
                          </small>
                        </Link>
                      </td>
                      <td>{task.assignee_name}</td>
                      <td>{task.seller_name ?? 'Nội bộ'}</td>
                      <td>
                        <span
                          className={
                            !isTerminal(task) &&
                            new Date(task.due_at).getTime() < new Date(context.server_now).getTime()
                              ? 'task-due task-due-overdue'
                              : 'task-due'
                          }
                        >
                          {dueLabel(task.due_at, context.timezone)}
                        </span>
                      </td>
                      <td>
                        <PriorityBadge priority={task.priority} />
                      </td>
                      <td>
                        <StatusBadge tone={statusTone(task.status)}>
                          {statusLabels[task.status]}
                        </StatusBadge>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="my-tasks-mobile-list">
            {filtered.map((task) => (
              <TaskMobileCard context={context} key={task.id} task={task} />
            ))}
          </div>
        </>
      )}

      {selectedAcknowledgeable.length > 50 ? (
        <p className="task-demo-inline-note">Chỉ 50 công việc đầu tiên được phép vào một batch.</p>
      ) : null}
    </section>
  );
}
