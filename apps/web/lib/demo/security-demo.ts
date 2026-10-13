import type { AuditLogItem, OrganizationContext } from '@opsdesk/contracts';
import { demoIds } from './opsdesk-demo';

export function createDemoAuditLogs(context: OrganizationContext): AuditLogItem[] {
  return [
    {
      id: 'fa000000-0000-4000-8000-000000000001',
      organization_id: context.organization_id,
      actor_member_id: demoIds.adminMember,
      actor_kind: 'member',
      actor_display_name: 'Admin OpsDesk',
      action: 'report.revision_created',
      entity_type: 'report_run',
      entity_id: 'e9000000-0000-4000-8000-000000000001',
      recorded_at: '2026-10-05T07:18:00.000Z',
      request_id: 'fa100000-0000-4000-8000-000000000001',
      safe_metadata: { revision: 2, reason: 'Bổ sung dữ liệu đối soát' },
    },
    {
      id: 'fa000000-0000-4000-8000-000000000002',
      organization_id: context.organization_id,
      actor_member_id: demoIds.managerMember,
      actor_kind: 'member',
      actor_display_name: 'Nguyễn Minh Anh',
      action: 'timesheet.closed',
      entity_type: 'timesheet_period',
      entity_id: 'fa200000-0000-4000-8000-000000000002',
      recorded_at: '2026-10-05T06:35:00.000Z',
      request_id: 'fa100000-0000-4000-8000-000000000002',
      safe_metadata: { month: '2026-09', revision: 1 },
    },
    {
      id: 'fa000000-0000-4000-8000-000000000003',
      organization_id: context.organization_id,
      actor_member_id: demoIds.adminMember,
      actor_kind: 'member',
      actor_display_name: 'Admin OpsDesk',
      action: 'evidence.view_authorized',
      entity_type: 'file',
      entity_id: 'fa300000-0000-4000-8000-000000000003',
      recorded_at: '2026-10-05T05:42:00.000Z',
      request_id: 'fa100000-0000-4000-8000-000000000003',
      safe_metadata: { purpose: 'attendance', bucket_id: 'attendance-evidence' },
    },
    {
      id: 'fa000000-0000-4000-8000-000000000004',
      organization_id: context.organization_id,
      actor_member_id: null,
      actor_kind: 'system',
      actor_display_name: null,
      action: 'file.retention_deleted',
      entity_type: 'file',
      entity_id: 'fa300000-0000-4000-8000-000000000004',
      recorded_at: '2026-10-05T03:00:00.000Z',
      request_id: 'fa100000-0000-4000-8000-000000000004',
      safe_metadata: { purpose: 'export', bucket_id: 'exports' },
    },
  ];
}
