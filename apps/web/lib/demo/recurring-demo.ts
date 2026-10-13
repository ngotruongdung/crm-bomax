import type { OrganizationContext } from '@opsdesk/contracts';
import { demoIds, demoMembers, demoSellers } from './opsdesk-demo';

export type RecurrenceScheduleKind = 'working_days' | 'every_day' | 'weekdays';
export type RecurringTemplateStatus = 'active' | 'paused' | 'ended' | 'needs_attention';

export type RecurrenceSchedule = {
  kind: RecurrenceScheduleKind;
  weekdays: number[];
  start_date: string;
  end_date: string | null;
  due_time: string;
};

export type RecurringTaskTemplate = {
  id: string;
  title: string;
  seller_id: string | null;
  seller_name: string | null;
  assignee_member_id: string | null;
  assignee_name: string | null;
  assignment_mode: 'fixed' | 'seller_owner';
  schedule: RecurrenceSchedule;
  status: RecurringTemplateStatus;
};

export type ProjectedOccurrence = {
  id: string;
  template_id: string;
  title: string;
  date: string;
  due_time: string;
  seller_name: string | null;
  assignee_name: string | null;
  projected: true;
};

const workingWeekdays = [1, 2, 3, 4, 5];

function dateOnly(value: string) {
  return value.slice(0, 10);
}

function addDays(date: string, amount: number) {
  const [year, month, day] = date.split('-').map(Number);
  const next = new Date(Date.UTC(year!, month! - 1, day! + amount));
  return next.toISOString().slice(0, 10);
}

function weekday(date: string) {
  const [year, month, day] = date.split('-').map(Number);
  return new Date(Date.UTC(year!, month! - 1, day!)).getUTCDay();
}

export function scheduleMatchesDate(schedule: RecurrenceSchedule, date: string) {
  if (date < schedule.start_date) return false;
  if (schedule.end_date && date > schedule.end_date) return false;
  const day = weekday(date);
  if (schedule.kind === 'every_day') return true;
  if (schedule.kind === 'working_days') return workingWeekdays.includes(day);
  return schedule.weekdays.includes(day);
}

export function projectScheduleDates(
  schedule: RecurrenceSchedule,
  fromDate: string,
  count: number,
  maxLookaheadDays = 90,
) {
  const results: string[] = [];
  for (let offset = 0; offset < maxLookaheadDays && results.length < count; offset += 1) {
    const candidate = addDays(fromDate, offset);
    if (scheduleMatchesDate(schedule, candidate)) results.push(candidate);
  }
  return results;
}

export function projectTemplateOccurrences(
  template: RecurringTaskTemplate,
  fromDate: string,
  count = 7,
): ProjectedOccurrence[] {
  if (template.status !== 'active') return [];
  return projectScheduleDates(template.schedule, fromDate, count).map((date) => ({
    id: `${template.id}:${date}`,
    template_id: template.id,
    title: template.title,
    date,
    due_time: template.schedule.due_time,
    seller_name: template.seller_name,
    assignee_name: template.assignee_name,
    projected: true,
  }));
}

export function formatScheduleLabel(schedule: RecurrenceSchedule) {
  if (schedule.kind === 'working_days') return `Theo lịch làm việc · ${schedule.due_time}`;
  if (schedule.kind === 'every_day') return `Mỗi ngày · ${schedule.due_time}`;
  const labels = schedule.weekdays
    .slice()
    .sort((a, b) => a - b)
    .map((day) => (day === 0 ? 'CN' : `T${day + 1}`));
  return `${labels.join(', ')} · ${schedule.due_time}`;
}

export function createDemoRecurringTemplates(
  context: OrganizationContext,
): RecurringTaskTemplate[] {
  const today = dateOnly(context.server_now);
  const employeeA = demoMembers.find((member) => member.member_id === demoIds.employeeAMember)!;
  const employeeB = demoMembers.find((member) => member.member_id === demoIds.employeeBMember)!;
  const sellerA = demoSellers.find((seller) => seller.id === demoIds.sellerA)!;
  const sellerB = demoSellers.find((seller) => seller.id === demoIds.sellerB)!;

  return [
    {
      id: '93000000-0000-0000-0000-000000000001',
      title: 'Kiểm tra tồn kho đầu ngày',
      seller_id: sellerA.id,
      seller_name: sellerA.name,
      assignee_member_id: employeeA.member_id,
      assignee_name: employeeA.display_name,
      assignment_mode: 'fixed',
      schedule: {
        kind: 'working_days',
        weekdays: [],
        start_date: today,
        end_date: null,
        due_time: '09:30',
      },
      status: 'active',
    },
    {
      id: '93000000-0000-0000-0000-000000000002',
      title: 'Đối soát đơn TikTok cuối ngày',
      seller_id: sellerB.id,
      seller_name: sellerB.name,
      assignee_member_id: employeeA.member_id,
      assignee_name: employeeA.display_name,
      assignment_mode: 'fixed',
      schedule: {
        kind: 'every_day',
        weekdays: [],
        start_date: today,
        end_date: null,
        due_time: '17:30',
      },
      status: 'active',
    },
    {
      id: '93000000-0000-0000-0000-000000000003',
      title: 'Rà soát nội dung chương trình tuần',
      seller_id: sellerA.id,
      seller_name: sellerA.name,
      assignee_member_id: employeeB.member_id,
      assignee_name: employeeB.display_name,
      assignment_mode: 'fixed',
      schedule: {
        kind: 'weekdays',
        weekdays: [1, 3, 5],
        start_date: today,
        end_date: null,
        due_time: '15:00',
      },
      status: 'paused',
    },
  ];
}
