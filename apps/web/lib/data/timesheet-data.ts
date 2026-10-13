import {
  memberDirectorySchema,
  timesheetViewSchema,
  type OrganizationContext,
  type TimesheetView,
} from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../supabase/server';

export function currentMonthStart(context: OrganizationContext) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: context.timezone,
    year: 'numeric',
    month: '2-digit',
  }).formatToParts(new Date(context.server_now));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-01`;
}

export function normalizeTimesheetMonth(context: OrganizationContext, value?: string | string[]) {
  const candidate = Array.isArray(value) ? value[0] : value;
  if (!candidate || !/^\d{4}-(0[1-9]|1[0-2])$/.test(candidate)) {
    return currentMonthStart(context);
  }
  return `${candidate}-01`;
}

export function shiftTimesheetMonth(monthStart: string, delta: number) {
  const [year, month] = monthStart.split('-').map(Number);
  if (!year || !month) return monthStart;
  const shifted = new Date(Date.UTC(year, month - 1 + delta, 1));
  return `${shifted.getUTCFullYear()}-${String(shifted.getUTCMonth() + 1).padStart(2, '0')}-01`;
}

export async function loadTimesheetView(
  context: OrganizationContext,
  memberId = context.member_id,
  monthStart = currentMonthStart(context),
): Promise<TimesheetView> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc('rpc_get_timesheet', {
    p_organization_id: context.organization_id,
    p_month_start: monthStart,
    p_member_id: memberId,
  });
  if (error) throw new Error(`TIMESHEET_LOAD_FAILED:${error.message}`);
  const parsed = timesheetViewSchema.safeParse(data);
  if (!parsed.success) throw new Error('TIMESHEET_CONTRACT_INVALID');
  return parsed.data;
}

export async function loadTimesheetRoster(
  context: OrganizationContext,
  monthStart = currentMonthStart(context),
): Promise<TimesheetView[]> {
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc('rpc_list_members_by_scope', {
    p_organization_id: context.organization_id,
  });
  if (error) throw new Error(`TIMESHEET_ROSTER_FAILED:${error.message}`);
  const directory = memberDirectorySchema.safeParse(data);
  if (!directory.success) throw new Error('TIMESHEET_ROSTER_CONTRACT_INVALID');
  return Promise.all(
    directory.data
      .filter((member) => member.status === 'active')
      .map((member) => loadTimesheetView(context, member.member_id, monthStart)),
  );
}
