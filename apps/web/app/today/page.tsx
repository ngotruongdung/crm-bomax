import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { loadTaskListData } from '../tasks/task-data';
import { groupTodayTasks } from '../tasks/task-projections';
import { TodayPanel } from './today-panel';

export default async function TodayPage() {
  try {
    const { context, source, tasks } = await loadTaskListData({ includeTerminal: true });
    const groups = groupTodayTasks(tasks, context);
    return (
      <WorkspaceShell
        activeSection="today"
        context={context}
        description="Tập trung vào những việc cần được xử lý trong ngày của bạn."
        eyebrow="Công việc"
        source={source}
        title="Hôm nay"
      >
        <TodayPanel context={context} groups={groups} />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/today" />;
  }
}
