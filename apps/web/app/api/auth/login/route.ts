import { organizationContextSchema } from '@opsdesk/contracts';
import { createServerClient } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';
import type { Database } from '@opsdesk/api-client';
import {
  loginFailureFromAuthCode,
  parseLoginCommand,
  type LoginFailureCode,
} from '../../../../lib/auth/login';

export const runtime = 'nodejs';

function failure(code: LoginFailureCode, status: number) {
  return NextResponse.json({ ok: false, error: { code } }, { status });
}

function getSupabaseConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  return url && anonKey ? { url, anonKey } : null;
}

export async function POST(request: NextRequest) {
  const command = parseLoginCommand(await request.json().catch(() => null));
  if (!command) return failure('INVALID_INPUT', 400);

  const config = getSupabaseConfig();
  if (!config) return failure('CONTEXT_UNAVAILABLE', 503);

  // The response owns the authentication cookies so the next navigation is already
  // authenticated on the server, including browsers that delay client cookie sync.
  const response = NextResponse.json({ ok: true });
  const supabase = createServerClient<Database>(config.url, config.anonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
      },
    },
  });

  let authData: Awaited<ReturnType<typeof supabase.auth.signInWithPassword>>['data'];
  let authError: Awaited<ReturnType<typeof supabase.auth.signInWithPassword>>['error'];
  try {
    ({ data: authData, error: authError } = await supabase.auth.signInWithPassword(command));
  } catch {
    return failure('CONTEXT_UNAVAILABLE', 503);
  }

  if (authError || !authData.user) {
    const code = loginFailureFromAuthCode(authError?.code);
    return failure(code, code === 'CONTEXT_UNAVAILABLE' ? 503 : 401);
  }

  const { data: contextData, error: contextError } = await supabase.rpc('rpc_get_context', {
    p_organization_id: null,
  });

  if (contextError) {
    return failure(
      contextError.message.includes('ACTIVE_MEMBERSHIP_REQUIRED')
        ? 'MEMBERSHIP_REQUIRED'
        : 'CONTEXT_UNAVAILABLE',
      contextError.message.includes('ACTIVE_MEMBERSHIP_REQUIRED') ? 403 : 503,
    );
  }

  const context = organizationContextSchema.safeParse(contextData);
  if (!context.success) return failure('CONTEXT_UNAVAILABLE', 503);

  response.headers.set('X-OpsDesk-Role', context.data.role);
  return response;
}
