import { exportJobSchema, exportRequestSchema } from '@opsdesk/contracts';
import { requestOriginAllowed } from '../../../lib/attendance/server';
import { createSupabaseServerClient } from '../../../lib/supabase/server';

export const runtime = 'nodejs';

function response(status: number, body: unknown) {
  return Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
}

export async function POST(request: Request) {
  if (!requestOriginAllowed(request)) {
    return response(403, { ok: false, error: { code: 'ORIGIN_NOT_ALLOWED' } });
  }
  const parsed = exportRequestSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return response(400, { ok: false, error: { code: 'VALIDATION_ERROR' } });

  try {
    const client = await createSupabaseServerClient();
    const { data, error } = await client.rpc(
      'rpc_create_export_job' as never,
      {
        p_organization_id: parsed.data.organization_id,
        p_export_kind: parsed.data.export_kind,
        p_parameters: parsed.data.parameters,
        p_idempotency_key: parsed.data.idempotency_key,
      } as never,
    );
    if (error) {
      const code = error.message.includes('RETENTION_POLICY_REQUIRED')
        ? 'RETENTION_POLICY_REQUIRED'
        : error.message.includes('EXPORT_SCOPE_DENIED')
          ? 'EXPORT_SCOPE_DENIED'
          : 'EXPORT_CREATE_FAILED';
      return response(code === 'EXPORT_SCOPE_DENIED' ? 403 : 422, { ok: false, error: { code } });
    }
    const job = exportJobSchema.safeParse(data);
    if (!job.success)
      return response(502, { ok: false, error: { code: 'EXPORT_CONTRACT_INVALID' } });
    return response(202, { ok: true, data: job.data });
  } catch {
    return response(503, { ok: false, error: { code: 'EXPORT_SERVER_NOT_CONFIGURED' } });
  }
}
