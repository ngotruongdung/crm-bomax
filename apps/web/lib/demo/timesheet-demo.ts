import type { OrganizationContext, TimesheetView } from '@opsdesk/contracts';
import {
  calculateTimesheetDay,
  summarizeTimesheetMonth,
  type CalculateTimesheetDayInput,
  type TimesheetSession,
} from '@opsdesk/domain';
import { demoMembers } from './opsdesk-demo';

function monthStartInTimezone(serverNow: string, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date(serverNow));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-01`;
}

function dateForDay(monthStart: string, day: number) {
  return `${monthStart.slice(0, 8)}${String(day).padStart(2, '0')}`;
}

function at(date: string, time: string) {
  return new Date(`${date}T${time}:00+07:00`).toISOString();
}

function calculatePreviewRow(
  date: string,
  sessions: TimesheetSession[],
  absences: CalculateTimesheetDayInput['absences'] = [],
) {
  const scheduleSegments = [
    { start: at(date, '09:00'), end: at(date, '12:00') },
    { start: at(date, '13:00'), end: at(date, '18:00') },
  ];
  const result = calculateTimesheetDay({
    workDate: date,
    scheduleSegments,
    sessions,
    absences,
    standardDayMinutes: 480,
    scheduleSnapshotRef: `demo-shift-${date}`,
    policySnapshotVersion: 1,
  });
  const completeSessions = sessions.filter(
    (session): session is TimesheetSession & { end: string } => Boolean(session.end),
  );

  return {
    ...result,
    shift_label: '09:00–18:00 · nghỉ 12:00–13:00',
    allowed_mode: 'hybrid' as const,
    first_check_in_at: sessions[0]?.start ?? null,
    last_check_out_at: completeSessions.at(-1)?.end ?? null,
  };
}

function createRows(monthStart: string, variant: number) {
  const d1 = dateForDay(monthStart, 1);
  const d2 = dateForDay(monthStart, 2);
  const d3 = dateForDay(monthStart, 3);
  const d4 = dateForDay(monthStart, 4);
  const d5 = dateForDay(monthStart, 5);

  const rows = [
    calculatePreviewRow(d1, [{ start: at(d1, '09:00'), end: at(d1, '18:00'), mode: 'office' }]),
    calculatePreviewRow(d2, [{ start: at(d2, '09:00'), end: at(d2, '18:00'), mode: 'remote' }]),
  ];

  if (variant % 3 === 0) {
    rows.push(
      calculatePreviewRow(
        d3,
        [{ start: at(d3, '09:00'), end: at(d3, '16:00'), mode: 'office' }],
        [{ start: at(d3, '16:00'), end: at(d3, '18:00'), treatment: 'unpaid' }],
      ),
    );
  } else if (variant % 3 === 1) {
    rows.push(
      calculatePreviewRow(
        d3,
        [{ start: at(d3, '09:00'), end: at(d3, '16:00'), mode: 'office' }],
        [{ start: at(d3, '16:00'), end: at(d3, '18:00'), treatment: 'paid' }],
      ),
    );
  } else {
    rows.push(
      calculatePreviewRow(d3, [{ start: at(d3, '09:10'), end: at(d3, '18:00'), mode: 'office' }]),
    );
  }

  rows.push(
    calculatePreviewRow(d4, [{ start: at(d4, '09:10'), end: at(d4, '18:00'), mode: 'office' }]),
  );
  if (variant === 0) {
    rows.push(calculatePreviewRow(d5, [{ start: at(d5, '09:00'), end: null, mode: 'office' }]));
  } else {
    rows.push(
      calculatePreviewRow(d5, [{ start: at(d5, '09:00'), end: at(d5, '18:00'), mode: 'office' }]),
    );
  }

  return rows;
}

export function createDemoTimesheetViews(context: OrganizationContext): TimesheetView[] {
  const monthStart = monthStartInTimezone(context.server_now, context.timezone);
  return demoMembers.map((member, index) => {
    const rows = createRows(monthStart, index);
    return {
      organization_id: context.organization_id,
      member_id: member.member_id,
      member_name: member.display_name,
      employee_code: member.employee_code,
      month_start: monthStart,
      period_id: null,
      period_status: 'open',
      period_version: 1,
      revision: 1,
      source: 'demo_preview',
      rows,
      totals: summarizeTimesheetMonth(rows),
    };
  });
}
