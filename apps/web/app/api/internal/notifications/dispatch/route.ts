import { randomUUID } from 'node:crypto';
import { automationSecretMatches, decryptPushToken } from '../../../../../lib/notifications/crypto';
import { createSupabasePrivilegedServerClient } from '../../../../../lib/supabase/admin';

export const runtime = 'nodejs';
export const maxDuration = 60;

type ClaimedOutbox = { id: string };
type Delivery = {
  id: string;
  notification_id: string;
  endpoint_id: string;
  attempts: number;
  status: string;
  updated_at: string;
};
type NotificationRow = {
  id: string;
  kind: string;
  title: string;
  body: string;
  target_type: string;
  target_id: string | null;
};
type EndpointRow = {
  id: string;
  provider: 'expo' | 'webpush';
  token_encrypted: string;
  active: boolean;
};

function response(status: number, body: unknown) {
  return Response.json(body, { status });
}

function retryDelayMs(attempt: number) {
  if (attempt <= 1) return 60_000;
  if (attempt === 2) return 5 * 60_000;
  if (attempt === 3) return 15 * 60_000;
  return 60 * 60_000;
}

function safePushData(notification: NotificationRow) {
  return {
    kind: notification.kind,
    notification_id: notification.id,
    target_type: notification.target_type,
    target_id: notification.target_id,
  };
}

async function sendExpoPush(token: string, notification: NotificationRow) {
  const result = await fetch('https://exp.host/--/api/v2/push/send', {
    method: 'POST',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({
      to: token,
      title: notification.title,
      body: notification.body,
      data: safePushData(notification),
      sound: 'default',
    }),
  });
  const payload = (await result.json().catch(() => null)) as {
    data?: { id?: string; status?: string; message?: string; details?: { error?: string } };
  } | null;
  if (!result.ok || payload?.data?.status === 'error') {
    const code = payload?.data?.details?.error ?? `HTTP_${result.status}`;
    return { ok: false as const, code };
  }
  return { ok: true as const, ticketId: payload?.data?.id ?? null };
}

async function checkExpoReceipt(ticketId: string) {
  const result = await fetch('https://exp.host/--/api/v2/push/getReceipts', {
    method: 'POST',
    headers: { accept: 'application/json', 'content-type': 'application/json' },
    body: JSON.stringify({ ids: [ticketId] }),
  });
  if (!result.ok) return { state: 'retry' as const, code: `HTTP_${result.status}` };
  const payload = (await result.json().catch(() => null)) as {
    data?: Record<string, { status?: string; details?: { error?: string } }>;
  } | null;
  const receipt = payload?.data?.[ticketId];
  if (!receipt) return { state: 'pending' as const };
  if (receipt.status === 'ok') return { state: 'confirmed' as const };
  return { state: 'failed' as const, code: receipt.details?.error ?? 'PROVIDER_RECEIPT_ERROR' };
}

function permanentEndpointError(code: string) {
  return (
    code === 'DeviceNotRegistered' ||
    code === 'DEVICE_NOT_REGISTERED' ||
    code === 'INVALID_PUSH_TOKEN'
  );
}

export async function POST(request: Request) {
  if (!automationSecretMatches(request.headers.get('x-opsdesk-automation-secret'))) {
    return response(401, { ok: false, error: { code: 'AUTOMATION_AUTH_REQUIRED' } });
  }

  const admin = createSupabasePrivilegedServerClient();
  const workerId = randomUUID();
  const counters = {
    reports_generated: 0,
    reports_failed: 0,
    outbox_claimed: 0,
    outbox_done: 0,
    outbox_failed: 0,
    push_accepted: 0,
    push_confirmed: 0,
    push_failed: 0,
    endpoints_revoked: 0,
  };

  const reportResult = await admin.rpc(
    'rpc_internal_generate_due_reports' as never,
    {
      p_now: new Date().toISOString(),
      p_limit: 10,
    } as never,
  );
  if (reportResult.error) {
    return response(503, { ok: false, error: { code: 'REPORT_TICK_FAILED' } });
  }
  const reportData = reportResult.data as
    | { generated?: number; failed?: number }
    | null
    | undefined;
  counters.reports_generated = reportData?.generated ?? 0;
  counters.reports_failed = reportData?.failed ?? 0;

  const reminderResult = await admin.rpc(
    'rpc_internal_enqueue_task_reminders' as never,
    {
      p_now: new Date().toISOString(),
    } as never,
  );
  if (reminderResult.error) {
    return response(503, { ok: false, error: { code: 'REMINDER_TICK_FAILED' } });
  }

  const claim = await admin.rpc(
    'rpc_internal_claim_outbox' as never,
    {
      p_worker_id: workerId,
      p_limit: 25,
    } as never,
  );
  const events = (Array.isArray(claim.data) ? claim.data : []) as ClaimedOutbox[];
  counters.outbox_claimed = events.length;

  for (const event of events) {
    const materialized = await admin.rpc(
      'rpc_internal_materialize_notification' as never,
      {
        p_event_id: event.id,
        p_worker_id: workerId,
      } as never,
    );
    if (materialized.error) {
      await admin.rpc(
        'rpc_internal_fail_outbox' as never,
        {
          p_event_id: event.id,
          p_worker_id: workerId,
          p_error_code: 'MATERIALIZE_FAILED',
          p_retryable: true,
        } as never,
      );
      counters.outbox_failed += 1;
      continue;
    }
    const ack = await admin.rpc(
      'rpc_internal_ack_outbox' as never,
      {
        p_event_id: event.id,
        p_worker_id: workerId,
      } as never,
    );
    if (!ack.error && ack.data === true) counters.outbox_done += 1;
  }

  const { data: deliveryRows } = await admin
    .from('notification_deliveries')
    .select('id,notification_id,endpoint_id,attempts,status,updated_at')
    .eq('channel', 'push')
    .in('status', ['pending', 'failed', 'accepted', 'sending'])
    .lte('next_attempt_at', new Date().toISOString())
    .order('created_at', { ascending: true })
    .limit(25);

  for (const delivery of (deliveryRows ?? []) as Delivery[]) {
    const { data: notification } = await admin
      .from('notifications')
      .select('id,kind,title,body,target_type,target_id')
      .eq('id', delivery.notification_id)
      .maybeSingle();
    const { data: endpoint } = await admin
      .from('push_endpoints')
      .select('id,provider,token_encrypted,active')
      .eq('id', delivery.endpoint_id)
      .maybeSingle();
    if (!notification || !endpoint || !endpoint.active) {
      await admin
        .from('notification_deliveries')
        .update({ status: 'expired' })
        .eq('id', delivery.id);
      continue;
    }
    const notificationRow = notification as NotificationRow;
    const endpointRow = endpoint as EndpointRow;

    if (delivery.status === 'accepted') {
      const { data: ticketDelivery } = await admin
        .from('notification_deliveries')
        .select('provider_ticket_id')
        .eq('id', delivery.id)
        .single();
      const ticketId = ticketDelivery?.provider_ticket_id as string | null | undefined;
      if (!ticketId || endpointRow.provider !== 'expo') continue;
      const receipt = await checkExpoReceipt(ticketId);
      if (receipt.state === 'pending') continue;
      if (receipt.state === 'confirmed') {
        await admin
          .from('notification_deliveries')
          .update({ status: 'provider_confirmed', last_error_code: null })
          .eq('id', delivery.id);
        counters.push_confirmed += 1;
        continue;
      }
      const code = receipt.code;
      if (receipt.state === 'failed' && permanentEndpointError(code)) {
        await admin
          .from('push_endpoints')
          .update({ active: false, last_error_code: code })
          .eq('id', endpointRow.id);
        counters.endpoints_revoked += 1;
      }
      await admin
        .from('notification_deliveries')
        .update({
          status: receipt.state === 'failed' ? 'failed' : 'accepted',
          last_error_code: code,
          next_attempt_at: new Date(Date.now() + retryDelayMs(delivery.attempts + 1)).toISOString(),
        })
        .eq('id', delivery.id);
      counters.push_failed += 1;
      continue;
    }

    if (endpointRow.provider !== 'expo') {
      await admin
        .from('notification_deliveries')
        .update({ status: 'expired', last_error_code: 'WEBPUSH_NOT_CONFIGURED' })
        .eq('id', delivery.id);
      counters.push_failed += 1;
      continue;
    }

    let token: string;
    try {
      token = decryptPushToken(endpointRow.token_encrypted);
    } catch {
      await admin
        .from('push_endpoints')
        .update({ active: false, last_error_code: 'TOKEN_DECRYPT_FAILED' })
        .eq('id', endpointRow.id);
      await admin
        .from('notification_deliveries')
        .update({ status: 'expired', last_error_code: 'TOKEN_DECRYPT_FAILED' })
        .eq('id', delivery.id);
      counters.endpoints_revoked += 1;
      continue;
    }

    const nextAttempts = delivery.attempts + 1;
    const sendLeaseUntil = new Date(Date.now() + 10 * 60_000).toISOString();
    const { data: claimedDelivery } = await admin
      .from('notification_deliveries')
      .update({
        status: 'sending',
        attempts: nextAttempts,
        last_error_code: null,
        next_attempt_at: sendLeaseUntil,
      })
      .eq('id', delivery.id)
      .eq('status', delivery.status)
      .eq('updated_at', delivery.updated_at)
      .select('id')
      .maybeSingle();
    if (!claimedDelivery) continue;

    const sent = await sendExpoPush(token, notificationRow);
    if (sent.ok) {
      await admin
        .from('notification_deliveries')
        .update({
          status: 'accepted',
          provider_ticket_id: sent.ticketId,
          next_attempt_at: new Date(Date.now() + 15 * 60_000).toISOString(),
        })
        .eq('id', delivery.id);
      counters.push_accepted += 1;
      continue;
    }

    if (permanentEndpointError(sent.code)) {
      await admin
        .from('push_endpoints')
        .update({ active: false, last_error_code: sent.code })
        .eq('id', endpointRow.id);
      await admin
        .from('notification_deliveries')
        .update({ status: 'expired', last_error_code: sent.code })
        .eq('id', delivery.id);
      counters.endpoints_revoked += 1;
    } else {
      await admin
        .from('notification_deliveries')
        .update({
          status: nextAttempts >= 5 ? 'expired' : 'failed',
          last_error_code: sent.code,
          next_attempt_at: new Date(Date.now() + retryDelayMs(nextAttempts)).toISOString(),
        })
        .eq('id', delivery.id);
    }
    counters.push_failed += 1;
  }

  return response(200, { ok: true, data: { worker_id: workerId, counters } });
}
