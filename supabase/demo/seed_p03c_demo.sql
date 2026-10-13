-- OpsDesk P03C demo data for manual execution in Supabase SQL Editor.
--
-- This is intentionally NOT a migration and is not required by the frontend demo mode.
-- It never creates auth.users and contains no credentials. Run the normal schema migrations first,
-- then create/activate your real organization members and sellers before running this file.
--
-- Expected BOMAX records:
--   organization slug: bomax-digital
--   members: NV0001 (admin), NV0002 (manager), NV0003/NV0004 (employees)
--   sellers: BM-SHOPEE, BM-TIKTOK, BY-SUNI
--
-- The script is idempotent by deterministic UUIDs and uses a reserved task-number range.
-- Existing demo rows are left untouched (ON CONFLICT DO NOTHING) rather than overwritten.

do $$
declare
  v_org uuid;
  v_admin uuid;
  v_manager uuid;
  v_employee_a uuid;
  v_employee_b uuid;
  v_seller_a uuid;
  v_seller_b uuid;
  v_seller_c uuid;
  v_today date := (timezone('Asia/Ho_Chi_Minh', now()))::date;
  v_yesterday date := v_today - 1;
  v_tomorrow date := v_today + 1;
  v_in_two_days date := v_today + 2;
  v_submission_review uuid := '98000000-0000-0000-0000-000000000005';
  v_submission_done uuid := '98000000-0000-0000-0000-000000000006';
begin
  select id into v_org
  from public.organizations
  where slug = 'bomax-digital' and status = 'active'
  limit 1;

  if v_org is null then
    raise exception 'OPSDESK_DEMO_PREREQUISITE: active organization slug bomax-digital is missing';
  end if;

  select id into v_admin from public.organization_members
  where organization_id = v_org and employee_code = 'NV0001' and role = 'admin' and status = 'active' limit 1;
  select id into v_manager from public.organization_members
  where organization_id = v_org and employee_code = 'NV0002' and role in ('admin', 'manager') and status = 'active' limit 1;
  select id into v_employee_a from public.organization_members
  where organization_id = v_org and employee_code = 'NV0003' and status = 'active' limit 1;
  select id into v_employee_b from public.organization_members
  where organization_id = v_org and employee_code = 'NV0004' and status = 'active' limit 1;

  if v_admin is null or v_manager is null or v_employee_a is null or v_employee_b is null then
    raise exception 'OPSDESK_DEMO_PREREQUISITE: active members NV0001(admin), NV0002(manager), NV0003 and NV0004 are required';
  end if;

  select id into v_seller_a from public.sellers where organization_id = v_org and code = 'BM-SHOPEE' and archived_at is null limit 1;
  select id into v_seller_b from public.sellers where organization_id = v_org and code = 'BM-TIKTOK' and archived_at is null limit 1;
  select id into v_seller_c from public.sellers where organization_id = v_org and code = 'BY-SUNI' and archived_at is null limit 1;

  if v_seller_a is null or v_seller_b is null or v_seller_c is null then
    raise exception 'OPSDESK_DEMO_PREREQUISITE: active sellers BM-SHOPEE, BM-TIKTOK and BY-SUNI are required';
  end if;

  -- Reviewer/assignee scope is enforced by P03B triggers. Ensure the members used by
  -- seller tasks have active seller scope before inserting representative rows.
  if not exists (
    select 1 from public.seller_members sm
    where sm.organization_id = v_org and sm.seller_id = v_seller_b and sm.member_id = v_manager
      and sm.active_from <= v_today and (sm.active_until is null or sm.active_until >= v_today)
  ) then
    raise exception 'OPSDESK_DEMO_PREREQUISITE: NV0002 needs active BM-TIKTOK seller scope';
  end if;
  if not exists (
    select 1 from public.seller_members sm
    where sm.organization_id = v_org and sm.seller_id = v_seller_b and sm.member_id = v_employee_a
      and sm.active_from <= v_today and (sm.active_until is null or sm.active_until >= v_today)
  ) then
    raise exception 'OPSDESK_DEMO_PREREQUISITE: NV0003 needs active BM-TIKTOK seller scope';
  end if;

  -- 1. New/unacknowledged today.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000001', v_org, 990001, v_seller_a,
    'Kiểm tra tồn kho trước khung sale tối', 'Đối chiếu tồn thực tế và các SKU đang chạy quảng cáo.',
    v_manager, v_admin, 'high', 'todo', v_today,
    (v_today::text || ' 21:30:00+07')::timestamptz, (v_today::text || ' 21:30:00+07')::timestamptz,
    (v_today::text || ' 08:10:00+07')::timestamptz, (v_today::text || ' 08:00:00+07')::timestamptz,
    false, true, true, 45, 1
  ) on conflict do nothing;

  -- 2. In progress today with a collaborator.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from, acknowledged_at, started_at,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000002', v_org, 990002, v_seller_b,
    'Tối ưu ngân sách quảng cáo TikTok Shop', 'Rà lại nhóm ads có ROAS thấp và ghi nhận thay đổi ngân sách.',
    v_manager, v_admin, 'normal', 'in_progress', v_today,
    (v_today::text || ' 22:00:00+07')::timestamptz, (v_today::text || ' 22:00:00+07')::timestamptz,
    (v_today::text || ' 08:20:00+07')::timestamptz, (v_today::text || ' 08:00:00+07')::timestamptz,
    (v_today::text || ' 09:04:00+07')::timestamptz, (v_today::text || ' 09:06:00+07')::timestamptz,
    false, true, true, 45, 3
  ) on conflict do nothing;

  -- 3. Urgent overdue.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from, acknowledged_at, started_at,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000003', v_org, 990003, v_seller_a,
    'Xử lý đơn giao trễ còn tồn từ hôm qua', 'Chốt nguyên nhân và hướng xử lý cho từng đơn chưa bàn giao.',
    v_manager, v_admin, 'urgent', 'in_progress', v_yesterday,
    (v_yesterday::text || ' 17:30:00+07')::timestamptz, (v_yesterday::text || ' 17:30:00+07')::timestamptz,
    (v_yesterday::text || ' 09:00:00+07')::timestamptz, (v_yesterday::text || ' 09:00:00+07')::timestamptz,
    (v_yesterday::text || ' 10:10:00+07')::timestamptz, (v_yesterday::text || ' 10:12:00+07')::timestamptz,
    false, true, true, 45, 4
  ) on conflict do nothing;

  -- 4. Blocked work.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from, acknowledged_at, started_at,
    blocked_at, blocker_reason, blocker_owner_member_id,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000004', v_org, 990004, v_seller_c,
    'Đối soát voucher seller và voucher sàn', 'Đang chờ quyền truy cập báo cáo voucher để hoàn tất đối soát.',
    v_manager, v_admin, 'high', 'in_progress', v_today,
    (v_today::text || ' 20:30:00+07')::timestamptz, (v_today::text || ' 20:30:00+07')::timestamptz,
    (v_today::text || ' 08:30:00+07')::timestamptz, (v_today::text || ' 08:00:00+07')::timestamptz,
    (v_today::text || ' 08:40:00+07')::timestamptz, (v_today::text || ' 08:42:00+07')::timestamptz,
    (v_today::text || ' 14:25:00+07')::timestamptz, 'Chưa được cấp quyền tải báo cáo voucher của seller.', v_manager,
    false, true, true, 45, 5
  ) on conflict do nothing;

  -- 5. Submitted and awaiting manager review.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, reviewer_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from, acknowledged_at, started_at, submitted_at,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000005', v_org, 990005, v_seller_b,
    'Duyệt nội dung campaign cuối tuần', 'Kiểm tra caption, mã giảm giá và lịch phát hành trước khi lên lịch.',
    v_employee_a, v_manager, v_manager, 'high', 'in_review', v_today,
    (v_today::text || ' 21:00:00+07')::timestamptz, (v_today::text || ' 21:00:00+07')::timestamptz,
    (v_today::text || ' 08:00:00+07')::timestamptz, (v_today::text || ' 08:00:00+07')::timestamptz,
    (v_today::text || ' 09:15:00+07')::timestamptz, (v_today::text || ' 09:20:00+07')::timestamptz,
    (v_today::text || ' 10:05:00+07')::timestamptz,
    true, true, true, 45, 6
  ) on conflict do nothing;

  -- 6. Completed today.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from, acknowledged_at, started_at, submitted_at, completed_at,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000006', v_org, 990006, v_seller_a,
    'Cập nhật giá flash sale buổi sáng', 'Đã cập nhật và kiểm tra giá hiển thị sau khi đồng bộ.',
    v_manager, v_admin, 'normal', 'done', v_today,
    (v_today::text || ' 10:30:00+07')::timestamptz, (v_today::text || ' 10:30:00+07')::timestamptz,
    (v_today::text || ' 07:55:00+07')::timestamptz, (v_today::text || ' 07:50:00+07')::timestamptz,
    (v_today::text || ' 08:05:00+07')::timestamptz, (v_today::text || ' 08:07:00+07')::timestamptz,
    (v_today::text || ' 08:52:00+07')::timestamptz, (v_today::text || ' 09:45:00+07')::timestamptz,
    false, true, true, 45, 5
  ) on conflict do nothing;

  -- 7. Future task (should remain outside Today).
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000007', v_org, 990007, v_seller_c,
    'Chuẩn bị checklist campaign 10/10', 'Công việc tương lai để kiểm tra My Tasks và Today.',
    v_manager, v_admin, 'normal', 'todo', v_in_two_days,
    (v_in_two_days::text || ' 17:00:00+07')::timestamptz, (v_in_two_days::text || ' 17:00:00+07')::timestamptz,
    (v_today::text || ' 15:00:00+07')::timestamptz, (v_today::text || ' 15:00:00+07')::timestamptz,
    false, true, true, 45, 1
  ) on conflict do nothing;

  -- 8. Internal task without seller.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000008', v_org, 990008, null,
    'Chuẩn hóa template báo cáo cuối ngày', 'Công việc nội bộ, không gắn seller.',
    v_employee_b, v_manager, 'low', 'todo', v_tomorrow,
    (v_tomorrow::text || ' 16:30:00+07')::timestamptz, (v_tomorrow::text || ' 16:30:00+07')::timestamptz,
    (v_today::text || ' 13:00:00+07')::timestamptz, (v_today::text || ' 13:00:00+07')::timestamptz,
    false, true, true, 45, 1
  ) on conflict do nothing;

  -- 9. Collaborative work where the current manager is a participant.
  insert into public.tasks (
    id, organization_id, task_number, seller_id, title, description,
    assignee_member_id, created_by_member_id, priority, status, planned_date,
    original_due_at, due_at, assigned_at, visible_from, acknowledged_at, started_at,
    requires_review, requires_result, allow_no_incident, estimated_minutes, version
  ) values (
    '83000000-0000-0000-0000-000000000009', v_org, 990009, v_seller_a,
    'Rà nội dung FAQ cho CSKH', 'Người quản lý tham gia phối hợp nhưng không phải người thực hiện chính.',
    v_employee_a, v_admin, 'normal', 'in_progress', v_today,
    (v_today::text || ' 22:15:00+07')::timestamptz, (v_today::text || ' 22:15:00+07')::timestamptz,
    (v_today::text || ' 09:30:00+07')::timestamptz, (v_today::text || ' 09:30:00+07')::timestamptz,
    (v_today::text || ' 10:00:00+07')::timestamptz, (v_today::text || ' 10:05:00+07')::timestamptz,
    false, true, true, 45, 2
  ) on conflict do nothing;

  insert into public.task_participants (organization_id, task_id, member_id, participant_role)
  values
    (v_org, '83000000-0000-0000-0000-000000000002', v_employee_a, 'collaborator'),
    (v_org, '83000000-0000-0000-0000-000000000009', v_manager, 'collaborator')
  on conflict do nothing;

  -- Representative checklist data. Deterministic IDs make reruns safe.
  insert into public.task_checklist_items (
    id, organization_id, task_id, title, sort_order, is_required, checked_at, checked_by_member_id
  ) values
    ('99000000-0000-0001-0000-000000000001', v_org, '83000000-0000-0000-0000-000000000001', 'Kiểm tra dữ liệu đầu vào', 0, true, null, null),
    ('99000000-0000-0002-0000-000000000001', v_org, '83000000-0000-0000-0000-000000000001', 'Thực hiện và đối chiếu kết quả', 1, true, null, null),
    ('99000000-0000-0003-0000-000000000001', v_org, '83000000-0000-0000-0000-000000000001', 'Ghi chú kết quả cuối', 2, true, null, null),
    ('99000000-0000-0001-0000-000000000005', v_org, '83000000-0000-0000-0000-000000000005', 'Kiểm tra dữ liệu đầu vào', 0, true, (v_today::text || ' 09:20:00+07')::timestamptz, v_employee_a),
    ('99000000-0000-0002-0000-000000000005', v_org, '83000000-0000-0000-0000-000000000005', 'Thực hiện và đối chiếu kết quả', 1, true, (v_today::text || ' 09:45:00+07')::timestamptz, v_employee_a),
    ('99000000-0000-0003-0000-000000000005', v_org, '83000000-0000-0000-0000-000000000005', 'Ghi chú kết quả cuối', 2, true, (v_today::text || ' 10:00:00+07')::timestamptz, v_employee_a),
    ('99000000-0000-0001-0000-000000000006', v_org, '83000000-0000-0000-0000-000000000006', 'Kiểm tra dữ liệu đầu vào', 0, true, (v_today::text || ' 08:15:00+07')::timestamptz, v_manager),
    ('99000000-0000-0002-0000-000000000006', v_org, '83000000-0000-0000-0000-000000000006', 'Thực hiện và đối chiếu kết quả', 1, true, (v_today::text || ' 08:45:00+07')::timestamptz, v_manager)
  on conflict do nothing;

  insert into public.task_submissions (
    id, organization_id, task_id, revision, submitted_by_member_id, result_text,
    no_incident, evidence, review_state, reviewed_by_member_id, reviewed_at, submitted_at
  ) values
    (v_submission_review, v_org, '83000000-0000-0000-0000-000000000005', 1, v_employee_a,
     'Đã hoàn tất nội dung, chờ người duyệt xác nhận.', false, '[]'::jsonb, 'pending', null, null,
     (v_today::text || ' 10:05:00+07')::timestamptz),
    (v_submission_done, v_org, '83000000-0000-0000-0000-000000000006', 1, v_manager,
     'Đã hoàn tất và kiểm tra lại dữ liệu hiển thị.', false, '[]'::jsonb, 'approved', null,
     (v_today::text || ' 09:45:00+07')::timestamptz, (v_today::text || ' 08:52:00+07')::timestamptz)
  on conflict do nothing;

  -- Link submissions after they exist. Preserve task version because this is fixture setup,
  -- not a user lifecycle transition.
  update public.tasks set current_submission_id = v_submission_review
  where organization_id = v_org and id = '83000000-0000-0000-0000-000000000005'
    and current_submission_id is null;
  update public.tasks set current_submission_id = v_submission_done
  where organization_id = v_org and id = '83000000-0000-0000-0000-000000000006'
    and current_submission_id is null;

  -- A compact immutable event trail for detail-screen history.
  insert into public.task_events (
    id, organization_id, task_id, task_version, event_type, actor_member_id, event_payload, occurred_at
  ) values
    ('93000000-0000-0000-0000-000000000001', v_org, '83000000-0000-0000-0000-000000000001', 1, 'created', v_admin, '{}'::jsonb, (v_today::text || ' 08:10:00+07')::timestamptz),
    ('93000000-0000-0000-0000-000000000002', v_org, '83000000-0000-0000-0000-000000000002', 1, 'created', v_admin, '{}'::jsonb, (v_today::text || ' 08:20:00+07')::timestamptz),
    ('94000000-0000-0000-0000-000000000002', v_org, '83000000-0000-0000-0000-000000000002', 2, 'acknowledged', v_manager, '{}'::jsonb, (v_today::text || ' 09:04:00+07')::timestamptz),
    ('95000000-0000-0000-0000-000000000002', v_org, '83000000-0000-0000-0000-000000000002', 3, 'started', v_manager, '{}'::jsonb, (v_today::text || ' 09:06:00+07')::timestamptz),
    ('93000000-0000-0000-0000-000000000004', v_org, '83000000-0000-0000-0000-000000000004', 1, 'created', v_admin, '{}'::jsonb, (v_today::text || ' 08:30:00+07')::timestamptz),
    ('96000000-0000-0000-0000-000000000004', v_org, '83000000-0000-0000-0000-000000000004', 5, 'blocker_reported', v_manager, jsonb_build_object('reason', 'Chưa được cấp quyền tải báo cáo voucher của seller.'), (v_today::text || ' 14:25:00+07')::timestamptz),
    ('93000000-0000-0000-0000-000000000005', v_org, '83000000-0000-0000-0000-000000000005', 1, 'created', v_manager, '{}'::jsonb, (v_today::text || ' 08:00:00+07')::timestamptz),
    ('95000000-0000-0000-0000-000000000005', v_org, '83000000-0000-0000-0000-000000000005', 5, 'started', v_employee_a, '{}'::jsonb, (v_today::text || ' 09:20:00+07')::timestamptz),
    ('97000000-0000-0000-0000-000000000005', v_org, '83000000-0000-0000-0000-000000000005', 6, 'submitted', v_employee_a, jsonb_build_object('submission_id', v_submission_review), (v_today::text || ' 10:05:00+07')::timestamptz),
    ('93000000-0000-0000-0000-000000000006', v_org, '83000000-0000-0000-0000-000000000006', 1, 'created', v_admin, '{}'::jsonb, (v_today::text || ' 07:55:00+07')::timestamptz),
    ('97000000-0000-0000-0000-000000000006', v_org, '83000000-0000-0000-0000-000000000006', 5, 'completed', v_manager, '{}'::jsonb, (v_today::text || ' 09:45:00+07')::timestamptz)
  on conflict do nothing;

  -- Keep future RPC-generated task numbers out of the reserved demo range.
  insert into private.task_number_counters (organization_id, next_number)
  values (v_org, 990100)
  on conflict (organization_id) do update
    set next_number = greatest(private.task_number_counters.next_number, excluded.next_number);

  raise notice 'OpsDesk P03C demo seed ready for organization %, local date %', v_org, v_today;
end;
$$;
