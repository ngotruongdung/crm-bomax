import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { loadTaskListData } from '../tasks/task-data';
import { projectMyTasks } from '../tasks/task-projections';
import { MyTasksPanel } from './my-tasks-panel';

export default async function MyTasksPage() {
  try {
    const { context, sellers, source, tasks } = await loadTaskListData({ includeTerminal: true });
    const projection = projectMyTasks(tasks, context);
    return (
      <WorkspaceShell
        activeSection="my-tasks"
        context={context}
        description="Theo dõi các việc bạn được giao, phối hợp, cần duyệt hoặc đã giao cho người khác."
        eyebrow="Công việc"
        source={source}
        title="Công việc của tôi"
      >
        <MyTasksPanel context={context} projection={projection} sellers={sellers} source={source} />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/my-tasks" />;
  }
}
