import { timesheetViewSchema } from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../../../lib/supabase/server';

export const runtime = 'nodejs';

function failure(code: string, status: number) {
  return Response.json({ ok: false, error: { code } }, { status });
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const organizationId = url.searchParams.get('organization_id');
  const monthStart = url.searchParams.get('month_start');
  const memberId = url.searchParams.get('member_id');
  if (
    !organizationId ||
    !monthStart ||
    !/^\d{4}-\d{2}-01$/.test(monthStart) ||
    (memberId !== null && memberId.length === 0)
  ) {
    return failure('VALIDATION_ERROR', 400);
  }

  try {
    const client = await createSupabaseServerClient();
    const { data, error } = await client.rpc('rpc_get_timesheet', {
      p_organization_id: organizationId,
      p_month_start: monthStart,
      p_member_id: memberId,
    });
    if (error) return failure(error.message || 'TIMESHEET_LOAD_FAILED', 422);
    const parsed = timesheetViewSchema.safeParse(data);
    if (!parsed.success) return failure('TIMESHEET_CONTRACT_INVALID', 502);
    return Response.json({ ok: true, data: parsed.data });
  } catch {
    return failure('AUTHENTICATION_OR_TIMESHEET_SERVER_REQUIRED', 401);
  }
}
