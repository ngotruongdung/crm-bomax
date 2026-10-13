import { NextResponse } from 'next/server';
import { safeAuthRedirect } from '../../../lib/auth/redirect';
import { createSupabaseServerClient } from '../../../lib/supabase/server';

export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get('code');
  const next = safeAuthRedirect(requestUrl.searchParams.get('next'));

  if (!code) {
    return NextResponse.redirect(new URL('/?error=auth_callback_failed', requestUrl));
  }

  const supabase = await createSupabaseServerClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return NextResponse.redirect(new URL('/?error=auth_callback_failed', requestUrl));
  }

  return NextResponse.redirect(new URL(next, requestUrl));
}
