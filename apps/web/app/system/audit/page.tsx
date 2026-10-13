import { notFound } from 'next/navigation';
import { loadAuditLogs } from '../../../lib/data/security-data';
import { loadWorkspaceContext } from '../../../lib/data/workspace-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';

function timeLabel(value: string) {
  return new Intl.DateTimeFormat('vi-VN', {
    dateStyle: 'short',
    timeStyle: 'short',
    timeZone: 'Asia/Ho_Chi_Minh',
  }).format(new Date(value));
}

function safeMetadataLabel(value: Record<string, unknown>) {
  const entries = Object.entries(value).slice(0, 3);
  if (entries.length === 0) return '—';
  return entries.map(([key, item]) => `${key}: ${String(item)}`).join(' · ');
}

export default async function AuditPage() {
  try {
    const { context, source } = await loadWorkspaceContext();
    if (context.role !== 'admin') notFound();
    const items = await loadAuditLogs(context, source);

    return (
      <WorkspaceShell
        activeSection="audit"
        context={context}
        description="Lịch sử hành động nhạy cảm và thay đổi quan trọng. Metadata chỉ chứa dữ liệu đã làm sạch, không chứa selfie hoặc lý do nghỉ riêng tư."
        eyebrow="Security & privacy"
        source={source}
        title="Nhật ký hệ thống"
      >
        <section className="audit-summary-grid" aria-label="Tóm tắt bảo mật">
          <div className="audit-summary-card">
            <span>Storage</span>
            <strong>Private buckets</strong>
            <small>Signed URL 90 giây hoặc 5 phút tùy loại file.</small>
          </div>
          <div className="audit-summary-card">
            <span>Retention</span>
            <strong>Legal hold ưu tiên</strong>
            <small>File có legal hold không được worker tự xóa.</small>
          </div>
          <div className="audit-summary-card">
            <span>Export</span>
            <strong>Recheck scope</strong>
            <small>Quyền được kiểm tra lại trước khi tạo link tải.</small>
          </div>
        </section>

        <section className="ui-table-wrap audit-table-card">
          <table className="ui-table">
            <caption>100 sự kiện audit gần nhất</caption>
            <thead>
              <tr>
                <th>Thời gian</th>
                <th>Người thực hiện</th>
                <th>Hành động</th>
                <th>Đối tượng</th>
                <th>Metadata an toàn</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr key={item.id}>
                  <td>{timeLabel(item.recorded_at)}</td>
                  <td>{item.actor_display_name ?? 'Hệ thống'}</td>
                  <td>
                    <code>{item.action}</code>
                  </td>
                  <td>{item.entity_type}</td>
                  <td className="audit-safe-metadata">{safeMetadataLabel(item.safe_metadata)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/system/audit" />;
  }
}
