import { describe, expect, it } from 'vitest';
import { bootstrapStatus, isIsoDate } from '../src/index';

describe('domain bootstrap', () => {
  it('reports the current phase', () => {
    expect(bootstrapStatus.code).toBe('P00_BOOTSTRAPPED');
  });

  it('validates an ISO calendar date', () => {
    expect(isIsoDate('2026-10-04')).toBe(true);
    expect(isIsoDate('04/10/2026')).toBe(false);
  });
});
