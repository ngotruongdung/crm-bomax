import { organizationContextSchema, type OrganizationContext } from '@opsdesk/contracts';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@opsdesk/api-client';
import { createSupabaseMobileClient } from './supabase';

export class MobileAuthenticationRequiredError extends Error {
  constructor() {
    super('MOBILE_AUTHENTICATION_REQUIRED');
    this.name = 'MobileAuthenticationRequiredError';
  }
}

export class MobileMembershipRequiredError extends Error {
  constructor() {
    super('ACTIVE_MEMBERSHIP_REQUIRED');
    this.name = 'MobileMembershipRequiredError';
  }
}

export async function loadMobileMemberContext(
  client: SupabaseClient<Database> = createSupabaseMobileClient(),
): Promise<OrganizationContext> {
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || !userData.user) {
    throw new MobileAuthenticationRequiredError();
  }

  const { data, error } = await client.rpc('rpc_get_context', {
    p_organization_id: null,
  });

  if (error) {
    if (error.message.includes('ACTIVE_MEMBERSHIP_REQUIRED')) {
      throw new MobileMembershipRequiredError();
    }

    throw new Error('MOBILE_CONTEXT_LOAD_FAILED');
  }

  const parsedContext = organizationContextSchema.safeParse(data);
  if (!parsedContext.success) {
    throw new Error('MOBILE_CONTEXT_INVALID');
  }

  return parsedContext.data;
}

export function getMobileContextErrorMessage(error: unknown) {
  if (error instanceof MobileMembershipRequiredError) {
    return 'Tài khoản chưa được cấp quyền trong workspace này.';
  }

  if (error instanceof MobileAuthenticationRequiredError) {
    return 'Phiên đăng nhập đã hết hạn. Đăng nhập lại để tiếp tục.';
  }

  if (error instanceof Error && error.message.startsWith('Missing EXPO_PUBLIC_SUPABASE_')) {
    return 'Mobile chưa được cấu hình kết nối Supabase.';
  }

  return 'Không thể xác minh quyền truy cập. Thử lại sau.';
}
