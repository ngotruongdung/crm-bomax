import { describe, expect, it } from 'vitest';
import {
  classifyReportTask,
  nextReportRevision,
  reportCountsForTasks,
  reportTaskVisibleToRecipient,
  type ReportTaskFact,
} from '../src/report';

const member = '11111111-1111-4111-8111-111111111111';
const sellerA = '22222222-2222-4222-8222-222222222222';

function task(overrides: Partial<ReportTaskFact> = {}): ReportTaskFact {
  return {
    task_id: '33333333-3333-4333-8333-333333333333',
    seller_id: sellerA,
    assignee_member_id: member,
    status: 'todo',
    due_at: '2026-10-05T10:30:00.000Z',
    completed_at: null,
    blocked: false,
    ...overrides,
  };
}

const cutoff = {
  reportDate: '2026-10-05',
  cutoffAt: '2026-10-05T11:00:00.000Z',
  timeZone: 'Asia/Ho_Chi_Minh',
};

describe('P09 report policy', () => {
  it('REPORT-02 uses organization timezone for the 18:00 cutoff cohort', () => {
    expect(classifyReportTask(task(), cutoff)).toBe('due_open');
  });

  it('REPORT-05 keeps a task due 20:00 outside the <=18:00 cohort', () => {
    expect(classifyReportTask(task({ due_at: '2026-10-05T13:00:00.000Z' }), cutoff)).toBe(
      'due_after_cutoff',
    );
  });

  it('REPORT-06 treats a submitted task at cutoff as review, not assignee miss', () => {
    expect(classifyReportTask(task({ status: 'in_review' }), cutoff)).toBe('due_review');
  });

  it('REPORT-07 enforces due = done + review + open and blocked subset open', () => {
    const counts = reportCountsForTasks(
      [
        task({ task_id: '44444444-4444-4444-8444-444444444444', status: 'done' }),
        task({ task_id: '55555555-5555-4555-8555-555555555555', status: 'in_review' }),
        task({ task_id: '66666666-6666-4666-8666-666666666666', blocked: true }),
      ],
      cutoff,
    );
    expect(counts).toEqual({
      due_count: 3,
      done_count: 1,
      review_count: 1,
      open_count: 1,
      blocked_count: 1,
    });
  });

  it('REPORT-08 separates canceled/waived tasks from the due cohort', () => {
    expect(classifyReportTask(task({ status: 'canceled' }), cutoff)).toBe('canceled_or_waived');
    expect(reportCountsForTasks([task({ status: 'waived' })], cutoff).due_count).toBe(0);
  });

  it('REPORT-09 counts a task once under its assignee regardless of collaborators', () => {
    expect(reportCountsForTasks([task()], cutoff).due_count).toBe(1);
  });

  it('REPORT-10 filters manager facts to assigned seller scope', () => {
    expect(
      reportTaskVisibleToRecipient({
        task: task(),
        recipientMemberId: '77777777-7777-4777-8777-777777777777',
        role: 'manager',
        sellerIds: [sellerA],
      }),
    ).toBe(true);
    expect(
      reportTaskVisibleToRecipient({
        task: task({ seller_id: '88888888-8888-4888-8888-888888888888' }),
        recipientMemberId: '77777777-7777-4777-8777-777777777777',
        role: 'manager',
        sellerIds: [sellerA],
      }),
    ).toBe(false);
  });

  it('REPORT-14 creates a new immutable revision version with reason', () => {
    expect(nextReportRevision(1, 'Late committed event')).toEqual({
      version: 2,
      reason: 'Late committed event',
    });
    expect(() => nextReportRevision(1, ' ')).toThrow('REPORT_REVISION_REASON_REQUIRED');
  });
});
