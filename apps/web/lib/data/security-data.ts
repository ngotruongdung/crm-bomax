import {
  auditLogPageSchema,
  type AuditLogItem,
  type OrganizationContext,
} from '@opsdesk/contracts';
import { createDemoAuditLogs } from '../demo/security-demo';
import type { WorkspaceDataSource } from '../demo/opsdesk-demo';
import { createSupabaseServerClient } from '../supabase/server';

export async function loadAuditLogs(
  context: OrganizationContext,
  source: WorkspaceDataSource,
): Promise<AuditLogItem[]> {
  if (context.role !== 'admin') return [];
  if (source === 'demo') return createDemoAuditLogs(context);

  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc(
    'rpc_list_audit_logs' as never,
    {
      p_organization_id: context.organization_id,
      p_before: null,
      p_limit: 100,
      p_action: null,
      p_entity_type: null,
    } as never,
  );
  if (error) throw new Error(`AUDIT_LIST_LOAD_FAILED:${error.code ?? 'UNKNOWN'}`);
  const parsed = auditLogPageSchema.safeParse(data);
  if (!parsed.success) throw new Error('AUDIT_LIST_CONTRACT_INVALID');
  return parsed.data.items;
}
