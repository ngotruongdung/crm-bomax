import { fileDownloadGrantSchema } from '@opsdesk/contracts';
import { signedUrlTtlSeconds } from '@opsdesk/domain';
import { createSupabasePrivilegedServerClient } from '../../../../../lib/supabase/admin';
import { createSupabaseServerClient } from '../../../../../lib/supabase/server';

export const runtime = 'nodejs';

function noStore(body: unknown, status = 200) {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store, private, max-age=0' },
  });
}

export async function GET(_request: Request, context: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await context.params;
    const client = await createSupabaseServerClient();
    const { data, error } = await client.rpc(
      'rpc_authorize_file_download' as never,
      {
        p_file_id: id,
      } as never,
    );
    if (error || !data) return noStore({ ok: false, error: { code: 'FILE_NOT_FOUND' } }, 404);

    const grant = fileDownloadGrantSchema.safeParse(data);
    if (!grant.success) {
      return noStore({ ok: false, error: { code: 'FILE_ACCESS_CONTRACT_INVALID' } }, 502);
    }

    const ttl = signedUrlTtlSeconds(grant.data.purpose);
    const admin = createSupabasePrivilegedServerClient();
    const { data: signed, error: signedError } = await admin.storage
      .from(grant.data.bucket_id)
      .createSignedUrl(grant.data.object_path, ttl, { download: grant.data.original_name });
    if (signedError || !signed?.signedUrl) {
      return noStore({ ok: false, error: { code: 'SIGNED_DOWNLOAD_UNAVAILABLE' } }, 503);
    }

    return noStore({
      ok: true,
      data: {
        url: signed.signedUrl,
        expires_in_seconds: ttl,
        file_name: grant.data.original_name,
        mime_type: grant.data.mime_type,
      },
    });
  } catch {
    return noStore({ ok: false, error: { code: 'FILE_NOT_FOUND' } }, 404);
  }
}
