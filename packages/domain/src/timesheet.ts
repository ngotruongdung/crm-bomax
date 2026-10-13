export type TimesheetMode = 'office' | 'remote';

export type TimesheetInterval = {
  start: string;
  end: string;
};

export type TimesheetSession = {
  start: string;
  end: string | null;
  mode: TimesheetMode;
};

export type TimesheetAbsence = TimesheetInterval & {
  treatment: 'paid' | 'unpaid';
};

export type TimesheetExceptionCode =
  | 'INVALID_SOURCE_INTERVAL'
  | 'MISSING_CHECK_OUT'
  | 'SESSION_OVERLAP'
  | 'ATTENDANCE_LEAVE_CONFLICT'
  | 'ABSENCE_TREATMENT_CONFLICT'
  | 'OUTSIDE_SCHEDULE';

export type TimesheetException = {
  code: TimesheetExceptionCode;
  blocking: boolean;
  seconds: number | null;
};

export type TimesheetDayState = 'ready' | 'provisional' | 'needs_review';

export type CalculateTimesheetDayInput = {
  workDate: string;
  scheduleSegments: TimesheetInterval[];
  sessions: TimesheetSession[];
  absences?: TimesheetAbsence[];
  standardDayMinutes: number;
  scheduleSnapshotRef: string;
  policySnapshotVersion: number;
};

export type TimesheetDayResult = {
  work_date: string;
  schedule_snapshot_ref: string;
  policy_snapshot_version: number;
  state: TimesheetDayState;
  scheduled_seconds: number;
  worked_seconds: number;
  worked_office_seconds: number;
  worked_remote_seconds: number;
  paid_leave_seconds: number;
  unpaid_leave_seconds: number;
  unknown_seconds: number;
  unexplained_seconds: number;
  outside_schedule_seconds: number;
  conflict_seconds: number;
  scheduled_units: number;
  worked_units: number;
  paid_leave_units: number;
  unpaid_leave_units: number;
  exceptions: TimesheetException[];
};

export type TimesheetMonthSummary = {
  scheduled_seconds: number;
  worked_seconds: number;
  worked_office_seconds: number;
  worked_remote_seconds: number;
  paid_leave_seconds: number;
  unpaid_leave_seconds: number;
  unknown_seconds: number;
  unexplained_seconds: number;
  outside_schedule_seconds: number;
  scheduled_units: number;
  worked_units: number;
  paid_leave_units: number;
  unpaid_leave_units: number;
  scheduled_days: number;
  requires_reconciliation_days: number;
};

type NumericInterval = {
  start: number;
  end: number;
};

const toSeconds = (milliseconds: number) => milliseconds / 1000;

function toNumericInterval(interval: TimesheetInterval): NumericInterval | null {
  const start = Date.parse(interval.start);
  const end = Date.parse(interval.end);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) return null;
  return { start, end };
}

function mergeIntervals(intervals: NumericInterval[]): NumericInterval[] {
  const sorted = [...intervals].sort((a, b) => a.start - b.start || a.end - b.end);
  const merged: NumericInterval[] = [];

  for (const interval of sorted) {
    const last = merged.at(-1);
    if (!last || interval.start > last.end) {
      merged.push({ ...interval });
      continue;
    }
    last.end = Math.max(last.end, interval.end);
  }

  return merged;
}

function intersection(a: NumericInterval[], b: NumericInterval[]): NumericInterval[] {
  const left = mergeIntervals(a);
  const right = mergeIntervals(b);
  const result: NumericInterval[] = [];
  let i = 0;
  let j = 0;

  while (i < left.length && j < right.length) {
    const leftInterval = left[i];
    const rightInterval = right[j];
    if (!leftInterval || !rightInterval) break;
    const start = Math.max(leftInterval.start, rightInterval.start);
    const end = Math.min(leftInterval.end, rightInterval.end);
    if (end > start) result.push({ start, end });
    if (leftInterval.end <= rightInterval.end) i += 1;
    else j += 1;
  }

  return mergeIntervals(result);
}

function durationMilliseconds(intervals: NumericInterval[]) {
  return mergeIntervals(intervals).reduce(
    (total, interval) => total + interval.end - interval.start,
    0,
  );
}

function overlapMilliseconds(a: NumericInterval[], b: NumericInterval[]) {
  return durationMilliseconds(intersection(a, b));
}

function hasRawOverlap(intervals: NumericInterval[]) {
  const sorted = [...intervals].sort((a, b) => a.start - b.start || a.end - b.end);
  let maxEnd = Number.NEGATIVE_INFINITY;
  for (const interval of sorted) {
    if (interval.start < maxEnd) return true;
    maxEnd = Math.max(maxEnd, interval.end);
  }
  return false;
}

function units(seconds: number, standardDayMinutes: number) {
  return seconds / (standardDayMinutes * 60);
}

export function calculateTimesheetDay(input: CalculateTimesheetDayInput): TimesheetDayResult {
  if (!Number.isFinite(input.standardDayMinutes) || input.standardDayMinutes <= 0) {
    throw new Error('STANDARD_DAY_MINUTES_INVALID');
  }
  if (!Number.isInteger(input.policySnapshotVersion) || input.policySnapshotVersion <= 0) {
    throw new Error('POLICY_SNAPSHOT_VERSION_INVALID');
  }
  if (!input.scheduleSnapshotRef.trim()) throw new Error('SCHEDULE_SNAPSHOT_REQUIRED');

  const exceptions: TimesheetException[] = [];
  const scheduleIntervals: NumericInterval[] = [];
  for (const segment of input.scheduleSegments) {
    const interval = toNumericInterval(segment);
    if (interval) scheduleIntervals.push(interval);
    else exceptions.push({ code: 'INVALID_SOURCE_INTERVAL', blocking: true, seconds: null });
  }
  const schedule = mergeIntervals(scheduleIntervals);

  const completeSessions: Array<NumericInterval & { mode: TimesheetMode }> = [];
  let hasIncompleteAttendance = false;
  for (const session of input.sessions) {
    if (!session.end) {
      hasIncompleteAttendance = true;
      exceptions.push({ code: 'MISSING_CHECK_OUT', blocking: true, seconds: null });
      continue;
    }
    const interval = toNumericInterval({ start: session.start, end: session.end });
    if (!interval) {
      exceptions.push({ code: 'INVALID_SOURCE_INTERVAL', blocking: true, seconds: null });
      continue;
    }
    completeSessions.push({ ...interval, mode: session.mode });
  }

  if (hasRawOverlap(completeSessions)) {
    exceptions.push({ code: 'SESSION_OVERLAP', blocking: true, seconds: null });
  }

  const allSessions = mergeIntervals(completeSessions);
  const officeSessions = mergeIntervals(
    completeSessions.filter((session) => session.mode === 'office'),
  );
  const remoteSessions = mergeIntervals(
    completeSessions.filter((session) => session.mode === 'remote'),
  );
  const workedWithinSchedule = intersection(allSessions, schedule);
  const officeWithinSchedule = intersection(officeSessions, schedule);
  const remoteWithinSchedule = intersection(remoteSessions, schedule);

  const paidAbsences: NumericInterval[] = [];
  const unpaidAbsences: NumericInterval[] = [];
  for (const absence of input.absences ?? []) {
    const interval = toNumericInterval(absence);
    if (!interval) {
      exceptions.push({ code: 'INVALID_SOURCE_INTERVAL', blocking: true, seconds: null });
      continue;
    }
    if (absence.treatment === 'paid') paidAbsences.push(interval);
    else unpaidAbsences.push(interval);
  }

  const paidWithinSchedule = intersection(paidAbsences, schedule);
  const unpaidWithinSchedule = intersection(unpaidAbsences, schedule);
  const attendanceLeaveConflictMs = overlapMilliseconds(
    workedWithinSchedule,
    mergeIntervals([...paidWithinSchedule, ...unpaidWithinSchedule]),
  );
  if (attendanceLeaveConflictMs > 0) {
    exceptions.push({
      code: 'ATTENDANCE_LEAVE_CONFLICT',
      blocking: true,
      seconds: toSeconds(attendanceLeaveConflictMs),
    });
  }
  const absenceTreatmentConflictMs = overlapMilliseconds(paidWithinSchedule, unpaidWithinSchedule);
  if (absenceTreatmentConflictMs > 0) {
    exceptions.push({
      code: 'ABSENCE_TREATMENT_CONFLICT',
      blocking: true,
      seconds: toSeconds(absenceTreatmentConflictMs),
    });
  }

  const scheduledMs = durationMilliseconds(schedule);
  const workedMs = durationMilliseconds(workedWithinSchedule);
  const workedOfficeMs = durationMilliseconds(officeWithinSchedule);
  const workedRemoteMs = durationMilliseconds(remoteWithinSchedule);
  const paidMs = durationMilliseconds(paidWithinSchedule);
  const unpaidMs = durationMilliseconds(unpaidWithinSchedule);
  const firstScheduleSegment = schedule[0];
  const lastScheduleSegment = schedule.at(-1);
  const shiftEnvelope =
    firstScheduleSegment && lastScheduleSegment
      ? [{ start: firstScheduleSegment.start, end: lastScheduleSegment.end }]
      : [];
  const insideShiftEnvelopeMs = durationMilliseconds(intersection(allSessions, shiftEnvelope));
  const outsideScheduleMs = Math.max(0, durationMilliseconds(allSessions) - insideShiftEnvelopeMs);
  if (outsideScheduleMs > 0) {
    exceptions.push({
      code: 'OUTSIDE_SCHEDULE',
      blocking: false,
      seconds: toSeconds(outsideScheduleMs),
    });
  }

  const classifiedUnionMs = durationMilliseconds(
    mergeIntervals([...workedWithinSchedule, ...paidWithinSchedule, ...unpaidWithinSchedule]),
  );
  const unclassifiedMs = Math.max(0, scheduledMs - classifiedUnionMs);
  const conflictMs = durationMilliseconds(
    mergeIntervals([
      ...intersection(workedWithinSchedule, paidWithinSchedule),
      ...intersection(workedWithinSchedule, unpaidWithinSchedule),
      ...intersection(paidWithinSchedule, unpaidWithinSchedule),
    ]),
  );
  const hasBlockingException = exceptions.some((exception) => exception.blocking);
  const state: TimesheetDayState = hasBlockingException
    ? hasIncompleteAttendance && exceptions.every((item) => item.code === 'MISSING_CHECK_OUT')
      ? 'provisional'
      : 'needs_review'
    : 'ready';
  const unknownMs = hasIncompleteAttendance ? unclassifiedMs : 0;
  const unexplainedMs = hasIncompleteAttendance || hasBlockingException ? 0 : unclassifiedMs;

  const scheduledSeconds = toSeconds(scheduledMs);
  const workedSeconds = toSeconds(workedMs);
  const paidSeconds = toSeconds(paidMs);
  const unpaidSeconds = toSeconds(unpaidMs);

  return {
    work_date: input.workDate,
    schedule_snapshot_ref: input.scheduleSnapshotRef,
    policy_snapshot_version: input.policySnapshotVersion,
    state,
    scheduled_seconds: scheduledSeconds,
    worked_seconds: workedSeconds,
    worked_office_seconds: toSeconds(workedOfficeMs),
    worked_remote_seconds: toSeconds(workedRemoteMs),
    paid_leave_seconds: paidSeconds,
    unpaid_leave_seconds: unpaidSeconds,
    unknown_seconds: toSeconds(unknownMs),
    unexplained_seconds: toSeconds(unexplainedMs),
    outside_schedule_seconds: toSeconds(outsideScheduleMs),
    conflict_seconds: toSeconds(conflictMs),
    scheduled_units: units(scheduledSeconds, input.standardDayMinutes),
    worked_units: units(workedSeconds, input.standardDayMinutes),
    paid_leave_units: units(paidSeconds, input.standardDayMinutes),
    unpaid_leave_units: units(unpaidSeconds, input.standardDayMinutes),
    exceptions,
  };
}

export function summarizeTimesheetMonth(days: TimesheetDayResult[]): TimesheetMonthSummary {
  const sum = (select: (day: TimesheetDayResult) => number) =>
    days.reduce((total, day) => total + select(day), 0);

  return {
    scheduled_seconds: sum((day) => day.scheduled_seconds),
    worked_seconds: sum((day) => day.worked_seconds),
    worked_office_seconds: sum((day) => day.worked_office_seconds),
    worked_remote_seconds: sum((day) => day.worked_remote_seconds),
    paid_leave_seconds: sum((day) => day.paid_leave_seconds),
    unpaid_leave_seconds: sum((day) => day.unpaid_leave_seconds),
    unknown_seconds: sum((day) => day.unknown_seconds),
    unexplained_seconds: sum((day) => day.unexplained_seconds),
    outside_schedule_seconds: sum((day) => day.outside_schedule_seconds),
    scheduled_units: sum((day) => day.scheduled_units),
    worked_units: sum((day) => day.worked_units),
    paid_leave_units: sum((day) => day.paid_leave_units),
    unpaid_leave_units: sum((day) => day.unpaid_leave_units),
    scheduled_days: days.filter((day) => day.scheduled_seconds > 0).length,
    requires_reconciliation_days: days.filter((day) => day.state !== 'ready').length,
  };
}
