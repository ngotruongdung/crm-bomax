import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const migrationPath = resolve(root, 'supabase/migrations/00000000000001_p01a_core_schema.sql');
const seedPath = resolve(root, 'supabase/seed.sql');
const testPath = resolve(root, 'supabase/tests/0001_p01a_rls.sql');
const middlewarePath = resolve(root, 'apps/web/lib/supabase/middleware.ts');
const callbackPath = resolve(root, 'apps/web/app/auth/callback/route.ts');
const authSeedPath = resolve(root, 'apps/web/scripts/seed-auth-demo.mjs');

const [migration, seed, tests, middleware, callback, authSeed] = await Promise.all([
  readFile(migrationPath, 'utf8'),
  readFile(seedPath, 'utf8'),
  readFile(testPath, 'utf8'),
  readFile(middlewarePath, 'utf8'),
  readFile(callbackPath, 'utf8'),
  readFile(authSeedPath, 'utf8'),
]);

const requiredMigrationFragments = [
  'create table public.organizations',
  'create table public.organization_members',
  'create table public.member_hr_settings',
  'create table public.specialties',
  'create table public.member_specialties',
  'create table public.invitations',
  'create table public.policy_versions',
  'create table public.audit_logs',
  'create table private.command_idempotency',
  'create or replace function private.current_member_id',
  'create or replace function private.is_admin',
  'create or replace function private.assert_organization_owner',
  'member_hr_settings_policy_version_fk',
  'create or replace function public.rpc_get_context',
  'grant execute on function public.rpc_get_context(uuid) to authenticated',
  'create policy organization_members_read_self_or_admin',
];

for (const fragment of requiredMigrationFragments) {
  if (!migration.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`P01A migration is missing: ${fragment}`);
  }
}

const rlsTables = [
  'public.organizations',
  'public.organization_members',
  'public.member_hr_settings',
  'public.specialties',
  'public.member_specialties',
  'public.invitations',
  'public.policy_versions',
  'public.audit_logs',
  'private.command_idempotency',
];
for (const table of rlsTables) {
  const marker = `alter table ${table} enable row level security`;
  if (!migration.toLowerCase().includes(marker)) {
    throw new Error(`RLS is not enabled for ${table}`);
  }
}

if (/\b(using|with\s+check)\s*\(\s*true\s*\)/i.test(migration)) {
  throw new Error('P01A migration contains an unsafe always-true policy');
}

if (migration.includes('create policy organization_members_read_same_org')) {
  throw new Error('Membership roster policy is broader than the P01A privacy matrix');
}

const helperCount = (migration.match(/set search_path\s*=\s*''/gi) ?? []).length;
if (helperCount < 5) {
  throw new Error(`Expected fixed search_path on security-sensitive helpers; found ${helperCount}`);
}

for (const fragment of [
  'opsdesk-demo-a',
  'opsdesk-demo-b',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
]) {
  if (!seed.toLowerCase().includes(fragment.toLowerCase())) {
    throw new Error(`Seed is missing deterministic fixture: ${fragment}`);
  }
}

for (const testId of ['AUTH-01', 'AUTH-02', 'AUTH-03', 'AUTH-04', 'AUTH-11', 'SEC-12', 'SEC-14']) {
  if (!tests.includes(testId)) {
    throw new Error(`P01A database test is missing required case: ${testId}`);
  }
}

for (const fragment of [
  'supabase.auth.getUser()',
  'request.cookies.getAll()',
  'exchangeCodeForSession',
]) {
  if (![middleware, callback].some((source) => source.includes(fragment))) {
    throw new Error(`Auth session foundation is missing: ${fragment}`);
  }
}

if (!callback.includes('safeAuthRedirect')) {
  throw new Error('Auth callback is missing internal redirect validation');
}

for (const fragment of [
  'SUPABASE_SERVICE_ROLE_KEY',
  'DEMO_SEED_PASSWORD',
  'localhost',
  'auth.admin.createUser',
  "from('organization_members')",
]) {
  if (!authSeed.includes(fragment)) {
    throw new Error(`Local Auth seed is missing: ${fragment}`);
  }
}

console.log(
  'P01A static migration checks passed. Runtime DB/RLS checks still require Supabase CLI and Docker.',
);
