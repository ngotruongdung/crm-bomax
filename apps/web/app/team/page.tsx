import { TeamManagementPanel } from '../management/management-panels';
import { loadManagementData } from '../management/management-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';

export default async function TeamPage() {
  try {
    const { source, context, members, sellers, tasks } = await loadManagementData();
    return (
      <WorkspaceShell
        activeSection="team"
        context={context}
        description="Danh bạ và quyền truy cập được lọc theo phạm vi thực tế của người xem."
        eyebrow="Vận hành"
        source={source}
        title="Nhân sự"
      >
        <TeamManagementPanel
          members={members}
          organizationId={context.organization_id}
          role={context.role}
          sellers={sellers}
          source={source}
          tasks={tasks}
        />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/team" />;
  }
}
