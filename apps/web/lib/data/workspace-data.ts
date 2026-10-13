import type { OrganizationContext } from '@opsdesk/contracts';
import { requireMemberContext } from '../auth/require-member';
import {
  createDemoOrganizationContext,
  resolveWorkspaceDataSource,
  type WorkspaceDataSource,
} from '../demo/opsdesk-demo';

export type WorkspaceContextData = {
  context: OrganizationContext;
  source: WorkspaceDataSource;
};

export async function loadWorkspaceContext(): Promise<WorkspaceContextData> {
  const source = resolveWorkspaceDataSource();
  if (source === 'demo') {
    return {
      context: createDemoOrganizationContext(),
      source,
    };
  }

  return {
    context: await requireMemberContext(),
    source: 'supabase',
  };
}
