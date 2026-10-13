import {
  attendanceDeviceRegistrationRequestSchema,
  attendanceDeviceRegistrationResponseSchema,
} from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';
import {
  attendanceFailure,
  requestOriginAllowed,
  requireAttendanceActor,
} from '../../../../lib/attendance/server';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return attendanceFailure('ORIGIN_NOT_ALLOWED', 403);

  const parsed = attendanceDeviceRegistrationRequestSchema.safeParse(
    await request.json().catch(() => null),
  );
  if (!parsed.success) return attendanceFailure('VALIDATION_ERROR', 400);

  let actor;
  try {
    actor = await requireAttendanceActor(request, parsed.data.organization_id);
  } catch {
    return attendanceFailure('AUTHENTICATION_OR_MEMBERSHIP_REQUIRED', 401);
  }

  try {
    const admin = createSupabasePrivilegedServerClient();
    const now = new Date().toISOString();
    const { data, error } = await admin
      .from('user_devices')
      .upsert(
        {
          organization_id: actor.organization_id,
          member_id: actor.member_id,
          installation_id: parsed.data.installation_id,
          platform: parsed.data.platform,
          label: parsed.data.label,
          last_seen_at: now,
          revoked_at: null,
        },
        { onConflict: 'organization_id,member_id,installation_id' },
      )
      .select('id,last_seen_at')
      .single();

    if (error || !data) return attendanceFailure('DEVICE_REGISTRATION_FAILED', 503);
    const response = attendanceDeviceRegistrationResponseSchema.safeParse({
      device_id: data.id,
      registered_at: data.last_seen_at,
    });
    if (!response.success) return attendanceFailure('DEVICE_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('ATTENDANCE_SERVER_NOT_CONFIGURED', 503);
  }
}
