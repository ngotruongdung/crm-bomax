import { describe, expect, it } from 'vitest';
import {
  encodeCsvCell,
  exportScopeStillContained,
  fileSizeLimitBytes,
  shouldDeleteRetainedFile,
  signedUrlTtlSeconds,
} from '../src/security';

describe('P10 security policy helpers', () => {
  it('SEC-03 keeps evidence URLs shorter than ordinary file/export URLs', () => {
    expect(signedUrlTtlSeconds('attendance')).toBe(90);
    expect(signedUrlTtlSeconds('request')).toBe(90);
    expect(signedUrlTtlSeconds('task')).toBe(300);
    expect(signedUrlTtlSeconds('export')).toBe(300);
  });

  it('SEC-04 enforces purpose-specific upload limits', () => {
    expect(fileSizeLimitBytes('attendance')).toBe(5 * 1024 * 1024);
    expect(fileSizeLimitBytes('request')).toBe(10 * 1024 * 1024);
    expect(fileSizeLimitBytes('task')).toBe(20 * 1024 * 1024);
  });

  it('SEC-05 neutralizes spreadsheet formulas while preserving ordinary text', () => {
    expect(encodeCsvCell('=2+2')).toBe("'=2+2");
    expect(encodeCsvCell('+cmd')).toBe("'+cmd");
    expect(encodeCsvCell('-1+2')).toBe("'-1+2");
    expect(encodeCsvCell('@SUM(A1:A2)')).toBe("'@SUM(A1:A2)");
    expect(encodeCsvCell('Bình thường')).toBe('Bình thường');
  });

  it('SEC-06 rejects a stale manager export scope that is broader than current scope', () => {
    const snapshot = {
      kind: 'sellers' as const,
      seller_ids: ['10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'],
    };
    const current = {
      kind: 'sellers' as const,
      seller_ids: ['10000000-0000-4000-8000-000000000001'],
    };
    expect(exportScopeStillContained(snapshot, current)).toBe(false);
    expect(exportScopeStillContained(current, snapshot)).toBe(true);
  });

  it('SEC-07 never deletes an expired file while legal hold is active', () => {
    const now = new Date('2026-10-05T08:00:00.000Z');
    expect(
      shouldDeleteRetainedFile({
        legal_hold: true,
        retention_until: '2026-10-01T00:00:00.000Z',
        state: 'ready',
        now,
      }),
    ).toBe(false);
    expect(
      shouldDeleteRetainedFile({
        legal_hold: false,
        retention_until: '2026-10-01T00:00:00.000Z',
        state: 'ready',
        now,
      }),
    ).toBe(true);
  });
});
