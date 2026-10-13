-- P03B reviewer policy hardening.
-- V1 reviewers are managers/admins, must be in seller scope when a seller is set,
-- and internal-task reviewer assignment remains admin-only.

create or replace function private.assert_task_reviewer_policy(
  p_organization_id uuid,
  p_seller_id uuid,
  p_reviewer_member_id uuid,
  p_assignee_member_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_reviewer_role text;
begin
  if p_reviewer_member_id is null then
    return;
  end if;

  if p_reviewer_member_id = p_assignee_member_id then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
  end if;

  perform private.assert_task_member_scope(
    p_organization_id,
    p_seller_id,
    p_reviewer_member_id
  );

  select m.role
    into v_reviewer_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = p_reviewer_member_id
    and m.status = 'active';

  if v_reviewer_role is null or v_reviewer_role not in ('admin', 'manager') then
    raise exception using errcode = '42501', message = 'TASK_REVIEWER_ROLE_DENIED';
  end if;
end;
$$;

create or replace function private.enforce_task_reviewer_policy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_role text;
begin
  if new.reviewer_member_id is null then
    return new;
  end if;

  perform private.assert_task_reviewer_policy(
    new.organization_id,
    new.seller_id,
    new.reviewer_member_id,
    new.assignee_member_id
  );

  if new.seller_id is null then
    if tg_op = 'INSERT' then
      select m.role
        into v_actor_role
      from public.organization_members as m
      where m.organization_id = new.organization_id
        and m.id = private.current_member_id(new.organization_id)
        and m.status = 'active';

      if v_actor_role is distinct from 'admin' then
        raise exception using errcode = '42501', message = 'INTERNAL_TASK_REVIEW_ASSIGNMENT_DENIED';
      end if;
    elsif old.reviewer_member_id is distinct from new.reviewer_member_id
       or old.seller_id is distinct from new.seller_id then
      select m.role
        into v_actor_role
      from public.organization_members as m
      where m.organization_id = new.organization_id
        and m.id = private.current_member_id(new.organization_id)
        and m.status = 'active';

      if v_actor_role is distinct from 'admin' then
        raise exception using errcode = '42501', message = 'INTERNAL_TASK_REVIEW_ASSIGNMENT_DENIED';
      end if;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists tasks_reviewer_policy_check on public.tasks;
create trigger tasks_reviewer_policy_check
before insert or update on public.tasks
for each row execute function private.enforce_task_reviewer_policy();

revoke all on function private.assert_task_reviewer_policy(uuid, uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.enforce_task_reviewer_policy()
  from public, anon, authenticated;
