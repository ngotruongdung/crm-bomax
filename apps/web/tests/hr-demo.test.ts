import { describe, expect, it } from 'vitest';
import {
  calculateAffectedMinutes,
  createDemoHrWorkspace,
  hasApprovedAbsenceOverlap,
  toManagerAvailability,
} from '../lib/demo/hr-demo';
import { createDemoOrganizationContext, demoIds } from '../lib/demo/opsdesk-demo';

describe('P05 HR demo policy', () => {
  it('REQ-02: partial unpaid leave only counts intersected working time', () => {
    const segments = [
      { start: '2026-10-05T02:00:00.000Z', end: '2026-10-05T05:00:00.000Z' },
      { start: '2026-10-05T06:00:00.000Z', end: '2026-10-05T11:00:00.000Z' },
    ];
    expect(
      calculateAffectedMinutes(segments, '2026-10-05T09:00:00.000Z', '2026-10-05T11:00:00.000Z'),
    ).toBe(120);
  });

  it('REQ-07: a request that only overlaps a break affects zero working minutes', () => {
    const segments = [
      { start: '2026-10-05T02:00:00.000Z', end: '2026-10-05T05:00:00.000Z' },
      { start: '2026-10-05T06:00:00.000Z', end: '2026-10-05T11:00:00.000Z' },
    ];
    expect(
      calculateAffectedMinutes(segments, '2026-10-05T05:00:00.000Z', '2026-10-05T06:00:00.000Z'),
    ).toBe(0);
  });

  it('REQ-08: approved overlapping absences are detected before submission', () => {
    const context = createDemoOrganizationContext('2026-10-05T03:00:00.000Z');
    const demo = createDemoHrWorkspace(context);
    const approved = demo.requests.find(
      (request) => request.status === 'approved' && request.request_type === 'early_leave',
    )!;
    expect(
      hasApprovedAbsenceOverlap(
        demo.requests,
        demoIds.employeeBMember,
        approved.starts_at,
        approved.ends_at,
      ),
    ).toBe(true);
  });

  it('REQ-01: pending requests do not appear in manager availability', () => {
    const context = createDemoOrganizationContext('2026-10-05T03:00:00.000Z');
    const demo = createDemoHrWorkspace(context);
    const availability = toManagerAvailability(demo.requests);
    expect(
      availability.some((row) => row.request_id === 'c5000000-0000-0000-0000-000000000001'),
    ).toBe(false);
  });

  it('REQ-13: manager availability never carries private reason data', () => {
    const context = createDemoOrganizationContext('2026-10-05T03:00:00.000Z');
    const demo = createDemoHrWorkspace(context);
    const row = toManagerAvailability(demo.requests)[0]!;
    expect(row).not.toHaveProperty('reason_private');
    expect(row).not.toHaveProperty('handover_note');
  });
});
