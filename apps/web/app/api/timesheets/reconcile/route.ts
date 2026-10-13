import { timesheetPeriodCommandSchema } from '@opsdesk/contracts';
import { requestOriginAllowed } from '../../../../lib/attendance/server';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';

export const runtime = 'nodejs';

function failure(code: string, status: number) {
  return Response.json({ ok: false, error: { code } }, { status });
}

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) return failure('ORIGIN_NOT_ALLOWED', 403);
  const parsed = timesheetPeriodCommandSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return failure('VALIDATION_ERROR', 400);

  try {
    const client = await createSupabaseServerClient();
    const { data, error } = await client.rpc('rpc_begin_timesheet_reconciliation', {
      p_organization_id: parsed.data.organization_id,
      p_month_start: parsed.data.month_start,
      p_expected_version: parsed.data.expected_version,
      p_idempotency_key: parsed.data.idempotency_key,
    });
    if (error) return failure(error.message || 'TIMESHEET_RECONCILE_FAILED', 422);
    return Response.json({ ok: true, data });
  } catch {
    return failure('AUTHENTICATION_OR_TIMESHEET_SERVER_REQUIRED', 401);
  }
}
