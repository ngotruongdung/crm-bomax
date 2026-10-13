import {
  attendanceDaySchema,
  memberDirectorySchema,
  type AttendanceDay,
  type OrganizationContext,
} from '@opsdesk/contracts';
import { createDemoTimesheetViews } from '../demo/timesheet-demo';
import type { WorkspaceDataSource } from '../demo/opsdesk-demo';
import { createSupabaseServerClient } from '../supabase/server';
import { loadWorkspaceContext } from './workspace-data';

export type AttendanceMonitorRow = {
  member_id: string;
  member_name: string;
  employee_code: string;
  day: AttendanceDay;
};

export type AttendanceMonitorData = {
  context: OrganizationContext;
  source: WorkspaceDataSource;
  rows: AttendanceMonitorRow[];
};

function dateInTimezone(value: string, timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(value));
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export async function loadAttendanceMonitorData(): Promise<AttendanceMonitorData> {
  const { context, source } = await loadWorkspaceContext();
  const today = dateInTimezone(context.server_now, context.timezone);

  if (!context.capabilities.includes('can_manage_attendance')) {
    return { context, source, rows: [] };
  }

  if (source === 'demo') {
    const rows = createDemoTimesheetViews(context).map((view) => {
      const preview = view.rows.find((item) => item.work_date === today);
      const sessions = preview?.first_check_in_at
        ? [
            {
              id: `00000000-0000-4000-8000-${view.member_id.replaceAll('-', '').slice(-12)}`,
              starts_at: preview.first_check_in_at,
              ends_at: preview.last_check_out_at,
              mode: preview.worked_remote_seconds ? ('remote' as const) : ('office' as const),
              status: preview.last_check_out_at ? ('closed' as const) : ('open' as const),
            },
          ]
        : [];
      const parsed = attendanceDaySchema.parse({
        member_id: view.member_id,
        work_date: today,
        server_now: context.server_now,
        shift: preview
          ? {
              id: `10000000-0000-4000-8000-${view.member_id.replaceAll('-', '').slice(-12)}`,
              starts_at: new Date(`${today}T09:00:00+07:00`).toISOString(),
              ends_at: new Date(`${today}T18:00:00+07:00`).toISOString(),
              scheduled_seconds: 28_800,
              allowed_mode: 'hybrid',
              office_id: null,
              status: 'scheduled',
            }
          : null,
        sessions,
        events: [],
      });
      return {
        member_id: view.member_id,
        member_name: view.member_name,
        employee_code: view.employee_code,
        day: parsed,
      };
    });
    return { context, source, rows };
  }

  const client = await createSupabaseServerClient();
  const { data: memberRows, error: membersError } = await client.rpc('rpc_list_members_by_scope', {
    p_organization_id: context.organization_id,
  });
  if (membersError) throw new Error('ATTENDANCE_MONITOR_MEMBERS_LOAD_FAILED');
  const members = memberDirectorySchema.safeParse(memberRows);
  if (!members.success) throw new Error('ATTENDANCE_MONITOR_MEMBER_CONTRACT_INVALID');

  const dayResults = await Promise.all(
    members.data
      .filter((member) => member.status === 'active')
      .map(async (member) => {
        const { data, error } = await client.rpc('rpc_get_attendance_day', {
          p_organization_id: context.organization_id,
          p_member_id: member.member_id,
          p_work_date: today,
        });
        if (error) throw new Error('ATTENDANCE_MONITOR_DAY_LOAD_FAILED');
        const parsed = attendanceDaySchema.safeParse({
          ...(typeof data === 'object' && data !== null ? data : {}),
          server_now: context.server_now,
        });
        if (!parsed.success) throw new Error('ATTENDANCE_MONITOR_DAY_CONTRACT_INVALID');
        return {
          member_id: member.member_id,
          member_name: member.display_name,
          employee_code: member.employee_code,
          day: parsed.data,
        };
      }),
  );

  return { context, source, rows: dayResults };
}
