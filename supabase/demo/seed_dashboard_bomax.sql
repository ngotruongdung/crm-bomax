-- OpsDesk dashboard demo bootstrap.
--
-- Run this ONLY after:
--   1) OPSDesk_Supabase_Schema.sql has completed successfully, and
--   2) the four Auth users listed below exist and are confirmed.
--
-- This script is for a demo/staging project only. It does not create auth.users,
-- passwords, sessions or service-role credentials. It can be re-run safely for
-- the same four users because it uses deterministic IDs and upserts.
--
-- Required Supabase Auth emails:
--   admin@bomax.demo
--   manager@bomax.demo
--   linh@bomax.demo
--   huy@bomax.demo

do $$
declare
  v_organization_id uuid := '53000000-0000-0000-0000-000000000001';
  v_admin_member_id uuid := '63000000-0000-0000-0000-000000000001';
  v_manager_member_id uuid := '63000000-0000-0000-0000-000000000002';
  v_employee_a_member_id uuid := '63000000-0000-0000-0000-000000000003';
  v_employee_b_member_id uuid := '63000000-0000-0000-0000-000000000004';
  v_admin_user_id uuid;
  v_manager_user_id uuid;
  v_employee_a_user_id uuid;
  v_employee_b_user_id uuid;
begin
  select id into v_admin_user_id from auth.users where lower(email) = 'admin@bomax.demo' limit 1;
  select id into v_manager_user_id from auth.users where lower(email) = 'manager@bomax.demo' limit 1;
  select id into v_employee_a_user_id from auth.users where lower(email) = 'linh@bomax.demo' limit 1;
  select id into v_employee_b_user_id from auth.users where lower(email) = 'huy@bomax.demo' limit 1;

  if v_admin_user_id is null or v_manager_user_id is null
    or v_employee_a_user_id is null or v_employee_b_user_id is null then
    raise exception using
      message = 'OPSDESK_DEMO_AUTH_USERS_MISSING',
      detail = 'Create and confirm admin@bomax.demo, manager@bomax.demo, linh@bomax.demo and huy@bomax.demo in Supabase Authentication > Users, then run this script again.';
  end if;

  insert into public.organizations (id, name, slug, timezone, status)
  values (v_organization_id, 'BOMAX Digital', 'bomax-digital', 'Asia/Ho_Chi_Minh', 'active')
  on conflict (id) do update
    set name = excluded.name,
        slug = excluded.slug,
        timezone = excluded.timezone,
        status = excluded.status;

  insert into public.organization_members (
    id, organization_id, user_id, employee_code, display_name, role, status,
    can_manage_attendance, can_approve_requests, can_view_attendance_evidence
  ) values
    (v_admin_member_id, v_organization_id, v_admin_user_id, 'NV0001', 'Admin OpsDesk', 'admin', 'active', true, true, true),
    (v_manager_member_id, v_organization_id, v_manager_user_id, 'NV0002', 'Nguyễn Minh Anh', 'manager', 'active', true, true, true),
    (v_employee_a_member_id, v_organization_id, v_employee_a_user_id, 'NV0003', 'Trần Ngọc Linh', 'employee', 'active', false, false, false),
    (v_employee_b_member_id, v_organization_id, v_employee_b_user_id, 'NV0004', 'Lê Quốc Huy', 'employee', 'active', false, false, false)
  on conflict (id) do update
    set user_id = excluded.user_id,
        employee_code = excluded.employee_code,
        display_name = excluded.display_name,
        role = excluded.role,
        status = excluded.status,
        can_manage_attendance = excluded.can_manage_attendance,
        can_approve_requests = excluded.can_approve_requests,
        can_view_attendance_evidence = excluded.can_view_attendance_evidence;

  update public.organizations
  set owner_member_id = v_admin_member_id
  where id = v_organization_id;

  insert into public.sellers (id, organization_id, code, name, platform, brand_label, version)
  values
    ('73000000-0000-0000-0000-000000000001', v_organization_id, 'BM-SHOPEE', 'Bomax Shopee', 'shopee', 'BOMAX', 1),
    ('73000000-0000-0000-0000-000000000002', v_organization_id, 'BM-TIKTOK', 'Bomax TikTok Shop', 'tiktok_shop', 'BOMAX', 1),
    ('73000000-0000-0000-0000-000000000003', v_organization_id, 'BY-SUNI', 'By Suni', 'shopee', 'By Suni', 1)
  on conflict (id) do update
    set organization_id = excluded.organization_id,
        code = excluded.code,
        name = excluded.name,
        platform = excluded.platform,
        brand_label = excluded.brand_label,
        archived_at = null,
        version = greatest(public.sellers.version, excluded.version);

  insert into public.seller_members (
    id, organization_id, seller_id, member_id, is_manager, active_from
  ) values
    ('74000000-0000-0000-0000-000000000001', v_organization_id, '73000000-0000-0000-0000-000000000001', v_manager_member_id, true, date '2020-01-01'),
    ('74000000-0000-0000-0000-000000000002', v_organization_id, '73000000-0000-0000-0000-000000000002', v_manager_member_id, true, date '2020-01-01'),
    ('74000000-0000-0000-0000-000000000003', v_organization_id, '73000000-0000-0000-0000-000000000003', v_manager_member_id, true, date '2020-01-01'),
    ('74000000-0000-0000-0000-000000000004', v_organization_id, '73000000-0000-0000-0000-000000000001', v_employee_a_member_id, false, date '2020-01-01'),
    ('74000000-0000-0000-0000-000000000005', v_organization_id, '73000000-0000-0000-0000-000000000002', v_employee_a_member_id, false, date '2020-01-01'),
    ('74000000-0000-0000-0000-000000000006', v_organization_id, '73000000-0000-0000-0000-000000000001', v_employee_b_member_id, false, date '2020-01-01')
  on conflict (id) do update
    set organization_id = excluded.organization_id,
        seller_id = excluded.seller_id,
        member_id = excluded.member_id,
        is_manager = excluded.is_manager,
        active_from = excluded.active_from,
        active_until = null;

  raise notice 'OpsDesk BOMAX demo organization, members and seller scope are ready.';
end;
$$;
