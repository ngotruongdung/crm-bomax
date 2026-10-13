import type {
  OrganizationContext,
  ReportDetail,
  ReportListItem,
  ReportScope,
} from '@opsdesk/contracts';

const runOne = 'e9000000-0000-4000-8000-000000000001';
const snapshotOne = 'e9000000-0000-4000-8000-000000000011';
const memberA = 'e9000000-0000-4000-8000-000000000021';
const memberB = 'e9000000-0000-4000-8000-000000000022';

function scopeFor(context: OrganizationContext): ReportScope {
  if (context.role === 'admin') return { kind: 'organization' };
  if (context.role === 'manager' && context.seller_scope.length > 0) {
    return { kind: 'sellers', seller_ids: context.seller_scope.map((item) => item.seller_id) };
  }
  return { kind: 'personal', member_id: context.member_id };
}

export function createDemoReportDetail(context: OrganizationContext): ReportDetail {
  const scope = scopeFor(context);
  const reportDate = '2026-10-04';
  const people =
    scope.kind === 'personal'
      ? [
          {
            member_id: context.member_id,
            display_name: context.display_name,
            counts: {
              due_count: 4,
              done_count: 3,
              review_count: 0,
              open_count: 1,
              blocked_count: 0,
            },
            due_task_ids: ['83000000-0000-4000-8000-000000000001'],
            overdue_previous_day_task_ids: [],
            due_after_cutoff_task_ids: [],
            canceled_or_waived_task_ids: [],
            availability: 'working' as const,
          },
        ]
      : [
          {
            member_id: memberA,
            display_name: 'Minh Anh',
            counts: {
              due_count: 6,
              done_count: 5,
              review_count: 1,
              open_count: 0,
              blocked_count: 0,
            },
            due_task_ids: ['83000000-0000-4000-8000-000000000001'],
            overdue_previous_day_task_ids: [],
            due_after_cutoff_task_ids: ['83000000-0000-4000-8000-000000000002'],
            canceled_or_waived_task_ids: [],
            availability: 'working' as const,
          },
          {
            member_id: memberB,
            display_name: 'Hoàng Nam',
            counts: {
              due_count: 5,
              done_count: 3,
              review_count: 0,
              open_count: 2,
              blocked_count: 1,
            },
            due_task_ids: ['83000000-0000-4000-8000-000000000003'],
            overdue_previous_day_task_ids: ['83000000-0000-4000-8000-000000000004'],
            due_after_cutoff_task_ids: [],
            canceled_or_waived_task_ids: ['83000000-0000-4000-8000-000000000005'],
            availability: 'unknown' as const,
          },
        ];
  const totals = people.reduce(
    (acc, item) => ({
      due_count: acc.due_count + item.counts.due_count,
      done_count: acc.done_count + item.counts.done_count,
      review_count: acc.review_count + item.counts.review_count,
      open_count: acc.open_count + item.counts.open_count,
      blocked_count: acc.blocked_count + item.counts.blocked_count,
    }),
    { due_count: 0, done_count: 0, review_count: 0, open_count: 0, blocked_count: 0 },
  );

  return {
    run_id: runOne,
    snapshot_id: snapshotOne,
    report_date: reportDate,
    cutoff_at: '2026-10-04T11:00:00.000Z',
    generated_at: '2026-10-04T11:01:12.000Z',
    timezone: context.timezone,
    revision: 1,
    is_late: false,
    revision_reason: null,
    scope,
    facts: {
      schema_version: 1,
      report_date: reportDate,
      cutoff_at: '2026-10-04T11:00:00.000Z',
      timezone: context.timezone,
      scope,
      totals,
      people,
      warnings: [],
    },
    summary_template: `Chốt 04/10/2026: ${totals.due_count} việc đến hạn, ${totals.done_count} hoàn thành, ${totals.review_count} chờ duyệt, ${totals.open_count} còn mở, ${totals.blocked_count} có vướng mắc.`,
    source_hash: 'a'.repeat(64),
  };
}

export function createDemoReportList(context: OrganizationContext): ReportListItem[] {
  const detail = createDemoReportDetail(context);
  return [
    {
      run_id: detail.run_id,
      snapshot_id: detail.snapshot_id,
      report_date: detail.report_date,
      cutoff_at: detail.cutoff_at,
      generated_at: detail.generated_at,
      timezone: detail.timezone,
      revision: detail.revision,
      is_late: detail.is_late,
      scope: detail.scope,
      totals: detail.facts.totals,
      people_count: detail.facts.people.length,
      warnings: detail.facts.warnings,
    },
  ];
}
