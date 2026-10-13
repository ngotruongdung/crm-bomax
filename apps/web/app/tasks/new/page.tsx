import Link from 'next/link';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';
import { TaskCreateForm } from '../task-create-form';
import { loadTaskCreateData } from '../task-data';

export default async function NewTaskPage() {
  try {
    const { context, members, sellers, source } = await loadTaskCreateData();
    return (
      <WorkspaceShell
        activeSection="tasks"
        context={context}
        description="Chọn người phụ trách, seller và thời hạn. Các thông tin còn lại có thể bổ sung khi cần."
        eyebrow="Công việc"
        source={source}
        title="Giao công việc"
      >
        <section className="task-create-page-card">
          <div className="task-detail-back">
            <Link href="/tasks">← Tất cả công việc</Link>
          </div>
          <TaskCreateForm context={context} members={members} sellers={sellers} source={source} />
        </section>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/tasks/new" />;
  }
}
