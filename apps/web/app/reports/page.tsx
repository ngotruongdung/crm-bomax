import Link from 'next/link';
import { loadReports } from '../../lib/data/report-data';
import { loadWorkspaceContext } from '../../lib/data/workspace-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../workspace-shell';

function dateLabel(value: string) {
  return new Intl.DateTimeFormat('vi-VN').format(new Date(`${value}T00:00:00+07:00`));
}

export default async function ReportsPage() {
  try {
    const { context, source } = await loadWorkspaceContext();
    const reports = await loadReports(context, source);
    return (
      <WorkspaceShell
        activeSection="reports"
        context={context}
        description="Snapshot công việc được chốt theo cutoff 18:00 của workspace và giữ nguyên khi job retry sau đó."
        eyebrow="Operations snapshot"
        source={source}
        title="Báo cáo 18:00"
      >
        {reports.length === 0 ? (
          <section className="hr-empty-card">
            Chưa có báo cáo đã chốt. Báo cáo hôm nay sẽ xuất hiện sau cutoff 18:00 theo timezone
            workspace.
          </section>
        ) : (
          <section className="report-list-card">
            <div className="report-list-head">
              <span>Ngày</span>
              <span>Phạm vi</span>
              <span>Nhân sự</span>
              <span>Đến hạn</span>
              <span>Hoàn thành</span>
              <span>Còn mở</span>
              <span>Phiên bản</span>
            </div>
            {reports.map((report) => (
              <Link
                className="report-list-row"
                href={`/reports/${report.run_id}`}
                key={report.run_id}
              >
                <strong>{dateLabel(report.report_date)}</strong>
                <span>
                  {report.scope.kind === 'organization'
                    ? 'Toàn workspace'
                    : report.scope.kind === 'sellers'
                      ? `${report.scope.seller_ids.length} seller`
                      : 'Cá nhân'}
                </span>
                <span>{report.people_count}</span>
                <span>{report.totals.due_count}</span>
                <span>{report.totals.done_count}</span>
                <span>{report.totals.open_count}</span>
                <span>
                  v{report.revision}
                  {report.is_late ? ' · Tạo muộn' : ''}
                </span>
              </Link>
            ))}
          </section>
        )}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath="/reports" />;
  }
}
