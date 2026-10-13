import { describe, expect, it } from 'vitest';
import {
  createInvitationAuthRedirect,
  createInvitationToken,
  invitationErrorCode,
} from '../lib/invitations';

describe('invitation server primitives', () => {
  it('creates a high-entropy token and hashes it without returning the raw value as the hash', () => {
    const invitation = createInvitationToken();

    expect(invitation.token).toHaveLength(43);
    expect(invitation.tokenHash).toMatch(/^[0-9a-f]{64}$/);
    expect(invitation.tokenHash).not.toBe(invitation.token);
  });

  it('routes Auth through the PKCE callback while preserving only an internal invitation path', () => {
    const redirect = new URL(createInvitationAuthRedirect('https://opsdesk.example', 'safe-token'));

    expect(redirect.origin).toBe('https://opsdesk.example');
    expect(redirect.pathname).toBe('/auth/callback');
    expect(redirect.searchParams.get('next')).toBe('/auth/accept-invite?token=safe-token');
  });

  it('maps known command failures without returning raw database details', () => {
    expect(invitationErrorCode({ message: 'INVITE_EMAIL_MISMATCH' })).toBe('INVITE_EMAIL_MISMATCH');
    expect(invitationErrorCode({ message: 'unexpected database detail' })).toBe(
      'INVITATION_COMMAND_FAILED',
    );
  });
});
