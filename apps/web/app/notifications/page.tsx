import { loadNotificationInbox } from '../../lib/data/notification-data';
import { loadWorkspaceContext } from '../../lib/data/workspace-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { NotificationInbox } from './notification-inbox';

export default async function NotificationsPage() {
  try {
    const { context, source } = await loadWorkspaceContext();
    const inbox = await loadNotificationInbox(context, source);
    return (
      <WorkspaceShell
        activeSection="notifications"
        context={context}
        description="Các cập nhật công việc, nhân sự và báo cáo được lưu bền trong hộp thư, kể cả khi bạn đóng web hoặc mobile."
        eyebrow="Cập nhật"
        source={source}
        title="Hộp thông báo"
      >
        <NotificationInbox
          initialItems={inbox.items}
          organizationId={context.organization_id}
          referenceNow={context.server_now}
          source={source}
        />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/notifications" />;
  }
}
