import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { loadTaskListData } from '../tasks/task-data';
import { OverviewPanel } from './overview-panel';

export default async function OverviewPage() {
  try {
    const { context, source, tasks } = await loadTaskListData({ includeTerminal: true });

    return (
      <WorkspaceShell
        activeSection="overview"
        context={context}
        description="Theo dõi các điểm cần chú ý, hạn xử lý và khối lượng công việc theo seller."
        eyebrow="Tổng quan"
        source={source}
        title="Tổng quan vận hành"
      >
        <OverviewPanel context={context} tasks={tasks} />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/overview" />;
  }
}
