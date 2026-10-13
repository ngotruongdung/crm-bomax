import { randomBytes, randomUUID } from 'node:crypto';
import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const requireFromWeb = createRequire(resolve(process.cwd(), 'apps/web/package.json'));
const { createClient } = requireFromWeb('@supabase/supabase-js');
const envPath = resolve(process.cwd(), '.env.local');
if (existsSync(envPath)) process.loadEnvFile(envPath);

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !anonKey || !serviceRoleKey) {
  console.error('SUPABASE_AUTH_RLS_SMOKE_CONFIGURATION_REQUIRED');
  process.exitCode = 1;
} else {
  const service = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const suffix = `${Date.now().toString(36)}${randomBytes(4).toString('hex')}`;
  const firstOrgId = randomUUID();
  const secondOrgId = randomUUID();
  const memberId = randomUUID();
  const email = `p11-${suffix}@opsdesk-runtime.invalid`;
  const password = `${randomBytes(24).toString('base64url')}Aa1!`;
  let userId = null;
  let firstOrganizationCreated = false;
  let secondOrganizationCreated = false;
  let memberCreated = false;
  const failures = [];

  try {
    const { data: createdUser, error: userError } = await service.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (userError || !createdUser.user) throw new Error('AUTH_USER_CREATE_FAILED');
    userId = createdUser.user.id;

    const { error: firstOrganizationError } = await service.from('organizations').insert({
      id: firstOrgId,
      name: `P11 Runtime QA ${suffix}`,
      slug: `p11-${suffix}`,
      timezone: 'Asia/Ho_Chi_Minh',
      status: 'active',
    });
    if (firstOrganizationError) throw new Error('QA_ORGANIZATION_CREATE_FAILED');
    firstOrganizationCreated = true;

    const { error: secondOrganizationError } = await service.from('organizations').insert({
      id: secondOrgId,
      name: `P11 Isolation QA ${suffix}`,
      slug: `p11-isolation-${suffix}`,
      timezone: 'Asia/Ho_Chi_Minh',
      status: 'active',
    });
    if (secondOrganizationError) throw new Error('QA_ISOLATION_ORGANIZATION_CREATE_FAILED');
    secondOrganizationCreated = true;

    const { error: membershipError } = await service.from('organization_members').insert({
      id: memberId,
      organization_id: firstOrgId,
      user_id: userId,
      employee_code: 'QA-RLS',
      display_name: 'P11 Runtime QA',
      role: 'employee',
      status: 'active',
    });
    if (membershipError) throw new Error('QA_MEMBERSHIP_CREATE_FAILED');
    memberCreated = true;

    const authenticated = createClient(url, anonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: signIn, error: signInError } = await authenticated.auth.signInWithPassword({
      email,
      password,
    });
    if (signInError || !signIn.session) throw new Error('QA_PASSWORD_SIGN_IN_FAILED');

    const { data: context, error: contextError } = await authenticated.rpc('rpc_get_context', {
      p_organization_id: firstOrgId,
    });
    if (
      contextError ||
      !context ||
      context.organization_id !== firstOrgId ||
      context.member_id !== memberId ||
      context.role !== 'employee'
    ) {
      failures.push('AUTH_CONTEXT');
    }

    const { data: visibleMembers, error: visibleMembersError } = await authenticated
      .from('organization_members')
      .select('id,organization_id');
    if (
      visibleMembersError ||
      visibleMembers?.length !== 1 ||
      visibleMembers[0]?.id !== memberId ||
      visibleMembers[0]?.organization_id !== firstOrgId
    ) {
      failures.push('RLS_MEMBER_SELF_ONLY');
    }

    const { data: visibleOrganizations, error: visibleOrganizationsError } = await authenticated
      .from('organizations')
      .select('id');
    if (
      visibleOrganizationsError ||
      visibleOrganizations?.length !== 1 ||
      visibleOrganizations[0]?.id !== firstOrgId
    ) {
      failures.push('RLS_ORGANIZATION_ISOLATION');
    }

    const { error: forbiddenContextError } = await authenticated.rpc('rpc_get_context', {
      p_organization_id: secondOrgId,
    });
    if (!forbiddenContextError) failures.push('RPC_CROSS_TENANT_DENY');

    const { error: forbiddenMutationError } = await authenticated
      .from('organization_members')
      .update({ display_name: 'Mutation must be denied' })
      .eq('id', memberId);
    if (!forbiddenMutationError) failures.push('DIRECT_MEMBER_MUTATION_DENY');

    const today = new Date().toISOString().slice(0, 10);
    const monthStart = `${today.slice(0, 7)}-01`;
    const businessReadChecks = await Promise.all([
      authenticated.rpc('rpc_list_tasks', {
        p_organization_id: firstOrgId,
        p_include_terminal: false,
      }),
      authenticated.rpc('rpc_list_request_availability', {
        p_organization_id: firstOrgId,
        p_from_date: today,
        p_to_date: today,
      }),
      authenticated.rpc('rpc_get_attendance_day', {
        p_organization_id: firstOrgId,
        p_member_id: memberId,
        p_work_date: today,
      }),
      authenticated.rpc('rpc_get_timesheet', {
        p_organization_id: firstOrgId,
        p_month_start: monthStart,
        p_member_id: memberId,
      }),
      authenticated.rpc('rpc_list_notifications', {
        p_organization_id: firstOrgId,
        p_limit: 20,
        p_before: null,
      }),
      authenticated.rpc('rpc_list_reports', {
        p_organization_id: firstOrgId,
        p_limit: 20,
      }),
    ]);
    const [tasks, availability, attendanceDay, timesheet, notifications, reports] =
      businessReadChecks;

    if (tasks.error || !Array.isArray(tasks.data)) failures.push('P03_TASK_READ');
    if (availability.error || !Array.isArray(availability.data))
      failures.push('P05_AVAILABILITY_READ');
    if (attendanceDay.error || !attendanceDay.data || Array.isArray(attendanceDay.data)) {
      failures.push('P06_ATTENDANCE_READ');
    }
    if (timesheet.error || !timesheet.data || Array.isArray(timesheet.data)) {
      failures.push('P07_TIMESHEET_READ');
    }
    if (notifications.error || !Array.isArray(notifications.data)) {
      failures.push('P08_NOTIFICATION_READ');
    }
    if (reports.error || !Array.isArray(reports.data)) failures.push('P09_REPORT_READ');

    if (failures.length > 0) {
      console.error(`P11 authenticated RLS: FAIL (${failures.join(', ')})`);
      process.exitCode = 1;
    } else {
      console.log('P11 authenticated RLS: PASS');
    }
  } catch (error) {
    const code = error instanceof Error ? error.message : 'P11_AUTH_RLS_SMOKE_FAILED';
    console.error(`P11 authenticated RLS: FAIL (${code})`);
    process.exitCode = 1;
  } finally {
    if (memberCreated) {
      await service.from('organization_members').delete().eq('id', memberId);
    }
    if (firstOrganizationCreated) {
      await service.from('organizations').delete().eq('id', firstOrgId);
    }
    if (secondOrganizationCreated) {
      await service.from('organizations').delete().eq('id', secondOrgId);
    }
    if (userId) {
      await service.auth.admin.deleteUser(userId);
    }
  }
}
