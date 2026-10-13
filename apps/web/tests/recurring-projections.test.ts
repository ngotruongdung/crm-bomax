import { describe, expect, it } from 'vitest';
import {
  projectScheduleDates,
  projectTemplateOccurrences,
  scheduleMatchesDate,
  type RecurringTaskTemplate,
} from '../lib/demo/recurring-demo';

describe('recurring schedule projections', () => {
  it('projects every day independently', () => {
    const schedule = {
      kind: 'every_day' as const,
      weekdays: [],
      start_date: '2026-10-04',
      end_date: null,
      due_time: '10:00',
    };

    expect(projectScheduleDates(schedule, '2026-10-04', 4)).toEqual([
      '2026-10-04',
      '2026-10-05',
      '2026-10-06',
      '2026-10-07',
    ]);
  });

  it('projects custom weekdays only', () => {
    const schedule = {
      kind: 'weekdays' as const,
      weekdays: [1, 3, 5],
      start_date: '2026-10-01',
      end_date: null,
      due_time: '15:00',
    };

    expect(projectScheduleDates(schedule, '2026-10-04', 5)).toEqual([
      '2026-10-05',
      '2026-10-07',
      '2026-10-09',
      '2026-10-12',
      '2026-10-14',
    ]);
  });

  it('working days skip Sunday and respect end date', () => {
    const schedule = {
      kind: 'working_days' as const,
      weekdays: [],
      start_date: '2026-10-04',
      end_date: '2026-10-07',
      due_time: '09:00',
    };

    expect(scheduleMatchesDate(schedule, '2026-10-04')).toBe(false);
    expect(projectScheduleDates(schedule, '2026-10-04', 7)).toEqual([
      '2026-10-05',
      '2026-10-06',
      '2026-10-07',
    ]);
  });

  it('paused templates produce no future virtual occurrence', () => {
    const template: RecurringTaskTemplate = {
      id: 'template-1',
      title: 'Daily check',
      seller_id: null,
      seller_name: null,
      assignee_member_id: null,
      assignee_name: null,
      assignment_mode: 'fixed',
      schedule: {
        kind: 'every_day',
        weekdays: [],
        start_date: '2026-10-01',
        end_date: null,
        due_time: '10:00',
      },
      status: 'paused',
    };

    expect(projectTemplateOccurrences(template, '2026-10-04')).toEqual([]);
  });

  it('creates deterministic occurrence identities per date', () => {
    const template: RecurringTaskTemplate = {
      id: 'template-2',
      title: 'Daily check',
      seller_id: null,
      seller_name: null,
      assignee_member_id: null,
      assignee_name: null,
      assignment_mode: 'fixed',
      schedule: {
        kind: 'every_day',
        weekdays: [],
        start_date: '2026-10-04',
        end_date: null,
        due_time: '10:00',
      },
      status: 'active',
    };

    const first = projectTemplateOccurrences(template, '2026-10-04', 2);
    const second = projectTemplateOccurrences(template, '2026-10-04', 2);
    expect(first).toEqual(second);
    expect(first.map((item) => item.id)).toEqual([
      'template-2:2026-10-04',
      'template-2:2026-10-05',
    ]);
  });
});
