import { loadReportDetail } from '../../../lib/data/report-data';
import { loadWorkspaceContext } from '../../../lib/data/workspace-data';
import { WorkspaceAccessFallback, WorkspaceShell } from '../../workspace-shell';
import { ReportRevisionAction } from './report-revision-action';

type Props = { params: Promise<{ id: string }> };

function when(value: string | null) {
  if (!value) return '—';
  return new Intl.DateTimeFormat('vi-VN', { dateStyle: 'short', timeStyle: 'short' }).format(
    new Date(value),
  );
}

export default async function ReportDetailPage({ params }: Props) {
  const { id } = await params;
  try {
    const { context, source } = await loadWorkspaceContext();
    const report = await loadReportDetail(context, source, id);
    const totals = report.facts.totals;
    return (
      <WorkspaceShell
        activeSection="reports"
        context={context}
        description={`Chốt ${when(report.cutoff_at)} · Tạo ${when(report.generated_at)} · Phiên bản ${report.revision}`}
        eyebrow="Snapshot bất biến"
        source={source}
        title={`Báo cáo vận hành — ${new Intl.DateTimeFormat('vi-VN').format(new Date(`${report.report_date}T00:00:00+07:00`))}`}
      >
        <section className="report-summary-card">
          <p>{report.summary_template}</p>
          {report.revision_reason ? <span>Lý do revision: {report.revision_reason}</span> : null}
        </section>
        <ReportRevisionAction
          demo={source === 'demo'}
          isAdmin={context.role === 'admin'}
          organizationId={context.organization_id}
          revision={report.revision}
          runId={report.run_id}
        />

        <section className="report-kpi-grid">
          {[
            ['Đến hạn', totals.due_count],
            ['Hoàn thành', totals.done_count],
            ['Chờ duyệt', totals.review_count],
            ['Còn mở', totals.open_count],
            ['Có vướng mắc', totals.blocked_count],
          ].map(([label, value]) => (
            <div className="report-kpi" key={label}>
              <span>{label}</span>
              <strong>{value}</strong>
            </div>
          ))}
        </section>

        <section className="report-people-card">
          <div className="report-people-head">
            <span>Nhân sự</span>
            <span>Đến hạn</span>
            <span>Hoàn thành</span>
            <span>Chờ duyệt</span>
            <span>Còn mở</span>
            <span>Vướng</span>
            <span>Trạng thái</span>
          </div>
          {report.facts.people.map((person) => (
            <div className="report-people-row" key={person.member_id}>
              <strong>{person.display_name}</strong>
              <span>{person.counts.due_count}</span>
              <span>{person.counts.done_count}</span>
              <span>{person.counts.review_count}</span>
              <span>{person.counts.open_count}</span>
              <span>{person.counts.blocked_count}</span>
              <span>
                {person.availability === 'working'
                  ? 'Đang trong ca'
                  : person.availability === 'away'
                    ? 'Vắng theo lịch'
                    : 'Chưa xác định'}
              </span>
            </div>
          ))}
        </section>

        {report.facts.warnings.length > 0 ? (
          <section className="report-warning-card">
            <strong>Cảnh báo snapshot</strong>
            <span>{report.facts.warnings.join(' · ')}</span>
          </section>
        ) : null}
      </WorkspaceShell>
    );
  } catch (error) {
    return <WorkspaceAccessFallback error={error} nextPath={`/reports/${id}`} />;
  }
}
