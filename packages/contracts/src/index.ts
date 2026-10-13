import { z } from 'zod';

export const organizationIdSchema = z.string().uuid();

export const commandMetaSchema = z.object({
  organization_id: organizationIdSchema,
  idempotency_key: z.string().min(1),
  expected_version: z.number().int().nonnegative().optional(),
});

export type CommandMeta = z.infer<typeof commandMetaSchema>;

export * from './organization';
export * from './attendance';
export * from './task';
export * from './timesheet';
export * from './notification';
export * from './report';
export * from './security';
