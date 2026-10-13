import { SellerManagementPanel } from '../management/management-panels';
import { loadManagementData } from '../management/management-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';

export default async function SellersPage() {
  try {
    const { source, context, members, sellers, tasks } = await loadManagementData();
    return (
      <WorkspaceShell
        activeSection="sellers"
        context={context}
        description="Cấu hình seller và người phụ trách trong phạm vi quyền hiện tại."
        eyebrow="Vận hành"
        source={source}
        title="Seller"
      >
        <SellerManagementPanel
          members={members}
          organizationId={context.organization_id}
          role={context.role}
          sellers={sellers}
          source={source}
          tasks={tasks}
          timezone={context.timezone}
        />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/sellers" />;
  }
}
