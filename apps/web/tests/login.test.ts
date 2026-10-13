import { describe, expect, it } from 'vitest';
import {
  loginFailureFromAuthCode,
  loginFailureMessage,
  parseLoginCommand,
} from '../lib/auth/login';

describe('login request helpers', () => {
  it('normalizes valid credentials and rejects malformed requests', () => {
    expect(parseLoginCommand({ email: ' admin@bomax.demo ', password: 'a-password' })).toEqual({
      email: 'admin@bomax.demo',
      password: 'a-password',
    });
    expect(parseLoginCommand({ email: 'not-an-email', password: 'a-password' })).toBeNull();
    expect(parseLoginCommand({ email: 'admin@bomax.demo', password: '' })).toBeNull();
  });

  it('returns safe login failures for Supabase authentication errors', () => {
    expect(loginFailureFromAuthCode('email_not_confirmed')).toBe('EMAIL_NOT_CONFIRMED');
    expect(loginFailureFromAuthCode('over_request_rate_limit')).toBe('RATE_LIMITED');
    expect(loginFailureFromAuthCode('invalid_credentials')).toBe('INVALID_CREDENTIALS');
    expect(loginFailureFromAuthCode('unexpected_upstream_detail')).toBe('CONTEXT_UNAVAILABLE');
    expect(loginFailureMessage('MEMBERSHIP_REQUIRED')).toContain('chưa được cấp quyền');
  });
});
