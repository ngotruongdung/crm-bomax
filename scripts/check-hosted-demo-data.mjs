import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const requireFromWeb = createRequire(resolve(process.cwd(), 'apps/web/package.json'));
const { createClient } = requireFromWeb('@supabase/supabase-js');

const envPath = resolve(process.cwd(), '.env.local');
if (existsSync(envPath)) process.loadEnvFile(envPath);

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const expectedUsers = [
  { email: 'admin@bomax.demo', employeeCode: 'NV0001', role: 'admin' },
  { email: 'manager@bomax.demo', employeeCode: 'NV0002', role: 'manager' },
  { email: 'linh@bomax.demo', employeeCode: 'NV0003', role: 'employee' },
  { email: 'huy@bomax.demo', employeeCode: 'NV0004', role: 'employee' },
];

if (!url || !serviceRoleKey) {
  console.error('HOSTED_DEMO_CHECK_CONFIGURATION_REQUIRED');
  process.exitCode = 1;
} else {
  const client = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const failures = [];

  const { data: usersPage, error: usersError } = await client.auth.admin.listUsers({
    page: 1,
    perPage: 1000,
  });
  if (usersError) {
    failures.push('AUTH_USERS_UNREADABLE');
  }

  const usersByEmail = new Map(
    (usersPage?.users ?? [])
      .filter((user) => user.email)
      .map((user) => [user.email.toLowerCase(), user]),
  );
  const expectedUserIds = new Set();
  const missingAuthUsers = [];
  for (const expected of expectedUsers) {
    const user = usersByEmail.get(expected.email);
    if (!user) {
      missingAuthUsers.push(expected.email);
    } else {
      expectedUserIds.add(user.id);
    }
  }
  if (missingAuthUsers.length > 0) failures.push('AUTH_USERS_MISSING');

  const { data: organization, error: organizationError } = await client
    .from('organizations')
    .select('id,status,owner_member_id')
    .eq('slug', 'bomax-digital')
    .maybeSingle();
  if (organizationError || !organization || organization.status !== 'active') {
    failures.push('BOMAX_ORGANIZATION_MISSING');
  }

  const organizationId = organization?.id;
  const [{ data: members, error: membersError }, sellersResult, tasksResult] = await Promise.all([
    organizationId
      ? client
          .from('organization_members')
          .select('id,user_id,employee_code,role,status')
          .eq('organization_id', organizationId)
      : Promise.resolve({ data: [], error: null }),
    organizationId
      ? client
          .from('sellers')
          .select('id', { count: 'exact', head: true })
          .eq('organization_id', organizationId)
          .is('archived_at', null)
      : Promise.resolve({ count: 0, error: null }),
    organizationId
      ? client
          .from('tasks')
          .select('id', { count: 'exact', head: true })
          .eq('organization_id', organizationId)
      : Promise.resolve({ count: 0, error: null }),
  ]);

  if (membersError) failures.push('BOMAX_MEMBERS_UNREADABLE');
  if (sellersResult.error) failures.push('BOMAX_SELLERS_UNREADABLE');
  if (tasksResult.error) failures.push('BOMAX_TASKS_UNREADABLE');

  const memberByUserId = new Map((members ?? []).map((member) => [member.user_id, member]));
  const membershipFailures = expectedUsers.filter((expected) => {
    const user = usersByEmail.get(expected.email);
    const member = user ? memberByUserId.get(user.id) : null;
    return (
      !member ||
      member.status !== 'active' ||
      member.employee_code !== expected.employeeCode ||
      member.role !== expected.role
    );
  });
  if (membershipFailures.length > 0 || expectedUserIds.size !== expectedUsers.length) {
    failures.push('BOMAX_MEMBERSHIP_LINKS_INCOMPLETE');
  }
  const adminUser = usersByEmail.get('admin@bomax.demo');
  const adminMember = adminUser ? memberByUserId.get(adminUser.id) : null;
  if (!adminMember || organization?.owner_member_id !== adminMember.id) {
    failures.push('BOMAX_OWNER_INCOMPLETE');
  }
  if ((sellersResult.count ?? 0) < 3) failures.push('BOMAX_SELLERS_INCOMPLETE');
  if ((tasksResult.count ?? 0) < 9) failures.push('BOMAX_TASKS_INCOMPLETE');

  console.log(
    `Demo Auth users: ${expectedUsers.length - missingAuthUsers.length}/${expectedUsers.length}`,
  );
  console.log(`BOMAX workspace: ${organizationId ? 'PRESENT' : 'MISSING'}`);
  console.log(
    `BOMAX memberships: ${expectedUsers.length - membershipFailures.length}/${expectedUsers.length}`,
  );
  console.log(
    `BOMAX owner: ${organization?.owner_member_id === adminMember?.id ? 'READY' : 'INCOMPLETE'}`,
  );
  console.log(`BOMAX active sellers: ${sellersResult.count ?? 0}/3`);
  console.log(`BOMAX seeded tasks: ${tasksResult.count ?? 0}/9`);

  if (failures.length > 0) {
    console.error(`Hosted demo data: INCOMPLETE (${failures.join(', ')})`);
    process.exitCode = 1;
  } else {
    console.log('Hosted demo data: READY');
  }
}
