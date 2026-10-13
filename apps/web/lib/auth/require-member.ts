import { organizationContextSchema, type OrganizationContext } from '@opsdesk/contracts';
import { createSupabaseServerClient } from '../supabase/server';

export class AuthenticationRequiredError extends Error {
  constructor() {
    super('AUTHENTICATION_REQUIRED');
    this.name = 'AuthenticationRequiredError';
  }
}

export class ActiveMembershipRequiredError extends Error {
  constructor() {
    super('ACTIVE_MEMBERSHIP_REQUIRED');
    this.name = 'ActiveMembershipRequiredError';
  }
}

export async function requireMemberContext(
  organizationId?: string | null,
): Promise<OrganizationContext> {
  const client = await createSupabaseServerClient();
  const { data: userData, error: userError } = await client.auth.getUser();

  if (userError || !userData.user) {
    throw new AuthenticationRequiredError();
  }

  const { data, error } = await client.rpc('rpc_get_context', {
    p_organization_id: organizationId ?? null,
  });

  if (error) {
    if (error.message.includes('ACTIVE_MEMBERSHIP_REQUIRED')) {
      throw new ActiveMembershipRequiredError();
    }
    throw new Error(`CONTEXT_LOAD_FAILED: ${error.message}`);
  }

  const parsed = organizationContextSchema.safeParse(data);
  if (!parsed.success) {
    throw new Error('CONTEXT_CONTRACT_INVALID');
  }

  return parsed.data;
}
