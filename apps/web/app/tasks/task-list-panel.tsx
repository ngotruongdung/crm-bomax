'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import type { MemberDirectoryEntry, OrganizationContext, TaskListItem } from '@opsdesk/contracts';
import {
  Button,
  Checkbox,
  Drawer,
  EmptyState,
  Input,
  PersonLabel,
  PriorityBadge,
  Select,
  StatusBadge,
} from '../../components/ui';
import type { WorkspaceDataSource } from '../../lib/demo/opsdesk-demo';
import { TaskCreateForm } from './task-create-form';
import type { TaskSellerOption } from './task-data';
import { localDateInTimeZone } from './task-timezone';
import { serializeTaskListFilters, type TaskListFilters } from './task-projections';

type SavedFilter = 'all' | 'unacknowledged' | 'due_soon' | 'overdue' | 'review' | 'blocked';
type TaskViewMode = 'list' | 'board' | 'calendar';
type TaskGroupMode = 'none' | 'status' | 'seller' | 'assignee' | 'due' | 'priority';
type TaskSortMode = 'default' | 'due_asc' | 'due_desc' | 'priority';

type VisibleColumns = {
  assignee: boolean;
  seller: boolean;
  priority: boolean;
  status: boolean;
};

const savedFilters: Array<{ id: SavedFilter; label: string }> = [
  { id: 'all', label: 'Tất cả' },
  { id: 'unacknowledged', label: 'Chưa nhận' },
  { id: 'due_soon', label: 'Sắp đến hạn' },
  { id: 'overdue', label: 'Quá hạn' },
  { id: 'review', label: 'Chờ duyệt' },
  { id: 'blocked', label: 'Bị vướng' },
];

const statusLabels: Record<TaskListItem['status'], string> = {
  todo: 'Chờ thực hiện',
  in_progress: 'Đang làm',
  in_review: 'Chờ duyệt',
  done: 'Hoàn thành',
  canceled: 'Đã hủy',
  waived: 'Đã miễn',
};

const priorityRank: Record<TaskListItem['priority'], number> = {
  urgent: 0,
  high: 1,
  normal: 2,
  low: 3,
};

const priorityLabels: Record<TaskListItem['priority'], string> = {
  urgent: 'Khẩn cấp',
  high: 'Cao',
  normal: 'Bình thường',
  low: 'Thấp',
};

const calendarWeekdays = ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];

function statusTone(status: TaskListItem['status']) {
  if (status === 'done') return 'success' as const;
  if (status === 'in_review') return 'warning' as const;
  if (status === 'canceled' || status === 'waived') return 'danger' as const;
  return 'neutral' as const;
}

function dateTimeLabel(value: string, timeZone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

function calendarMonthLabel(month: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(`${month}-01T12:00:00Z`));
}

function calendarDays(month: string) {
  const [yearPart = '1970', monthPart = '01'] = month.split('-');
  const year = Number(yearPart);
  const calendarMonth = Number(monthPart);
  const firstDay = new Date(Date.UTC(year, calendarMonth - 1, 1));
  const firstWeekday = (firstDay.getUTCDay() + 6) % 7;
  const lastDay = new Date(Date.UTC(year, calendarMonth, 0));
  const lastWeekday = (lastDay.getUTCDay() + 6) % 7;
  const count = firstWeekday + lastDay.getUTCDate() + (6 - lastWeekday);
  const startMs = Date.UTC(year, calendarMonth - 1, 1 - firstWeekday);

  return Array.from({ length: count }, (_, index) => {
    const date = new Date(startMs + index * 24 * 60 * 60 * 1000);
    const iso = date.toISOString().slice(0, 10);
    return {
      iso,
      day: date.getUTCDate(),
      isCurrentMonth: iso.startsWith(month),
    };
  });
}

function shiftCalendarMonth(month: string, amount: number) {
  const [yearPart = '1970', monthPart = '01'] = month.split('-');
  const year = Number(yearPart);
  const calendarMonth = Number(monthPart);
  const date = new Date(Date.UTC(year, calendarMonth - 1 + amount, 1));
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}`;
}

function groupDueLabel(task: TaskListItem, timeZone: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    timeZone,
  }).format(new Date(task.due_at));
}

function matchesSavedFilter(task: TaskListItem, filter: SavedFilter, nowMs: number) {
  const dueMs = new Date(task.due_at).getTime();
  const terminal = task.status === 'done' || task.status === 'canceled' || task.status === 'waived';
  if (filter === 'unacknowledged') return task.status === 'todo' && !task.acknowledged_at;
  if (filter === 'due_soon')
    return !terminal && dueMs >= nowMs && dueMs <= nowMs + 48 * 60 * 60 * 1000;
  if (filter === 'overdue') return !terminal && dueMs < nowMs;
  if (filter === 'review') return task.status === 'in_review';
  if (filter === 'blocked') return Boolean(task.blocked_at);
  return true;
}

function matchesDueFilter(
  task: TaskListItem,
  filter: TaskListFilters['due'],
  context: OrganizationContext,
) {
  if (!filter) return true;
  const nowMs = new Date(context.server_now).getTime();
  const dueMs = new Date(task.due_at).getTime();
  const terminal = task.status === 'done' || task.status === 'canceled' || task.status === 'waived';
  if (filter === 'overdue') return !terminal && dueMs < nowMs;
  if (filter === 'today') {
    return (
      localDateInTimeZone(task.due_at, context.timezone) ===
      localDateInTimeZone(context.server_now, context.timezone)
    );
  }
  if (filter === 'next7') {
    return dueMs >= nowMs && dueMs <= nowMs + 7 * 24 * 60 * 60 * 1000;
  }
  return true;
}

export function TaskListPanel({
  context,
  initialFilters,
  members,
  sellers,
  source,
  tasks,
}: {
  context: OrganizationContext;
  initialFilters: TaskListFilters;
  members: MemberDirectoryEntry[];
  sellers: TaskSellerOption[];
  source: WorkspaceDataSource;
  tasks: TaskListItem[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const [isCreateOpen, setCreateOpen] = useState(false);
  const [savedFilter, setSavedFilter] = useState<SavedFilter>(initialFilters.saved);
  const [query, setQuery] = useState(initialFilters.query);
  const [sellerId, setSellerId] = useState(initialFilters.seller);
  const [assigneeId, setAssigneeId] = useState(initialFilters.assignee);
  const [reviewerId, setReviewerId] = useState(initialFilters.reviewer);
  const [dueFilter, setDueFilter] = useState<TaskListFilters['due']>(initialFilters.due);
  const [status, setStatus] = useState<TaskListFilters['status']>(initialFilters.status);
  const [priority, setPriority] = useState<TaskListFilters['priority']>(initialFilters.priority);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [viewMode, setViewMode] = useState<TaskViewMode>(initialFilters.view);
  const [groupMode, setGroupMode] = useState<TaskGroupMode>(initialFilters.group);
  const [sortMode, setSortMode] = useState<TaskSortMode>(initialFilters.sort);
  const [calendarMonth, setCalendarMonth] = useState(
    initialFilters.month || localDateInTimeZone(context.server_now, context.timezone).slice(0, 7),
  );
  const [showFilters, setShowFilters] = useState(
    Boolean(
      initialFilters.seller ||
        initialFilters.assignee ||
        initialFilters.reviewer ||
        initialFilters.due ||
        initialFilters.status ||
        initialFilters.priority,
    ),
  );
  const [visibleColumns, setVisibleColumns] = useState<VisibleColumns>({
    assignee: true,
    seller: true,
    priority: true,
    status: true,
  });

  const nowMs = new Date(context.server_now).getTime();
  const currentFilters = useMemo<TaskListFilters>(
    () => ({
      assignee: assigneeId,
      due: dueFilter,
      priority,
      query,
      reviewer: reviewerId,
      saved: savedFilter,
      seller: sellerId,
      group: groupMode,
      month: viewMode === 'calendar' ? calendarMonth : '',
      sort: sortMode,
      status,
      view: viewMode,
    }),
    [
      assigneeId,
      calendarMonth,
      dueFilter,
      groupMode,
      priority,
      query,
      reviewerId,
      savedFilter,
      sellerId,
      sortMode,
      status,
      viewMode,
    ],
  );

  useEffect(() => {
    const queryString = serializeTaskListFilters(currentFilters);
    const nextUrl = queryString ? `${pathname}?${queryString}` : pathname;
    window.history.replaceState(window.history.state, '', nextUrl);
  }, [currentFilters, pathname]);

  const filteredTasks = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase('vi');
    return tasks.filter((task) => {
      if (!matchesSavedFilter(task, savedFilter, nowMs)) return false;
      if (sellerId && task.seller_id !== sellerId) return false;
      if (assigneeId && task.assignee_member_id !== assigneeId) return false;
      if (reviewerId && task.reviewer_member_id !== reviewerId) return false;
      if (status && task.status !== status) return false;
      if (priority && task.priority !== priority) return false;
      if (!matchesDueFilter(task, dueFilter, context)) return false;
      if (!normalizedQuery) return true;
      return [
        task.task_number,
        task.title,
        task.seller_name,
        task.assignee_name,
        task.reviewer_name,
      ]
        .filter(Boolean)
        .some((value) => String(value).toLocaleLowerCase('vi').includes(normalizedQuery));
    });
  }, [
    assigneeId,
    context,
    dueFilter,
    nowMs,
    priority,
    query,
    reviewerId,
    savedFilter,
    sellerId,
    status,
    tasks,
  ]);

  const displayTasks = useMemo(() => {
    const next = [...filteredTasks];
    if (sortMode === 'due_asc') {
      next.sort((a, b) => new Date(a.due_at).getTime() - new Date(b.due_at).getTime());
    } else if (sortMode === 'due_desc') {
      next.sort((a, b) => new Date(b.due_at).getTime() - new Date(a.due_at).getTime());
    } else if (sortMode === 'priority') {
      next.sort((a, b) => priorityRank[a.priority] - priorityRank[b.priority]);
    }
    return next;
  }, [filteredTasks, sortMode]);

  const groupedTasks = useMemo(() => {
    if (groupMode === 'none') {
      return [{ key: 'all', label: '', tasks: displayTasks }];
    }

    const groups = new Map<string, { key: string; label: string; tasks: TaskListItem[] }>();
    for (const task of displayTasks) {
      const group =
        groupMode === 'status'
          ? { key: task.status, label: statusLabels[task.status] }
          : groupMode === 'seller'
            ? { key: task.seller_id || 'internal', label: task.seller_name || 'Công việc nội bộ' }
            : groupMode === 'assignee'
              ? {
                  key: task.assignee_member_id || 'unassigned',
                  label: task.assignee_name || 'Chưa giao',
                }
              : groupMode === 'due'
                ? {
                    key: localDateInTimeZone(task.due_at, context.timezone),
                    label: groupDueLabel(task, context.timezone),
                  }
                : { key: task.priority, label: priorityLabels[task.priority] };
      const key = group.key;
      const label = group.label;
      const current = groups.get(key) ?? { key, label, tasks: [] };
      current.tasks.push(task);
      groups.set(key, current);
    }
    return Array.from(groups.values());
  }, [context.timezone, displayTasks, groupMode]);

  const calendarTasksByDate = useMemo(() => {
    const groups = new Map<string, TaskListItem[]>();
    for (const task of displayTasks) {
      const key = localDateInTimeZone(task.due_at, context.timezone);
      groups.set(key, [...(groups.get(key) ?? []), task]);
    }
    return groups;
  }, [context.timezone, displayTasks]);

  const visibleCalendarDays = useMemo(() => calendarDays(calendarMonth), [calendarMonth]);
  const today = localDateInTimeZone(context.server_now, context.timezone);

  const allVisibleSelected =
    displayTasks.length > 0 && displayTasks.every((task) => selectedIds.includes(task.id));

  function toggleVisible(checked: boolean) {
    const visibleIds = displayTasks.slice(0, 50).map((task) => task.id);
    setSelectedIds((current) =>
      checked
        ? Array.from(new Set([...current, ...visibleIds])).slice(0, 50)
        : current.filter((id) => !visibleIds.includes(id)),
    );
  }

  function renderTaskTable(tableTasks: TaskListItem[]) {
    return (
      <div className="task-table-wrap">
        <table className="task-table">
          <thead>
            <tr>
              <th className="task-table-check">
                <Checkbox
                  aria-label="Chọn toàn bộ công việc đang hiển thị"
                  checked={allVisibleSelected}
                  className="task-checkbox-only"
                  label="Chọn toàn bộ công việc đang hiển thị"
                  onChange={(event) => toggleVisible(event.target.checked)}
                />
              </th>
              <th>Công việc</th>
              {visibleColumns.assignee ? <th>Người thực hiện</th> : null}
              {visibleColumns.seller ? <th>Seller</th> : null}
              <th>Hạn</th>
              {visibleColumns.priority ? <th>Ưu tiên</th> : null}
              {visibleColumns.status ? <th>Trạng thái</th> : null}
            </tr>
          </thead>
          <tbody>
            {tableTasks.map((task) => {
              const overdue =
                new Date(task.due_at).getTime() < nowMs &&
                !['done', 'canceled', 'waived'].includes(task.status);
              return (
                <tr key={task.id}>
                  <td className="task-table-check">
                    <Checkbox
                      aria-label={`Chọn ${task.task_number}`}
                      checked={selectedIds.includes(task.id)}
                      className="task-checkbox-only"
                      label={`Chọn ${task.task_number}`}
                      onChange={(event) =>
                        setSelectedIds((current) =>
                          event.target.checked
                            ? [...current.filter((id) => id !== task.id), task.id].slice(0, 50)
                            : current.filter((id) => id !== task.id),
                        )
                      }
                    />
                  </td>
                  <td>
                    <Link className="task-title-link" href={`/tasks/${task.id}`}>
                      <span className="task-number">{task.task_number}</span>
                      <strong>{task.title}</strong>
                      <small>
                        Checklist {task.checklist_checked}/{task.checklist_total}
                        {task.blocked_at ? ' · Có vướng mắc' : ''}
                      </small>
                    </Link>
                  </td>
                  {visibleColumns.assignee ? (
                    <td>
                      <PersonLabel
                        name={task.assignee_name}
                        role={task.reviewer_name ? `Duyệt: ${task.reviewer_name}` : undefined}
                      />
                    </td>
                  ) : null}
                  {visibleColumns.seller ? <td>{task.seller_name ?? 'Nội bộ'}</td> : null}
                  <td>
                    <span className={overdue ? 'task-due task-due-overdue' : 'task-due'}>
                      {dateTimeLabel(task.due_at, context.timezone)}
                    </span>
                  </td>
                  {visibleColumns.priority ? (
                    <td>
                      <PriorityBadge priority={task.priority} />
                    </td>
                  ) : null}
                  {visibleColumns.status ? (
                    <td>
                      <StatusBadge tone={statusTone(task.status)}>
                        {statusLabels[task.status]}
                      </StatusBadge>
                    </td>
                  ) : null}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    );
  }

  return (
    <section className="task-list-section" aria-labelledby="task-list-title">
      <div className="task-section-header">
        <div>
          <p className="workspace-eyebrow">Task core</p>
          <h2 id="task-list-title">Danh sách công việc</h2>
          <p>{tasks.length} công việc đang hiển thị trong phạm vi quyền hiện tại.</p>
        </div>
        <Button onClick={() => setCreateOpen(true)}>Giao việc</Button>
      </div>

      <div className="task-filter-tabs" aria-label="Bộ lọc nhanh">
        {savedFilters.map((filter) => (
          <button
            aria-pressed={savedFilter === filter.id}
            className={
              savedFilter === filter.id
                ? 'task-filter-tab task-filter-tab-active'
                : 'task-filter-tab'
            }
            key={filter.id}
            onClick={() => setSavedFilter(filter.id)}
            type="button"
          >
            {filter.label}
            <span>{tasks.filter((task) => matchesSavedFilter(task, filter.id, nowMs)).length}</span>
          </button>
        ))}
      </div>

      <div className="task-command-bar">
        <div className="task-view-switcher" role="group" aria-label="Kiểu hiển thị công việc">
          {(
            [
              ['list', 'Danh sách'],
              ['board', 'Bảng'],
              ['calendar', 'Lịch'],
            ] as const
          ).map(([id, label]) => (
            <button
              aria-pressed={viewMode === id}
              className={
                viewMode === id ? 'task-view-button task-view-button-active' : 'task-view-button'
              }
              key={id}
              onClick={() => setViewMode(id)}
              type="button"
            >
              {label}
            </button>
          ))}
        </div>

        <div className="task-command-actions">
          <div className="task-command-search">
            <Input
              aria-label="Tìm công việc"
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Tìm công việc…"
              value={query}
            />
          </div>
          <Button
            aria-expanded={showFilters}
            onClick={() => setShowFilters((value) => !value)}
            variant="ghost"
          >
            Lọc
          </Button>

          <details className="task-command-menu">
            <summary>Nhóm</summary>
            <div className="task-command-menu-popover">
              {(
                [
                  ['none', 'Không nhóm'],
                  ['status', 'Theo trạng thái'],
                  ['seller', 'Theo seller'],
                  ['assignee', 'Theo người thực hiện'],
                  ['due', 'Theo hạn'],
                  ['priority', 'Theo ưu tiên'],
                ] as const
              ).map(([id, label]) => (
                <button
                  aria-pressed={groupMode === id}
                  key={id}
                  onClick={() => setGroupMode(id)}
                  type="button"
                >
                  {label}
                </button>
              ))}
            </div>
          </details>

          <details className="task-command-menu">
            <summary>Sắp xếp</summary>
            <div className="task-command-menu-popover">
              {(
                [
                  ['default', 'Mặc định'],
                  ['due_asc', 'Hạn gần nhất'],
                  ['due_desc', 'Hạn xa nhất'],
                  ['priority', 'Ưu tiên cao trước'],
                ] as const
              ).map(([id, label]) => (
                <button
                  aria-pressed={sortMode === id}
                  key={id}
                  onClick={() => setSortMode(id)}
                  type="button"
                >
                  {label}
                </button>
              ))}
            </div>
          </details>

          <details className="task-command-menu">
            <summary>Trường</summary>
            <div className="task-command-menu-popover task-fields-menu">
              {(
                [
                  ['assignee', 'Người thực hiện'],
                  ['seller', 'Seller'],
                  ['priority', 'Ưu tiên'],
                  ['status', 'Trạng thái'],
                ] as const
              ).map(([key, label]) => (
                <label key={key}>
                  <input
                    checked={visibleColumns[key]}
                    onChange={(event) =>
                      setVisibleColumns((current) => ({ ...current, [key]: event.target.checked }))
                    }
                    type="checkbox"
                  />
                  <span>{label}</span>
                </label>
              ))}
            </div>
          </details>
        </div>
      </div>

      {showFilters ? (
        <div className="task-filter-bar">
          <Select
            aria-label="Lọc seller"
            onChange={(event) => setSellerId(event.target.value)}
            options={sellers.map((seller) => ({ value: seller.id, label: seller.name }))}
            placeholder="Tất cả seller"
            value={sellerId}
          />
          <Select
            aria-label="Lọc người thực hiện"
            onChange={(event) => setAssigneeId(event.target.value)}
            options={members.map((member) => ({
              value: member.member_id,
              label: member.display_name,
            }))}
            placeholder="Tất cả nhân sự"
            value={assigneeId}
          />
          <Select
            aria-label="Lọc người duyệt"
            onChange={(event) => setReviewerId(event.target.value)}
            options={members
              .filter((member) => member.role !== 'employee')
              .map((member) => ({ value: member.member_id, label: member.display_name }))}
            placeholder="Tất cả người duyệt"
            value={reviewerId}
          />
          <Select
            aria-label="Lọc thời hạn"
            onChange={(event) => setDueFilter(event.target.value as TaskListFilters['due'])}
            options={[
              { value: 'today', label: 'Hạn hôm nay' },
              { value: 'next7', label: '7 ngày tới' },
              { value: 'overdue', label: 'Đã quá hạn' },
            ]}
            placeholder="Tất cả thời hạn"
            value={dueFilter}
          />
          <Select
            aria-label="Lọc trạng thái"
            onChange={(event) => setStatus(event.target.value as TaskListFilters['status'])}
            options={Object.entries(statusLabels).map(([value, label]) => ({ value, label }))}
            placeholder="Tất cả trạng thái"
            value={status}
          />
          <Select
            aria-label="Lọc ưu tiên"
            onChange={(event) => setPriority(event.target.value as TaskListFilters['priority'])}
            options={[
              { value: 'urgent', label: 'Khẩn cấp' },
              { value: 'high', label: 'Cao' },
              { value: 'normal', label: 'Bình thường' },
              { value: 'low', label: 'Thấp' },
            ]}
            placeholder="Tất cả ưu tiên"
            value={priority}
          />
        </div>
      ) : null}

      {selectedIds.length > 0 ? (
        <div className="task-selection-bar" role="status">
          <span>Đã chọn {selectedIds.length} công việc.</span>
          <span className="task-selection-note">
            Checkbox chỉ dùng để chọn dòng; chưa thực hiện thay đổi hàng loạt.
          </span>
          <Button onClick={() => setSelectedIds([])} variant="ghost">
            Bỏ chọn
          </Button>
        </div>
      ) : null}

      {displayTasks.length === 0 ? (
        <EmptyState title="Không có công việc phù hợp">
          <p>Thử đổi bộ lọc hoặc tạo công việc mới.</p>
        </EmptyState>
      ) : viewMode === 'list' ? (
        <div className="task-list-groups">
          {groupedTasks.map((group) => (
            <section className="task-list-group" key={group.key}>
              {group.label ? (
                <div className="task-list-group-heading">
                  <strong>{group.label}</strong>
                  <span>{group.tasks.length}</span>
                </div>
              ) : null}
              {renderTaskTable(group.tasks)}
            </section>
          ))}
          <button className="task-quick-add-row" onClick={() => setCreateOpen(true)} type="button">
            <span aria-hidden="true">＋</span> Thêm công việc
          </button>
        </div>
      ) : viewMode === 'board' ? (
        <div className="task-board" aria-label="Bảng công việc theo trạng thái">
          {Object.entries(statusLabels).map(([statusKey, label]) => {
            const columnTasks = displayTasks.filter((task) => task.status === statusKey);
            return (
              <section className="task-board-column" key={statusKey}>
                <div className="task-board-column-heading">
                  <strong>{label}</strong>
                  <span>{columnTasks.length}</span>
                </div>
                <div className="task-board-cards">
                  {columnTasks.map((task) => (
                    <Link className="task-board-card" href={`/tasks/${task.id}`} key={task.id}>
                      <span className="task-number">{task.task_number}</span>
                      <strong>{task.title}</strong>
                      <small>
                        {task.seller_name ?? 'Nội bộ'} · {task.assignee_name ?? 'Chưa giao'}
                      </small>
                      <span className="task-board-card-footer">
                        <span>{dateTimeLabel(task.due_at, context.timezone)}</span>
                        <PriorityBadge priority={task.priority} />
                      </span>
                    </Link>
                  ))}
                  <button
                    className="task-board-add"
                    onClick={() => setCreateOpen(true)}
                    type="button"
                  >
                    ＋ Thêm công việc
                  </button>
                </div>
              </section>
            );
          })}
        </div>
      ) : (
        <div
          className="task-calendar"
          aria-label={`Lịch công việc ${calendarMonthLabel(calendarMonth)}`}
        >
          <div className="task-calendar-toolbar">
            <div>
              <p className="workspace-eyebrow">Lịch công việc</p>
              <h3>{calendarMonthLabel(calendarMonth)}</h3>
            </div>
            <div className="task-calendar-controls">
              <button
                aria-label="Tháng trước"
                onClick={() => setCalendarMonth((month) => shiftCalendarMonth(month, -1))}
                type="button"
              >
                ‹
              </button>
              <button
                onClick={() =>
                  setCalendarMonth(
                    localDateInTimeZone(context.server_now, context.timezone).slice(0, 7),
                  )
                }
                type="button"
              >
                Hôm nay
              </button>
              <button
                aria-label="Tháng sau"
                onClick={() => setCalendarMonth((month) => shiftCalendarMonth(month, 1))}
                type="button"
              >
                ›
              </button>
            </div>
          </div>

          <div className="task-calendar-scroll">
            <div className="task-calendar-weekdays" aria-hidden="true">
              {calendarWeekdays.map((weekday) => (
                <span key={weekday}>{weekday}</span>
              ))}
            </div>
            <div className="task-calendar-grid">
              {visibleCalendarDays.map((day) => {
                const dateTasks = calendarTasksByDate.get(day.iso) ?? [];
                const visibleTasks = dateTasks.slice(0, 3);
                const remainingTasks = dateTasks.length - visibleTasks.length;
                return (
                  <section
                    className={
                      day.isCurrentMonth
                        ? day.iso === today
                          ? 'task-calendar-day-cell task-calendar-day-today'
                          : 'task-calendar-day-cell'
                        : 'task-calendar-day-cell task-calendar-day-outside'
                    }
                    key={day.iso}
                  >
                    <span className="task-calendar-date-number">{day.day}</span>
                    {day.isCurrentMonth ? (
                      <div className="task-calendar-day-tasks">
                        {visibleTasks.map((task) => (
                          <Link
                            aria-label={`${dateTimeLabel(task.due_at, context.timezone)}: ${task.title}`}
                            className="task-calendar-chip"
                            href={`/tasks/${task.id}`}
                            key={task.id}
                          >
                            <span>
                              {dateTimeLabel(task.due_at, context.timezone).split(' ')[1] ?? ''}
                            </span>
                            <strong>{task.title}</strong>
                            <small>{task.seller_name ?? 'Nội bộ'}</small>
                          </Link>
                        ))}
                        {remainingTasks > 0 ? (
                          <span className="task-calendar-more">+{remainingTasks} việc khác</span>
                        ) : null}
                      </div>
                    ) : null}
                  </section>
                );
              })}
            </div>
          </div>
        </div>
      )}

      <Drawer
        onClose={() => setCreateOpen(false)}
        open={isCreateOpen}
        size="compact"
        title="Giao công việc"
      >
        <div className="task-create-drawer-intro">
          <p>
            Chọn người phụ trách, seller và thời hạn. Các thông tin còn lại có thể bổ sung khi cần.
          </p>
        </div>
        <TaskCreateForm
          context={context}
          members={members}
          mode="drawer"
          onCancel={() => setCreateOpen(false)}
          onCreated={(taskId) => {
            setCreateOpen(false);
            router.push(`/tasks/${taskId}`);
          }}
          sellers={sellers}
          source={source}
        />
      </Drawer>
    </section>
  );
}
