import { attendanceCommitSchema, attendanceFinalizeRequestSchema } from '@opsdesk/contracts';
import { createSupabasePrivilegedServerClient } from '../../../../lib/supabase/admin';
import { verifyAttendanceImageBytes } from '../../../../lib/files/image-validation';
import {
  attendanceFailure,
  isFreshWifiClaim,
  isSameOriginWebRequest,
  requestOriginAllowed,
  requireAttendanceActor,
  sha256Hex,
  trustedSourceIpFromHeaders,
} from '../../../../lib/attendance/server';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return attendanceFailure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = attendanceFinalizeRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return attendanceFailure('VALIDATION_ERROR', 400);

  try {
    const admin = createSupabasePrivilegedServerClient();
    const { data: challenge, error: challengeError } = await admin
      .from('attendance_challenges')
      .select('id,organization_id,member_id,mode,device_id,expires_at,consumed_at')
      .eq('id', parsed.data.challenge_id)
      .single();
    if (challengeError || !challenge) return attendanceFailure('CHALLENGE_NOT_FOUND', 404);

    const actor = await requireAttendanceActor(request, challenge.organization_id);
    if (actor.member_id !== challenge.member_id)
      return attendanceFailure('CHALLENGE_OWNER_MISMATCH', 403);
    if (challenge.device_id !== parsed.data.device_id)
      return attendanceFailure('DEVICE_MISMATCH', 403);

    let sourceIp: string | null = null;
    let bssid: string | null = null;
    if (challenge.mode === 'office') {
      const hasNativeWifiClaim = Boolean(parsed.data.wifi_claim);
      const isWebOfficeAttempt = isSameOriginWebRequest(request) && !hasNativeWifiClaim;
      if (hasNativeWifiClaim && !isFreshWifiClaim(parsed.data.wifi_claim!.captured_at_device)) {
        return attendanceFailure('WIFI_CLAIM_STALE_OR_MISSING', 422);
      }
      if (!hasNativeWifiClaim && !isWebOfficeAttempt) {
        return attendanceFailure('WIFI_CLAIM_STALE_OR_MISSING', 422);
      }
      if (isWebOfficeAttempt) {
        const { data: settings, error: settingsError } = await admin
          .from('attendance_settings')
          .select('allow_web_office_attendance')
          .eq('organization_id', actor.organization_id)
          .maybeSingle();
        if (settingsError || !settings?.allow_web_office_attendance) {
          return attendanceFailure('WEB_OFFICE_ATTENDANCE_DISABLED', 403);
        }
      }
      const ingress = trustedSourceIpFromHeaders(request.headers);
      if (ingress.status !== 'trusted') return attendanceFailure(ingress.code, 503);
      sourceIp = ingress.sourceIp;
      bssid = parsed.data.wifi_claim?.bssid.toLowerCase() ?? null;
    }

    if (challenge.mode === 'remote') {
      if (!parsed.data.file_id) return attendanceFailure('REMOTE_EVIDENCE_REQUIRED', 422);
      const { data: file, error: fileError } = await admin
        .from('files')
        .select(
          'id,organization_id,uploaded_by_member_id,bucket_id,object_path,mime_type,size_bytes,purpose,state',
        )
        .eq('id', parsed.data.file_id)
        .single();
      if (
        fileError ||
        !file ||
        file.organization_id !== actor.organization_id ||
        file.uploaded_by_member_id !== actor.member_id ||
        file.purpose !== 'attendance'
      ) {
        return attendanceFailure('REMOTE_EVIDENCE_INVALID', 422);
      }
      if (!['pending', 'ready'].includes(file.state)) {
        return attendanceFailure('REMOTE_EVIDENCE_INVALID_CONTENT', 422);
      }
      const { data: uploadIntent, error: uploadIntentError } = await admin
        .from('upload_intents')
        .select(
          'id,organization_id,member_id,file_id,target_kind,challenge_id,expires_at,consumed_at',
        )
        .eq('organization_id', actor.organization_id)
        .eq('member_id', actor.member_id)
        .eq('file_id', file.id)
        .eq('target_kind', 'attendance')
        .eq('challenge_id', challenge.id)
        .is('consumed_at', null)
        .gt('expires_at', new Date().toISOString())
        .maybeSingle();
      if (uploadIntentError || !uploadIntent) {
        return attendanceFailure('REMOTE_UPLOAD_INTENT_INVALID', 422);
      }
      const { data: exists, error: existsError } = await admin.storage
        .from(file.bucket_id)
        .exists(file.object_path);
      if (existsError || !exists) return attendanceFailure('REMOTE_EVIDENCE_NOT_UPLOADED', 422);
      if (file.state !== 'ready') {
        const { data: blob, error: downloadError } = await admin.storage
          .from(file.bucket_id)
          .download(file.object_path);
        if (downloadError || !blob) return attendanceFailure('REMOTE_EVIDENCE_VERIFY_FAILED', 503);
        const bytes = new Uint8Array(await blob.arrayBuffer());
        const verified = verifyAttendanceImageBytes(bytes, file.mime_type, file.size_bytes);
        if (!verified) {
          await admin
            .from('files')
            .update({ state: 'quarantined', verification_code: 'CONTENT_VALIDATION_FAILED' })
            .eq('id', file.id)
            .eq('state', 'pending');
          return attendanceFailure('REMOTE_EVIDENCE_INVALID_CONTENT', 422);
        }
        const { error: readyError } = await admin
          .from('files')
          .update({
            state: 'ready',
            verified_at: new Date().toISOString(),
            verification_code: 'CONTENT_VERIFIED',
          })
          .eq('id', file.id)
          .eq('state', 'pending');
        if (readyError) return attendanceFailure('REMOTE_EVIDENCE_FINALIZE_FAILED', 503);
      }
    }

    const { data, error } = await admin.rpc('rpc_internal_finalize_attendance', {
      p_challenge_id: parsed.data.challenge_id,
      p_nonce_hash: sha256Hex(parsed.data.nonce),
      p_bssid: bssid,
      p_source_ip: sourceIp,
      p_file_id: parsed.data.file_id ?? null,
      p_laptop_session_id: parsed.data.laptop_session_id ?? null,
      p_idempotency_key: parsed.data.idempotency_key,
    });
    if (error || !data || typeof data !== 'object') {
      return attendanceFailure(error?.message ?? 'ATTENDANCE_FINALIZE_FAILED', 422);
    }
    const response = attendanceCommitSchema.safeParse(data);
    if (!response.success) return attendanceFailure('ATTENDANCE_COMMIT_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: response.data });
  } catch {
    return attendanceFailure('ATTENDANCE_SERVER_NOT_CONFIGURED', 503);
  }
}
