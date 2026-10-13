import { describe, expect, it } from 'vitest';
import {
  isFreshWifiClaim,
  isSameOriginWebRequest,
  sha256Hex,
  trustedSourceIpFromHeaders,
} from '../lib/attendance/server';

describe('P06 attendance server boundary', () => {
  it('ATT-05: trusted ingress is explicit and disabled by default', () => {
    expect(trustedSourceIpFromHeaders(new Headers(), 'none')).toEqual({
      status: 'unavailable',
      code: 'TRUSTED_INGRESS_NOT_CONFIGURED',
    });
  });

  it('ATT-03: Vercel adapter accepts only a parseable source IP', () => {
    const headers = new Headers({ 'x-vercel-forwarded-for': '203.0.113.10, 10.0.0.2' });
    expect(trustedSourceIpFromHeaders(headers, 'vercel')).toEqual({
      status: 'trusted',
      sourceIp: '203.0.113.10',
      provider: 'vercel',
    });
    expect(
      trustedSourceIpFromHeaders(new Headers({ 'x-vercel-forwarded-for': 'not-an-ip' }), 'vercel'),
    ).toEqual({ status: 'unavailable', code: 'TRUSTED_SOURCE_IP_UNAVAILABLE' });
  });

  it('ATT-01/02: a Wi-Fi claim older than five seconds cannot be finalized', () => {
    const now = Date.parse('2026-10-05T03:00:10.000Z');
    expect(isFreshWifiClaim('2026-10-05T03:00:06.000Z', now)).toBe(true);
    expect(isFreshWifiClaim('2026-10-05T03:00:04.000Z', now)).toBe(false);
  });

  it('ATT-09: nonce material is compared through a stable SHA-256 digest', () => {
    expect(sha256Hex('opsdesk-attendance-nonce')).toHaveLength(64);
    expect(sha256Hex('opsdesk-attendance-nonce')).toBe(sha256Hex('opsdesk-attendance-nonce'));
  });

  it('ATT-30: laptop-session creation excludes bearer/mobile-style requests', () => {
    const url = 'https://opsdesk.test/api/attendance/laptop-session';
    expect(
      isSameOriginWebRequest(
        new Request(url, { method: 'POST', headers: { origin: 'https://opsdesk.test' } }),
      ),
    ).toBe(true);
    expect(isSameOriginWebRequest(new Request(url, { method: 'POST' }))).toBe(false);
    expect(
      isSameOriginWebRequest(
        new Request(url, {
          method: 'POST',
          headers: { authorization: 'Bearer mobile-token', origin: 'https://opsdesk.test' },
        }),
      ),
    ).toBe(false);
    expect(
      isSameOriginWebRequest(
        new Request(url, { method: 'POST', headers: { origin: 'https://other.test' } }),
      ),
    ).toBe(false);
  });
});
