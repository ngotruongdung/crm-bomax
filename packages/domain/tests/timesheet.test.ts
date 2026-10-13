import { describe, expect, it } from 'vitest';
import {
  calculateTimesheetDay,
  summarizeTimesheetMonth,
  type CalculateTimesheetDayInput,
  type TimesheetInterval,
} from '../src/timesheet';

const at = (time: string) => `2026-10-05T${time}:00+07:00`;
const segment = (start: string, end: string): TimesheetInterval => ({
  start: at(start),
  end: at(end),
});
const baseSchedule = [segment('09:00', '12:00'), segment('13:00', '18:00')];

function day(overrides: Partial<CalculateTimesheetDayInput> = {}) {
  return calculateTimesheetDay({
    workDate: '2026-10-05',
    scheduleSegments: baseSchedule,
    sessions: [],
    absences: [],
    standardDayMinutes: 480,
    scheduleSnapshotRef: 'shift-instance-v1',
    policySnapshotVersion: 1,
    ...overrides,
  });
}

describe('P07 timesheet interval engine', () => {
  it('TIME-01: full 09-18 attendance minus break is 480 minutes and one unit', () => {
    const result = day({ sessions: [{ start: at('09:00'), end: at('18:00'), mode: 'office' }] });
    expect(result.scheduled_seconds).toBe(480 * 60);
    expect(result.worked_seconds).toBe(480 * 60);
    expect(result.worked_units).toBe(1);
    expect(result.state).toBe('ready');
  });

  it('TIME-02: early checkout plus unpaid leave keeps worked and unpaid separate', () => {
    const result = day({
      sessions: [{ start: at('09:00'), end: at('16:00'), mode: 'office' }],
      absences: [{ start: at('16:00'), end: at('18:00'), treatment: 'unpaid' }],
    });
    expect(result.worked_seconds).toBe(360 * 60);
    expect(result.worked_units).toBe(0.75);
    expect(result.unpaid_leave_seconds).toBe(120 * 60);
    expect(result.unpaid_leave_units).toBe(0.25);
  });

  it('TIME-03: early checkout plus paid leave does not call leave worked time', () => {
    const result = day({
      sessions: [{ start: at('09:00'), end: at('16:00'), mode: 'office' }],
      absences: [{ start: at('16:00'), end: at('18:00'), treatment: 'paid' }],
    });
    expect(result.worked_units).toBe(0.75);
    expect(result.paid_leave_units).toBe(0.25);
    expect(result.unpaid_leave_units).toBe(0);
  });

  it('TIME-04: attendance overlapping approved leave is a blocking conflict, never a ready 1.25 day', () => {
    const result = day({
      sessions: [{ start: at('09:00'), end: at('18:00'), mode: 'office' }],
      absences: [{ start: at('16:00'), end: at('18:00'), treatment: 'paid' }],
    });
    expect(result.state).toBe('needs_review');
    expect(result.conflict_seconds).toBe(120 * 60);
    expect(result.exceptions).toContainEqual({
      code: 'ATTENDANCE_LEAVE_CONFLICT',
      blocking: true,
      seconds: 120 * 60,
    });
  });

  it('TIME-05: arriving ten minutes late reduces worked time once', () => {
    const result = day({ sessions: [{ start: at('09:10'), end: at('18:00'), mode: 'office' }] });
    expect(result.worked_seconds).toBe(470 * 60);
    expect(result.unexplained_seconds).toBe(10 * 60);
  });

  it('TIME-06: a check-in without checkout stays provisional and unknown', () => {
    const result = day({ sessions: [{ start: at('09:00'), end: null, mode: 'office' }] });
    expect(result.state).toBe('provisional');
    expect(result.worked_seconds).toBe(0);
    expect(result.unknown_seconds).toBe(480 * 60);
    expect(result.unexplained_seconds).toBe(0);
  });

  it('TIME-07: overlapping sessions are unioned instead of double-counted and require review', () => {
    const result = day({
      scheduleSegments: [segment('09:00', '12:00')],
      sessions: [
        { start: at('09:00'), end: at('11:00'), mode: 'office' },
        { start: at('10:00'), end: at('12:00'), mode: 'office' },
      ],
    });
    expect(result.worked_seconds).toBe(3 * 60 * 60);
    expect(result.exceptions.some((item) => item.code === 'SESSION_OVERLAP' && item.blocking)).toBe(
      true,
    );
  });

  it('TIME-08: time outside the historical schedule is separated and not treated as payable OT', () => {
    const result = day({ sessions: [{ start: at('08:30'), end: at('18:30'), mode: 'office' }] });
    expect(result.worked_seconds).toBe(480 * 60);
    expect(result.outside_schedule_seconds).toBe(60 * 60);
    expect(result.exceptions).toContainEqual({
      code: 'OUTSIDE_SCHEDULE',
      blocking: false,
      seconds: 60 * 60,
    });
  });

  it('TIME-09: a four-hour shift is half a standard eight-hour day', () => {
    const result = day({
      scheduleSegments: [segment('09:00', '13:00')],
      sessions: [{ start: at('09:00'), end: at('13:00'), mode: 'remote' }],
    });
    expect(result.scheduled_units).toBe(0.5);
    expect(result.worked_units).toBe(0.5);
    expect(result.worked_remote_seconds).toBe(4 * 60 * 60);
  });

  it('TIME-10: month totals use actual scheduled days rather than a hard-coded 26 days', () => {
    const rows = Array.from({ length: 22 }, (_, index) =>
      day({
        workDate: `2026-10-${String(index + 1).padStart(2, '0')}`,
        sessions: [{ start: at('09:00'), end: at('18:00'), mode: 'office' }],
      }),
    );
    const summary = summarizeTimesheetMonth(rows);
    expect(summary.scheduled_days).toBe(22);
    expect(summary.scheduled_units).toBe(22);
    expect(summary.worked_units).toBe(22);
  });

  it('TIME-13: seconds are summed before converting to work units', () => {
    const result = day({
      scheduleSegments: [
        { start: '2026-10-05T09:00:00.000+07:00', end: '2026-10-05T09:10:00.000+07:00' },
      ],
      sessions: [
        {
          start: '2026-10-05T09:00:00.000+07:00',
          end: '2026-10-05T09:01:00.400+07:00',
          mode: 'office',
        },
        {
          start: '2026-10-05T09:02:00.000+07:00',
          end: '2026-10-05T09:03:00.400+07:00',
          mode: 'office',
        },
      ],
    });
    expect(result.worked_seconds).toBeCloseTo(120.8, 8);
    expect(result.worked_units).toBeCloseTo(120.8 / (480 * 60), 12);
  });

  it('TIME-14: calculation carries the historical schedule/policy snapshot identity', () => {
    const result = day({
      scheduleSnapshotRef: 'shift-instance-historical-v4',
      policySnapshotVersion: 4,
      scheduleSegments: [segment('09:00', '13:00')],
      sessions: [{ start: at('09:00'), end: at('13:00'), mode: 'office' }],
    });
    expect(result.schedule_snapshot_ref).toBe('shift-instance-historical-v4');
    expect(result.policy_snapshot_version).toBe(4);
    expect(result.worked_units).toBe(0.5);
  });
});
