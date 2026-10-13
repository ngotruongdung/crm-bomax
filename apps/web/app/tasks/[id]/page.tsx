import { ErrorState } from '../../../components/ui';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';
import { loadTaskDetailData } from '../task-data';
import { TaskDetailPanel } from '../task-detail-panel';

export default async function TaskDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  try {
    const { context, members, task, taskError, taskErrorCode, source } =
      await loadTaskDetailData(id);
    return (
      <WorkspaceShell
        activeSection="tasks"
        context={context}
        description="Danh sách công việc của workspace. Chi tiết đang mở ở ngăn bên phải."
        eyebrow="Công việc"
        source={source}
        title="Tất cả công việc"
      >
        {task ? (
          <TaskDetailPanel context={context} members={members} source={source} task={task} />
        ) : (
          <ErrorState
            title={
              taskErrorCode === 'TASK_ACCESS_DENIED'
                ? 'Không có quyền truy cập'
                : 'Không thể tải công việc'
            }
          >
            <p>{taskError ?? 'Công việc không tồn tại hoặc bạn không còn quyền xem.'}</p>
          </ErrorState>
        )}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath={`/tasks/${id}`} />;
  }
}
