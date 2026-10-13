import { describe, expect, it } from 'vitest';
import { canonicalAppUrl, canonicalizeLocalUrl } from '../lib/auth/canonical-origin';

describe('canonical local app origin', () => {
  it('redirects 127.0.0.1 to the configured localhost origin and preserves path/query', () => {
    const canonical = new URL('http://localhost:3000');
    expect(
      canonicalizeLocalUrl('http://127.0.0.1:3000/login?next=%2Foverview', canonical)?.href,
    ).toBe('http://localhost:3000/login?next=%2Foverview');
  });

  it('does not redirect an already canonical local request', () => {
    const canonical = new URL('http://localhost:3000');
    expect(canonicalizeLocalUrl('http://localhost:3000/overview', canonical)).toBeNull();
  });

  it('does not rewrite a non-local host', () => {
    const canonical = new URL('http://localhost:3000');
    expect(canonicalizeLocalUrl('https://opsdesk.example.com/overview', canonical)).toBeNull();
  });

  it('rejects invalid configured app URLs', () => {
    expect(canonicalAppUrl('not-a-url')).toBeNull();
  });
});
