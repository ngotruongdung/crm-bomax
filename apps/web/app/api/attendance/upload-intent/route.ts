import { randomUUID } from 'node:crypto';
import {
  attendanceUploadIntentRequestSchema,
  attendanceUploadIntentResponseSchema,
} from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';
import {
  attendanceFailure,
  requestOriginAllowed,
  requireAttendanceActor,
} from '../../../../lib/attendance/server';

export const runtime = 'nodejs';
const BUCKET = 'attendance-evidence';

function extensionForMime(mime: string) {
  if (mime === 'image/webp') return 'webp';
  return 'jpg';
}

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return attendanceFailure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = attendanceUploadIntentRequestSchema.safeParse(
    await request.json().catch(() => null),
  );
  if (!parsed.success) return attendanceFailure('VALIDATION_ERROR', 400);

  try {
    const admin = createSupabasePrivilegedServerClient();
    const { data: challenge, error: challengeError } = await admin
      .from('attendance_challenges')
      .select('id,organization_id,member_id,mode,expires_at,consumed_at')
      .eq('id', parsed.data.challenge_id)
      .single();
    if (challengeError || !challenge) return attendanceFailure('CHALLENGE_NOT_FOUND', 404);

    const actor = await requireAttendanceActor(request, challenge.organization_id);
    if (actor.member_id !== challenge.member_id)
      return attendanceFailure('CHALLENGE_OWNER_MISMATCH', 403);
    if (challenge.mode !== 'remote') return attendanceFailure('REMOTE_EVIDENCE_NOT_ALLOWED', 422);
    if (challenge.consumed_at || Date.parse(challenge.expires_at) <= Date.now()) {
      return attendanceFailure('CHALLENGE_EXPIRED', 409);
    }

    const objectPath = `${actor.organization_id}/attendance/${challenge.id}/${randomUUID()}.${extensionForMime(parsed.data.mime_type)}`;
    const { data: retentionPolicy, error: retentionError } = await admin
      .from('policy_versions')
      .select('config')
      .eq('organization_id', actor.organization_id)
      .eq('policy_kind', 'retention')
      .lte('effective_from', new Date().toISOString())
      .order('effective_from', { ascending: false })
      .order('version_number', { ascending: false })
      .limit(1)
      .maybeSingle();
    const retentionDays = Number(
      retentionPolicy && typeof retentionPolicy.config === 'object' && retentionPolicy.config
        ? (retentionPolicy.config as Record<string, unknown>).attendance_photo_retention_days
        : NaN,
    );
    if (
      retentionError ||
      !Number.isInteger(retentionDays) ||
      retentionDays < 1 ||
      retentionDays > 3650
    ) {
      return attendanceFailure('RETENTION_POLICY_REQUIRED', 503);
    }
    const retentionUntil = new Date(Date.now() + retentionDays * 86_400_000).toISOString();
    const expiresAt = new Date(
      Math.min(Date.parse(challenge.expires_at), Date.now() + 120_000),
    ).toISOString();
    const { data: fileRow, error: fileError } = await admin
      .from('files')
      .insert({
        organization_id: actor.organization_id,
        uploaded_by_member_id: actor.member_id,
        bucket_id: BUCKET,
        object_path: objectPath,
        original_name: `attendance-${challenge.id}.${extensionForMime(parsed.data.mime_type)}`,
        mime_type: parsed.data.mime_type,
        size_bytes: parsed.data.size_bytes,
        purpose: 'attendance',
        state: 'pending',
        retention_until: retentionUntil,
      })
      .select('id')
      .single();
    if (fileError || !fileRow) return attendanceFailure('UPLOAD_INTENT_CREATE_FAILED', 503);

    const { error: intentError } = await admin.from('upload_intents').insert({
      organization_id: actor.organization_id,
      member_id: actor.member_id,
      file_id: fileRow.id,
      target_kind: 'attendance',
      challenge_id: challenge.id,
      expires_at: expiresAt,
    });
    if (intentError) return attendanceFailure('UPLOAD_INTENT_CREATE_FAILED', 503);

    const { data: signed, error: signedError } = await admin.storage
      .from(BUCKET)
      .createSignedUploadUrl(objectPath, { upsert: false });
    if (signedError || !signed) return attendanceFailure('SIGNED_UPLOAD_UNAVAILABLE', 503);

    const response = attendanceUploadIntentResponseSchema.safeParse({
      file_id: fileRow.id,
      bucket_id: BUCKET,
      object_path: objectPath,
      signed_url: signed.signedUrl,
      token: signed.token,
      expires_at: expiresAt,
    });
    if (!response.success) return attendanceFailure('UPLOAD_INTENT_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('ATTENDANCE_SERVER_NOT_CONFIGURED', 503);
  }
}
