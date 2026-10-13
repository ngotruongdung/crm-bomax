import type { Notification, OrganizationContext } from '@opsdesk/contracts';
import { demoIds } from './opsdesk-demo';

function isoOffsetMinutes(base: string, minutes: number) {
  return new Date(Date.parse(base) + minutes * 60_000).toISOString();
}

export function createDemoNotifications(context: OrganizationContext): Notification[] {
  const now = context.server_now;
  return [
    {
      id: 'd8000000-0000-0000-0000-000000000001',
      organization_id: context.organization_id,
      recipient_member_id: context.member_id,
      kind: 'task_assigned',
      title: 'Bạn có công việc mới',
      body: 'Kiểm tra tồn kho trước khung sale tối · Hạn hôm nay',
      target_type: 'task',
      target_id: '83000000-0000-0000-0000-000000000001',
      safe_payload: { kind: 'task_assigned', target_type: 'task' },
      created_at: isoOffsetMinutes(now, -18),
      read_at: null,
      expires_at: null,
    },
    {
      id: 'd8000000-0000-0000-0000-000000000002',
      organization_id: context.organization_id,
      recipient_member_id: context.member_id,
      kind: 'task_review_requested',
      title: 'Có công việc chờ duyệt',
      body: 'Đối soát nội dung banner Flash Sale đang chờ bạn xem.',
      target_type: 'task',
      target_id: '83000000-0000-0000-0000-000000000006',
      safe_payload: { kind: 'task_review_requested', target_type: 'task' },
      created_at: isoOffsetMinutes(now, -46),
      read_at: null,
      expires_at: null,
    },
    {
      id: 'd8000000-0000-0000-0000-000000000003',
      organization_id: context.organization_id,
      recipient_member_id: context.member_id,
      kind: 'request_result',
      title: 'Yêu cầu của bạn đã có cập nhật',
      body: 'Mở ứng dụng để xem trạng thái mới nhất.',
      target_type: 'request',
      target_id: 'c5000000-0000-0000-0000-000000000001',
      safe_payload: { kind: 'request_result', target_type: 'request' },
      created_at: isoOffsetMinutes(now, -150),
      read_at: isoOffsetMinutes(now, -120),
      expires_at: null,
    },
    {
      id: 'd8000000-0000-0000-0000-000000000004',
      organization_id: context.organization_id,
      recipient_member_id: context.member_id,
      kind: 'digest',
      title: 'Bạn còn thông báo mới',
      body: 'Một số nhắc việc đã được gộp vào hộp thư để tránh gửi push quá nhiều.',
      target_type: 'system',
      target_id: null,
      safe_payload: { kind: 'digest', delivery_mode: 'inbox_only' },
      created_at: isoOffsetMinutes(now, -250),
      read_at: isoOffsetMinutes(now, -220),
      expires_at: null,
    },
  ];
}

export const demoPushEndpoint = {
  device_id: demoIds.managerMember,
  state: 'preview-only',
} as const;
