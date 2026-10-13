-- OpsDesk P05 HR demo data for manual execution in Supabase SQL Editor.
--
-- Run migrations through 00000000000007_p05_hr_requests.sql first. This is optional
-- deterministic fixture data; it creates no auth.users, passwords, tokens or credentials.
-- It requires the BOMAX demo organization and active members created in your own project.

do $$
declare
  v_org uuid;
  v_admin uuid;
  v_manager uuid;
  v_employee_a uuid;
  v_employee_b uuid;
  v_today date := (timezone('Asia/Ho_Chi_Minh', now()))::date;
  v_tomorrow date := v_today + 1;
  v_after_tomorrow date := v_today + 2;
  v_office_id uuid := 'a5000000-0000-0000-0000-000000000001';
  v_template_id uuid := 'a5000000-0000-0000-0000-000000000002';
  v_paid_leave_id uuid := 'a5000000-0000-0000-0000-000000000003';
  v_unpaid_leave_id uuid := 'a5000000-0000-0000-0000-000000000004';
  v_pending_leave_id uuid := 'a5000000-0000-0000-0000-000000000005';
  v_employee_a_tomorrow_shift_id uuid := 'b5000000-0000-0000-0000-000000000005';
  v_employee_b_today_shift_id uuid := 'b5000000-0000-0000-0000-000000000003';
begin
  select id into v_org from public.organizations
  where slug = 'bomax-digital' and status = 'active' limit 1;
  if v_org is null then
    raise exception 'OPSDESK_P05_DEMO_PREREQUISITE: active organization slug bomax-digital is missing';
  end if;

  select id into v_admin from public.organization_members
  where organization_id = v_org and employee_code = 'NV0001' and role = 'admin' and status = 'active' limit 1;
  select id into v_manager from public.organization_members
  where organization_id = v_org and employee_code = 'NV0002' and status = 'active' limit 1;
  select id into v_employee_a from public.organization_members
  where organization_id = v_org and employee_code = 'NV0003' and status = 'active' limit 1;
  select id into v_employee_b from public.organization_members
  where organization_id = v_org and employee_code = 'NV0004' and status = 'active' limit 1;
  if v_admin is null or v_manager is null or v_employee_a is null or v_employee_b is null then
    raise exception 'OPSDESK_P05_DEMO_PREREQUISITE: active members NV0001, NV0002, NV0003 and NV0004 are required';
  end if;

  insert into public.offices (id, organization_id, name, timezone)
  values (v_office_id, v_org, 'BOMAX Office', 'Asia/Ho_Chi_Minh')
  on conflict do nothing;

  insert into public.shift_templates (
    id, organization_id, office_id, name, start_local, end_local, breaks, allowed_mode, standard_day_minutes
  ) values (
    v_template_id, v_org, v_office_id, 'Ca hành chính', time '09:00', time '18:00',
    jsonb_build_array(jsonb_build_object('start', '12:00', 'end', '13:00')), 'hybrid', 480
  ) on conflict do nothing;

  insert into public.leave_types (id, organization_id, code, name, pay_treatment, consumes_balance)
  values
    (v_paid_leave_id, v_org, 'PAID_PERSONAL', 'Nghỉ cá nhân hưởng lương', 'paid', true),
    (v_unpaid_leave_id, v_org, 'UNPAID', 'Nghỉ không lương', 'unpaid', false),
    (v_pending_leave_id, v_org, 'HR_REVIEW', 'HR xác định treatment', 'pending_hr', false)
  on conflict do nothing;

  insert into public.shift_instances (
    id, organization_id, member_id, template_id, work_date, starts_at, ends_at,
    working_segments, scheduled_seconds, standard_day_minutes, allowed_mode, office_id, policy_snapshot
  ) values
    ('b5000000-0000-0000-0000-000000000001', v_org, v_manager, v_template_id, v_today,
      (v_today::text || ' 09:00:00+07')::timestamptz, (v_today::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_today::text || 'T09:00:00+07', 'end', v_today::text || 'T12:00:00+07'), jsonb_build_object('start', v_today::text || 'T13:00:00+07', 'end', v_today::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    ('b5000000-0000-0000-0000-000000000002', v_org, v_employee_a, v_template_id, v_today,
      (v_today::text || ' 09:00:00+07')::timestamptz, (v_today::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_today::text || 'T09:00:00+07', 'end', v_today::text || 'T12:00:00+07'), jsonb_build_object('start', v_today::text || 'T13:00:00+07', 'end', v_today::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    (v_employee_b_today_shift_id, v_org, v_employee_b, v_template_id, v_today,
      (v_today::text || ' 09:00:00+07')::timestamptz, (v_today::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_today::text || 'T09:00:00+07', 'end', v_today::text || 'T12:00:00+07'), jsonb_build_object('start', v_today::text || 'T13:00:00+07', 'end', v_today::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    ('b5000000-0000-0000-0000-000000000004', v_org, v_manager, v_template_id, v_tomorrow,
      (v_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_tomorrow::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_tomorrow::text || 'T09:00:00+07', 'end', v_tomorrow::text || 'T12:00:00+07'), jsonb_build_object('start', v_tomorrow::text || 'T13:00:00+07', 'end', v_tomorrow::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    (v_employee_a_tomorrow_shift_id, v_org, v_employee_a, v_template_id, v_tomorrow,
      (v_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_tomorrow::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_tomorrow::text || 'T09:00:00+07', 'end', v_tomorrow::text || 'T12:00:00+07'), jsonb_build_object('start', v_tomorrow::text || 'T13:00:00+07', 'end', v_tomorrow::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    ('b5000000-0000-0000-0000-000000000006', v_org, v_employee_b, v_template_id, v_tomorrow,
      (v_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_tomorrow::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_tomorrow::text || 'T09:00:00+07', 'end', v_tomorrow::text || 'T12:00:00+07'), jsonb_build_object('start', v_tomorrow::text || 'T13:00:00+07', 'end', v_tomorrow::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    ('b5000000-0000-0000-0000-000000000007', v_org, v_manager, v_template_id, v_after_tomorrow,
      (v_after_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_after_tomorrow::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_after_tomorrow::text || 'T09:00:00+07', 'end', v_after_tomorrow::text || 'T12:00:00+07'), jsonb_build_object('start', v_after_tomorrow::text || 'T13:00:00+07', 'end', v_after_tomorrow::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    ('b5000000-0000-0000-0000-000000000008', v_org, v_employee_a, v_template_id, v_after_tomorrow,
      (v_after_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_after_tomorrow::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_after_tomorrow::text || 'T09:00:00+07', 'end', v_after_tomorrow::text || 'T12:00:00+07'), jsonb_build_object('start', v_after_tomorrow::text || 'T13:00:00+07', 'end', v_after_tomorrow::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb),
    ('b5000000-0000-0000-0000-000000000009', v_org, v_employee_b, v_template_id, v_after_tomorrow,
      (v_after_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_after_tomorrow::text || ' 18:00:00+07')::timestamptz,
      jsonb_build_array(jsonb_build_object('start', v_after_tomorrow::text || 'T09:00:00+07', 'end', v_after_tomorrow::text || 'T12:00:00+07'), jsonb_build_object('start', v_after_tomorrow::text || 'T13:00:00+07', 'end', v_after_tomorrow::text || 'T18:00:00+07')),
      28800, 480, 'hybrid', v_office_id, '{}'::jsonb)
  on conflict do nothing;

  insert into public.employee_requests (
    id, organization_id, member_id, request_type, status, starts_at, ends_at, leave_type_id,
    pay_treatment_snapshot, reason_private, handover_note, submitted_at, idempotency_key
  ) values
    ('c5000000-0000-0000-0000-000000000001', v_org, v_employee_a, 'leave', 'pending',
      (v_tomorrow::text || ' 13:00:00+07')::timestamptz, (v_tomorrow::text || ' 17:00:00+07')::timestamptz,
      v_paid_leave_id, 'paid', 'Có việc gia đình cần xử lý trong buổi chiều.',
      'Nhờ team theo dõi inbox seller trong khung 13:00–17:00.', timezone('utc', now()), 'p05-demo-linh-pending'),
    ('c5000000-0000-0000-0000-000000000002', v_org, v_employee_b, 'early_leave', 'approved',
      (v_today::text || ' 16:00:00+07')::timestamptz, (v_today::text || ' 18:00:00+07')::timestamptz,
      v_unpaid_leave_id, 'unpaid', 'Lịch hẹn cá nhân cuối giờ chiều.',
      'Bàn giao ticket còn mở cho Minh Anh.', timezone('utc', now()), 'p05-demo-huy-approved'),
    ('c5000000-0000-0000-0000-000000000003', v_org, v_manager, 'remote_work', 'approved',
      (v_after_tomorrow::text || ' 09:00:00+07')::timestamptz, (v_after_tomorrow::text || ' 18:00:00+07')::timestamptz,
      null, 'not_applicable', 'Làm việc online theo lịch cá nhân đã được duyệt.',
      null, timezone('utc', now()), 'p05-demo-manager-remote')
  on conflict do nothing;

  insert into public.request_segments (
    organization_id, request_id, shift_instance_id, starts_at, ends_at, affected_seconds, pay_treatment_snapshot
  ) values
    (v_org, 'c5000000-0000-0000-0000-000000000001', v_employee_a_tomorrow_shift_id,
      (v_tomorrow::text || ' 13:00:00+07')::timestamptz, (v_tomorrow::text || ' 17:00:00+07')::timestamptz, 14400, 'paid'),
    (v_org, 'c5000000-0000-0000-0000-000000000002', v_employee_b_today_shift_id,
      (v_today::text || ' 16:00:00+07')::timestamptz, (v_today::text || ' 18:00:00+07')::timestamptz, 7200, 'unpaid')
  on conflict do nothing;
end;
$$;
