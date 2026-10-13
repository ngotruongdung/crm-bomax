-- OpsDesk P04 recurring-task demo data for manual execution in Supabase SQL Editor.
--
-- Run schema migrations through 00000000000006_p04_recurring_tasks.sql first.
-- This script creates no auth.users, passwords, tokens or credentials. It only resolves
-- existing BOMAX organization/member/seller records and inserts deterministic fixtures.
--
-- Expected BOMAX records:
--   organization slug: bomax-digital
--   members: NV0001 (admin), NV0003, NV0004
--   sellers: BM-SHOPEE, BM-TIKTOK, BY-SUNI
--
-- Fixtures mirror apps/web/lib/demo/recurring-demo.ts. Reruns are safe because IDs are
-- deterministic and existing rows are left untouched with ON CONFLICT DO NOTHING.

do $$
declare
  v_org uuid;
  v_admin uuid;
  v_employee_a uuid;
  v_employee_b uuid;
  v_seller_shopee uuid;
  v_seller_tiktok uuid;
  v_seller_suni uuid;
  v_today date := (timezone('Asia/Ho_Chi_Minh', now()))::date;
begin
  select id into v_org
  from public.organizations
  where slug = 'bomax-digital' and status = 'active'
  limit 1;

  if v_org is null then
    raise exception 'OPSDESK_P04_DEMO_PREREQUISITE: active organization slug bomax-digital is missing';
  end if;

  select id into v_admin
  from public.organization_members
  where organization_id = v_org and employee_code = 'NV0001' and role = 'admin' and status = 'active'
  limit 1;

  select id into v_employee_a
  from public.organization_members
  where organization_id = v_org and employee_code = 'NV0003' and status = 'active'
  limit 1;

  select id into v_employee_b
  from public.organization_members
  where organization_id = v_org and employee_code = 'NV0004' and status = 'active'
  limit 1;

  if v_admin is null or v_employee_a is null or v_employee_b is null then
    raise exception 'OPSDESK_P04_DEMO_PREREQUISITE: active members NV0001(admin), NV0003 and NV0004 are required';
  end if;

  select id into v_seller_shopee
  from public.sellers
  where organization_id = v_org and code = 'BM-SHOPEE' and archived_at is null
  limit 1;

  select id into v_seller_tiktok
  from public.sellers
  where organization_id = v_org and code = 'BM-TIKTOK' and archived_at is null
  limit 1;

  select id into v_seller_suni
  from public.sellers
  where organization_id = v_org and code = 'BY-SUNI' and archived_at is null
  limit 1;

  if v_seller_shopee is null or v_seller_tiktok is null or v_seller_suni is null then
    raise exception 'OPSDESK_P04_DEMO_PREREQUISITE: active sellers BM-SHOPEE, BM-TIKTOK and BY-SUNI are required';
  end if;

  if not exists (
    select 1
    from public.seller_members sm
    where sm.organization_id = v_org
      and sm.seller_id = v_seller_shopee
      and sm.member_id = v_employee_a
      and sm.active_from <= v_today
      and (sm.active_until is null or sm.active_until >= v_today)
  ) then
    raise exception 'OPSDESK_P04_DEMO_PREREQUISITE: NV0003 needs active BM-SHOPEE seller scope';
  end if;

  if not exists (
    select 1
    from public.seller_members sm
    where sm.organization_id = v_org
      and sm.seller_id = v_seller_tiktok
      and sm.member_id = v_employee_a
      and sm.active_from <= v_today
      and (sm.active_until is null or sm.active_until >= v_today)
  ) then
    raise exception 'OPSDESK_P04_DEMO_PREREQUISITE: NV0003 needs active BM-TIKTOK seller scope';
  end if;

  if not exists (
    select 1
    from public.seller_members sm
    where sm.organization_id = v_org
      and sm.seller_id = v_seller_shopee
      and sm.member_id = v_employee_b
      and sm.active_from <= v_today
      and (sm.active_until is null or sm.active_until >= v_today)
  ) then
    raise exception 'OPSDESK_P04_DEMO_PREREQUISITE: NV0004 needs active BM-SHOPEE seller scope';
  end if;

  insert into public.recurring_task_templates (
    id, organization_id, status, current_version_number, generation_floor_date,
    paused_at, created_by_member_id, version
  ) values
    ('93000000-0000-0000-0000-000000000001', v_org, 'active', 1, v_today, null, v_admin, 1),
    ('93000000-0000-0000-0000-000000000002', v_org, 'active', 1, v_today, null, v_admin, 1),
    ('93000000-0000-0000-0000-000000000003', v_org, 'paused', 1, v_today, timezone('utc', now()), v_admin, 1)
  on conflict do nothing;

  insert into public.recurring_task_template_versions (
    id, organization_id, template_id, version_number, effective_from,
    title, description, schedule_kind, weekdays, start_date, end_date, due_time,
    reviewer_member_id, priority, requires_review, requires_result, requires_attachment,
    allow_no_incident, reminder_profile, estimated_minutes, checklist,
    created_by_member_id, change_reason
  ) values
    (
      '93100000-0000-0000-0000-000000000001', v_org,
      '93000000-0000-0000-0000-000000000001', 1, v_today,
      'Kiểm tra tồn kho đầu ngày', 'Đối chiếu tồn kho và ghi nhận chênh lệch cần xử lý.',
      'working_days', '{}'::smallint[], v_today, null, '09:30'::time,
      null, 'normal', false, true, false, true, '{}'::jsonb, 30, '[]'::jsonb,
      v_admin, null
    ),
    (
      '93100000-0000-0000-0000-000000000002', v_org,
      '93000000-0000-0000-0000-000000000002', 1, v_today,
      'Đối soát đơn TikTok cuối ngày', 'Rà soát đơn cuối ngày và ghi nhận các trường hợp cần xử lý tiếp.',
      'every_day', '{}'::smallint[], v_today, null, '17:30'::time,
      null, 'normal', false, true, false, true, '{}'::jsonb, 30, '[]'::jsonb,
      v_admin, null
    ),
    (
      '93100000-0000-0000-0000-000000000003', v_org,
      '93000000-0000-0000-0000-000000000003', 1, v_today,
      'Rà soát nội dung chương trình tuần', 'Rà lại nội dung chương trình theo lịch thứ 2, 4, 6.',
      'weekdays', array[1,3,5]::smallint[], v_today, null, '15:00'::time,
      null, 'normal', false, true, false, true, '{}'::jsonb, 45, '[]'::jsonb,
      v_admin, null
    )
  on conflict do nothing;

  insert into public.recurring_task_targets (
    id, organization_id, template_id, version_id, target_key,
    seller_id, assignment_mode, assignee_member_id
  ) values
    (
      '93200000-0000-0000-0000-000000000001', v_org,
      '93000000-0000-0000-0000-000000000001', '93100000-0000-0000-0000-000000000001',
      'primary', v_seller_shopee, 'fixed', v_employee_a
    ),
    (
      '93200000-0000-0000-0000-000000000002', v_org,
      '93000000-0000-0000-0000-000000000002', '93100000-0000-0000-0000-000000000002',
      'primary', v_seller_tiktok, 'fixed', v_employee_a
    ),
    (
      '93200000-0000-0000-0000-000000000003', v_org,
      '93000000-0000-0000-0000-000000000003', '93100000-0000-0000-0000-000000000003',
      'primary', v_seller_shopee, 'fixed', v_employee_b
    )
  on conflict do nothing;
end;
$$;
