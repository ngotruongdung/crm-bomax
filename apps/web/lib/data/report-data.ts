import {
  reportDetailSchema,
  reportListSchema,
  type OrganizationContext,
  type ReportDetail,
  type ReportListItem,
} from '@opsdesk/contracts';
import { createDemoReportDetail, createDemoReportList } from '../demo/report-demo';
import type { WorkspaceDataSource } from '../demo/opsdesk-demo';
import { createSupabaseServerClient } from '../supabase/server';

export async function loadReports(
  context: OrganizationContext,
  source: WorkspaceDataSource,
): Promise<ReportListItem[]> {
  if (source === 'demo') return createDemoReportList(context);
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc('rpc_list_reports', {
    p_organization_id: context.organization_id,
    p_limit: 60,
  });
  if (error) throw new Error(`REPORT_LIST_LOAD_FAILED:${error.code ?? 'UNKNOWN'}`);
  const parsed = reportListSchema.safeParse(data);
  if (!parsed.success) throw new Error('REPORT_LIST_CONTRACT_INVALID');
  return parsed.data;
}

export async function loadReportDetail(
  context: OrganizationContext,
  source: WorkspaceDataSource,
  runId: string,
): Promise<ReportDetail> {
  if (source === 'demo') {
    const detail = createDemoReportDetail(context);
    if (runId !== detail.run_id) throw new Error('REPORT_NOT_FOUND');
    return detail;
  }
  const client = await createSupabaseServerClient();
  const { data, error } = await client.rpc('rpc_get_report', { p_run_id: runId });
  if (error) throw new Error(`REPORT_DETAIL_LOAD_FAILED:${error.code ?? 'UNKNOWN'}`);
  const parsed = reportDetailSchema.safeParse(data);
  if (!parsed.success) throw new Error('REPORT_DETAIL_CONTRACT_INVALID');
  return parsed.data;
}
