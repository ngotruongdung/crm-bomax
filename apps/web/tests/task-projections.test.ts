import { describe, expect, it } from 'vitest';
import { createDemoOrganizationContext, createDemoTasks } from '../lib/demo/opsdesk-demo';
import {
  groupTodayTasks,
  overviewAttentionTasks,
  overviewMetrics,
  overviewSellerSummary,
  parseTaskListFilters,
  projectMyTasks,
  serializeTaskListFilters,
} from '../app/tasks/task-projections';

const serverNow = '2026-10-04T13:56:00.000Z';

describe('P03C task projections', () => {
  it('groups Today tasks by precedence without overlap', () => {
    const context = createDemoOrganizationContext(serverNow);
    const groups = groupTodayTasks(createDemoTasks(context), context);
    const allIds = Object.values(groups).flatMap((tasks) => tasks.map((task) => task.id));

    expect(new Set(allIds).size).toBe(allIds.length);
    expect(groups.waiting.map((task) => task.task_number)).toEqual(['TASK-1030', 'TASK-1031']);
    expect(groups.overdue.map((task) => task.task_number)).toEqual(['TASK-1024']);
    expect(groups.new.map((task) => task.task_number)).toEqual(['TASK-1028']);
    expect(groups.today.map((task) => task.task_number)).toEqual(['TASK-1029']);
    expect(groups.completed.map((task) => task.task_number)).toEqual(['TASK-1027']);
    expect(allIds.some((id) => id.endsWith('000000000007'))).toBe(false);
  });

  it('TASK-17 keeps a task planned for today in Today even when its due date is tomorrow', () => {
    const context = createDemoOrganizationContext(serverNow);
    const demoTasks = createDemoTasks(context);
    const todayTask = demoTasks[0]!;
    const tomorrowTask = demoTasks.find((task) => task.task_number === 'TASK-1032')!;
    const plannedTodayDueTomorrow = {
      ...todayTask,
      id: '83000000-0000-0000-0000-000000000017',
      task_number: 'TASK-17-REGRESSION',
      status: 'todo' as const,
      planned_date: todayTask.planned_date,
      due_at: tomorrowTask.due_at,
      original_due_at: tomorrowTask.original_due_at,
      acknowledged_at: todayTask.assigned_at ?? context.server_now,
    };

    const groups = groupTodayTasks([plannedTodayDueTomorrow], context);

    expect(groups.today.map((task) => task.task_number)).toEqual(['TASK-17-REGRESSION']);
    expect(groups.new).toHaveLength(0);
  });

  it('projects role-aware My Tasks tabs', () => {
    const context = createDemoOrganizationContext(serverNow);
    const tabs = projectMyTasks(createDemoTasks(context), context);

    expect(tabs.assigned.some((task) => task.task_number === 'TASK-1034')).toBe(true);
    expect(tabs.collaborating.map((task) => task.task_number)).toContain('TASK-1033');
    expect(tabs.review.map((task) => task.task_number)).toContain('TASK-1031');
    expect(tabs.created.map((task) => task.task_number)).toContain('TASK-1032');
  });

  it('computes only task-based overview metrics', () => {
    const context = createDemoOrganizationContext(serverNow);
    const metrics = overviewMetrics(createDemoTasks(context), context);

    expect(metrics.dueToday).toBeGreaterThan(0);
    expect(metrics.unacknowledged).toBeGreaterThan(0);
    expect(metrics.needsAttention).toBe(2);
    expect(metrics.overdue).toBeGreaterThan(0);
  });

  it('orders management attention with blockers before review and overdue', () => {
    const context = createDemoOrganizationContext(serverNow);
    const attention = overviewAttentionTasks(createDemoTasks(context), context);

    expect(attention.map((task) => task.task_number).slice(0, 3)).toEqual([
      'TASK-1030',
      'TASK-1031',
      'TASK-1024',
    ]);
    expect(attention.every((task) => !['done', 'canceled', 'waived'].includes(task.status))).toBe(
      true,
    );
  });

  it('summarizes seller workload without inventing revenue or attendance data', () => {
    const context = createDemoOrganizationContext(serverNow);
    const sellers = overviewSellerSummary(createDemoTasks(context), context);
    const shopee = sellers.find((seller) => seller.sellerName === 'Bomax Shopee');

    expect(sellers).toHaveLength(3);
    expect(shopee).toMatchObject({
      active: 3,
      dueToday: 2,
      overdue: 1,
    });
  });

  it('UI-10 parses and serializes URL task filters safely', () => {
    const filters = parseTaskListFilters({
      q: 'sale',
      saved: 'review',
      view: 'calendar',
      due: 'today',
      group: 'seller',
      month: '2026-10',
      priority: 'high',
      sort: 'priority',
      status: 'in_review',
      seller: 'seller-a',
    });
    const query = serializeTaskListFilters(filters);

    expect(filters.saved).toBe('review');
    expect(filters.view).toBe('calendar');
    expect(filters.group).toBe('seller');
    expect(filters.month).toBe('2026-10');
    expect(query).toContain('q=sale');
    expect(query).toContain('saved=review');
    expect(query).toContain('view=calendar');
    expect(query).toContain('group=seller');
    expect(query).toContain('month=2026-10');
    expect(query).toContain('sort=priority');
    expect(parseTaskListFilters({ view: 'review' }).saved).toBe('review');
    expect(parseTaskListFilters({ view: 'review' }).view).toBe('list');
    expect(parseTaskListFilters({ view: 'invalid', month: '2026-14' })).toMatchObject({
      saved: 'all',
      month: '',
      view: 'list',
    });
  });
});
