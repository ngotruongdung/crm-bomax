import Link from 'next/link';
import { loadWorkspaceContext } from '../../../lib/data/workspace-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';

export default async function AttendanceRemoteSessionPage() {
  try {
    const { context, source } = await loadWorkspaceContext();

    return (
      <WorkspaceShell
        activeSection="attendance"
        context={context}
        description="Chấm công online dùng ảnh chụp trực tiếp từ điện thoại; không cần tạo mã phiên trên máy tính."
        eyebrow="Remote attendance"
        source={source}
        title="Phiên chấm công online"
      >
        <section className="remote-session-card">
          <div className="remote-session-copy">
            <p className="workspace-eyebrow">{context.organization_name}</p>
            <h2>Chụp ảnh trên điện thoại</h2>
            <p>
              Mở OpsDesk trên điện thoại, vào Chấm công online, chụp ảnh trực tiếp bằng camera và
              gửi. Ảnh được tải lên private storage cùng challenge ngắn hạn và timestamp từ máy chủ.
            </p>
          </div>
        </section>

        <section className="attendance-diagnostic-card remote-session-note">
          <div>
            <small>MOBILE_CAMERA_REQUIRED</small>
            <strong>Ảnh chỉ được chụp trực tiếp trong ứng dụng điện thoại</strong>
            <p>
              Không chọn ảnh từ thư viện và không cần mã từ máy tính. Ca làm việc vẫn phải cho phép
              online trước khi máy chủ ghi nhận check-in hoặc check-out.
            </p>
          </div>
          <Link href="/attendance">Quay lại chấm công →</Link>
        </section>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/attendance/remote-session" />;
  }
}
