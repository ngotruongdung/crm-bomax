import { NextResponse } from 'next/server';
import type { Json } from '@opsdesk/api-client';
import {
  createInvitationAuthRedirect,
  createInvitationToken,
  invitationErrorCode,
} from '../../../../lib/invitations';
import { createSupabaseAdminClient } from '../../../../lib/supabase/admin';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';

export const runtime = 'nodejs';

type InvitePayload = {
  organization_id?: unknown;
  email?: unknown;
  role?: unknown;
  capabilities?: unknown;
  seller_scope?: unknown;
  expires_at?: unknown;
};

function asInvitePayload(value: unknown): InvitePayload | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as InvitePayload)
    : null;
}

function asRequiredString(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function commandFailure(code: string, status: number) {
  return NextResponse.json({ ok: false, error: { code } }, { status });
}

function publicCommandStatus(code: string): number {
  if (code === 'AUTHENTICATION_REQUIRED') return 401;
  if (code === 'ADMIN_REQUIRED' || code === 'SELF_INVITE_NOT_ALLOWED') return 403;
  if (code === 'MEMBER_ALREADY_ACTIVE') return 409;
  return 422;
}

export async function POST(request: Request) {
  const requestUrl = new URL(request.url);
  const origin = request.headers.get('origin');
  if (origin && origin !== requestUrl.origin) {
    return commandFailure('ORIGIN_NOT_ALLOWED', 403);
  }

  let body: InvitePayload | null;
  try {
    body = asInvitePayload(await request.json());
  } catch {
    return commandFailure('VALIDATION_ERROR', 400);
  }

  const organizationId = asRequiredString(body?.organization_id);
  const email = asRequiredString(body?.email)?.toLowerCase();
  const role = asRequiredString(body?.role);
  if (!organizationId || !email || !role) {
    return commandFailure('VALIDATION_ERROR', 400);
  }

  const client = await createSupabaseServerClient();
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    return commandFailure('AUTHENTICATION_REQUIRED', 401);
  }

  if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return commandFailure('INVITATION_DELIVERY_NOT_CONFIGURED', 503);
  }

  const expiresAt =
    typeof body?.expires_at === 'string' && !Number.isNaN(Date.parse(body.expires_at))
      ? body.expires_at
      : new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
  const { token, tokenHash } = createInvitationToken();

  const { data: invitation, error: invitationError } = await client.rpc('rpc_create_invitation', {
    p_organization_id: organizationId,
    p_email: email,
    p_role: role,
    p_capabilities: (body?.capabilities ?? {}) as Json,
    p_seller_scope: (body?.seller_scope ?? []) as Json,
    p_token_hash: tokenHash,
    p_expires_at: expiresAt,
  });

  if (invitationError || !invitation || typeof invitation !== 'object') {
    const code = invitationErrorCode(invitationError);
    return commandFailure(code, publicCommandStatus(code));
  }

  const invitationId = (invitation as { invitation_id?: unknown }).invitation_id;
  if (typeof invitationId !== 'string') {
    return commandFailure('INVITATION_COMMAND_FAILED', 502);
  }

  let redirectTo: string;
  try {
    redirectTo = createInvitationAuthRedirect(requestUrl.origin, token);
  } catch {
    return commandFailure('INVITATION_DELIVERY_FAILED', 500);
  }

  const admin = createSupabaseAdminClient();
  const { data: authInvite, error: authInviteError } = await admin.auth.admin.inviteUserByEmail(
    email,
    {
      redirectTo,
    },
  );

  if (authInviteError || !authInvite.user) {
    // The DB invitation is intentionally left open. A retry replaces the token in the
    // same invitation record; the Auth user has no application membership at this point.
    return commandFailure('INVITATION_DELIVERY_PENDING', 503);
  }

  const { error: referenceError } = await admin.rpc('rpc_internal_set_invitation_auth_reference', {
    p_invitation_id: invitationId,
    p_auth_invite_reference: authInvite.user.id,
  });
  if (referenceError) {
    return commandFailure('INVITATION_DELIVERY_PENDING', 503);
  }

  return NextResponse.json({
    ok: true,
    data: {
      invitation_id: invitationId,
      expires_at: (invitation as { expires_at?: unknown }).expires_at ?? expiresAt,
    },
  });
}
