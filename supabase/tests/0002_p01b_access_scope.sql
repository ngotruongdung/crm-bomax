begin;

create extension if not exists pgtap with schema extensions;

select plan(29);

select has_table('public', 'sellers', 'P01B: sellers exists');
select has_table('public', 'seller_members', 'P01B: seller membership history exists');
select has_table('public', 'invitation_seller_scopes', 'P01B: invitation seller scopes exists');
select is((select relrowsecurity from pg_class where oid = 'public.sellers'::regclass), true, 'SEC-14: seller RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.seller_members'::regclass), true, 'SEC-14: seller membership RLS enabled');
select is((select relrowsecurity from pg_class where oid = 'public.invitation_seller_scopes'::regclass), true, 'SEC-14: invitation scope RLS enabled');
select has_function('public', 'rpc_create_invitation', array['uuid', 'text', 'text', 'jsonb', 'jsonb', 'text', 'timestamp with time zone'], 'P01B: create invitation command exists');
select has_function('public', 'rpc_validate_invitation', array['text'], 'P01B: validate invitation command exists');
select has_function('public', 'rpc_accept_invitation', array['text', 'text'], 'P01B: accept invitation command exists');
select ok(not has_function_privilege('authenticated', 'public.rpc_internal_create_invited_membership(uuid,uuid,text)', 'EXECUTE'), 'AUTH-10: authenticated cannot finalize an invitation internally');
select ok(not has_function_privilege('authenticated', 'public.rpc_internal_set_invitation_auth_reference(uuid,text)', 'EXECUTE'), 'AUTH-10: authenticated cannot set an Auth invitation reference');
select ok(not has_function_privilege('authenticated', 'private.is_seller_member(uuid,uuid,uuid)', 'EXECUTE'), 'SEC-12: broad seller-member helper is not client callable');
select ok(has_table_privilege('authenticated', 'public.seller_members', 'UPDATE') is false, 'AUTH-02: authenticated cannot alter seller scope directly');
select ok(has_table_privilege('authenticated', 'public.sellers', 'INSERT') is false, 'AUTH-02: authenticated cannot create sellers directly');

insert into auth.users (id, aud, role, email)
values
  ('41000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'p01b.admin@opsdesk.local'),
  ('41000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'p01b.manager@opsdesk.local'),
  ('41000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'p01b.employee@opsdesk.local'),
  ('41000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'p01b.manager-c@opsdesk.local'),
  ('41000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'p01b.wrong@opsdesk.local'),
  ('41000000-0000-0000-0000-000000000006', 'authenticated', 'authenticated', 'p01b.correct@opsdesk.local'),
  ('41000000-0000-0000-0000-000000000007', 'authenticated', 'authenticated', 'p01b.retry@opsdesk.local');

insert into public.organizations (id, name, slug)
values ('51000000-0000-0000-0000-000000000001', 'pgTAP P01B', 'pgtap-p01b');

insert into public.organization_members (id, organization_id, user_id, employee_code, display_name, role, status)
values
  ('61000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', 'P1-ADM', 'P01B Admin', 'admin', 'active'),
  ('61000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000002', 'P1-MGR', 'P01B Manager', 'manager', 'active'),
  ('61000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000003', 'P1-EMP', 'P01B Employee', 'employee', 'active'),
  ('61000000-0000-0000-0000-000000000004', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000004', 'P1-MGC', 'P01B Manager C', 'manager', 'active');

update public.organizations
set owner_member_id = '61000000-0000-0000-0000-000000000001'
where id = '51000000-0000-0000-0000-000000000001';

insert into public.sellers (id, organization_id, code, name, platform)
values
  ('71000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'SELLER-A', 'Seller A', 'shopee'),
  ('71000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', 'SELLER-B', 'Seller B', 'tiktok_shop'),
  ('71000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', 'SELLER-C', 'Seller C', 'lazada');

insert into public.seller_members (organization_id, seller_id, member_id, is_manager, active_from)
values
  ('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000002', true, current_date - 1),
  ('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000002', '61000000-0000-0000-0000-000000000002', true, current_date - 1),
  ('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', '61000000-0000-0000-0000-000000000003', false, current_date - 1),
  ('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003', '61000000-0000-0000-0000-000000000004', true, current_date - 1);

insert into public.member_hr_settings (member_id, organization_id, employment_start)
values ('61000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', current_date - 30);

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"41000000-0000-0000-0000-000000000002","user_metadata":{"role":"admin"}}', true);

select is((select count(*)::integer from public.sellers), 2, 'AUTH-05: manager A/B cannot read Seller C');
select ok(private.can_read_seller('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001'), 'AUTH-05: manager reads assigned Seller A');
select ok(not private.can_read_seller('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000003'), 'AUTH-05: metadata cannot elevate manager into Seller C');
select is(jsonb_array_length(public.rpc_list_members_by_scope('51000000-0000-0000-0000-000000000001')), 2, 'P01B: manager directory is limited to shared seller scope');
select is((select count(*)::integer from public.member_hr_settings where member_id = '61000000-0000-0000-0000-000000000003'), 0, 'AUTH-07: seller manager without HR capability cannot read attendance settings');

select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000003', true);
select is((select count(*)::integer from public.sellers), 1, 'AUTH-06: employee sees only the seller scope, not organization-wide sellers');
select ok(not private.current_actor_is_seller_manager('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001'), 'AUTH-06: seller membership alone is not manager authority');

reset role;
insert into public.invitations (id, organization_id, email, invited_role, invited_by, token_hash, expires_at, capabilities)
values
  ('81000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'p01b.wrong@opsdesk.local', 'employee', '61000000-0000-0000-0000-000000000001', encode(extensions.digest(convert_to('expired-token-123456789012345678901234567890', 'UTF8'), 'sha256'), 'hex'), timezone('utc', now()) - interval '1 minute', '{}'::jsonb),
  ('81000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', 'p01b.correct@opsdesk.local', 'employee', '61000000-0000-0000-0000-000000000001', encode(extensions.digest(convert_to('wrong-email-token-123456789012345678901234567', 'UTF8'), 'sha256'), 'hex'), timezone('utc', now()) + interval '1 day', '{}'::jsonb),
  ('81000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', 'p01b.retry@opsdesk.local', 'employee', '61000000-0000-0000-0000-000000000001', encode(extensions.digest(convert_to('retry-token-12345678901234567890123456789012', 'UTF8'), 'sha256'), 'hex'), timezone('utc', now()) + interval '1 day', '{}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000005', true);
select throws_ok(
  $$select public.rpc_accept_invitation('expired-token-123456789012345678901234567890', 'Expired User')$$,
  '22023',
  'INVITE_INVALID_OR_EXPIRED',
  'AUTH-08: expired invitation cannot activate a membership'
);
select throws_ok(
  $$select public.rpc_accept_invitation('wrong-email-token-123456789012345678901234567', 'Wrong Email')$$,
  '42501',
  'INVITE_EMAIL_MISMATCH',
  'AUTH-08: invitation cannot be accepted by another signed-in email'
);

reset role;
select is((select count(*)::integer from public.organization_members where user_id = '41000000-0000-0000-0000-000000000006'), 0, 'AUTH-08: wrong-email attempt did not create membership');

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000007', true);
select is((public.rpc_accept_invitation('retry-token-12345678901234567890123456789012', 'Retry User') ->> 'already_accepted')::boolean, false, 'AUTH-09: first acceptance creates membership');
select is((public.rpc_accept_invitation('retry-token-12345678901234567890123456789012', 'Retry User') ->> 'already_accepted')::boolean, true, 'AUTH-09: retry reuses the existing membership');

reset role;
select is((select count(*)::integer from public.organization_members where user_id = '41000000-0000-0000-0000-000000000007'), 1, 'AUTH-09: acceptance retry never creates duplicate memberships');

delete from public.seller_members
where organization_id = '51000000-0000-0000-0000-000000000001'
  and seller_id = '71000000-0000-0000-0000-000000000001'
  and member_id = '61000000-0000-0000-0000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.sellers), 1, 'AUTH-12: revoked seller scope is denied on the next read');
select ok(not private.can_read_seller('51000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001'), 'AUTH-12: current-scope helper rejects revoked Seller A');

select * from finish();
rollback;
