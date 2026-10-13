import { randomBytes, randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const requireFromWeb = createRequire(resolve(process.cwd(), 'apps/web/package.json'));
const { createBrowserClient } = requireFromWeb('@supabase/ssr');
const { createClient } = requireFromWeb('@supabase/supabase-js');

const envPath = resolve(process.cwd(), '.env.local');
if (existsSync(envPath)) process.loadEnvFile(envPath);

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const appUrl = process.env.NEXT_PUBLIC_APP_URL;

if (!url || !anonKey || !serviceRoleKey || !appUrl) {
  console.error('WEB_SESSION_SMOKE_CONFIGURATION_REQUIRED');
  process.exitCode = 1;
} else {
  const appOrigin = new URL(appUrl).origin;
  const service = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const suffix = `${Date.now().toString(36)}${randomBytes(4).toString('hex')}`;
  const organizationId = randomUUID();
  const memberId = randomUUID();
  const email = `p11-web-${suffix}@opsdesk-runtime.invalid`;
  const password = `${randomBytes(24).toString('base64url')}Aa1!`;
  let userId = null;
  let organizationCreated = false;
  let memberCreated = false;
  const failures = [];

  try {
    const { data: createdUser, error: userError } = await service.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (userError || !createdUser.user) throw new Error('WEB_SESSION_USER_CREATE_FAILED');
    userId = createdUser.user.id;

    const { error: organizationError } = await service.from('organizations').insert({
      id: organizationId,
      name: `P11 Web Session QA ${suffix}`,
      slug: `p11-web-${suffix}`,
      timezone: 'Asia/Ho_Chi_Minh',
      status: 'active',
    });
    if (organizationError) throw new Error('WEB_SESSION_ORGANIZATION_CREATE_FAILED');
    organizationCreated = true;

    const { error: membershipError } = await service.from('organization_members').insert({
      id: memberId,
      organization_id: organizationId,
      user_id: userId,
      employee_code: 'QA-ADMIN',
      display_name: 'P11 Web Session QA',
      role: 'admin',
      status: 'active',
    });
    if (membershipError) throw new Error('WEB_SESSION_MEMBERSHIP_CREATE_FAILED');
    memberCreated = true;

    const { error: ownerError } = await service
      .from('organizations')
      .update({ owner_member_id: memberId })
      .eq('id', organizationId);
    if (ownerError) throw new Error('WEB_SESSION_OWNER_ASSIGN_FAILED');

    let cookies = [];
    const browser = createBrowserClient(url, anonKey, {
      isSingleton: false,
      cookies: {
        getAll: () => cookies,
        setAll: (nextCookies) => {
          const nextNames = new Set(nextCookies.map((cookie) => cookie.name));
          cookies = cookies.filter((cookie) => !nextNames.has(cookie.name));
          cookies.push(...nextCookies.map(({ name, value }) => ({ name, value })));
        },
      },
    });
    const { data: signIn, error: signInError } = await browser.auth.signInWithPassword({
      email,
      password,
    });
    if (signInError || !signIn.session || cookies.length === 0) {
      throw new Error('WEB_SESSION_BROWSER_SIGN_IN_FAILED');
    }

    const cookieHeader = cookies.map(({ name, value }) => `${name}=${value}`).join('; ');
    const response = await fetch(new URL('/overview', appOrigin), {
      headers: { cookie: cookieHeader },
      redirect: 'manual',
    });
    const body = await response.text();
    if (!response.ok || !body.includes('Tổng quan vận hành')) {
      failures.push('SSR_SESSION_OR_WORKSPACE_CONTEXT');
    }
    if (body.includes('Cần đăng nhập để tiếp tục') || body.includes('Không thể tải workspace')) {
      failures.push('SSR_AUTH_FALLBACK_RENDERED');
    }

    if (failures.length > 0) {
      console.error(`Web SSR session: FAIL (${failures.join(', ')})`);
      process.exitCode = 1;
    } else {
      console.log('Web SSR session: PASS');
    }
  } catch (error) {
    const code = error instanceof Error ? error.message : 'WEB_SESSION_SMOKE_FAILED';
    console.error(`Web SSR session: FAIL (${code})`);
    process.exitCode = 1;
  } finally {
    if (memberCreated) {
      await service.from('organization_members').delete().eq('id', memberId);
    }
    if (organizationCreated) {
      await service.from('organizations').delete().eq('id', organizationId);
    }
    if (userId) {
      await service.auth.admin.deleteUser(userId);
    }
  }
}
