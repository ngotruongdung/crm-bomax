import { AttendanceSettingsPanel } from '../../attendance-settings-panel';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';
import { loadAttendanceSettingsWorkspace } from '../../../lib/data/attendance-settings-data';

export default async function AttendanceSettingsPage() {
  try {
    const data = await loadAttendanceSettingsWorkspace();
    return (
      <WorkspaceShell
        activeSection="attendance-settings"
        context={data.context}
        description="Quản trị viên tự cấu hình Wi‑Fi văn phòng, xác thực web và ca làm việc. Các thay đổi được lưu kèm audit log."
        eyebrow="Attendance settings"
        title="Thiết lập chấm công"
      >
        <AttendanceSettingsPanel data={data} />
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/settings/attendance" />;
  }
}
