import { notificationListSchema, type Notification } from '@opsdesk/contracts';
import type { OrganizationContext } from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../supabase/server';
import { createDemoNotifications } from '../demo/notification-demo';
import type { WorkspaceDataSource } from '../demo/opsdesk-demo';

export type NotificationInboxData = {
  items: Notification[];
  source: WorkspaceDataSource;
};

export async function loadNotificationInbox(
  context: OrganizationContext,
  source: WorkspaceDataSource,
): Promise<NotificationInboxData> {
  if (source === 'demo') {
    return { items: createDemoNotifications(context), source };
  }

  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc('rpc_list_notifications', {
    p_organization_id: context.organization_id,
    p_limit: 100,
    p_before: null,
  });
  if (error) throw new Error(`NOTIFICATIONS_LOAD_FAILED:${error.code ?? 'UNKNOWN'}`);
  const parsed = notificationListSchema.safeParse(data);
  if (!parsed.success) throw new Error('NOTIFICATIONS_CONTRACT_INVALID');
  return { items: parsed.data, source };
}
