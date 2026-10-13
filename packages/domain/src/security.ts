export type FilePurpose = 'task' | 'attendance' | 'request' | 'export';

export type ExportScope =
  | { kind: 'organization' }
  | { kind: 'sellers'; seller_ids: string[] }
  | { kind: 'personal'; member_id: string };

const purposeLimits: Record<FilePurpose, number> = {
  attendance: 5 * 1024 * 1024,
  request: 10 * 1024 * 1024,
  task: 20 * 1024 * 1024,
  export: 50 * 1024 * 1024,
};

const signedUrlTtls: Record<FilePurpose, number> = {
  attendance: 90,
  request: 90,
  task: 5 * 60,
  export: 5 * 60,
};

export function fileSizeLimitBytes(purpose: FilePurpose): number {
  return purposeLimits[purpose] ?? 0;
}

export function signedUrlTtlSeconds(purpose: FilePurpose): number {
  return signedUrlTtls[purpose] ?? 0;
}

export function escapeSpreadsheetFormulaCell(value: string): string {
  return /^[=+\-@]/.test(value) ? `'${value}` : value;
}

export function encodeCsvCell(value: unknown): string {
  const text = escapeSpreadsheetFormulaCell(value == null ? '' : String(value));
  return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

export function encodeCsvRow(values: readonly unknown[]): string {
  return values.map(encodeCsvCell).join(',');
}

export function exportScopeStillContained(snapshot: ExportScope, current: ExportScope): boolean {
  if (current.kind === 'organization') return true;
  if (snapshot.kind === 'organization') return false;
  if (snapshot.kind === 'personal') {
    return current.kind === 'personal' && snapshot.member_id === current.member_id;
  }
  if (current.kind !== 'sellers') return false;
  const allowed = new Set(current.seller_ids);
  return snapshot.seller_ids.every((sellerId) => allowed.has(sellerId));
}

export function shouldDeleteRetainedFile(input: {
  legal_hold: boolean;
  retention_until: string | null;
  state: 'pending' | 'ready' | 'quarantined' | 'deleted';
  now?: Date;
}): boolean {
  if (input.legal_hold || !input.retention_until || input.state === 'deleted') return false;
  const retentionMs = Date.parse(input.retention_until);
  if (Number.isNaN(retentionMs)) return false;
  return retentionMs <= (input.now ?? new Date()).getTime();
}
