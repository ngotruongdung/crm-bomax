import { describe, expect, it } from 'vitest';
import { bootstrapStatus } from '@opsdesk/domain';

describe('web bootstrap', () => {
  it('exposes the P00 status contract', () => {
    expect(bootstrapStatus.code).toBe('P00_BOOTSTRAPPED');
    expect(bootstrapStatus.label).toContain('Bootstrap');
  });
});
