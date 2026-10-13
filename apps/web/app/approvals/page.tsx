import { loadApprovalsData } from '../../lib/data/hr-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { ApprovalsPanel } from './approvals-panel';

export default async function ApprovalsPage() {
  try {
    const { context, source, schemaReady, requests } = await loadApprovalsData();
    const canApprove = context.capabilities.includes('can_approve_requests');
    const pending = requests.filter(
      (request) => request.status === 'pending' && request.member_id !== context.member_id,
    );

    return (
      <WorkspaceShell
        activeSection="approvals"
        context={context}
        description="Duyệt đơn nhân sự, xem tác động lên lịch làm việc và giữ riêng tư đúng phạm vi HR."
        eyebrow="HR approvals"
        source={source}
        title="Phê duyệt"
      >
        {!schemaReady ? (
          <section className="hr-empty-card">
            Supabase chưa có schema HR P05. Chạy file schema/migration P05 rồi tải lại trang.
          </section>
        ) : !canApprove ? (
          <section className="hr-empty-card">
            Bạn không có capability duyệt yêu cầu nhân sự.
          </section>
        ) : (
          <>
            <ApprovalsPanel allRequests={requests} pending={pending} source={source} />
            {source === 'demo' ? (
              <p className="calendar-footnote">
                Demo chỉ mô phỏng quyền và tác động. Workspace Supabase dùng RPC/version check và
                chặn tự duyệt đơn của chính mình.
              </p>
            ) : null}
          </>
        )}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/approvals" />;
  }
}
