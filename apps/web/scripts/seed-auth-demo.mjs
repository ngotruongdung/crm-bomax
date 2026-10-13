import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const password = process.env.DEMO_SEED_PASSWORD;

if (!url || !serviceRoleKey || !password) {
  throw new Error('Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and DEMO_SEED_PASSWORD first.');
}

if (!/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/i.test(url.replace(/\/$/, ''))) {
  throw new Error('Demo Auth seed is local-only; use a localhost Supabase URL.');
}

if (password.length < 12) {
  throw new Error('DEMO_SEED_PASSWORD must contain at least 12 characters.');
}

const supabase = createClient(url, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const demoMembers = [
  {
    email: 'admin.a@opsdesk.local',
    organizationId: '10000000-0000-0000-0000-000000000001',
    memberId: '30000000-0000-0000-0000-000000000001',
    employeeCode: 'ADM-A',
    displayName: 'Admin Demo A',
    role: 'admin',
    capabilities: {
      can_manage_attendance: true,
      can_approve_requests: true,
      can_view_attendance_evidence: true,
    },
  },
  {
    email: 'employee.a@opsdesk.local',
    organizationId: '10000000-0000-0000-0000-000000000001',
    memberId: '30000000-0000-0000-0000-000000000002',
    employeeCode: 'EMP-A',
    displayName: 'Employee Demo A',
    role: 'employee',
    capabilities: {},
  },
  {
    email: 'admin.b@opsdesk.local',
    organizationId: '10000000-0000-0000-0000-000000000002',
    memberId: '30000000-0000-0000-0000-000000000003',
    employeeCode: 'ADM-B',
    displayName: 'Admin Demo B',
    role: 'admin',
    capabilities: {
      can_manage_attendance: true,
      can_approve_requests: true,
      can_view_attendance_evidence: true,
    },
  },
  {
    email: 'employee.b@opsdesk.local',
    organizationId: '10000000-0000-0000-0000-000000000002',
    memberId: '30000000-0000-0000-0000-000000000004',
    employeeCode: 'EMP-B',
    displayName: 'Employee Demo B',
    role: 'employee',
    capabilities: {},
  },
];

const { data: usersPage, error: listError } = await supabase.auth.admin.listUsers({
  page: 1,
  perPage: 1000,
});

if (listError) {
  throw listError;
}

const usersByEmail = new Map(usersPage.users.map((user) => [user.email?.toLowerCase(), user]));

for (const member of demoMembers) {
  let user = usersByEmail.get(member.email);

  if (!user) {
    const result = await supabase.auth.admin.createUser({
      email: member.email,
      password,
      email_confirm: true,
      user_metadata: { display_name: member.displayName },
    });

    if (result.error || !result.data.user) {
      throw result.error ?? new Error(`Could not create ${member.email}`);
    }

    user = result.data.user;
    usersByEmail.set(member.email, user);
  } else {
    const result = await supabase.auth.admin.updateUserById(user.id, {
      password,
      email_confirm: true,
      user_metadata: { display_name: member.displayName },
    });

    if (result.error) {
      throw result.error;
    }
  }

  const { error: membershipError } = await supabase.from('organization_members').upsert(
    {
      id: member.memberId,
      organization_id: member.organizationId,
      user_id: user.id,
      employee_code: member.employeeCode,
      display_name: member.displayName,
      role: member.role,
      status: 'active',
      can_manage_attendance: member.capabilities.can_manage_attendance ?? false,
      can_approve_requests: member.capabilities.can_approve_requests ?? false,
      can_view_attendance_evidence: member.capabilities.can_view_attendance_evidence ?? false,
    },
    { onConflict: 'id' },
  );

  if (membershipError) {
    throw membershipError;
  }

  if (member.role === 'admin') {
    const { error: ownerError } = await supabase
      .from('organizations')
      .update({ owner_member_id: member.memberId })
      .eq('id', member.organizationId);

    if (ownerError) {
      throw ownerError;
    }
  }
}

console.log(`Seeded ${demoMembers.length} local Auth demo users and memberships.`);
