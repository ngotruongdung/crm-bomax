begin;

create extension if not exists pgtap with schema extensions;

select plan(28);

select has_table('public', 'organizations', 'AUTH-04: organizations exists');
select has_table('public', 'organization_members', 'AUTH-04: memberships exists');
select has_table('public', 'invitations', 'AUTH-04: invitations exists');
select has_table('public', 'audit_logs', 'SEC-12: audit logs exists');
select has_table('private', 'command_idempotency', 'SEC-12: private idempotency exists');

select is((select relrowsecurity from pg_class where oid = 'public.organizations'::regclass), true, 'SEC-14: organizations RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.organization_members'::regclass), true, 'SEC-14: memberships RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.audit_logs'::regclass), true, 'SEC-14: audit RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'private.command_idempotency'::regclass), true, 'SEC-14: private idempotency RLS enabled');

select has_function('public', 'rpc_get_context', array['uuid'], 'AUTH-04: context RPC exists');
select has_function('private', 'assert_organization_owner', array[]::text[], 'AUTH-04: owner eligibility guard exists');
select ok(not has_function_privilege('anon', 'public.rpc_get_context(uuid)', 'EXECUTE'), 'AUTH-01: anon cannot execute context RPC');
select ok(not has_function_privilege('anon', 'private.current_member_id(uuid)', 'EXECUTE'), 'SEC-12: private helper is not anonymous');
select ok(not has_function_privilege('authenticated', 'private.write_audit(uuid,text,text,uuid,jsonb,uuid)', 'EXECUTE'), 'SEC-12: audit writer is not client callable');

select ok(has_table_privilege('anon', 'public.organizations', 'SELECT') is false, 'AUTH-01: anon has no organizations SELECT grant');
select ok(has_table_privilege('authenticated', 'public.organization_members', 'INSERT') is false, 'AUTH-02: employee cannot insert memberships directly');
select ok(has_table_privilege('authenticated', 'public.organization_members', 'UPDATE') is false, 'AUTH-02: employee cannot update role/capability directly');
select ok(has_table_privilege('authenticated', 'public.organization_members', 'DELETE') is false, 'AUTH-02: employee cannot delete memberships directly');

insert into auth.users (id, aud, role, email)
values
  ('40000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'pgtap.a@opsdesk.local'),
  ('40000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'pgtap.inactive@opsdesk.local')
on conflict (id) do nothing;

insert into public.organizations (id, name, slug)
values
  ('50000000-0000-0000-0000-000000000001', 'pgTAP A', 'pgtap-a'),
  ('50000000-0000-0000-0000-000000000002', 'pgTAP B', 'pgtap-b');

insert into public.organization_members (id, organization_id, user_id, employee_code, display_name, role, status)
values
  ('60000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'PT-A', 'pgTAP Active', 'employee', 'active'),
  ('60000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'PT-B', 'pgTAP Cross Org', 'admin', 'active'),
  ('60000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 'PT-I', 'pgTAP Inactive', 'admin', 'inactive');

select throws_ok(
  $sql$update public.organizations
       set owner_member_id = '60000000-0000-0000-0000-000000000003'
       where id = '50000000-0000-0000-0000-000000000001'$sql$,
  '23514',
  'OWNER_MEMBER_MUST_BE_ACTIVE_ADMIN',
  'AUTH-04: inactive member cannot become organization owner'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"40000000-0000-0000-0000-000000000001","user_metadata":{"role":"admin"}}', true);

select is((select count(*)::integer from public.organizations), 2, 'AUTH-04: a user sees only organizations where membership is active');
select is((select count(*)::integer from public.organizations where id = '50000000-0000-0000-0000-000000000001'), 1, 'AUTH-04: organization A is visible');
select is((select count(*)::integer from public.organizations where id = '50000000-0000-0000-0000-000000000002'), 1, 'AUTH-04: explicit second active membership is visible only through real membership');
select is((select count(*)::integer from public.organization_members where organization_id = '50000000-0000-0000-0000-000000000001'), 1, 'AUTH-04: employee reads only own membership projection');
select is(private.is_admin('50000000-0000-0000-0000-000000000001'), false, 'AUTH-11: user_metadata role does not elevate employee membership');

reset role;
update public.organizations
set status = 'suspended'
where id = '50000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.organizations), 1, 'AUTH-03: suspended organization is not readable');
select is((select count(*)::integer from public.organizations where id = '50000000-0000-0000-0000-000000000002'), 0, 'AUTH-03: suspended organization is denied');

reset role;
update public.organizations
set status = 'active'
where id = '50000000-0000-0000-0000-000000000002';
set local role authenticated;
select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000001', true);

select set_config('request.jwt.claim.sub', '40000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"40000000-0000-0000-0000-000000000002","user_metadata":{"role":"admin"}}', true);
select is((select count(*)::integer from public.organizations), 0, 'AUTH-03: inactive membership cannot read organizations');
select throws_ok($sql$select public.rpc_get_context('50000000-0000-0000-0000-000000000001')$sql$, '42501', 'ACTIVE_MEMBERSHIP_REQUIRED', 'AUTH-03: context requires active membership for selected organization');

select * from finish();
rollback;
