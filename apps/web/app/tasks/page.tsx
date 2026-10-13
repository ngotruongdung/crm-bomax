import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { TaskListPanel } from './task-list-panel';
import { loadTaskListData } from './task-data';
import { parseTaskListFilters } from './task-projections';

export default async function TasksPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  try {
    const [params, data] = await Promise.all([
      searchParams,
      loadTaskListData({ includeTerminal: true }),
    ]);
    const { context, members, sellers, source, tasks } = data;
    const initialFilters = parseTaskListFilters(params);
    return (
      <WorkspaceShell
        activeSection="tasks"
        context={context}
        description="Theo dõi và điều phối công việc theo seller, nhân sự và thời hạn."
        eyebrow="Vận hành"
        source={source}
        title="Tất cả công việc"
      >
        <TaskListPanel
          context={context}
          initialFilters={initialFilters}
          members={members}
          sellers={sellers}
          source={source}
          tasks={tasks}
        />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/tasks" />;
  }
}
