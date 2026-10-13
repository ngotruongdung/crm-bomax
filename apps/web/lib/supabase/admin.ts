import { createClient } from '@supabase/supabase-js';
import type { Database } from '@opsdesk/api-client';

/**
 * Server-only client for the two invitation delivery operations that Supabase Auth
 * does not permit with an end-user session. Never import this module from a client
 * component or mobile app.
 */
export function createSupabaseAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error('Missing server-only Supabase invitation configuration');
  }

  return createClient<Database>(url, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
}

/**
 * Server-only privileged client used by attendance APIs while the checked-in database
 * type snapshot intentionally lags P05/P06. All public request/response payloads are
 * validated through @opsdesk/contracts; `supabase gen types` replaces this gap later.
 */
export function createSupabasePrivilegedServerClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    throw new Error('Missing server-only Supabase privileged configuration');
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
}
