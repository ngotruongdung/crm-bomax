type ShiftBreak = { end: string; start: string };

export type ShiftMaterializationTemplate = {
  allowedMode: 'office' | 'remote' | 'hybrid';
  breaks: ShiftBreak[];
  officeId: string | null;
  templateId: string;
  templateVersion: number;
  endLocal: string;
  startLocal: string;
  standardDayMinutes: number;
};

export type MaterializedShift = {
  allowed_mode: ShiftMaterializationTemplate['allowedMode'];
  ends_at: string;
  member_id: string;
  office_id: string | null;
  organization_id: string;
  policy_snapshot: Record<string, unknown>;
  scheduled_seconds: number;
  standard_day_minutes: number;
  starts_at: string;
  status: 'scheduled';
  template_id: string;
  work_date: string;
  working_segments: Array<{ end: string; start: string }>;
};

function splitDate(value: string) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) throw new Error('SHIFT_DATE_INVALID');
  return { day: Number(match[3]), month: Number(match[2]), year: Number(match[1]) };
}

function minutesForTime(value: string) {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) throw new Error('SHIFT_TIME_INVALID');
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours > 23 || minutes > 59) throw new Error('SHIFT_TIME_INVALID');
  return hours * 60 + minutes;
}

function timeForMinutes(value: number) {
  const hours = Math.floor(value / 60);
  const minutes = value % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`;
}

function partsAt(utcTimestamp: number, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-US', {
    day: '2-digit',
    hour: '2-digit',
    hour12: false,
    minute: '2-digit',
    month: '2-digit',
    second: '2-digit',
    timeZone: timezone,
    year: 'numeric',
  }).formatToParts(new Date(utcTimestamp));
  const fields = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    day: Number(fields.day),
    hour: Number(fields.hour),
    minute: Number(fields.minute),
    month: Number(fields.month),
    second: Number(fields.second),
    year: Number(fields.year),
  };
}

/** Converts a local IANA date/time into an ISO instant without relying on host timezone. */
export function localDateTimeToIso(date: string, localTime: string, timezone: string) {
  const { day, month, year } = splitDate(date);
  const minutes = minutesForTime(localTime);
  const hour = Math.floor(minutes / 60);
  const minute = minutes % 60;
  const expectedUtc = Date.UTC(year, month - 1, day, hour, minute, 0);
  let utc = expectedUtc;

  // A second pass handles daylight-saving offset transitions for organizations outside Vietnam.
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const local = partsAt(utc, timezone);
    const localAsUtc = Date.UTC(
      local.year,
      local.month - 1,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    utc = expectedUtc - (localAsUtc - utc);
  }
  return new Date(utc).toISOString();
}

export function isoWeekday(date: string) {
  const { day, month, year } = splitDate(date);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return weekday === 0 ? 7 : weekday;
}

export function addDays(date: string, amount: number) {
  const { day, month, year } = splitDate(date);
  const next = new Date(Date.UTC(year, month - 1, day + amount));
  return next.toISOString().slice(0, 10);
}

function usableBreaks(breaks: ShiftBreak[], startMinutes: number, endMinutes: number) {
  return breaks
    .map((item) => ({ end: minutesForTime(item.end), start: minutesForTime(item.start) }))
    .filter((item) => item.start >= startMinutes && item.end <= endMinutes && item.end > item.start)
    .sort((left, right) => left.start - right.start)
    .filter((item, index, items) => index === 0 || item.start >= items[index - 1]!.end);
}

export function materializeShift({
  date,
  memberId,
  organizationId,
  template,
  timezone,
}: {
  date: string;
  memberId: string;
  organizationId: string;
  template: ShiftMaterializationTemplate;
  timezone: string;
}): MaterializedShift {
  const startMinutes = minutesForTime(template.startLocal);
  const endMinutes = minutesForTime(template.endLocal);
  if (endMinutes <= startMinutes) throw new Error('SHIFT_OVERNIGHT_NOT_SUPPORTED');

  const intervals: Array<{ end: number; start: number }> = [];
  let cursor = startMinutes;
  for (const breakTime of usableBreaks(template.breaks, startMinutes, endMinutes)) {
    if (cursor < breakTime.start) intervals.push({ end: breakTime.start, start: cursor });
    cursor = breakTime.end;
  }
  if (cursor < endMinutes) intervals.push({ end: endMinutes, start: cursor });
  if (intervals.length === 0) throw new Error('SHIFT_WORKING_SEGMENTS_INVALID');

  const workingSegments = intervals.map((interval) => ({
    end: localDateTimeToIso(date, timeForMinutes(interval.end).slice(0, 5), timezone),
    start: localDateTimeToIso(date, timeForMinutes(interval.start).slice(0, 5), timezone),
  }));
  const scheduledSeconds = intervals.reduce(
    (total, interval) => total + (interval.end - interval.start) * 60,
    0,
  );

  return {
    allowed_mode: template.allowedMode,
    ends_at: localDateTimeToIso(date, template.endLocal, timezone),
    member_id: memberId,
    office_id: template.officeId,
    organization_id: organizationId,
    policy_snapshot: {
      generated_by: 'attendance_settings',
      template_version: template.templateVersion,
      timezone,
    },
    scheduled_seconds: scheduledSeconds,
    standard_day_minutes: template.standardDayMinutes,
    starts_at: localDateTimeToIso(date, template.startLocal, timezone),
    status: 'scheduled',
    template_id: template.templateId,
    work_date: date,
    working_segments: workingSegments,
  };
}
