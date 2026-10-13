import { attendanceDaySchema } from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';
import { attendanceFailure, requireAttendanceActor } from '../../../../lib/attendance/server';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  const url = new URL(request.url);
  const organizationId = url.searchParams.get('organization_id');
  const workDate = url.searchParams.get('work_date');
  if (!organizationId || !workDate || !/^\d{4}-\d{2}-\d{2}$/.test(workDate)) {
    return attendanceFailure('VALIDATION_ERROR', 400);
  }

  try {
    const actor = await requireAttendanceActor(request, organizationId);
    const admin = createSupabasePrivilegedServerClient();
    const [
      { data: shift, error: shiftError },
      { data: sessions, error: sessionsError },
      { data: events, error: eventsError },
    ] = await Promise.all([
      admin
        .from('shift_instances')
        .select('id,starts_at,ends_at,scheduled_seconds,allowed_mode,office_id,status')
        .eq('organization_id', actor.organization_id)
        .eq('member_id', actor.member_id)
        .eq('work_date', workDate)
        .order('starts_at', { ascending: true })
        .limit(1)
        .maybeSingle(),
      admin
        .from('attendance_sessions')
        .select('id,starts_at,ends_at,mode,status,shift_instance_id')
        .eq('organization_id', actor.organization_id)
        .eq('member_id', actor.member_id)
        .order('starts_at', { ascending: true }),
      admin
        .from('attendance_events')
        .select('id,event_kind,effective_at,recorded_at,mode,verification_status,shift_instance_id')
        .eq('organization_id', actor.organization_id)
        .eq('member_id', actor.member_id)
        .order('effective_at', { ascending: true }),
    ]);

    if (shiftError || sessionsError || eventsError) {
      return attendanceFailure('ATTENDANCE_DAY_LOAD_FAILED', 503);
    }

    const shiftId = shift?.id ?? null;
    const response = attendanceDaySchema.safeParse({
      member_id: actor.member_id,
      work_date: workDate,
      server_now: new Date().toISOString(),
      shift: shift ?? null,
      sessions: shiftId
        ? (sessions ?? []).filter((item) => item.shift_instance_id === shiftId)
        : [],
      events: shiftId ? (events ?? []).filter((item) => item.shift_instance_id === shiftId) : [],
    });
    if (!response.success) return attendanceFailure('ATTENDANCE_DAY_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('AUTHENTICATION_OR_ATTENDANCE_SERVER_REQUIRED', 401);
  }
}
