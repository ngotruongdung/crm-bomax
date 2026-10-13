import type { NextRequest } from 'next/server';
import { NextResponse } from 'next/server';
import { canonicalizeLocalUrl } from './lib/auth/canonical-origin';
import { updateSupabaseSession } from './lib/supabase/middleware';

export async function middleware(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const requestHost = request.headers.get('host');
  if (requestHost) requestUrl.host = requestHost;

  const canonicalUrl = canonicalizeLocalUrl(requestUrl.href);
  if (canonicalUrl) {
    return NextResponse.redirect(canonicalUrl);
  }

  return updateSupabaseSession(request);
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
};
