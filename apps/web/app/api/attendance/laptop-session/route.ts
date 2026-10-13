import { remoteLaptopSessionRequestSchema, remoteLaptopSessionSchema } from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';
import {
  attendanceFailure,
  createRemoteDisplayCode,
  isSameOriginWebRequest,
  requestOriginAllowed,
  requireAttendanceActor,
} from '../../../../lib/attendance/server';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return attendanceFailure('ORIGIN_NOT_ALLOWED', 403);
  if (!isSameOriginWebRequest(request)) {
    return attendanceFailure('LAPTOP_SESSION_DESKTOP_WEB_REQUIRED', 403);
  }
  const parsed = remoteLaptopSessionRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return attendanceFailure('VALIDATION_ERROR', 400);

  let actor;
  try {
    actor = await requireAttendanceActor(request, parsed.data.organization_id);
  } catch {
    return attendanceFailure('AUTHENTICATION_OR_MEMBERSHIP_REQUIRED', 401);
  }

  try {
    const admin = createSupabasePrivilegedServerClient();
    const { displayCode, codeHash } = createRemoteDisplayCode();
    const { data, error } = await admin.rpc('rpc_internal_create_remote_laptop_session', {
      p_organization_id: actor.organization_id,
      p_member_id: actor.member_id,
      p_shift_instance_id: parsed.data.shift_instance_id,
      p_code_hash: codeHash,
    });
    if (error || !data || typeof data !== 'object') {
      return attendanceFailure(error?.message ?? 'LAPTOP_SESSION_FAILED', 422);
    }
    const response = remoteLaptopSessionSchema.safeParse({ ...data, display_code: displayCode });
    if (!response.success) return attendanceFailure('LAPTOP_SESSION_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('ATTENDANCE_SERVER_NOT_CONFIGURED', 503);
  }
}
