import {
  remoteLaptopSessionResolveRequestSchema,
  remoteLaptopSessionResolveResponseSchema,
} from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../../lib/supabase/admin';
import {
  attendanceFailure,
  requestOriginAllowed,
  requireAttendanceActor,
  sha256Hex,
} from '../../../../../lib/attendance/server';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return attendanceFailure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = remoteLaptopSessionResolveRequestSchema.safeParse(
    await request.json().catch(() => null),
  );
  if (!parsed.success) return attendanceFailure('VALIDATION_ERROR', 400);

  try {
    const actor = await requireAttendanceActor(request, parsed.data.organization_id);
    const admin = createSupabasePrivilegedServerClient();
    const { data, error } = await admin.rpc('rpc_internal_resolve_remote_laptop_session', {
      p_organization_id: actor.organization_id,
      p_member_id: actor.member_id,
      p_shift_instance_id: parsed.data.shift_instance_id,
      p_code_hash: sha256Hex(parsed.data.display_code),
    });

    if (error || !data || typeof data !== 'object') {
      return attendanceFailure('LAPTOP_SESSION_INVALID', 404);
    }
    const result = data as {
      matched?: unknown;
      code?: unknown;
      session_id?: unknown;
      expires_at?: unknown;
    };
    if (result.matched !== true) {
      const code =
        result.code === 'LAPTOP_SESSION_LOCKED'
          ? 'LAPTOP_SESSION_LOCKED'
          : 'LAPTOP_SESSION_INVALID';
      return attendanceFailure(code, code === 'LAPTOP_SESSION_LOCKED' ? 429 : 404);
    }
    const response = remoteLaptopSessionResolveResponseSchema.safeParse({
      session_id: result.session_id,
      expires_at: result.expires_at,
    });
    if (!response.success) return attendanceFailure('LAPTOP_SESSION_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('AUTHENTICATION_OR_ATTENDANCE_SERVER_REQUIRED', 401);
  }
}
