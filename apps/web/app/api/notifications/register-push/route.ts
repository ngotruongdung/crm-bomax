import { pushRegistrationRequestSchema, pushRegistrationResponseSchema } from '@opsdesk/contracts';
import { requireAttendanceActor, requestOriginAllowed } from '../../../../lib/attendance/server';
import { encryptPushToken, pushTokenHash } from '../../../../lib/notifications/crypto';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';

export const runtime = 'nodejs';

function failure(code: string, status: number) {
  return Response.json({ ok: false, error: { code } }, { status });
}

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return failure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = pushRegistrationRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return failure('VALIDATION_ERROR', 400);

  let actor;
  try {
    actor = await requireAttendanceActor(request, parsed.data.organization_id);
  } catch {
    return failure('AUTHENTICATION_OR_MEMBERSHIP_REQUIRED', 401);
  }

  try {
    const admin = createSupabasePrivilegedServerClient();
    const { data: device, error: deviceError } = await admin
      .from('user_devices')
      .select('id,member_id,revoked_at')
      .eq('organization_id', actor.organization_id)
      .eq('id', parsed.data.device_id)
      .eq('member_id', actor.member_id)
      .maybeSingle();
    if (deviceError || !device || device.revoked_at) return failure('DEVICE_NOT_ACTIVE', 403);

    const tokenHash = pushTokenHash(parsed.data.token);
    const tokenEncrypted = encryptPushToken(parsed.data.token);
    const { data, error } = await admin
      .from('push_endpoints')
      .upsert(
        {
          organization_id: actor.organization_id,
          device_id: device.id,
          provider: parsed.data.provider,
          token_hash: tokenHash,
          token_encrypted: tokenEncrypted,
          active: true,
          last_error_code: null,
        },
        { onConflict: 'organization_id,provider,token_hash' },
      )
      .select('id,updated_at')
      .single();
    if (error || !data) return failure('PUSH_REGISTRATION_FAILED', 503);
    const response = pushRegistrationResponseSchema.safeParse({
      endpoint_id: data.id,
      registered_at: data.updated_at,
    });
    if (!response.success) return failure('PUSH_REGISTRATION_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch (error) {
    return failure(
      error instanceof Error && error.message === 'PUSH_TOKEN_ENCRYPTION_KEY_INVALID'
        ? 'PUSH_ENCRYPTION_NOT_CONFIGURED'
        : 'NOTIFICATION_SERVER_NOT_CONFIGURED',
      503,
    );
  }
}
