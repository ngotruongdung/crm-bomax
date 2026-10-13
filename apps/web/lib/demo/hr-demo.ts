import type { OrganizationContext } from '@opsdesk/contracts';
import { demoIds } from './opsdesk-demo';

export type DemoPayTreatment = 'paid' | 'unpaid' | 'pending_hr' | 'not_applicable';
export type DemoRequestStatus = 'pending' | 'approved' | 'rejected' | 'withdrawn' | 'canceled';
export type DemoRequestType =
  | 'leave'
  | 'early_leave'
  | 'late_arrival'
  | 'remote_work'
  | 'attendance_correction'
  | 'cancel_approved_request';

export type DemoWorkingSegment = { start: string; end: string };

export type DemoLeaveType = {
  id: string;
  code: string;
  name: string;
  pay_treatment: Exclude<DemoPayTreatment, 'not_applicable'>;
  consumes_balance: boolean;
};

export type DemoShiftInstance = {
  id: string;
  member_id: string;
  member_name: string;
  work_date: string;
  starts_at: string;
  ends_at: string;
  working_segments: DemoWorkingSegment[];
  scheduled_minutes: number;
  allowed_mode: 'office' | 'remote' | 'hybrid';
  label: string;
};

export type DemoEmployeeRequest = {
  id: string;
  version: number;
  member_id: string;
  member_name: string;
  request_type: DemoRequestType;
  status: DemoRequestStatus;
  starts_at: string;
  ends_at: string;
  leave_type_id: string | null;
  leave_type_name: string | null;
  pay_treatment: DemoPayTreatment;
  affected_minutes: number;
  submitted_at: string;
  reason_private: string;
  handover_note: string | null;
  impacted_task_count: number;
  coverage_state: 'not_required' | 'pending' | 'resolved';
};

export type DemoAvailability = {
  request_id: string;
  member_id: string;
  member_name: string;
  starts_at: string;
  ends_at: string;
  status: 'unavailable' | 'remote';
  label: string;
};

const timezone = 'Asia/Ho_Chi_Minh';

function dateInTimezone(iso: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(iso));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function offsetDate(date: string, offsetDays: number) {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year!, month! - 1, day! + offsetDays)).toISOString().slice(0, 10);
}

function at(date: string, hour: number, minute = 0) {
  const hh = String(hour).padStart(2, '0');
  const mm = String(minute).padStart(2, '0');
  return new Date(`${date}T${hh}:${mm}:00+07:00`).toISOString();
}

function overlapMinutes(aStart: string, aEnd: string, bStart: string, bEnd: string) {
  const start = Math.max(Date.parse(aStart), Date.parse(bStart));
  const end = Math.min(Date.parse(aEnd), Date.parse(bEnd));
  return Math.max(0, Math.round((end - start) / 60_000));
}

export function calculateAffectedMinutes(
  segments: DemoWorkingSegment[],
  startsAt: string,
  endsAt: string,
) {
  if (Date.parse(endsAt) <= Date.parse(startsAt)) return 0;
  return segments.reduce(
    (total, segment) => total + overlapMinutes(segment.start, segment.end, startsAt, endsAt),
    0,
  );
}

export function hasApprovedAbsenceOverlap(
  requests: DemoEmployeeRequest[],
  memberId: string,
  startsAt: string,
  endsAt: string,
) {
  return requests.some(
    (request) =>
      request.member_id === memberId &&
      request.status === 'approved' &&
      ['leave', 'early_leave', 'late_arrival'].includes(request.request_type) &&
      overlapMinutes(request.starts_at, request.ends_at, startsAt, endsAt) > 0,
  );
}

export function toManagerAvailability(requests: DemoEmployeeRequest[]): DemoAvailability[] {
  return requests
    .filter((request) => request.status === 'approved')
    .filter((request) =>
      ['leave', 'early_leave', 'late_arrival', 'remote_work'].includes(request.request_type),
    )
    .map((request) => ({
      request_id: request.id,
      member_id: request.member_id,
      member_name: request.member_name,
      starts_at: request.starts_at,
      ends_at: request.ends_at,
      status: request.request_type === 'remote_work' ? 'remote' : 'unavailable',
      label: request.request_type === 'remote_work' ? 'Làm online' : 'Không khả dụng',
    }));
}

export function payTreatmentLabel(value: DemoPayTreatment) {
  if (value === 'paid') return 'Hưởng lương';
  if (value === 'unpaid') return 'Không lương';
  if (value === 'pending_hr') return 'Cần HR xác định';
  return 'Không áp dụng';
}

export function requestTypeLabel(value: DemoRequestType) {
  const labels: Record<DemoRequestType, string> = {
    leave: 'Nghỉ theo giờ / cả ngày',
    early_leave: 'Về sớm',
    late_arrival: 'Đi muộn',
    remote_work: 'Làm online',
    attendance_correction: 'Bổ sung chấm công',
    cancel_approved_request: 'Hủy yêu cầu đã duyệt',
  };
  return labels[value];
}

export function createDemoHrWorkspace(context: OrganizationContext) {
  const today = dateInTimezone(context.server_now);
  const tomorrow = offsetDate(today, 1);
  const afterTomorrow = offsetDate(today, 2);

  const leaveTypes: DemoLeaveType[] = [
    {
      id: 'a5000000-0000-0000-0000-000000000001',
      code: 'PAID_PERSONAL',
      name: 'Nghỉ cá nhân hưởng lương',
      pay_treatment: 'paid',
      consumes_balance: true,
    },
    {
      id: 'a5000000-0000-0000-0000-000000000002',
      code: 'UNPAID',
      name: 'Nghỉ không lương',
      pay_treatment: 'unpaid',
      consumes_balance: false,
    },
    {
      id: 'a5000000-0000-0000-0000-000000000003',
      code: 'HR_REVIEW',
      name: 'HR xác định treatment',
      pay_treatment: 'pending_hr',
      consumes_balance: false,
    },
  ];

  const makeShift = (
    id: string,
    memberId: string,
    memberName: string,
    workDate: string,
  ): DemoShiftInstance => ({
    id,
    member_id: memberId,
    member_name: memberName,
    work_date: workDate,
    starts_at: at(workDate, 9),
    ends_at: at(workDate, 18),
    working_segments: [
      { start: at(workDate, 9), end: at(workDate, 12) },
      { start: at(workDate, 13), end: at(workDate, 18) },
    ],
    scheduled_minutes: 480,
    allowed_mode: 'hybrid',
    label: 'Ca hành chính · 09:00–18:00',
  });

  const shifts = [
    makeShift(
      'b5000000-0000-0000-0000-000000000001',
      demoIds.managerMember,
      'Nguyễn Minh Anh',
      today,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000002',
      demoIds.employeeAMember,
      'Trần Ngọc Linh',
      today,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000003',
      demoIds.employeeBMember,
      'Lê Quốc Huy',
      today,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000004',
      demoIds.managerMember,
      'Nguyễn Minh Anh',
      tomorrow,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000005',
      demoIds.employeeAMember,
      'Trần Ngọc Linh',
      tomorrow,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000006',
      demoIds.employeeBMember,
      'Lê Quốc Huy',
      tomorrow,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000007',
      demoIds.managerMember,
      'Nguyễn Minh Anh',
      afterTomorrow,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000008',
      demoIds.employeeAMember,
      'Trần Ngọc Linh',
      afterTomorrow,
    ),
    makeShift(
      'b5000000-0000-0000-0000-000000000009',
      demoIds.employeeBMember,
      'Lê Quốc Huy',
      afterTomorrow,
    ),
  ];

  const employeeAShift = shifts.find(
    (shift) => shift.member_id === demoIds.employeeAMember && shift.work_date === tomorrow,
  )!;
  const employeeBShift = shifts.find(
    (shift) => shift.member_id === demoIds.employeeBMember && shift.work_date === today,
  )!;

  const requests: DemoEmployeeRequest[] = [
    {
      id: 'c5000000-0000-0000-0000-000000000001',
      version: 1,
      member_id: demoIds.employeeAMember,
      member_name: 'Trần Ngọc Linh',
      request_type: 'leave',
      status: 'pending',
      starts_at: at(tomorrow, 13),
      ends_at: at(tomorrow, 17),
      leave_type_id: leaveTypes[0]!.id,
      leave_type_name: leaveTypes[0]!.name,
      pay_treatment: leaveTypes[0]!.pay_treatment,
      affected_minutes: calculateAffectedMinutes(
        employeeAShift.working_segments,
        at(tomorrow, 13),
        at(tomorrow, 17),
      ),
      submitted_at: at(today, 10, 20),
      reason_private: 'Có việc gia đình cần xử lý trong buổi chiều.',
      handover_note: 'Nhờ team theo dõi inbox seller trong khung 13:00–17:00.',
      impacted_task_count: 2,
      coverage_state: 'pending',
    },
    {
      id: 'c5000000-0000-0000-0000-000000000002',
      version: 1,
      member_id: demoIds.employeeBMember,
      member_name: 'Lê Quốc Huy',
      request_type: 'early_leave',
      status: 'approved',
      starts_at: at(today, 16),
      ends_at: at(today, 18),
      leave_type_id: leaveTypes[1]!.id,
      leave_type_name: leaveTypes[1]!.name,
      pay_treatment: leaveTypes[1]!.pay_treatment,
      affected_minutes: calculateAffectedMinutes(
        employeeBShift.working_segments,
        at(today, 16),
        at(today, 18),
      ),
      submitted_at: at(today, 8, 25),
      reason_private: 'Lịch hẹn cá nhân cuối giờ chiều.',
      handover_note: 'Bàn giao ticket còn mở cho Minh Anh.',
      impacted_task_count: 1,
      coverage_state: 'pending',
    },
    {
      id: 'c5000000-0000-0000-0000-000000000003',
      version: 1,
      member_id: demoIds.managerMember,
      member_name: 'Nguyễn Minh Anh',
      request_type: 'remote_work',
      status: 'approved',
      starts_at: at(afterTomorrow, 9),
      ends_at: at(afterTomorrow, 18),
      leave_type_id: null,
      leave_type_name: null,
      pay_treatment: 'not_applicable',
      affected_minutes: 0,
      submitted_at: at(today, 9, 10),
      reason_private: 'Làm việc online theo lịch cá nhân đã được duyệt.',
      handover_note: null,
      impacted_task_count: 0,
      coverage_state: 'not_required',
    },
  ];

  return {
    leaveTypes,
    shifts,
    requests,
    availability: toManagerAvailability(requests),
  };
}
