import { describe, expect, it } from 'vitest';
import {
  isoWeekday,
  localDateTimeToIso,
  materializeShift,
} from '../lib/attendance/shift-materialization';

describe('attendance shift materialization', () => {
  it('converts a local office time without depending on the server timezone', () => {
    expect(localDateTimeToIso('2026-10-06', '09:00', 'Asia/Ho_Chi_Minh')).toBe(
      '2026-10-06T02:00:00.000Z',
    );
  });

  it('materializes two working segments around an administrator-configured break', () => {
    const shift = materializeShift({
      date: '2026-10-06',
      memberId: 'member-1',
      organizationId: 'organization-1',
      template: {
        allowedMode: 'hybrid',
        breaks: [{ end: '13:00', start: '12:00' }],
        endLocal: '18:00',
        officeId: 'office-1',
        standardDayMinutes: 480,
        startLocal: '09:00',
        templateId: 'template-1',
        templateVersion: 2,
      },
      timezone: 'Asia/Ho_Chi_Minh',
    });

    expect(shift.scheduled_seconds).toBe(28_800);
    expect(shift.working_segments).toEqual([
      { end: '2026-10-06T05:00:00.000Z', start: '2026-10-06T02:00:00.000Z' },
      { end: '2026-10-06T11:00:00.000Z', start: '2026-10-06T06:00:00.000Z' },
    ]);
  });

  it('uses ISO weekdays so Monday through Friday are deterministic', () => {
    expect(isoWeekday('2026-10-05')).toBe(1);
    expect(isoWeekday('2026-10-11')).toBe(7);
  });
});
