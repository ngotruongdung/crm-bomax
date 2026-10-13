import { createHash, randomBytes } from 'node:crypto';

export type InvitationToken = {
  token: string;
  tokenHash: string;
};

export function createInvitationToken(): InvitationToken {
  const token = randomBytes(32).toString('base64url');
  return {
    token,
    tokenHash: createHash('sha256').update(token, 'utf8').digest('hex'),
  };
}

/**
 * Auth must first exchange its code in the callback route. The app invitation
 * token remains in an internal `next` path and is validated only after login.
 */
export function createInvitationAuthRedirect(origin: string, token: string): string {
  const normalizedOrigin = new URL(origin).origin;
  const acceptInvite = new URL('/auth/accept-invite', normalizedOrigin);
  acceptInvite.searchParams.set('token', token);

  const callback = new URL('/auth/callback', normalizedOrigin);
  callback.searchParams.set('next', `${acceptInvite.pathname}${acceptInvite.search}`);
  return callback.toString();
}

export function invitationErrorCode(error: { message?: string | null } | null | undefined): string {
  const message = error?.message ?? '';
  const match = message.match(
    /\b(?:ADMIN_REQUIRED|AUTHENTICATION_REQUIRED|INVITE_EMAIL_MISMATCH|INVITE_INVALID_OR_EXPIRED|INVALID_DISPLAY_NAME|SELF_INVITE_NOT_ALLOWED|MEMBER_ALREADY_ACTIVE)\b/,
  );
  return match?.[0] ?? 'INVITATION_COMMAND_FAILED';
}
