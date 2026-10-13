-- Safe upgrade for an existing hosted OpsDesk project.
-- Run once in Supabase Dashboard > SQL Editor after the P01B schema exists.
-- Source: supabase/migrations/00000000000013_p11_context_contract.sql

create or replace function public.rpc_get_context(p_organization_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_organization_id uuid := p_organization_id;
  v_context jsonb;
begin
  if v_organization_id is null then
    select m.organization_id
      into v_organization_id
    from public.organization_members as m
    join public.organizations as o on o.id = m.organization_id
    where m.user_id = (select auth.uid())
      and m.status = 'active'
      and o.status = 'active'
    order by m.created_at, m.id
    limit 1;
  end if;

  if v_organization_id is null or private.current_member_id(v_organization_id) is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select jsonb_build_object(
    'organization_id', o.id,
    'organization_name', o.name,
    'organization_slug', o.slug,
    'timezone', o.timezone,
    'member_id', m.id,
    'user_id', m.user_id,
    'employee_code', m.employee_code,
    'display_name', m.display_name,
    'role', m.role,
    'status', m.status,
    'is_owner', coalesce(o.owner_member_id = m.id, false),
    'capabilities', (
      select coalesce(jsonb_agg(granted_capability order by granted_capability), '[]'::jsonb)
      from (
        select 'can_manage_attendance'::text as granted_capability
        where m.role = 'admin' or m.can_manage_attendance
        union all
        select 'can_approve_requests'::text
        where m.role = 'admin' or m.can_approve_requests
        union all
        select 'can_view_attendance_evidence'::text
        where m.role = 'admin' or m.can_view_attendance_evidence
      ) as capabilities_for_member
    ),
    'seller_scope', private.member_seller_scope(o.id, m.id),
    'scope_version', m.scope_version,
    'server_now', timezone('utc', now())
  )
    into v_context
  from public.organizations as o
  join public.organization_members as m
    on m.organization_id = o.id
   and m.id = private.current_member_id(v_organization_id)
  where o.id = v_organization_id
    and o.status = 'active';

  return v_context;
end;
$$;

revoke all on function public.rpc_get_context(uuid) from public, anon;
grant execute on function public.rpc_get_context(uuid) to authenticated;
