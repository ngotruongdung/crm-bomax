import { exportJobSchema } from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../../../../lib/supabase/server';

export const runtime = 'nodejs';

function response(status: number, body: unknown) {
  return Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
}

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const client = await createSupabaseServerClient();
    const { data, error } = await client.rpc(
      'rpc_get_export_job' as never,
      {
        p_job_id: id,
      } as never,
    );
    if (error || !data) return response(404, { ok: false, error: { code: 'EXPORT_NOT_FOUND' } });
    const job = exportJobSchema.safeParse(data);
    if (!job.success)
      return response(502, { ok: false, error: { code: 'EXPORT_CONTRACT_INVALID' } });
    return response(200, { ok: true, data: job.data });
  } catch {
    return response(404, { ok: false, error: { code: 'EXPORT_NOT_FOUND' } });
  }
}
