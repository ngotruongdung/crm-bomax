import { describe, expect, it } from 'vitest';
import { csvDocument } from '../lib/files/export-csv';

describe('P10 CSV export', () => {
  it('SEC-05 escapes formula cells in generated exports', () => {
    const csv = csvDocument(['name', 'value'], [['=HYPERLINK("https://bad")', '+1']]);
    expect(csv).toContain("'=HYPERLINK");
    expect(csv).toContain("'+1");
  });

  it('quotes commas and preserves UTF-8 BOM for spreadsheet compatibility', () => {
    const csv = csvDocument(['Tên'], [['Nguyễn, An']]);
    expect(csv.startsWith('\uFEFF')).toBe(true);
    expect(csv).toContain('"Nguyễn, An"');
  });
});
