import { z } from 'zod';

export const filePurposeSchema = z.enum(['task', 'attendance', 'request', 'export']);
export type FilePurpose = z.infer<typeof filePurposeSchema>;

export const fileDownloadGrantSchema = z.object({
  file_id: z.string().uuid(),
  bucket_id: z.string().min(1),
  object_path: z.string().min(1),
  original_name: z.string().min(1),
  mime_type: z.string().min(1),
  size_bytes: z.number().int().positive(),
  purpose: filePurposeSchema,
});
export type FileDownloadGrant = z.infer<typeof fileDownloadGrantSchema>;

export const exportKindSchema = z.enum(['tasks', 'timesheet', 'report', 'audit']);
export type ExportKind = z.infer<typeof exportKindSchema>;

export const exportScopeSchema = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('organization') }),
  z.object({ kind: z.literal('sellers'), seller_ids: z.array(z.string().uuid()).min(1) }),
  z.object({ kind: z.literal('personal'), member_id: z.string().uuid() }),
]);
export type ExportScope = z.infer<typeof exportScopeSchema>;

export const exportJobSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  requested_by: z.string().uuid(),
  export_kind: exportKindSchema,
  format: z.literal('csv'),
  status: z.enum(['queued', 'processing', 'ready', 'failed', 'expired']),
  scope_snapshot: exportScopeSchema,
  parameters: z.record(z.string(), z.unknown()).default({}),
  file_id: z.string().uuid().nullable(),
  requested_at: z.string().datetime({ offset: true }),
  completed_at: z.string().datetime({ offset: true }).nullable(),
  expires_at: z.string().datetime({ offset: true }).nullable(),
  error_code: z.string().nullable(),
});
export type ExportJob = z.infer<typeof exportJobSchema>;

export const exportRequestSchema = z.object({
  organization_id: z.string().uuid(),
  export_kind: exportKindSchema,
  format: z.literal('csv').default('csv'),
  parameters: z.record(z.string(), z.unknown()).default({}),
  idempotency_key: z.string().min(8).max(240),
});
export type ExportRequest = z.infer<typeof exportRequestSchema>;

export const auditLogItemSchema = z.object({
  id: z.string().uuid(),
  organization_id: z.string().uuid(),
  actor_member_id: z.string().uuid().nullable(),
  actor_kind: z.enum(['member', 'system']),
  actor_display_name: z.string().nullable(),
  action: z.string().min(1),
  entity_type: z.string().min(1),
  entity_id: z.string().uuid().nullable(),
  recorded_at: z.string().datetime({ offset: true }),
  request_id: z.string().uuid(),
  safe_metadata: z.record(z.string(), z.unknown()),
});
export type AuditLogItem = z.infer<typeof auditLogItemSchema>;

export const auditLogPageSchema = z.object({
  items: z.array(auditLogItemSchema),
  next_before: z.string().datetime({ offset: true }).nullable(),
});
export type AuditLogPage = z.infer<typeof auditLogPageSchema>;
