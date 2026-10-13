import type { OrganizationContext } from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../supabase/admin';
import { loadWorkspaceContext } from './workspace-data';

export type AttendanceOffice = {
  id: string;
  name: string;
  timezone: string;
};

export type AttendanceNetwork = {
  bssid: string;
  id: string;
  office_id: string;
  ssid_label: string;
};

export type AttendanceIpRange = {
  id: string;
  ip_range: string;
  note: string | null;
  office_id: string;
};

export type AttendanceShiftTemplate = {
  allowed_mode: 'office' | 'remote' | 'hybrid';
  breaks: Array<{ end: string; start: string }>;
  end_local: string;
  id: string;
  name: string;
  office_id: string | null;
  standard_day_minutes: number;
  start_local: string;
};

export type AttendanceSettingsWorkspace = {
  canManage: boolean;
  context: OrganizationContext;
  ipRanges: AttendanceIpRange[];
  members: Array<{ display_name: string; id: string; employee_code: string }>;
  networks: AttendanceNetwork[];
  offices: AttendanceOffice[];
  schemaReady: boolean;
  shifts: AttendanceShiftTemplate[];
  webOfficeAttendanceEnabled: boolean;
};

function missingP12(error: { code?: string; message?: string } | null) {
  return (
    error?.code === '42P01' ||
    error?.code === 'PGRST205' ||
    error?.message?.includes('attendance_settings')
  );
}

export async function loadAttendanceSettingsWorkspace(): Promise<AttendanceSettingsWorkspace> {
  const { context } = await loadWorkspaceContext();
  const canManage =
    context.role === 'admin' || context.capabilities.includes('can_manage_attendance');
  const empty = {
    canManage,
    context,
    ipRanges: [],
    members: [],
    networks: [],
    offices: [],
    schemaReady: true,
    shifts: [],
    webOfficeAttendanceEnabled: false,
  };
  if (!canManage) return empty;

  const admin = createSupabasePrivilegedServerClient();
  const [
    settingsResult,
    officesResult,
    networksResult,
    ipRangesResult,
    shiftsResult,
    membersResult,
  ] = await Promise.all([
    admin
      .from('attendance_settings')
      .select('allow_web_office_attendance')
      .eq('organization_id', context.organization_id)
      .maybeSingle(),
    admin
      .from('offices')
      .select('id,name,timezone')
      .eq('organization_id', context.organization_id)
      .eq('active', true)
      .order('name'),
    admin
      .from('office_networks')
      .select('id,office_id,ssid_label,bssid')
      .eq('organization_id', context.organization_id)
      .is('valid_until', null)
      .order('ssid_label'),
    admin
      .from('office_ip_ranges')
      .select('id,office_id,ip_range,note')
      .eq('organization_id', context.organization_id)
      .is('valid_until', null)
      .order('created_at'),
    admin
      .from('shift_templates')
      .select('id,name,office_id,start_local,end_local,breaks,allowed_mode,standard_day_minutes')
      .eq('organization_id', context.organization_id)
      .eq('active', true)
      .order('name'),
    admin
      .from('organization_members')
      .select('id,display_name,employee_code')
      .eq('organization_id', context.organization_id)
      .eq('status', 'active')
      .order('display_name'),
  ]);

  if (missingP12(settingsResult.error)) return { ...empty, schemaReady: false };
  if (
    settingsResult.error ||
    officesResult.error ||
    networksResult.error ||
    ipRangesResult.error ||
    shiftsResult.error ||
    membersResult.error
  ) {
    throw new Error('ATTENDANCE_SETTINGS_LOAD_FAILED');
  }

  return {
    ...empty,
    ipRanges: (ipRangesResult.data ?? []) as AttendanceIpRange[],
    members: (membersResult.data ?? []) as AttendanceSettingsWorkspace['members'],
    networks: (networksResult.data ?? []) as AttendanceNetwork[],
    offices: (officesResult.data ?? []) as AttendanceOffice[],
    shifts: (shiftsResult.data ?? []).map((row) => ({
      ...row,
      allowed_mode: row.allowed_mode as AttendanceShiftTemplate['allowed_mode'],
      breaks: Array.isArray(row.breaks) ? (row.breaks as AttendanceShiftTemplate['breaks']) : [],
    })),
    webOfficeAttendanceEnabled: Boolean(settingsResult.data?.allow_web_office_attendance),
  };
}
