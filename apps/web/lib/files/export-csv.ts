import { encodeCsvRow } from '@opsdesk/domain';

export function csvDocument(headers: readonly string[], rows: readonly (readonly unknown[])[]) {
  const lines = [encodeCsvRow(headers), ...rows.map((row) => encodeCsvRow(row))];
  return `\uFEFF${lines.join('\r\n')}\r\n`;
}

export function safeJsonCell(value: unknown) {
  return JSON.stringify(value ?? null);
}
