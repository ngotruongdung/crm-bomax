import { loadRequestsData } from '../../lib/data/hr-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';
import { RequestsPanel } from './requests-panel';

export default async function RequestsPage() {
  try {
    const { context, source, schemaReady, leaveTypes, requests } = await loadRequestsData();

    return (
      <WorkspaceShell
        activeSection="requests"
        context={context}
        description="Theo dõi nghỉ, về sớm, đi muộn, làm online và các yêu cầu điều chỉnh thời gian."
        eyebrow="Thời gian & nhân sự"
        source={source}
        title="Yêu cầu của tôi"
      >
        {!schemaReady ? (
          <section className="hr-empty-card">
            Supabase chưa có schema HR P05. Chạy file schema/migration P05 rồi tải lại trang;
            OpsDesk sẽ không tự chèn dữ liệu mẫu vào workspace thật.
          </section>
        ) : (
          <RequestsPanel
            context={context}
            leaveTypes={leaveTypes}
            requests={requests}
            source={source}
          />
        )}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/requests" />;
  }
}
