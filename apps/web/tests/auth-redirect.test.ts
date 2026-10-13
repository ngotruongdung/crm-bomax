import { describe, expect, it } from 'vitest';
import { safeAuthRedirect } from '../lib/auth/redirect';

describe('safeAuthRedirect', () => {
  it('keeps an internal path', () => {
    expect(safeAuthRedirect('/dashboard?tab=team')).toBe('/dashboard?tab=team');
  });

  it('rejects absolute URLs', () => {
    expect(safeAuthRedirect('https://example.com')).toBe('/');
  });

  it('rejects protocol-relative URLs', () => {
    expect(safeAuthRedirect('//example.com')).toBe('/');
  });

  it('rejects backslash-normalized external URLs', () => {
    expect(safeAuthRedirect('/\\example.com')).toBe('/');
  });
});
