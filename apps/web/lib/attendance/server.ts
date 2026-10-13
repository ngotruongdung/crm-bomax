import { createHash, randomBytes, randomInt } from 'node:crypto';
import { isIP } from 'node:net';
import { NextResponse } from 'next/server';
import { requireMemberContext } from '../auth/require-member';
import { createSupabasePrivilegedServerClient } from '../supabase/admin';

export type AttendanceActor = {
  organization_id: string;
  member_id: string;
  user_id: string;
};

export type TrustedIngressResult =
  | { status: 'trusted'; sourceIp: string; provider: 'vercel' | 'cloudflare' }
  | {
      status: 'unavailable';
      code: 'TRUSTED_INGRESS_NOT_CONFIGURED' | 'TRUSTED_SOURCE_IP_UNAVAILABLE';
    };

export function attendanceFailure(code: string, status: number) {
  return NextResponse.json({ ok: false, error: { code } }, { status });
}

export function requestOriginAllowed(request: Request) {
  const origin = request.headers.get('origin');
  return !origin || origin === new URL(request.url).origin;
}

export function sha256Hex(value: string) {
  return createHash('sha256').update(value, 'utf8').digest('hex');
}

export function createAttendanceNonce() {
  const nonce = randomBytes(32).toString('base64url');
  return { nonce, nonceHash: sha256Hex(nonce) };
}

export function createRemoteDisplayCode() {
  const displayCode = String(randomInt(100000, 1000000));
  return { displayCode, codeHash: sha256Hex(displayCode) };
}

export function isFreshWifiClaim(capturedAtDevice: string, nowMs = Date.now()) {
  const capturedMs = Date.parse(capturedAtDevice);
  if (Number.isNaN(capturedMs)) return false;
  const ageMs = nowMs - capturedMs;
  return ageMs >= -30_000 && ageMs <= 5_000;
}

function singleIp(value: string | null) {
  if (!value) return null;
  const first = value.split(',')[0]?.trim() ?? '';
  return isIP(first) ? first : null;
}

export function trustedSourceIpFromHeaders(
  headers: Headers,
  mode = process.env.ATTENDANCE_TRUSTED_INGRESS ?? 'none',
): TrustedIngressResult {
  if (mode === 'vercel') {
    const sourceIp = singleIp(headers.get('x-vercel-forwarded-for'));
    return sourceIp
      ? { status: 'trusted', sourceIp, provider: 'vercel' }
      : { status: 'unavailable', code: 'TRUSTED_SOURCE_IP_UNAVAILABLE' };
  }

  if (mode === 'cloudflare') {
    const sourceIp = singleIp(headers.get('cf-connecting-ip'));
    return sourceIp
      ? { status: 'trusted', sourceIp, provider: 'cloudflare' }
      : { status: 'unavailable', code: 'TRUSTED_SOURCE_IP_UNAVAILABLE' };
  }

  return { status: 'unavailable', code: 'TRUSTED_INGRESS_NOT_CONFIGURED' };
}

function bearerToken(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const token = authorization.slice('Bearer '.length).trim();
  return token || null;
}

export function isSameOriginWebRequest(request: Request) {
  const origin = request.headers.get('origin');
  return Boolean(origin && origin === new URL(request.url).origin && !bearerToken(request));
}

export async function requireAttendanceActor(
  request: Request,
  organizationId: string,
): Promise<AttendanceActor> {
  const token = bearerToken(request);
  if (!token) {
    const context = await requireMemberContext(organizationId);
    return {
      organization_id: context.organization_id,
      member_id: context.member_id,
      user_id: context.user_id,
    };
  }

  const admin = createSupabasePrivilegedServerClient();
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) throw new Error('AUTHENTICATION_REQUIRED');

  const { data: member, error: memberError } = await admin
    .from('organization_members')
    .select('id,organization_id,user_id,status,organizations!inner(status)')
    .eq('organization_id', organizationId)
    .eq('user_id', userData.user.id)
    .eq('status', 'active')
    .eq('organizations.status', 'active')
    .maybeSingle();
  if (memberError || !member) throw new Error('ACTIVE_MEMBERSHIP_REQUIRED');

  return {
    organization_id: member.organization_id,
    member_id: member.id,
    user_id: member.user_id,
  };
}
