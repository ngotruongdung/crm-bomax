-- P01A seed: deterministic organizations and reference specialties.
-- Auth users are deliberately not created here. Local auth credentials belong to
-- the Supabase Auth seed flow, so this file never contains plaintext passwords.

insert into public.organizations (id, name, slug, timezone, status)
values
  ('10000000-0000-0000-0000-000000000001', 'OpsDesk Demo A', 'opsdesk-demo-a', 'Asia/Ho_Chi_Minh', 'active'),
  ('10000000-0000-0000-0000-000000000002', 'OpsDesk Demo B', 'opsdesk-demo-b', 'Asia/Ho_Chi_Minh', 'active')
on conflict (id) do update
set name = excluded.name,
    slug = excluded.slug,
    timezone = excluded.timezone,
    status = excluded.status;

insert into public.specialties (id, organization_id, code, name)
values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'OPS', 'Vận hành'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'CS', 'Chăm sóc khách hàng'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'OPS', 'Vận hành')
on conflict (id) do update
set organization_id = excluded.organization_id,
    code = excluded.code,
    name = excluded.name,
    archived_at = null;

-- If matching Auth users already exist, attach them to the two demo tenants.
-- This makes the seed useful after a local auth fixture is loaded while keeping
-- a clean database reset safe when no Auth users are present.
do $$
declare
  v_admin_a uuid;
  v_employee_a uuid;
  v_admin_b uuid;
  v_employee_b uuid;
begin
  select id into v_admin_a from auth.users where lower(email) = 'admin.a@opsdesk.local' limit 1;
  select id into v_employee_a from auth.users where lower(email) = 'employee.a@opsdesk.local' limit 1;
  select id into v_admin_b from auth.users where lower(email) = 'admin.b@opsdesk.local' limit 1;
  select id into v_employee_b from auth.users where lower(email) = 'employee.b@opsdesk.local' limit 1;

  if v_admin_a is not null then
    insert into public.organization_members (
      id, organization_id, user_id, employee_code, display_name, role, status,
      can_manage_attendance, can_approve_requests, can_view_attendance_evidence
    ) values (
      '30000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000001',
      v_admin_a, 'ADM-A', 'Admin Demo A', 'admin', 'active', true, true, true
    ) on conflict (id) do update
      set user_id = excluded.user_id,
          display_name = excluded.display_name,
          role = excluded.role,
          status = excluded.status,
          can_manage_attendance = excluded.can_manage_attendance,
          can_approve_requests = excluded.can_approve_requests,
          can_view_attendance_evidence = excluded.can_view_attendance_evidence;
  end if;

  if v_employee_a is not null then
    insert into public.organization_members (
      id, organization_id, user_id, employee_code, display_name, role, status
    ) values (
      '30000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000001',
      v_employee_a, 'EMP-A', 'Employee Demo A', 'employee', 'active'
    ) on conflict (id) do update
      set user_id = excluded.user_id,
          display_name = excluded.display_name,
          role = excluded.role,
          status = excluded.status;
  end if;

  if v_admin_b is not null then
    insert into public.organization_members (
      id, organization_id, user_id, employee_code, display_name, role, status,
      can_manage_attendance, can_approve_requests, can_view_attendance_evidence
    ) values (
      '30000000-0000-0000-0000-000000000003',
      '10000000-0000-0000-0000-000000000002',
      v_admin_b, 'ADM-B', 'Admin Demo B', 'admin', 'active', true, true, true
    ) on conflict (id) do update
      set user_id = excluded.user_id,
          display_name = excluded.display_name,
          role = excluded.role,
          status = excluded.status,
          can_manage_attendance = excluded.can_manage_attendance,
          can_approve_requests = excluded.can_approve_requests,
          can_view_attendance_evidence = excluded.can_view_attendance_evidence;
  end if;

  if v_employee_b is not null then
    insert into public.organization_members (
      id, organization_id, user_id, employee_code, display_name, role, status
    ) values (
      '30000000-0000-0000-0000-000000000004',
      '10000000-0000-0000-0000-000000000002',
      v_employee_b, 'EMP-B', 'Employee Demo B', 'employee', 'active'
    ) on conflict (id) do update
      set user_id = excluded.user_id,
          display_name = excluded.display_name,
          role = excluded.role,
          status = excluded.status;
  end if;

  if v_admin_a is not null then
    update public.organizations
    set owner_member_id = '30000000-0000-0000-0000-000000000001'
    where id = '10000000-0000-0000-0000-000000000001';
  end if;

  if v_admin_b is not null then
    update public.organizations
    set owner_member_id = '30000000-0000-0000-0000-000000000003'
    where id = '10000000-0000-0000-0000-000000000002';
  end if;
end;
$$;

