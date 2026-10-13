import {
  attendanceChallengeRequestSchema,
  attendanceChallengeResponseSchema,
} from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';
import {
  attendanceFailure,
  createAttendanceNonce,
  requestOriginAllowed,
  requireAttendanceActor,
} from '../../../../lib/attendance/server';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return attendanceFailure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = attendanceChallengeRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return attendanceFailure('VALIDATION_ERROR', 400);

  let actor;
  try {
    actor = await requireAttendanceActor(request, parsed.data.organization_id);
  } catch {
    return attendanceFailure('AUTHENTICATION_OR_MEMBERSHIP_REQUIRED', 401);
  }

  try {
    const admin = createSupabasePrivilegedServerClient();
    const { nonce, nonceHash } = createAttendanceNonce();
    const { data, error } = await admin.rpc('rpc_internal_create_attendance_challenge', {
      p_organization_id: actor.organization_id,
      p_member_id: actor.member_id,
      p_shift_instance_id: parsed.data.shift_instance_id,
      p_action: parsed.data.action,
      p_mode: parsed.data.mode,
      p_device_id: parsed.data.device_id,
      p_nonce_hash: nonceHash,
    });
    if (error || !data || typeof data !== 'object') {
      return attendanceFailure(error?.message ?? 'ATTENDANCE_CHALLENGE_FAILED', 422);
    }

    const response = attendanceChallengeResponseSchema.safeParse({ ...data, nonce });
    if (!response.success) return attendanceFailure('ATTENDANCE_CHALLENGE_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('ATTENDANCE_SERVER_NOT_CONFIGURED', 503);
  }
}
