import {
  markAllNotificationsReadCommandSchema,
  markNotificationReadCommandSchema,
} from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';

export const runtime = 'nodejs';

function originAllowed(request: Request) {
  const origin = request.headers.get('origin');
  return !origin || origin === new URL(request.url).origin;
}

function failure(code: string, status: number) {
  return Response.json({ ok: false, error: { code } }, { status });
}

export async function POST(request: Request) {
  if (!originAllowed(request)) return failure('ORIGIN_NOT_ALLOWED', 403);
  const body = await request.json().catch(() => null);
  const action = typeof body === 'object' && body !== null && 'action' in body ? body.action : null;
  const client = await createSupabaseServerClient();

  if (action === 'one') {
    const parsed = markNotificationReadCommandSchema.safeParse(body);
    if (!parsed.success) return failure('VALIDATION_ERROR', 400);
    const { data, error } = await client.rpc('rpc_mark_notification_read', {
      p_notification_id: parsed.data.notification_id,
    });
    if (error) return failure(error.message || 'NOTIFICATION_READ_FAILED', 400);
    return Response.json({ ok: true, data });
  }

  if (action === 'all') {
    const parsed = markAllNotificationsReadCommandSchema.safeParse(body);
    if (!parsed.success) return failure('VALIDATION_ERROR', 400);
    const { data, error } = await client.rpc('rpc_mark_all_notifications_read', {
      p_organization_id: parsed.data.organization_id,
      p_cutoff: parsed.data.cutoff,
    });
    if (error) return failure(error.message || 'NOTIFICATION_MARK_ALL_FAILED', 400);
    return Response.json({ ok: true, data });
  }

  return failure('VALIDATION_ERROR', 400);
}
