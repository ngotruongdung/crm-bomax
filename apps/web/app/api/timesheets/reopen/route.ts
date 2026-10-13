import { timesheetReopenCommandSchema } from '@opsdesk/contracts';
import { requestOriginAllowed } from '../../../../lib/attendance/server';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';

export const runtime = 'nodejs';

function failure(code: string, status: number) {
  return Response.json({ ok: false, error: { code } }, { status });
}

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return failure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = timesheetReopenCommandSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return failure('VALIDATION_ERROR', 400);

  try {
    const client = await createSupabaseServerClient();
    const { data, error } = await client.rpc('rpc_reopen_timesheet', {
      p_organization_id: parsed.data.organization_id,
      p_period_id: parsed.data.period_id,
      p_reason: parsed.data.reason,
      p_expected_version: parsed.data.expected_version,
      p_idempotency_key: parsed.data.idempotency_key,
    });
    if (error) return failure(error.message || 'TIMESHEET_REOPEN_FAILED', 422);
    return Response.json({ ok: true, data });
  } catch {
    return failure('AUTHENTICATION_OR_TIMESHEET_SERVER_REQUIRED', 401);
  }
}
