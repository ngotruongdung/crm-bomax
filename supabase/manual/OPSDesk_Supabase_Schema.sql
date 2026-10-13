-- GENERATED FILE. DO NOT EDIT BY HAND.
-- Source: supabase/migrations/*.sql
-- Generate again with: pnpm build:supabase:dashboard-sql
--
-- Run once only in Supabase Dashboard > SQL Editor on a new, empty project.
-- Do not use this file for a project that already has any OPSDesk migration applied.

-- ============================================================================
-- BEGIN 00000000000000_p00_bootstrap.sql
-- ============================================================================

-- P00 deliberately creates no business tables.
-- P01A owns the first tenant/auth schema migration.
create extension if not exists pgcrypto;

-- ============================================================================
-- END 00000000000000_p00_bootstrap.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000001_p01a_core_schema.sql
-- ============================================================================

-- P01A: multi-tenant organization, membership and auth foundation.
-- Business feature tables are intentionally deferred to later phases.

create schema if not exists extensions;
create schema if not exists private;
create extension if not exists pgcrypto with schema extensions;

revoke all on schema private from public;
revoke all on schema private from anon;
grant usage on schema private to authenticated;
grant usage on schema private to service_role;

alter default privileges for role postgres in schema public
  revoke execute on functions from public;
alter default privileges for role postgres in schema private
  revoke execute on functions from public;

create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 120),
  slug text not null check (
    slug = lower(slug)
    and slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
    and char_length(slug) between 2 and 80
  ),
  timezone text not null default 'Asia/Ho_Chi_Minh',
  owner_member_id uuid,
  status text not null default 'active' check (status in ('active', 'suspended')),
  settings_version integer not null default 1 check (settings_version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (slug)
);

create table public.organization_members (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  employee_code text not null check (
    employee_code = upper(trim(employee_code))
    and char_length(employee_code) between 2 and 32
  ),
  display_name text not null check (char_length(trim(display_name)) between 1 and 160),
  role text not null default 'employee' check (role in ('admin', 'manager', 'employee')),
  status text not null default 'invited' check (status in ('invited', 'active', 'inactive')),
  can_manage_attendance boolean not null default false,
  can_approve_requests boolean not null default false,
  can_view_attendance_evidence boolean not null default false,
  scope_version integer not null default 1 check (scope_version > 0),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, user_id),
  unique (organization_id, employee_code)
);

alter table public.organizations
  add constraint organizations_owner_member_fk
  foreign key (id, owner_member_id)
  references public.organization_members(organization_id, id)
  on delete restrict;

create table public.member_hr_settings (
  member_id uuid primary key references public.organization_members(id) on delete restrict,
  organization_id uuid not null,
  employment_start date not null,
  employment_end date,
  standard_day_minutes integer not null default 480 check (standard_day_minutes between 1 and 1440),
  default_work_mode text not null default 'office' check (default_work_mode in ('office', 'remote', 'hybrid')),
  policy_version_id uuid,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  check (employment_end is null or employment_end >= employment_start),
  unique (organization_id, member_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.specialties (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null check (code = upper(trim(code)) and char_length(code) between 2 and 40),
  name text not null check (char_length(trim(name)) between 1 and 120),
  archived_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, code)
);

create table public.member_specialties (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  specialty_id uuid not null,
  primary key (organization_id, member_id, specialty_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, specialty_id)
    references public.specialties(organization_id, id)
    on delete restrict
);

create table public.invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  email text not null check (
    email = lower(trim(email))
    and char_length(email) between 3 and 320
    and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
  ),
  invited_role text not null check (invited_role in ('admin', 'manager', 'employee')),
  invited_by uuid not null,
  auth_invite_reference text,
  token_hash text,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz,
  capabilities jsonb not null default '{}'::jsonb check (jsonb_typeof(capabilities) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  foreign key (organization_id, invited_by)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create unique index invitations_one_open_per_email_idx
  on public.invitations(organization_id, email)
  where accepted_at is null and revoked_at is null;

create table public.policy_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  policy_kind text not null check (policy_kind in ('attendance', 'reminders', 'retention', 'report')),
  version_number integer not null check (version_number > 0),
  effective_from timestamptz not null,
  config jsonb not null check (jsonb_typeof(config) = 'object'),
  created_by uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, policy_kind, version_number),
  foreign key (organization_id, created_by)
    references public.organization_members(organization_id, id)
    on delete restrict
);

alter table public.member_hr_settings
  add constraint member_hr_settings_policy_version_fk
  foreign key (organization_id, policy_version_id)
  references public.policy_versions(organization_id, id)
  on delete restrict;

create table public.audit_logs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_member_id uuid,
  actor_kind text not null check (actor_kind in ('member', 'system')),
  action text not null check (char_length(trim(action)) between 1 and 120),
  entity_type text not null check (char_length(trim(entity_type)) between 1 and 120),
  entity_id uuid,
  recorded_at timestamptz not null default timezone('utc', now()),
  request_id uuid not null default extensions.gen_random_uuid(),
  safe_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(safe_metadata) = 'object'),
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((actor_kind = 'member' and actor_member_id is not null) or (actor_kind = 'system' and actor_member_id is null))
);

create table private.command_idempotency (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  actor_key text not null check (char_length(trim(actor_key)) between 1 and 160),
  command_name text not null check (char_length(trim(command_name)) between 1 and 120),
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 1 and 200),
  payload_hash text not null check (char_length(payload_hash) between 32 and 256),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (organization_id, actor_key, command_name, idempotency_key)
);

create index organization_members_user_idx
  on public.organization_members(user_id, status);
create index organization_members_active_idx
  on public.organization_members(organization_id, status, role);
create index member_specialties_member_idx
  on public.member_specialties(organization_id, member_id);
create index audit_logs_org_recorded_idx
  on public.audit_logs(organization_id, recorded_at desc, id desc);
create index private_command_idempotency_created_idx
  on private.command_idempotency(created_at desc);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

create trigger organizations_set_updated_at
before update on public.organizations
for each row execute function private.set_updated_at();
create trigger organization_members_set_updated_at
before update on public.organization_members
for each row execute function private.set_updated_at();
create trigger member_hr_settings_set_updated_at
before update on public.member_hr_settings
for each row execute function private.set_updated_at();
create trigger specialties_set_updated_at
before update on public.specialties
for each row execute function private.set_updated_at();
create trigger invitations_set_updated_at
before update on public.invitations
for each row execute function private.set_updated_at();

create or replace function private.prevent_immutable_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '42501',
    message = 'IMMUTABLE_RECORD';
end;
$$;

create or replace function private.assert_organization_owner()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.owner_member_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.organization_members as m
    where m.organization_id = new.id
      and m.id = new.owner_member_id
      and m.role = 'admin'
      and m.status = 'active'
  ) then
    raise exception using
      errcode = '23514',
      message = 'OWNER_MEMBER_MUST_BE_ACTIVE_ADMIN';
  end if;

  return new;
end;
$$;

create or replace function private.assert_membership_owner_eligibility()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.organizations as o
    where o.id = new.organization_id
      and o.owner_member_id = new.id
      and (new.role <> 'admin' or new.status <> 'active')
  ) then
    raise exception using
      errcode = '23514',
      message = 'OWNER_MEMBER_MUST_BE_ACTIVE_ADMIN';
  end if;

  return new;
end;
$$;

create trigger organizations_owner_eligibility
before insert or update of owner_member_id on public.organizations
for each row execute function private.assert_organization_owner();

create trigger organization_members_owner_eligibility
before insert or update of organization_id, role, status on public.organization_members
for each row execute function private.assert_membership_owner_eligibility();

create trigger audit_logs_immutable
before update or delete on public.audit_logs
for each row execute function private.prevent_immutable_mutation();
create trigger policy_versions_immutable
before update or delete on public.policy_versions
for each row execute function private.prevent_immutable_mutation();

create or replace function private.current_member_id(p_organization_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.organization_members as m
  join public.organizations as o
    on o.id = m.organization_id
  where m.organization_id = p_organization_id
    and m.user_id = (select auth.uid())
    and m.status = 'active'
    and o.status = 'active'
  limit 1;
$$;

create or replace function private.is_active_member(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.current_member_id(p_organization_id) is not null;
$$;

create or replace function private.is_admin(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    where m.id = private.current_member_id(p_organization_id)
      and m.role = 'admin'
      and m.status = 'active'
  );
$$;

create or replace function private.can_manage_attendance(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    where m.id = private.current_member_id(p_organization_id)
      and (m.role = 'admin' or m.can_manage_attendance)
  );
$$;

create or replace function private.write_audit(
  p_organization_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_safe_metadata jsonb default '{}'::jsonb,
  p_request_id uuid default extensions.gen_random_uuid()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_id uuid := extensions.gen_random_uuid();
begin
  insert into public.audit_logs (
    id,
    organization_id,
    actor_member_id,
    actor_kind,
    action,
    entity_type,
    entity_id,
    request_id,
    safe_metadata
  )
  values (
    v_id,
    p_organization_id,
    v_member_id,
    case when v_member_id is null then 'system' else 'member' end,
    p_action,
    p_entity_type,
    p_entity_id,
    p_request_id,
    coalesce(p_safe_metadata, '{}'::jsonb)
  );
  return v_id;
end;
$$;

create or replace function public.rpc_get_context(p_organization_id uuid default null)
returns jsonb
language plpgsql
stable
security invoker
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

revoke all on function private.current_member_id(uuid) from public, anon;
revoke all on function private.is_active_member(uuid) from public, anon;
revoke all on function private.is_admin(uuid) from public, anon;
revoke all on function private.can_manage_attendance(uuid) from public, anon;
revoke all on function private.write_audit(uuid, text, text, uuid, jsonb, uuid) from public, anon, authenticated;
grant execute on function private.current_member_id(uuid) to authenticated;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.is_admin(uuid) to authenticated;
grant execute on function private.can_manage_attendance(uuid) to authenticated;
grant execute on function private.write_audit(uuid, text, text, uuid, jsonb, uuid) to service_role;
revoke all on function public.rpc_get_context(uuid) from public, anon;
grant execute on function public.rpc_get_context(uuid) to authenticated;

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.member_hr_settings enable row level security;
alter table public.specialties enable row level security;
alter table public.member_specialties enable row level security;
alter table public.invitations enable row level security;
alter table public.policy_versions enable row level security;
alter table public.audit_logs enable row level security;
alter table private.command_idempotency enable row level security;

create policy organizations_read_active_member
on public.organizations for select to authenticated
using (private.is_active_member(id));

create policy organization_members_read_self_or_admin
on public.organization_members for select to authenticated
using (
  id = private.current_member_id(organization_id)
  or private.is_admin(organization_id)
);

create policy member_hr_settings_read_own_or_hr
on public.member_hr_settings for select to authenticated
using (
  member_id = private.current_member_id(organization_id)
  or private.is_admin(organization_id)
  or private.can_manage_attendance(organization_id)
);

create policy specialties_read_active_member
on public.specialties for select to authenticated
using (private.is_active_member(organization_id));

create policy member_specialties_read_active_member
on public.member_specialties for select to authenticated
using (private.is_active_member(organization_id));

create policy policy_versions_read_admin
on public.policy_versions for select to authenticated
using (private.is_admin(organization_id));

create policy audit_logs_read_admin
on public.audit_logs for select to authenticated
using (private.is_admin(organization_id));

revoke all on public.organizations from anon;
revoke all on public.organization_members from anon;
revoke all on public.member_hr_settings from anon;
revoke all on public.specialties from anon;
revoke all on public.member_specialties from anon;
revoke all on public.invitations from anon;
revoke all on public.policy_versions from anon;
revoke all on public.audit_logs from anon;
revoke all on private.command_idempotency from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.organizations, public.organization_members, public.member_hr_settings,
     public.specialties, public.member_specialties, public.invitations,
     public.policy_versions, public.audit_logs
  from authenticated;

grant select on public.organizations, public.organization_members,
  public.member_hr_settings, public.specialties, public.member_specialties,
  public.policy_versions, public.audit_logs to authenticated;

-- ============================================================================
-- END 00000000000001_p01a_core_schema.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000002_p01b_access_scope.sql
-- ============================================================================

-- P01B: invitation activation, role/capability commands and seller-scoped access.
-- All client mutations go through explicit commands; direct authenticated writes stay revoked.

create extension if not exists btree_gist with schema extensions;

alter table public.invitations
  add constraint invitations_organization_id_id_key unique (organization_id, id);

create table public.sellers (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null check (
    code = upper(trim(code))
    and char_length(code) between 2 and 40
  ),
  name text not null check (char_length(trim(name)) between 1 and 160),
  platform text not null check (platform in ('shopee', 'tiktok_shop', 'lazada', 'other')),
  brand_label text,
  shop_url text,
  archived_at timestamptz,
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, code),
  check (brand_label is null or char_length(trim(brand_label)) between 1 and 120),
  check (shop_url is null or char_length(trim(shop_url)) between 1 and 2000)
);

create table public.seller_members (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  seller_id uuid not null,
  member_id uuid not null,
  is_manager boolean not null default false,
  active_from date not null,
  active_until date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  check (active_until is null or active_until >= active_from),
  foreign key (organization_id, seller_id)
    references public.sellers(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

alter table public.seller_members
  add constraint seller_members_no_overlapping_scope
  exclude using gist (
    organization_id with =,
    seller_id with =,
    member_id with =,
    daterange(active_from, coalesce(active_until, 'infinity'::date), '[]') with &&
  );

create table public.invitation_seller_scopes (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  invitation_id uuid not null,
  seller_id uuid not null,
  is_manager boolean not null default false,
  primary key (organization_id, invitation_id, seller_id),
  foreign key (organization_id, invitation_id)
    references public.invitations(organization_id, id)
    on delete cascade,
  foreign key (organization_id, seller_id)
    references public.sellers(organization_id, id)
    on delete restrict
);

create index sellers_org_active_idx
  on public.sellers(organization_id, archived_at, code);
create index seller_members_member_scope_idx
  on public.seller_members(organization_id, member_id, active_from, active_until);
create index seller_members_seller_scope_idx
  on public.seller_members(organization_id, seller_id, is_manager, active_from, active_until);
create index invitation_seller_scopes_invitation_idx
  on public.invitation_seller_scopes(organization_id, invitation_id);
create index invitations_token_hash_open_idx
  on public.invitations(token_hash)
  where accepted_at is null and revoked_at is null and token_hash is not null;

create trigger sellers_set_updated_at
before update on public.sellers
for each row execute function private.set_updated_at();
create trigger seller_members_set_updated_at
before update on public.seller_members
for each row execute function private.set_updated_at();

create or replace function private.organization_local_date(p_organization_id uuid)
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (current_timestamp at time zone o.timezone)::date
  from public.organizations as o
  where o.id = p_organization_id
    and o.status = 'active';
$$;

create or replace function private.normalize_capabilities(
  p_role text,
  p_capabilities jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_capabilities jsonb := coalesce(p_capabilities, '{}'::jsonb);
begin
  if p_role not in ('admin', 'manager', 'employee') then
    raise exception using errcode = '22023', message = 'INVALID_ORGANIZATION_ROLE';
  end if;

  if jsonb_typeof(v_capabilities) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_CAPABILITIES';
  end if;

  if exists (
    select 1
    from jsonb_object_keys(v_capabilities) as key_name
    where key_name not in (
      'can_manage_attendance',
      'can_approve_requests',
      'can_view_attendance_evidence'
    )
  ) then
    raise exception using errcode = '22023', message = 'INVALID_CAPABILITY_KEY';
  end if;

  if exists (
    select 1
    from jsonb_each(v_capabilities) as entry
    where jsonb_typeof(entry.value) <> 'boolean'
  ) then
    raise exception using errcode = '22023', message = 'INVALID_CAPABILITY_VALUE';
  end if;

  return jsonb_build_object(
    'can_manage_attendance',
      case when p_role = 'admin' then true
           else coalesce((v_capabilities ->> 'can_manage_attendance')::boolean, false) end,
    'can_approve_requests',
      case when p_role = 'admin' then true
           else coalesce((v_capabilities ->> 'can_approve_requests')::boolean, false) end,
    'can_view_attendance_evidence',
      case when p_role = 'admin' then true
           else coalesce((v_capabilities ->> 'can_view_attendance_evidence')::boolean, false) end
  );
end;
$$;

create or replace function private.has_capability(
  p_organization_id uuid,
  p_capability text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    where m.id = private.current_member_id(p_organization_id)
      and m.status = 'active'
      and (
        m.role = 'admin'
        or (p_capability = 'can_manage_attendance' and m.can_manage_attendance)
        or (p_capability = 'can_approve_requests' and m.can_approve_requests)
        or (p_capability = 'can_view_attendance_evidence' and m.can_view_attendance_evidence)
      )
  );
$$;

create or replace function private.is_seller_member(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.seller_members as sm
    join public.organization_members as m
      on m.organization_id = sm.organization_id
     and m.id = sm.member_id
    where sm.organization_id = p_organization_id
      and sm.seller_id = p_seller_id
      and sm.member_id = coalesce(p_member_id, private.current_member_id(p_organization_id))
      and m.status = 'active'
      and sm.active_from <= private.organization_local_date(p_organization_id)
      and (
        sm.active_until is null
        or sm.active_until >= private.organization_local_date(p_organization_id)
      )
  );
$$;

create or replace function private.is_seller_manager(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.seller_members as sm
    join public.organization_members as m
      on m.organization_id = sm.organization_id
     and m.id = sm.member_id
    where sm.organization_id = p_organization_id
      and sm.seller_id = p_seller_id
      and sm.member_id = coalesce(p_member_id, private.current_member_id(p_organization_id))
      and m.status = 'active'
      and m.role in ('admin', 'manager')
      and sm.is_manager
      and sm.active_from <= private.organization_local_date(p_organization_id)
      and (
        sm.active_until is null
        or sm.active_until >= private.organization_local_date(p_organization_id)
      )
  );
$$;

create or replace function private.can_read_seller(
  p_organization_id uuid,
  p_seller_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin(p_organization_id)
    or private.is_seller_member(p_organization_id, p_seller_id);
$$;

-- This narrow wrapper is the only manager helper granted for use inside an RLS policy.
-- Keep the three-argument helper private so a client cannot probe another member's scope.
create or replace function private.current_actor_is_seller_manager(
  p_organization_id uuid,
  p_seller_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_seller_manager(p_organization_id, p_seller_id);
$$;

create or replace function private.member_seller_scope(
  p_organization_id uuid,
  p_member_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'seller_id', s.id,
        'code', s.code,
        'name', s.name,
        'platform', s.platform,
        'is_manager', sm.is_manager
      )
      order by s.name, s.id
    ),
    '[]'::jsonb
  )
  from public.seller_members as sm
  join public.sellers as s
    on s.organization_id = sm.organization_id
   and s.id = sm.seller_id
  where sm.organization_id = p_organization_id
    and sm.member_id = p_member_id
    and s.archived_at is null
    and sm.active_from <= private.organization_local_date(p_organization_id)
    and (
      sm.active_until is null
      or sm.active_until >= private.organization_local_date(p_organization_id)
    );
$$;

create or replace function private.assert_seller_scope_json(
  p_organization_id uuid,
  p_role text,
  p_scope jsonb
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope jsonb := coalesce(p_scope, '[]'::jsonb);
begin
  if jsonb_typeof(v_scope) <> 'array' then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_SCOPE';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_scope) as entry
    where jsonb_typeof(entry) <> 'object'
      or not (entry ? 'seller_id')
      or (entry ? 'is_manager' and jsonb_typeof(entry -> 'is_manager') <> 'boolean')
  ) then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_SCOPE_ENTRY';
  end if;

  if exists (
    select 1
    from (
      select (entry ->> 'seller_id')::uuid as seller_id, count(*) as item_count
      from jsonb_array_elements(v_scope) as entry
      group by (entry ->> 'seller_id')::uuid
    ) as duplicates
    where duplicates.item_count > 1
  ) then
    raise exception using errcode = '22023', message = 'DUPLICATE_SELLER_SCOPE';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(v_scope) as entry
    left join public.sellers as s
      on s.organization_id = p_organization_id
     and s.id = (entry ->> 'seller_id')::uuid
     and s.archived_at is null
    where s.id is null
  ) then
    raise exception using errcode = '22023', message = 'SELLER_SCOPE_OUTSIDE_ORGANIZATION';
  end if;

  if p_role = 'employee' and exists (
    select 1
    from jsonb_array_elements(v_scope) as entry
    where coalesce((entry ->> 'is_manager')::boolean, false)
  ) then
    raise exception using errcode = '22023', message = 'EMPLOYEE_CANNOT_MANAGE_SELLER';
  end if;
end;
$$;

create or replace function private.replace_member_seller_scope(
  p_organization_id uuid,
  p_member_id uuid,
  p_role text,
  p_scope jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope jsonb := coalesce(p_scope, '[]'::jsonb);
  v_today date := private.organization_local_date(p_organization_id);
  v_entry jsonb;
  v_seller_id uuid;
  v_is_manager boolean;
  v_existing public.seller_members%rowtype;
begin
  perform private.assert_seller_scope_json(p_organization_id, p_role, v_scope);

  delete from public.seller_members
  where organization_id = p_organization_id
    and member_id = p_member_id
    and active_from > v_today;

  for v_existing in
    select sm.*
    from public.seller_members as sm
    where sm.organization_id = p_organization_id
      and sm.member_id = p_member_id
      and sm.active_from <= v_today
      and (sm.active_until is null or sm.active_until >= v_today)
    for update
  loop
    if not exists (
      select 1
      from jsonb_array_elements(v_scope) as entry
      where (entry ->> 'seller_id')::uuid = v_existing.seller_id
        and coalesce((entry ->> 'is_manager')::boolean, false) = v_existing.is_manager
    ) then
      if v_existing.active_from = v_today then
        delete from public.seller_members where id = v_existing.id;
      else
        update public.seller_members
        set active_until = v_today - 1
        where id = v_existing.id;
      end if;
    end if;
  end loop;

  for v_entry in select value from jsonb_array_elements(v_scope)
  loop
    v_seller_id := (v_entry ->> 'seller_id')::uuid;
    v_is_manager := coalesce((v_entry ->> 'is_manager')::boolean, false);

    if not exists (
      select 1
      from public.seller_members as sm
      where sm.organization_id = p_organization_id
        and sm.seller_id = v_seller_id
        and sm.member_id = p_member_id
        and sm.is_manager = v_is_manager
        and sm.active_from <= v_today
        and (sm.active_until is null or sm.active_until >= v_today)
    ) then
      insert into public.seller_members (
        organization_id,
        seller_id,
        member_id,
        is_manager,
        active_from
      )
      values (
        p_organization_id,
        v_seller_id,
        p_member_id,
        v_is_manager,
        v_today
      );
    end if;
  end loop;
end;
$$;

create or replace function private.invitation_scope_json(
  p_organization_id uuid,
  p_invitation_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'seller_id', s.id,
        'code', s.code,
        'name', s.name,
        'platform', s.platform,
        'is_manager', iss.is_manager
      )
      order by s.name, s.id
    ),
    '[]'::jsonb
  )
  from public.invitation_seller_scopes as iss
  join public.sellers as s
    on s.organization_id = iss.organization_id
   and s.id = iss.seller_id
  where iss.organization_id = p_organization_id
    and iss.invitation_id = p_invitation_id;
$$;

create or replace function private.finalize_invited_membership(
  p_invitation_id uuid,
  p_user_id uuid,
  p_display_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invitation public.invitations%rowtype;
  v_user_email text;
  v_member public.organization_members%rowtype;
  v_capabilities jsonb;
  v_scope jsonb;
  v_employee_code text;
begin
  if char_length(trim(coalesce(p_display_name, ''))) not between 1 and 160 then
    raise exception using errcode = '22023', message = 'INVALID_DISPLAY_NAME';
  end if;

  select i.*
    into v_invitation
  from public.invitations as i
  where i.id = p_invitation_id
  for update;

  if v_invitation.id is null
     or v_invitation.revoked_at is not null
     or v_invitation.expires_at <= timezone('utc', now()) then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  if not exists (
    select 1
    from public.organizations as o
    where o.id = v_invitation.organization_id
      and o.status = 'active'
  ) then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  select lower(trim(u.email))
    into v_user_email
  from auth.users as u
  where u.id = p_user_id;

  if v_user_email is null or v_user_email <> v_invitation.email then
    raise exception using errcode = '42501', message = 'INVITE_EMAIL_MISMATCH';
  end if;

  select m.*
    into v_member
  from public.organization_members as m
  where m.organization_id = v_invitation.organization_id
    and m.user_id = p_user_id
  for update;

  if v_invitation.accepted_at is not null then
    if v_member.id is null or v_member.status <> 'active' then
      raise exception using errcode = '22023', message = 'INVITE_ALREADY_USED';
    end if;

    return jsonb_build_object(
      'member_id', v_member.id,
      'organization_id', v_member.organization_id,
      'role', v_member.role,
      'status', v_member.status,
      'already_accepted', true
    );
  end if;

  v_capabilities := private.normalize_capabilities(
    v_invitation.invited_role,
    v_invitation.capabilities
  );
  v_scope := private.invitation_scope_json(v_invitation.organization_id, v_invitation.id);

  if v_member.id is null then
    v_employee_code := 'EMP-' || upper(substr(replace(v_invitation.id::text, '-', ''), 1, 8));

    insert into public.organization_members (
      organization_id,
      user_id,
      employee_code,
      display_name,
      role,
      status,
      can_manage_attendance,
      can_approve_requests,
      can_view_attendance_evidence
    )
    values (
      v_invitation.organization_id,
      p_user_id,
      v_employee_code,
      trim(p_display_name),
      v_invitation.invited_role,
      'active',
      (v_capabilities ->> 'can_manage_attendance')::boolean,
      (v_capabilities ->> 'can_approve_requests')::boolean,
      (v_capabilities ->> 'can_view_attendance_evidence')::boolean
    )
    returning * into v_member;
  else
    update public.organization_members
    set display_name = trim(p_display_name),
        role = v_invitation.invited_role,
        status = 'active',
        can_manage_attendance = (v_capabilities ->> 'can_manage_attendance')::boolean,
        can_approve_requests = (v_capabilities ->> 'can_approve_requests')::boolean,
        can_view_attendance_evidence = (v_capabilities ->> 'can_view_attendance_evidence')::boolean,
        scope_version = scope_version + 1,
        version = version + 1
    where id = v_member.id
    returning * into v_member;
  end if;

  perform private.replace_member_seller_scope(
    v_invitation.organization_id,
    v_member.id,
    v_member.role,
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'seller_id', iss.seller_id,
            'is_manager', iss.is_manager
          )
          order by iss.seller_id
        ),
        '[]'::jsonb
      )
      from public.invitation_seller_scopes as iss
      where iss.organization_id = v_invitation.organization_id
        and iss.invitation_id = v_invitation.id
    )
  );

  update public.invitations
  set accepted_at = timezone('utc', now())
  where id = v_invitation.id;

  perform private.write_audit(
    v_invitation.organization_id,
    'membership.invite_accepted',
    'organization_member',
    v_member.id,
    jsonb_build_object('invitation_id', v_invitation.id)
  );

  return jsonb_build_object(
    'member_id', v_member.id,
    'organization_id', v_member.organization_id,
    'role', v_member.role,
    'status', v_member.status,
    'already_accepted', false
  );
end;
$$;

create or replace function public.rpc_create_invitation(
  p_organization_id uuid,
  p_email text,
  p_role text,
  p_capabilities jsonb,
  p_seller_scope jsonb,
  p_token_hash text,
  p_expires_at timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_member_id uuid := private.current_member_id(p_organization_id);
  v_email text := lower(trim(coalesce(p_email, '')));
  v_capabilities jsonb;
  v_invitation public.invitations%rowtype;
  v_scope_entry jsonb;
  v_reused boolean := false;
begin
  if v_actor_member_id is null or not private.is_admin(p_organization_id) then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;

  if char_length(v_email) not between 3 and 320
     or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception using errcode = '22023', message = 'INVALID_EMAIL';
  end if;

  if p_expires_at <= timezone('utc', now()) then
    raise exception using errcode = '22023', message = 'INVALID_INVITE_EXPIRY';
  end if;

  if p_token_hash is null
     or p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'INVALID_INVITE_TOKEN_HASH';
  end if;

  v_capabilities := private.normalize_capabilities(p_role, p_capabilities);
  perform private.assert_seller_scope_json(p_organization_id, p_role, p_seller_scope);

  if exists (
    select 1
    from public.organization_members as m
    join auth.users as u on u.id = m.user_id
    where m.organization_id = p_organization_id
      and m.status = 'active'
      and lower(trim(u.email)) = v_email
  ) then
    raise exception using errcode = '22023', message = 'MEMBER_ALREADY_ACTIVE';
  end if;

  if exists (
    select 1
    from auth.users as u
    where u.id = (select auth.uid())
      and lower(trim(u.email)) = v_email
  ) then
    raise exception using errcode = '22023', message = 'SELF_INVITE_NOT_ALLOWED';
  end if;

  perform pg_advisory_xact_lock(hashtext(p_organization_id::text || ':' || v_email));

  update public.invitations
  set revoked_at = timezone('utc', now())
  where organization_id = p_organization_id
    and email = v_email
    and accepted_at is null
    and revoked_at is null
    and expires_at <= timezone('utc', now());

  select i.*
    into v_invitation
  from public.invitations as i
  where i.organization_id = p_organization_id
    and i.email = v_email
    and i.accepted_at is null
    and i.revoked_at is null
  for update;

  if v_invitation.id is null then
    insert into public.invitations (
      organization_id,
      email,
      invited_role,
      invited_by,
      token_hash,
      expires_at,
      capabilities
    )
    values (
      p_organization_id,
      v_email,
      p_role,
      v_actor_member_id,
      p_token_hash,
      p_expires_at,
      v_capabilities
    )
    returning * into v_invitation;
  else
    v_reused := true;
    update public.invitations
    set invited_role = p_role,
        invited_by = v_actor_member_id,
        token_hash = p_token_hash,
        expires_at = p_expires_at,
        capabilities = v_capabilities,
        auth_invite_reference = null
    where id = v_invitation.id
    returning * into v_invitation;

    delete from public.invitation_seller_scopes
    where organization_id = p_organization_id
      and invitation_id = v_invitation.id;
  end if;

  for v_scope_entry in
    select value from jsonb_array_elements(coalesce(p_seller_scope, '[]'::jsonb))
  loop
    insert into public.invitation_seller_scopes (
      organization_id,
      invitation_id,
      seller_id,
      is_manager
    )
    values (
      p_organization_id,
      v_invitation.id,
      (v_scope_entry ->> 'seller_id')::uuid,
      coalesce((v_scope_entry ->> 'is_manager')::boolean, false)
    );
  end loop;

  perform private.write_audit(
    p_organization_id,
    case when v_reused then 'invitation.resent' else 'invitation.created' end,
    'invitation',
    v_invitation.id,
    jsonb_build_object('email', v_email, 'role', p_role)
  );

  return jsonb_build_object(
    'invitation_id', v_invitation.id,
    'organization_id', p_organization_id,
    'email', v_email,
    'role', p_role,
    'expires_at', v_invitation.expires_at,
    'reused', v_reused
  );
end;
$$;

create or replace function public.rpc_validate_invitation(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_token_hash text;
  v_invitation public.invitations%rowtype;
  v_user_id uuid := (select auth.uid());
  v_user_email text;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if char_length(coalesce(p_token, '')) < 32 then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  v_token_hash := encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex');

  select i.*
    into v_invitation
  from public.invitations as i
  where i.token_hash = v_token_hash
  limit 1;

  if v_invitation.id is null
     or v_invitation.revoked_at is not null
     or v_invitation.accepted_at is not null
     or v_invitation.expires_at <= timezone('utc', now()) then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  select lower(trim(u.email))
    into v_user_email
  from auth.users as u
  where u.id = v_user_id;

  if v_user_email is null or v_user_email <> v_invitation.email then
    raise exception using errcode = '42501', message = 'INVITE_EMAIL_MISMATCH';
  end if;

  select jsonb_build_object(
      'invitation_id', v_invitation.id,
      'organization_id', o.id,
      'organization_name', o.name,
      'organization_slug', o.slug,
      'email', v_invitation.email,
      'role', v_invitation.invited_role,
      'capabilities', v_invitation.capabilities,
      'seller_scope', private.invitation_scope_json(o.id, v_invitation.id),
      'expires_at', v_invitation.expires_at
    )
    from public.organizations as o
    where o.id = v_invitation.organization_id
      and o.status = 'active'
    into v_result;

  if v_result is null then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  return v_result;
end;
$$;

create or replace function public.rpc_accept_invitation(
  p_token text,
  p_display_name text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token_hash text;
  v_invitation_id uuid;
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  if char_length(coalesce(p_token, '')) < 32 then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  v_token_hash := encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex');

  select i.id
    into v_invitation_id
  from public.invitations as i
  where i.token_hash = v_token_hash
  limit 1;

  if v_invitation_id is null then
    raise exception using errcode = '22023', message = 'INVITE_INVALID_OR_EXPIRED';
  end if;

  return private.finalize_invited_membership(v_invitation_id, v_user_id, p_display_name);
end;
$$;

create or replace function public.rpc_internal_create_invited_membership(
  p_invitation_id uuid,
  p_user_id uuid,
  p_display_name text
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.finalize_invited_membership(p_invitation_id, p_user_id, p_display_name);
$$;

create or replace function public.rpc_internal_set_invitation_auth_reference(
  p_invitation_id uuid,
  p_auth_invite_reference text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.invitations
  set auth_invite_reference = nullif(trim(p_auth_invite_reference), '')
  where id = p_invitation_id
    and accepted_at is null
    and revoked_at is null;

  if not found then
    raise exception using errcode = '22023', message = 'INVITATION_NOT_OPEN';
  end if;
end;
$$;

create or replace function public.rpc_list_members_by_scope(p_organization_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_actor_role text;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.role into v_actor_role
  from public.organization_members as m
  where m.id = v_actor_id;

  return (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'member_id', m.id,
          'employee_code', m.employee_code,
          'display_name', m.display_name,
          'role', m.role,
          'status', m.status,
          'is_owner', o.owner_member_id = m.id,
          'capabilities', case
            when v_actor_role = 'admin' then jsonb_build_object(
              'can_manage_attendance', m.role = 'admin' or m.can_manage_attendance,
              'can_approve_requests', m.role = 'admin' or m.can_approve_requests,
              'can_view_attendance_evidence', m.role = 'admin' or m.can_view_attendance_evidence
            )
            else null
          end,
          'seller_scope', private.member_seller_scope(p_organization_id, m.id),
          'scope_version', m.scope_version,
          'version', m.version
        )
        order by m.display_name, m.id
      ),
      '[]'::jsonb
    )
    from public.organization_members as m
    join public.organizations as o on o.id = m.organization_id
    where m.organization_id = p_organization_id
      and (
        v_actor_role = 'admin'
        or m.id = v_actor_id
        or (
          v_actor_role = 'manager'
          and exists (
            select 1
            from public.seller_members as actor_scope
            join public.seller_members as target_scope
              on target_scope.organization_id = actor_scope.organization_id
             and target_scope.seller_id = actor_scope.seller_id
            where actor_scope.organization_id = p_organization_id
              and actor_scope.member_id = v_actor_id
              and actor_scope.is_manager
              and target_scope.member_id = m.id
              and actor_scope.active_from <= private.organization_local_date(p_organization_id)
              and (actor_scope.active_until is null or actor_scope.active_until >= private.organization_local_date(p_organization_id))
              and target_scope.active_from <= private.organization_local_date(p_organization_id)
              and (target_scope.active_until is null or target_scope.active_until >= private.organization_local_date(p_organization_id))
          )
        )
      )
  );
end;
$$;

create or replace function public.rpc_update_member_access(
  p_member_id uuid,
  p_role text,
  p_capabilities jsonb,
  p_scope jsonb,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.organization_members%rowtype;
  v_capabilities jsonb;
begin
  select m.*
    into v_target
  from public.organization_members as m
  where m.id = p_member_id
  for update;

  if v_target.id is null then
    raise exception using errcode = 'P0002', message = 'MEMBER_NOT_FOUND';
  end if;

  if not private.is_admin(v_target.organization_id) then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;

  if p_expected_version is null or p_expected_version <> v_target.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  v_capabilities := private.normalize_capabilities(p_role, p_capabilities);
  perform private.assert_seller_scope_json(v_target.organization_id, p_role, p_scope);

  update public.organization_members
  set role = p_role,
      can_manage_attendance = (v_capabilities ->> 'can_manage_attendance')::boolean,
      can_approve_requests = (v_capabilities ->> 'can_approve_requests')::boolean,
      can_view_attendance_evidence = (v_capabilities ->> 'can_view_attendance_evidence')::boolean,
      scope_version = scope_version + 1,
      version = version + 1
  where id = p_member_id
  returning * into v_target;

  perform private.replace_member_seller_scope(
    v_target.organization_id,
    v_target.id,
    v_target.role,
    coalesce(p_scope, '[]'::jsonb)
  );

  perform private.write_audit(
    v_target.organization_id,
    'membership.access_updated',
    'organization_member',
    v_target.id,
    jsonb_build_object(
      'role', v_target.role,
      'scope_version', v_target.scope_version,
      'version', v_target.version
    )
  );

  return jsonb_build_object(
    'member_id', v_target.id,
    'organization_id', v_target.organization_id,
    'role', v_target.role,
    'status', v_target.status,
    'capabilities', v_capabilities,
    'seller_scope', private.member_seller_scope(v_target.organization_id, v_target.id),
    'scope_version', v_target.scope_version,
    'version', v_target.version
  );
end;
$$;

create or replace function public.rpc_deactivate_member(
  p_member_id uuid,
  p_handover_plan jsonb,
  p_expected_version integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target public.organization_members%rowtype;
  v_today date;
begin
  select m.*
    into v_target
  from public.organization_members as m
  where m.id = p_member_id
  for update;

  if v_target.id is null then
    raise exception using errcode = 'P0002', message = 'MEMBER_NOT_FOUND';
  end if;

  if not private.is_admin(v_target.organization_id) then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;

  if p_expected_version is null or p_expected_version <> v_target.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  if jsonb_typeof(coalesce(p_handover_plan, '{}'::jsonb)) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_HANDOVER_PLAN';
  end if;

  v_today := private.organization_local_date(v_target.organization_id);

  update public.organization_members
  set status = 'inactive',
      scope_version = scope_version + 1,
      version = version + 1
  where id = v_target.id
  returning * into v_target;

  delete from public.seller_members
  where organization_id = v_target.organization_id
    and member_id = v_target.id
    and active_from > v_today;

  delete from public.seller_members
  where organization_id = v_target.organization_id
    and member_id = v_target.id
    and active_from = v_today;

  update public.seller_members
  set active_until = v_today - 1
  where organization_id = v_target.organization_id
    and member_id = v_target.id
    and active_from < v_today
    and (active_until is null or active_until >= v_today);

  perform private.write_audit(
    v_target.organization_id,
    'membership.deactivated',
    'organization_member',
    v_target.id,
    jsonb_build_object(
      'handover_plan', coalesce(p_handover_plan, '{}'::jsonb),
      'scope_version', v_target.scope_version
    )
  );

  return jsonb_build_object(
    'member_id', v_target.id,
    'organization_id', v_target.organization_id,
    'status', v_target.status,
    'scope_version', v_target.scope_version,
    'version', v_target.version
  );
end;
$$;

create or replace function public.rpc_create_or_update_seller(
  p_organization_id uuid,
  p_seller jsonb,
  p_expected_version integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_seller public.sellers%rowtype;
  v_is_admin boolean := private.is_admin(p_organization_id);
  v_code text := upper(trim(coalesce(p_seller ->> 'code', '')));
  v_name text := trim(coalesce(p_seller ->> 'name', ''));
  v_platform text := p_seller ->> 'platform';
  v_archived_at timestamptz;
begin
  if private.current_member_id(p_organization_id) is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  if jsonb_typeof(coalesce(p_seller, '{}'::jsonb)) <> 'object' then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_INPUT';
  end if;

  if p_seller ? 'id' and nullif(p_seller ->> 'id', '') is not null then
    v_id := (p_seller ->> 'id')::uuid;
  end if;

  if char_length(v_code) not between 2 and 40
     or char_length(v_name) not between 1 and 160
     or v_platform not in ('shopee', 'tiktok_shop', 'lazada', 'other') then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_INPUT';
  end if;

  if p_seller ? 'archived' and jsonb_typeof(p_seller -> 'archived') <> 'boolean' then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_INPUT';
  end if;

  if p_seller ? 'archived' then
    v_archived_at := case
      when (p_seller ->> 'archived')::boolean then timezone('utc', now())
      else null
    end;
  elsif p_seller ? 'archived_at' and nullif(p_seller ->> 'archived_at', '') is not null then
    v_archived_at := (p_seller ->> 'archived_at')::timestamptz;
  end if;

  if v_id is null then
    if not v_is_admin then
      raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
    end if;

    insert into public.sellers (
      organization_id,
      code,
      name,
      platform,
      brand_label,
      shop_url
    )
    values (
      p_organization_id,
      v_code,
      v_name,
      v_platform,
      nullif(trim(p_seller ->> 'brand_label'), ''),
      nullif(trim(p_seller ->> 'shop_url'), '')
    )
    returning * into v_seller;
  else
    select s.*
      into v_seller
    from public.sellers as s
    where s.organization_id = p_organization_id
      and s.id = v_id
    for update;

    if v_seller.id is null then
      raise exception using errcode = 'P0002', message = 'SELLER_NOT_FOUND';
    end if;

    if not v_is_admin and not private.is_seller_manager(p_organization_id, v_id) then
      raise exception using errcode = '42501', message = 'SELLER_MANAGER_REQUIRED';
    end if;

    if p_expected_version is null or p_expected_version <> v_seller.version then
      raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
    end if;

    if not v_is_admin and v_archived_at is distinct from v_seller.archived_at then
      raise exception using errcode = '42501', message = 'ADMIN_REQUIRED_TO_ARCHIVE_SELLER';
    end if;

    update public.sellers
    set code = v_code,
        name = v_name,
        platform = v_platform,
        brand_label = nullif(trim(p_seller ->> 'brand_label'), ''),
        shop_url = nullif(trim(p_seller ->> 'shop_url'), ''),
        archived_at = v_archived_at,
        version = version + 1
    where id = v_id
    returning * into v_seller;
  end if;

  perform private.write_audit(
    p_organization_id,
    case when v_id is null then 'seller.created' else 'seller.updated' end,
    'seller',
    v_seller.id,
    jsonb_build_object('code', v_seller.code, 'version', v_seller.version)
  );

  return to_jsonb(v_seller);
end;
$$;

create or replace function public.rpc_update_seller_members(
  p_seller_id uuid,
  p_members jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_seller public.sellers%rowtype;
  v_actor_id uuid;
  v_actor_is_admin boolean;
  v_today date;
  v_entry jsonb;
  v_member_id uuid;
  v_is_manager boolean;
  v_existing public.seller_members%rowtype;
  v_affected uuid[] := '{}'::uuid[];
begin
  select s.*
    into v_seller
  from public.sellers as s
  where s.id = p_seller_id
  for update;

  if v_seller.id is null then
    raise exception using errcode = 'P0002', message = 'SELLER_NOT_FOUND';
  end if;

  v_actor_id := private.current_member_id(v_seller.organization_id);
  v_actor_is_admin := private.is_admin(v_seller.organization_id);

  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  if not v_actor_is_admin
     and not private.is_seller_manager(v_seller.organization_id, v_seller.id, v_actor_id) then
    raise exception using errcode = '42501', message = 'SELLER_MANAGER_REQUIRED';
  end if;

  if jsonb_typeof(coalesce(p_members, '[]'::jsonb)) <> 'array' then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_MEMBERS';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as entry
    where jsonb_typeof(entry) <> 'object'
      or not (entry ? 'member_id')
      or (entry ? 'is_manager' and jsonb_typeof(entry -> 'is_manager') <> 'boolean')
  ) then
    raise exception using errcode = '22023', message = 'INVALID_SELLER_MEMBER_ENTRY';
  end if;

  if exists (
    select 1
    from (
      select (entry ->> 'member_id')::uuid as member_id, count(*) as item_count
      from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as entry
      group by (entry ->> 'member_id')::uuid
    ) as duplicates
    where duplicates.item_count > 1
  ) then
    raise exception using errcode = '22023', message = 'DUPLICATE_SELLER_MEMBER';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as entry
    left join public.organization_members as m
      on m.organization_id = v_seller.organization_id
     and m.id = (entry ->> 'member_id')::uuid
     and m.status = 'active'
    where m.id is null
  ) then
    raise exception using errcode = '22023', message = 'SELLER_MEMBER_OUTSIDE_ORGANIZATION';
  end if;

  if not v_actor_is_admin and exists (
    select 1
    from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as entry
    where coalesce((entry ->> 'is_manager')::boolean, false)
  ) then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED_FOR_MANAGER_SCOPE';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as entry
    join public.organization_members as m
      on m.organization_id = v_seller.organization_id
     and m.id = (entry ->> 'member_id')::uuid
    where coalesce((entry ->> 'is_manager')::boolean, false)
      and m.role = 'employee'
  ) then
    raise exception using errcode = '22023', message = 'EMPLOYEE_CANNOT_MANAGE_SELLER';
  end if;

  v_today := private.organization_local_date(v_seller.organization_id);

  select coalesce(array_agg(distinct sm.member_id), '{}'::uuid[])
    into v_affected
  from public.seller_members as sm
  where sm.organization_id = v_seller.organization_id
    and sm.seller_id = v_seller.id
    and sm.active_from <= v_today
    and (sm.active_until is null or sm.active_until >= v_today)
    and (v_actor_is_admin or not sm.is_manager);

  for v_existing in
    select sm.*
    from public.seller_members as sm
    where sm.organization_id = v_seller.organization_id
      and sm.seller_id = v_seller.id
      and sm.active_from <= v_today
      and (sm.active_until is null or sm.active_until >= v_today)
      and (v_actor_is_admin or not sm.is_manager)
    for update
  loop
    if not exists (
      select 1
      from jsonb_array_elements(coalesce(p_members, '[]'::jsonb)) as entry
      where (entry ->> 'member_id')::uuid = v_existing.member_id
        and coalesce((entry ->> 'is_manager')::boolean, false) = v_existing.is_manager
    ) then
      if v_existing.active_from = v_today then
        delete from public.seller_members where id = v_existing.id;
      else
        update public.seller_members
        set active_until = v_today - 1
        where id = v_existing.id;
      end if;
    end if;
  end loop;

  for v_entry in select value from jsonb_array_elements(coalesce(p_members, '[]'::jsonb))
  loop
    v_member_id := (v_entry ->> 'member_id')::uuid;
    v_is_manager := coalesce((v_entry ->> 'is_manager')::boolean, false);
    v_affected := array_append(v_affected, v_member_id);

    if not exists (
      select 1
      from public.seller_members as sm
      where sm.organization_id = v_seller.organization_id
        and sm.seller_id = v_seller.id
        and sm.member_id = v_member_id
        and sm.is_manager = v_is_manager
        and sm.active_from <= v_today
        and (sm.active_until is null or sm.active_until >= v_today)
    ) then
      insert into public.seller_members (
        organization_id,
        seller_id,
        member_id,
        is_manager,
        active_from
      )
      values (
        v_seller.organization_id,
        v_seller.id,
        v_member_id,
        v_is_manager,
        v_today
      );
    end if;
  end loop;

  update public.organization_members
  set scope_version = scope_version + 1,
      version = version + 1
  where organization_id = v_seller.organization_id
    and id = any(v_affected);

  perform private.write_audit(
    v_seller.organization_id,
    'seller.members_updated',
    'seller',
    v_seller.id,
    jsonb_build_object('member_count', jsonb_array_length(coalesce(p_members, '[]'::jsonb)))
  );

  return jsonb_build_object(
    'seller_id', v_seller.id,
    'members', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'member_id', sm.member_id,
            'is_manager', sm.is_manager
          )
          order by sm.is_manager desc, sm.member_id
        ),
        '[]'::jsonb
      )
      from public.seller_members as sm
      where sm.organization_id = v_seller.organization_id
        and sm.seller_id = v_seller.id
        and sm.active_from <= v_today
        and (sm.active_until is null or sm.active_until >= v_today)
    )
  );
end;
$$;

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
    'is_owner', o.owner_member_id = m.id,
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

revoke all on function private.organization_local_date(uuid) from public, anon;
revoke all on function private.normalize_capabilities(text, jsonb) from public, anon, authenticated;
revoke all on function private.has_capability(uuid, text) from public, anon;
revoke all on function private.is_seller_member(uuid, uuid, uuid) from public, anon;
revoke all on function private.is_seller_manager(uuid, uuid, uuid) from public, anon;
revoke all on function private.can_read_seller(uuid, uuid) from public, anon;
revoke all on function private.current_actor_is_seller_manager(uuid, uuid) from public, anon;
revoke all on function private.member_seller_scope(uuid, uuid) from public, anon, authenticated;
revoke all on function private.assert_seller_scope_json(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function private.replace_member_seller_scope(uuid, uuid, text, jsonb) from public, anon, authenticated;
revoke all on function private.invitation_scope_json(uuid, uuid) from public, anon, authenticated;
revoke all on function private.finalize_invited_membership(uuid, uuid, text) from public, anon, authenticated;

grant execute on function private.can_read_seller(uuid, uuid) to authenticated;
grant execute on function private.current_actor_is_seller_manager(uuid, uuid) to authenticated;

revoke all on function public.rpc_create_invitation(uuid, text, text, jsonb, jsonb, text, timestamptz) from public, anon;
revoke all on function public.rpc_validate_invitation(text) from public, anon;
revoke all on function public.rpc_accept_invitation(text, text) from public, anon;
revoke all on function public.rpc_list_members_by_scope(uuid) from public, anon;
revoke all on function public.rpc_update_member_access(uuid, text, jsonb, jsonb, integer) from public, anon;
revoke all on function public.rpc_deactivate_member(uuid, jsonb, integer) from public, anon;
revoke all on function public.rpc_create_or_update_seller(uuid, jsonb, integer) from public, anon;
revoke all on function public.rpc_update_seller_members(uuid, jsonb) from public, anon;
revoke all on function public.rpc_internal_create_invited_membership(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_internal_set_invitation_auth_reference(uuid, text) from public, anon, authenticated;

grant execute on function public.rpc_create_invitation(uuid, text, text, jsonb, jsonb, text, timestamptz) to authenticated;
grant execute on function public.rpc_validate_invitation(text) to authenticated;
grant execute on function public.rpc_accept_invitation(text, text) to authenticated;
grant execute on function public.rpc_list_members_by_scope(uuid) to authenticated;
grant execute on function public.rpc_update_member_access(uuid, text, jsonb, jsonb, integer) to authenticated;
grant execute on function public.rpc_deactivate_member(uuid, jsonb, integer) to authenticated;
grant execute on function public.rpc_create_or_update_seller(uuid, jsonb, integer) to authenticated;
grant execute on function public.rpc_update_seller_members(uuid, jsonb) to authenticated;
grant execute on function public.rpc_internal_create_invited_membership(uuid, uuid, text) to service_role;
grant execute on function public.rpc_internal_set_invitation_auth_reference(uuid, text) to service_role;

revoke all on function public.rpc_get_context(uuid) from public, anon;
grant execute on function public.rpc_get_context(uuid) to authenticated;

alter table public.sellers enable row level security;
alter table public.seller_members enable row level security;
alter table public.invitation_seller_scopes enable row level security;

create policy sellers_read_by_scope
on public.sellers for select to authenticated
using (private.can_read_seller(organization_id, id));

create policy seller_members_read_by_scope
on public.seller_members for select to authenticated
using (
  private.is_admin(organization_id)
  or member_id = private.current_member_id(organization_id)
  or private.current_actor_is_seller_manager(organization_id, seller_id)
);

revoke all on public.sellers from anon;
revoke all on public.seller_members from anon;
revoke all on public.invitation_seller_scopes from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.sellers, public.seller_members
  from authenticated;

grant select on public.sellers, public.seller_members to authenticated;

-- ============================================================================
-- END 00000000000002_p01b_access_scope.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000003_p03b_task_core.sql
-- ============================================================================

-- P03B: task core, transactional state machine and read projections.
-- Recurrence/templates/daily generation are intentionally deferred to P04.

create table private.outbox_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  event_type text not null check (char_length(trim(event_type)) between 1 and 120),
  entity_type text not null check (char_length(trim(entity_type)) between 1 and 120),
  entity_id uuid not null,
  dedupe_key text not null check (char_length(trim(dedupe_key)) between 1 and 240),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  status text not null default 'pending' check (status in ('pending', 'published', 'failed')),
  available_at timestamptz not null default timezone('utc', now()),
  attempts integer not null default 0 check (attempts >= 0),
  published_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, dedupe_key)
);

create table private.task_number_counters (
  organization_id uuid primary key references public.organizations(id) on delete restrict,
  next_number bigint not null default 1 check (next_number > 0)
);

create table public.tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_number bigint not null check (task_number > 0),
  batch_id uuid,
  seller_id uuid,
  template_occurrence_id uuid,
  title text not null check (char_length(trim(title)) between 1 and 240),
  description text not null default '',
  assignee_member_id uuid not null,
  created_by_member_id uuid not null,
  reviewer_member_id uuid,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'in_review', 'done', 'canceled', 'waived')),
  planned_date date not null,
  original_due_at timestamptz not null,
  due_at timestamptz not null,
  assigned_at timestamptz not null default timezone('utc', now()),
  visible_from timestamptz not null default timezone('utc', now()),
  acknowledged_at timestamptz,
  started_at timestamptz,
  submitted_at timestamptz,
  completed_at timestamptz,
  requires_review boolean not null default false,
  requires_result boolean not null default false,
  requires_attachment boolean not null default false,
  allow_no_incident boolean not null default false,
  reminder_profile jsonb not null default '{}'::jsonb check (jsonb_typeof(reminder_profile) = 'object'),
  reminder_profile_reason text,
  reminder_profile_review_at timestamptz,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  blocked_at timestamptz,
  blocker_reason text,
  blocker_owner_member_id uuid,
  last_meaningful_update_at timestamptz not null default timezone('utc', now()),
  current_submission_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, task_number),
  foreign key (organization_id, seller_id)
    references public.sellers(organization_id, id)
    on delete restrict,
  foreign key (organization_id, assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, reviewer_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, blocker_owner_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (reviewer_member_id is null or reviewer_member_id <> assignee_member_id),
  check (not requires_review or reviewer_member_id is not null),
  check ((status = 'done' and completed_at is not null) or status <> 'done'),
  check (
    (blocked_at is null and blocker_reason is null and blocker_owner_member_id is null)
    or (blocked_at is not null and nullif(trim(blocker_reason), '') is not null and blocker_owner_member_id is not null)
  )
);

create table public.task_participants (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  member_id uuid not null,
  participant_role text not null default 'collaborator' check (participant_role in ('collaborator', 'observer')),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (organization_id, task_id, member_id),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.task_checklist_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  title text not null check (char_length(trim(title)) between 1 and 240),
  sort_order integer not null default 0 check (sort_order >= 0),
  is_required boolean not null default true,
  checked_at timestamptz,
  checked_by_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, checked_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((checked_at is null and checked_by_member_id is null) or (checked_at is not null and checked_by_member_id is not null))
);

create table public.task_submissions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  revision integer not null check (revision > 0),
  submitted_by_member_id uuid not null,
  result_text text,
  no_incident boolean not null default false,
  evidence jsonb not null default '[]'::jsonb check (jsonb_typeof(evidence) in ('array', 'object')),
  review_state text not null default 'pending' check (review_state in ('pending', 'approved', 'changes_requested', 'withdrawn')),
  reviewed_by_member_id uuid,
  reviewed_at timestamptz,
  review_reason text,
  revision_due_at timestamptz,
  submitted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (task_id, revision),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, submitted_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, reviewed_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

alter table public.tasks
  add constraint tasks_current_submission_fk
  foreign key (organization_id, current_submission_id)
  references public.task_submissions(organization_id, id)
  on delete restrict;

create table public.task_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  task_version integer not null check (task_version > 0),
  event_type text not null check (char_length(trim(event_type)) between 1 and 120),
  actor_member_id uuid,
  event_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(event_payload) = 'object'),
  occurred_at timestamptz not null default timezone('utc', now()),
  unique (task_id, task_version),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create index tasks_org_status_planned_idx
  on public.tasks(organization_id, status, planned_date, due_at, id);
create index tasks_assignee_status_idx
  on public.tasks(organization_id, assignee_member_id, status, due_at);
create index tasks_reviewer_status_idx
  on public.tasks(organization_id, reviewer_member_id, status, due_at)
  where reviewer_member_id is not null;
create index tasks_seller_status_idx
  on public.tasks(organization_id, seller_id, status, due_at)
  where seller_id is not null;
create index task_checklist_task_idx
  on public.task_checklist_items(organization_id, task_id, sort_order, id);
create index task_submissions_task_idx
  on public.task_submissions(organization_id, task_id, revision desc);
create index task_events_task_idx
  on public.task_events(organization_id, task_id, task_version desc);
create index private_outbox_pending_idx
  on private.outbox_events(status, available_at, created_at)
  where status in ('pending', 'failed');

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function private.set_updated_at();

create or replace function private.current_actor_can_read_task(
  p_organization_id uuid,
  p_task_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tasks as t
    join public.organization_members as actor
      on actor.organization_id = t.organization_id
     and actor.id = private.current_member_id(t.organization_id)
     and actor.status = 'active'
    where t.organization_id = p_organization_id
      and t.id = p_task_id
      and (
        actor.role = 'admin'
        or t.assignee_member_id = actor.id
        or t.reviewer_member_id = actor.id
        or exists (
          select 1
          from public.task_participants as tp
          where tp.organization_id = t.organization_id
            and tp.task_id = t.id
            and tp.member_id = actor.id
        )
        or (
          actor.role = 'manager'
          and t.seller_id is not null
          and private.is_seller_manager(t.organization_id, t.seller_id, actor.id)
        )
      )
  );
$$;

create or replace function private.current_actor_can_manage_task(
  p_organization_id uuid,
  p_task_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tasks as t
    join public.organization_members as actor
      on actor.organization_id = t.organization_id
     and actor.id = private.current_member_id(t.organization_id)
     and actor.status = 'active'
    where t.organization_id = p_organization_id
      and t.id = p_task_id
      and (
        actor.role = 'admin'
        or (
          actor.role = 'manager'
          and (
            (t.seller_id is not null and private.is_seller_manager(t.organization_id, t.seller_id, actor.id))
            or (t.seller_id is null and t.assignee_member_id = actor.id)
          )
        )
      )
  );
$$;

create or replace function private.assert_task_member_scope(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.organization_members as m
    where m.organization_id = p_organization_id
      and m.id = p_member_id
      and m.status = 'active'
  ) then
    raise exception using errcode = '22023', message = 'TASK_MEMBER_NOT_ACTIVE';
  end if;

  if p_seller_id is not null
     and not private.is_seller_member(p_organization_id, p_seller_id, p_member_id) then
    raise exception using errcode = '42501', message = 'TASK_MEMBER_OUTSIDE_SELLER_SCOPE';
  end if;
end;
$$;

create or replace function private.task_idempotency_replay(
  p_organization_id uuid,
  p_actor_member_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_key text := p_actor_member_id::text;
  v_payload_hash text;
  v_existing private.command_idempotency%rowtype;
begin
  if nullif(trim(p_idempotency_key), '') is null then
    raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REQUIRED';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_organization_id::text || ':' || v_actor_key || ':' || p_command_name || ':' || p_idempotency_key,
      0
    )
  );

  v_payload_hash := pg_catalog.encode(
    extensions.digest(coalesce(p_payload, '{}'::jsonb)::text, 'sha256'),
    'hex'
  );

  select ci.*
    into v_existing
  from private.command_idempotency as ci
  where ci.organization_id = p_organization_id
    and ci.actor_key = v_actor_key
    and ci.command_name = p_command_name
    and ci.idempotency_key = p_idempotency_key;

  if v_existing.organization_id is not null then
    if v_existing.payload_hash <> v_payload_hash then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_existing.result;
  end if;

  return null;
end;
$$;

create or replace function private.task_idempotency_store(
  p_organization_id uuid,
  p_actor_member_id uuid,
  p_command_name text,
  p_idempotency_key text,
  p_payload jsonb,
  p_result jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.command_idempotency (
    organization_id,
    actor_key,
    command_name,
    idempotency_key,
    payload_hash,
    result
  )
  values (
    p_organization_id,
    p_actor_member_id::text,
    p_command_name,
    p_idempotency_key,
    pg_catalog.encode(extensions.digest(coalesce(p_payload, '{}'::jsonb)::text, 'sha256'), 'hex'),
    p_result
  );
end;
$$;

create or replace function public.rpc_create_task(
  p_organization_id uuid,
  p_task jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_actor public.organization_members%rowtype;
  v_assignee_id uuid := nullif(p_task ->> 'assignee_member_id', '')::uuid;
  v_reviewer_id uuid := nullif(p_task ->> 'reviewer_member_id', '')::uuid;
  v_seller_id uuid := nullif(p_task ->> 'seller_id', '')::uuid;
  v_task_id uuid := extensions.gen_random_uuid();
  v_task_number bigint;
  v_task public.tasks%rowtype;
  v_replay jsonb;
  v_result jsonb;
  v_checklist jsonb := coalesce(p_task -> 'checklist', '[]'::jsonb);
  v_participants jsonb := coalesce(p_task -> 'participant_member_ids', '[]'::jsonb);
  v_item jsonb;
  v_member_text text;
  v_request_id uuid := extensions.gen_random_uuid();
  v_requires_review boolean := coalesce((p_task ->> 'requires_review')::boolean, false);
  v_priority text := coalesce(nullif(p_task ->> 'priority', ''), 'normal');
  v_planned_date date := nullif(p_task ->> 'planned_date', '')::date;
  v_due_at timestamptz := nullif(p_task ->> 'due_at', '')::timestamptz;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = p_organization_id and m.id = v_actor_id;

  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'task.create',
    p_idempotency_key,
    p_task
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if nullif(trim(p_task ->> 'title'), '') is null
     or v_assignee_id is null
     or v_planned_date is null
     or v_due_at is null then
    raise exception using errcode = '22023', message = 'TASK_REQUIRED_FIELDS_MISSING';
  end if;

  if v_priority not in ('low', 'normal', 'high', 'urgent') then
    raise exception using errcode = '22023', message = 'TASK_PRIORITY_INVALID';
  end if;

  if v_requires_review and v_reviewer_id is null then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_REQUIRED';
  end if;

  if v_reviewer_id is not null and v_reviewer_id = v_assignee_id then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
  end if;

  perform private.assert_task_member_scope(p_organization_id, v_seller_id, v_assignee_id);
  if v_reviewer_id is not null then
    perform private.assert_task_member_scope(p_organization_id, v_seller_id, v_reviewer_id);
  end if;

  if v_assignee_id <> v_actor_id then
    if v_actor.role = 'admin' then
      null;
    elsif v_actor.role = 'manager'
      and v_seller_id is not null
      and private.is_seller_manager(p_organization_id, v_seller_id, v_actor_id) then
      null;
    else
      raise exception using errcode = '42501', message = 'TASK_ASSIGNMENT_SCOPE_DENIED';
    end if;
  elsif v_seller_id is not null
    and v_actor.role = 'manager'
    and not private.is_seller_manager(p_organization_id, v_seller_id, v_actor_id) then
    -- Managers may self-create only inside a seller they manage. Employees may self-create in membership scope.
    raise exception using errcode = '42501', message = 'TASK_ASSIGNMENT_SCOPE_DENIED';
  end if;

  if v_seller_id is null and v_actor.role <> 'admin' and v_reviewer_id is not null then
    raise exception using errcode = '42501', message = 'INTERNAL_TASK_REVIEW_ASSIGNMENT_DENIED';
  end if;

  if jsonb_typeof(v_checklist) <> 'array' or jsonb_typeof(v_participants) <> 'array' then
    raise exception using errcode = '22023', message = 'TASK_ARRAY_FIELD_INVALID';
  end if;

  insert into private.task_number_counters (organization_id, next_number)
  values (p_organization_id, 2)
  on conflict (organization_id) do update
    set next_number = private.task_number_counters.next_number + 1
  returning next_number - 1 into v_task_number;

  insert into public.tasks (
    id,
    organization_id,
    task_number,
    seller_id,
    title,
    description,
    assignee_member_id,
    created_by_member_id,
    reviewer_member_id,
    priority,
    planned_date,
    original_due_at,
    due_at,
    visible_from,
    requires_review,
    requires_result,
    requires_attachment,
    allow_no_incident,
    reminder_profile,
    estimated_minutes
  )
  values (
    v_task_id,
    p_organization_id,
    v_task_number,
    v_seller_id,
    trim(p_task ->> 'title'),
    coalesce(p_task ->> 'description', ''),
    v_assignee_id,
    v_actor_id,
    v_reviewer_id,
    v_priority,
    v_planned_date,
    v_due_at,
    v_due_at,
    coalesce(nullif(p_task ->> 'visible_from', '')::timestamptz, timezone('utc', now())),
    v_requires_review,
    coalesce((p_task ->> 'requires_result')::boolean, false),
    coalesce((p_task ->> 'requires_attachment')::boolean, false),
    coalesce((p_task ->> 'allow_no_incident')::boolean, false),
    case
      when jsonb_typeof(coalesce(p_task -> 'reminder_profile', '{}'::jsonb)) = 'object'
        then coalesce(p_task -> 'reminder_profile', '{}'::jsonb)
      else '{}'::jsonb
    end,
    nullif(p_task ->> 'estimated_minutes', '')::integer
  )
  returning * into v_task;

  for v_item in select value from jsonb_array_elements(v_checklist)
  loop
    if nullif(trim(v_item ->> 'title'), '') is null then
      raise exception using errcode = '22023', message = 'TASK_CHECKLIST_TITLE_REQUIRED';
    end if;

    insert into public.task_checklist_items (
      organization_id,
      task_id,
      title,
      sort_order,
      is_required
    )
    values (
      p_organization_id,
      v_task_id,
      trim(v_item ->> 'title'),
      coalesce((v_item ->> 'sort_order')::integer, 0),
      coalesce((v_item ->> 'is_required')::boolean, true)
    );
  end loop;

  for v_member_text in select value #>> '{}' from jsonb_array_elements(v_participants)
  loop
    if v_member_text::uuid = v_assignee_id or v_member_text::uuid = v_reviewer_id then
      continue;
    end if;
    perform private.assert_task_member_scope(p_organization_id, v_seller_id, v_member_text::uuid);
    insert into public.task_participants (organization_id, task_id, member_id)
    values (p_organization_id, v_task_id, v_member_text::uuid)
    on conflict do nothing;
  end loop;

  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload
  )
  values (
    p_organization_id,
    v_task_id,
    1,
    'created',
    v_actor_id,
    jsonb_build_object(
      'assignee_member_id', v_assignee_id,
      'reviewer_member_id', v_reviewer_id,
      'seller_id', v_seller_id,
      'due_at', v_due_at,
      'planned_date', v_planned_date
    )
  );

  perform private.write_audit(
    p_organization_id,
    'task.created',
    'task',
    v_task_id,
    jsonb_build_object('task_number', v_task_number, 'seller_id', v_seller_id),
    v_request_id
  );

  insert into private.outbox_events (
    organization_id,
    event_type,
    entity_type,
    entity_id,
    dedupe_key,
    payload
  )
  values (
    p_organization_id,
    'task.assigned',
    'task',
    v_task_id,
    'task:' || v_task_id::text || ':assigned:1',
    jsonb_build_object('task_id', v_task_id, 'assignee_member_id', v_assignee_id, 'task_version', 1)
  );

  v_result := jsonb_build_object(
    'task_id', v_task_id,
    'task_number', v_task_number,
    'status', v_task.status,
    'version', v_task.version
  );

  perform private.task_idempotency_store(
    p_organization_id,
    v_actor_id,
    'task.create',
    p_idempotency_key,
    p_task,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_task_command(
  p_task_id uuid,
  p_action text,
  p_payload jsonb,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_actor_id uuid;
  v_actor public.organization_members%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_command_name text := 'task.' || trim(coalesce(p_action, ''));
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
  v_replay jsonb;
  v_result jsonb;
  v_event_type text;
  v_event_payload jsonb := '{}'::jsonb;
  v_outbox_type text;
  v_outbox_payload jsonb;
  v_status text;
  v_assignee_id uuid;
  v_acknowledged_at timestamptz;
  v_started_at timestamptz;
  v_submitted_at timestamptz;
  v_completed_at timestamptz;
  v_due_at timestamptz;
  v_blocked_at timestamptz;
  v_blocker_reason text;
  v_blocker_owner_id uuid;
  v_current_submission_id uuid;
  v_submission_id uuid;
  v_revision integer;
  v_item_id uuid;
  v_target_member_id uuid;
  v_reason text;
  v_missing_items jsonb;
  v_request_id uuid := extensions.gen_random_uuid();
begin
  select t.* into v_task
  from public.tasks as t
  where t.id = p_task_id
  for update;

  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;

  v_actor_id := private.current_member_id(v_task.organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = v_task.organization_id and m.id = v_actor_id;

  v_replay := private.task_idempotency_replay(
    v_task.organization_id,
    v_actor_id,
    v_command_name,
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'payload', v_payload)
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if p_expected_version is null or p_expected_version <> v_task.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  if not private.current_actor_can_read_task(v_task.organization_id, v_task.id) then
    raise exception using errcode = '42501', message = 'TASK_ACCESS_DENIED';
  end if;

  v_status := v_task.status;
  v_assignee_id := v_task.assignee_member_id;
  v_acknowledged_at := v_task.acknowledged_at;
  v_started_at := v_task.started_at;
  v_submitted_at := v_task.submitted_at;
  v_completed_at := v_task.completed_at;
  v_due_at := v_task.due_at;
  v_blocked_at := v_task.blocked_at;
  v_blocker_reason := v_task.blocker_reason;
  v_blocker_owner_id := v_task.blocker_owner_member_id;
  v_current_submission_id := v_task.current_submission_id;

  if p_action = 'ack' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status <> 'todo' then
      raise exception using errcode = '42501', message = 'TASK_ACK_NOT_ALLOWED';
    end if;
    if v_acknowledged_at is null then
      v_acknowledged_at := v_now;
    end if;
    v_event_type := 'acknowledged';

  elsif p_action = 'start' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status <> 'todo' then
      raise exception using errcode = '42501', message = 'TASK_START_NOT_ALLOWED';
    end if;
    v_acknowledged_at := coalesce(v_acknowledged_at, v_now);
    v_started_at := coalesce(v_started_at, v_now);
    v_status := 'in_progress';
    v_event_type := 'started';
    v_event_payload := jsonb_build_object('auto_acknowledged', v_task.acknowledged_at is null);

  elsif p_action = 'checklist' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status not in ('todo', 'in_progress') then
      raise exception using errcode = '42501', message = 'TASK_CHECKLIST_NOT_EDITABLE';
    end if;
    v_item_id := nullif(v_payload ->> 'item_id', '')::uuid;
    if v_item_id is null or not exists (
      select 1 from public.task_checklist_items as item
      where item.organization_id = v_task.organization_id
        and item.task_id = v_task.id
        and item.id = v_item_id
    ) then
      raise exception using errcode = 'P0002', message = 'TASK_CHECKLIST_ITEM_NOT_FOUND';
    end if;
    update public.task_checklist_items
    set checked_at = case when coalesce((v_payload ->> 'checked')::boolean, false) then v_now else null end,
        checked_by_member_id = case when coalesce((v_payload ->> 'checked')::boolean, false) then v_actor_id else null end
    where organization_id = v_task.organization_id and task_id = v_task.id and id = v_item_id;
    v_event_type := 'checklist_updated';
    v_event_payload := jsonb_build_object(
      'item_id', v_item_id,
      'checked', coalesce((v_payload ->> 'checked')::boolean, false)
    );

  elsif p_action = 'submit' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status not in ('todo', 'in_progress') then
      raise exception using errcode = '42501', message = 'TASK_SUBMIT_NOT_ALLOWED';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object('id', item.id, 'title', item.title) order by item.sort_order, item.id), '[]'::jsonb)
      into v_missing_items
    from public.task_checklist_items as item
    where item.organization_id = v_task.organization_id
      and item.task_id = v_task.id
      and item.is_required
      and item.checked_at is null;

    if jsonb_array_length(v_missing_items) > 0 then
      raise exception using
        errcode = '23514',
        message = 'TASK_REQUIRED_CHECKLIST_INCOMPLETE',
        detail = v_missing_items::text;
    end if;

    if v_task.requires_result
      and nullif(trim(coalesce(v_payload ->> 'result_text', '')), '') is null
      and not (v_task.allow_no_incident and coalesce((v_payload ->> 'no_incident')::boolean, false)) then
      raise exception using errcode = '23514', message = 'TASK_RESULT_REQUIRED';
    end if;

    if v_task.requires_attachment then
      if v_payload -> 'evidence' is null
        or jsonb_typeof(v_payload -> 'evidence') not in ('array', 'object')
        or (jsonb_typeof(v_payload -> 'evidence') = 'array' and jsonb_array_length(v_payload -> 'evidence') = 0)
        or (jsonb_typeof(v_payload -> 'evidence') = 'object' and v_payload -> 'evidence' = '{}'::jsonb) then
        raise exception using errcode = '23514', message = 'TASK_EVIDENCE_REQUIRED';
      end if;
    end if;

    if v_task.requires_review and v_task.reviewer_member_id is null then
      raise exception using errcode = '23514', message = 'TASK_REVIEWER_REQUIRED';
    end if;
    if v_task.reviewer_member_id = v_task.assignee_member_id then
      raise exception using errcode = '23514', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
    end if;

    select coalesce(max(s.revision), 0) + 1 into v_revision
    from public.task_submissions as s
    where s.organization_id = v_task.organization_id and s.task_id = v_task.id;
    v_submission_id := extensions.gen_random_uuid();

    insert into public.task_submissions (
      id,
      organization_id,
      task_id,
      revision,
      submitted_by_member_id,
      result_text,
      no_incident,
      evidence,
      review_state
    )
    values (
      v_submission_id,
      v_task.organization_id,
      v_task.id,
      v_revision,
      v_actor_id,
      nullif(trim(v_payload ->> 'result_text'), ''),
      coalesce((v_payload ->> 'no_incident')::boolean, false),
      coalesce(v_payload -> 'evidence', '[]'::jsonb),
      case when v_task.requires_review then 'pending' else 'approved' end
    );

    v_current_submission_id := v_submission_id;
    v_submitted_at := v_now;
    if v_task.requires_review then
      v_status := 'in_review';
      v_event_type := 'submitted_for_review';
      v_outbox_type := 'task.review_requested';
      v_outbox_payload := jsonb_build_object(
        'task_id', v_task.id,
        'reviewer_member_id', v_task.reviewer_member_id,
        'submission_id', v_submission_id
      );
    else
      v_status := 'done';
      v_completed_at := v_now;
      v_event_type := 'completed';
    end if;
    v_event_payload := jsonb_build_object('submission_id', v_submission_id, 'revision', v_revision);

  elsif p_action = 'withdraw_submission' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status <> 'in_review' or v_task.current_submission_id is null then
      raise exception using errcode = '42501', message = 'TASK_WITHDRAW_NOT_ALLOWED';
    end if;
    update public.task_submissions
    set review_state = 'withdrawn'
    where organization_id = v_task.organization_id
      and task_id = v_task.id
      and id = v_task.current_submission_id
      and review_state = 'pending';
    v_status := 'in_progress';
    v_submitted_at := null;
    v_event_type := 'submission_withdrawn';
    v_event_payload := jsonb_build_object('submission_id', v_task.current_submission_id);

  elsif p_action = 'approve' then
    if v_task.status <> 'in_review' or v_task.current_submission_id is null then
      raise exception using errcode = '23514', message = 'TASK_NOT_IN_REVIEW';
    end if;
    if v_actor_id = v_task.assignee_member_id then
      raise exception using errcode = '42501', message = 'TASK_SELF_APPROVAL_DENIED';
    end if;
    if v_actor.role <> 'admin' and v_actor_id <> v_task.reviewer_member_id then
      raise exception using errcode = '42501', message = 'TASK_REVIEW_DENIED';
    end if;
    update public.task_submissions
    set review_state = 'approved', reviewed_by_member_id = v_actor_id, reviewed_at = v_now, review_reason = null
    where organization_id = v_task.organization_id and task_id = v_task.id and id = v_task.current_submission_id;
    v_status := 'done';
    v_completed_at := v_now;
    v_event_type := 'approved';
    v_event_payload := jsonb_build_object('submission_id', v_task.current_submission_id);

  elsif p_action = 'request_changes' then
    if v_task.status <> 'in_review' or v_task.current_submission_id is null then
      raise exception using errcode = '23514', message = 'TASK_NOT_IN_REVIEW';
    end if;
    if v_actor_id = v_task.assignee_member_id then
      raise exception using errcode = '42501', message = 'TASK_SELF_APPROVAL_DENIED';
    end if;
    if v_actor.role <> 'admin' and v_actor_id <> v_task.reviewer_member_id then
      raise exception using errcode = '42501', message = 'TASK_REVIEW_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_CHANGE_REASON_REQUIRED';
    end if;
    update public.task_submissions
    set review_state = 'changes_requested',
        reviewed_by_member_id = v_actor_id,
        reviewed_at = v_now,
        review_reason = v_reason,
        revision_due_at = coalesce(nullif(v_payload ->> 'revision_due_at', '')::timestamptz, v_task.due_at)
    where organization_id = v_task.organization_id and task_id = v_task.id and id = v_task.current_submission_id;
    v_status := 'in_progress';
    v_submitted_at := null;
    v_completed_at := null;
    v_event_type := 'changes_requested';
    v_event_payload := jsonb_build_object(
      'submission_id', v_task.current_submission_id,
      'reason', v_reason,
      'revision_due_at', coalesce(nullif(v_payload ->> 'revision_due_at', '')::timestamptz, v_task.due_at)
    );

  elsif p_action = 'report_blocker' then
    if v_actor_id <> v_task.assignee_member_id or v_task.status not in ('todo', 'in_progress') then
      raise exception using errcode = '42501', message = 'TASK_BLOCKER_REPORT_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    v_blocker_owner_id := coalesce(nullif(v_payload ->> 'owner_member_id', '')::uuid, v_actor_id);
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_BLOCKER_REASON_REQUIRED';
    end if;
    perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_blocker_owner_id);
    v_blocked_at := v_now;
    v_blocker_reason := v_reason;
    v_event_type := 'blocker_reported';
    v_event_payload := jsonb_build_object('owner_member_id', v_blocker_owner_id, 'reason', v_reason);

  elsif p_action = 'resolve_blocker' then
    if v_task.blocked_at is null then
      raise exception using errcode = '23514', message = 'TASK_BLOCKER_NOT_FOUND';
    end if;
    if v_actor_id <> v_task.assignee_member_id
      and v_actor_id <> v_task.blocker_owner_member_id
      and not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_BLOCKER_RESOLVE_DENIED';
    end if;
    v_event_type := 'blocker_resolved';
    v_event_payload := jsonb_build_object('previous_reason', v_task.blocker_reason);
    v_blocked_at := null;
    v_blocker_reason := null;
    v_blocker_owner_id := null;

  elsif p_action = 'reassign' then
    if v_task.status not in ('todo', 'in_progress') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_REASSIGN_DENIED';
    end if;
    v_target_member_id := nullif(v_payload ->> 'assignee_member_id', '')::uuid;
    if v_target_member_id is null then
      raise exception using errcode = '22023', message = 'TASK_ASSIGNEE_REQUIRED';
    end if;
    if v_task.seller_id is null and v_actor.role <> 'admin' and v_target_member_id <> v_actor_id then
      raise exception using errcode = '42501', message = 'INTERNAL_TASK_REASSIGN_DENIED';
    end if;
    perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_target_member_id);
    if v_task.reviewer_member_id = v_target_member_id then
      raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
    end if;
    v_event_payload := jsonb_build_object(
      'from_assignee_member_id', v_task.assignee_member_id,
      'to_assignee_member_id', v_target_member_id
    );
    v_assignee_id := v_target_member_id;
    v_acknowledged_at := null;
    v_event_type := 'reassigned';
    v_outbox_type := 'task.assigned';
    v_outbox_payload := jsonb_build_object('task_id', v_task.id, 'assignee_member_id', v_target_member_id);

  elsif p_action = 'change_deadline' then
    if v_task.status in ('canceled', 'waived') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_DEADLINE_CHANGE_DENIED';
    end if;
    v_due_at := nullif(v_payload ->> 'due_at', '')::timestamptz;
    if v_due_at is null then
      raise exception using errcode = '22023', message = 'TASK_DUE_AT_REQUIRED';
    end if;
    v_event_type := 'deadline_changed';
    v_event_payload := jsonb_build_object('before', v_task.due_at, 'after', v_due_at);

  elsif p_action = 'cancel' then
    if v_task.status in ('done', 'canceled', 'waived') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_CANCEL_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_CANCEL_REASON_REQUIRED';
    end if;
    v_status := 'canceled';
    v_completed_at := null;
    v_event_type := 'canceled';
    v_event_payload := jsonb_build_object('reason', v_reason);

  elsif p_action = 'waive' then
    if v_task.status in ('done', 'canceled', 'waived') or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_WAIVE_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_WAIVE_REASON_REQUIRED';
    end if;
    v_status := 'waived';
    v_completed_at := null;
    v_event_type := 'waived';
    v_event_payload := jsonb_build_object('reason', v_reason);

  elsif p_action = 'reopen' then
    if v_task.status <> 'done' or not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
      raise exception using errcode = '42501', message = 'TASK_REOPEN_DENIED';
    end if;
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_REOPEN_REASON_REQUIRED';
    end if;
    v_status := 'in_progress';
    v_completed_at := null;
    v_event_type := 'reopened';
    v_event_payload := jsonb_build_object('reason', v_reason, 'previous_completed_at', v_task.completed_at);

  else
    raise exception using errcode = '22023', message = 'TASK_ACTION_INVALID';
  end if;

  update public.tasks
  set status = v_status,
      assignee_member_id = v_assignee_id,
      acknowledged_at = v_acknowledged_at,
      started_at = v_started_at,
      submitted_at = v_submitted_at,
      completed_at = v_completed_at,
      due_at = v_due_at,
      blocked_at = v_blocked_at,
      blocker_reason = v_blocker_reason,
      blocker_owner_member_id = v_blocker_owner_id,
      current_submission_id = v_current_submission_id,
      last_meaningful_update_at = v_now,
      version = version + 1
  where id = v_task.id
  returning * into v_task;

  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload
  )
  values (
    v_task.organization_id,
    v_task.id,
    v_task.version,
    v_event_type,
    v_actor_id,
    v_event_payload
  );

  perform private.write_audit(
    v_task.organization_id,
    'task.' || v_event_type,
    'task',
    v_task.id,
    jsonb_build_object('task_version', v_task.version, 'status', v_task.status),
    v_request_id
  );

  if v_outbox_type is not null then
    insert into private.outbox_events (
      organization_id,
      event_type,
      entity_type,
      entity_id,
      dedupe_key,
      payload
    )
    values (
      v_task.organization_id,
      v_outbox_type,
      'task',
      v_task.id,
      'task:' || v_task.id::text || ':' || replace(v_outbox_type, '.', '-') || ':' || v_task.version::text,
      coalesce(v_outbox_payload, '{}'::jsonb) || jsonb_build_object('task_version', v_task.version)
    );
  end if;

  v_result := jsonb_build_object(
    'task_id', v_task.id,
    'status', v_task.status,
    'version', v_task.version,
    'event_type', v_event_type,
    'submission_id', v_submission_id
  );

  perform private.task_idempotency_store(
    v_task.organization_id,
    v_actor_id,
    v_command_name,
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'payload', v_payload),
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_list_tasks(
  p_organization_id uuid,
  p_include_terminal boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'task_number', t.task_number,
        'title', t.title,
        'description', t.description,
        'seller_id', t.seller_id,
        'seller_name', s.name,
        'assignee_member_id', t.assignee_member_id,
        'assignee_name', assignee.display_name,
        'reviewer_member_id', t.reviewer_member_id,
        'reviewer_name', reviewer.display_name,
        'priority', t.priority,
        'status', t.status,
        'planned_date', t.planned_date,
        'original_due_at', t.original_due_at,
        'due_at', t.due_at,
        'acknowledged_at', t.acknowledged_at,
        'blocked_at', t.blocked_at,
        'blocker_reason', t.blocker_reason,
        'requires_review', t.requires_review,
        'version', t.version,
        'checklist_total', (select count(*) from public.task_checklist_items item where item.organization_id = t.organization_id and item.task_id = t.id),
        'checklist_checked', (select count(*) from public.task_checklist_items item where item.organization_id = t.organization_id and item.task_id = t.id and item.checked_at is not null)
      )
      order by
        case t.priority when 'urgent' then 0 when 'high' then 1 when 'normal' then 2 else 3 end,
        t.due_at,
        t.task_number
    ),
    '[]'::jsonb
  )
  from public.tasks as t
  join public.organization_members as assignee
    on assignee.organization_id = t.organization_id and assignee.id = t.assignee_member_id
  left join public.organization_members as reviewer
    on reviewer.organization_id = t.organization_id and reviewer.id = t.reviewer_member_id
  left join public.sellers as s
    on s.organization_id = t.organization_id and s.id = t.seller_id
  where t.organization_id = p_organization_id
    and private.current_actor_can_read_task(t.organization_id, t.id)
    and (p_include_terminal or t.status not in ('done', 'canceled', 'waived'));
$$;

create or replace function public.rpc_get_task(p_task_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_actor_id uuid;
  v_actor public.organization_members%rowtype;
begin
  select t.* into v_task from public.tasks as t where t.id = p_task_id;
  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;
  if not private.current_actor_can_read_task(v_task.organization_id, v_task.id) then
    raise exception using errcode = '42501', message = 'TASK_ACCESS_DENIED';
  end if;

  v_actor_id := private.current_member_id(v_task.organization_id);
  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = v_task.organization_id and m.id = v_actor_id;

  return (
    select jsonb_build_object(
      'id', t.id,
      'organization_id', t.organization_id,
      'task_number', t.task_number,
      'seller_id', t.seller_id,
      'seller_name', s.name,
      'title', t.title,
      'description', t.description,
      'assignee_member_id', t.assignee_member_id,
      'assignee_name', assignee.display_name,
      'created_by_member_id', t.created_by_member_id,
      'created_by_name', creator.display_name,
      'reviewer_member_id', t.reviewer_member_id,
      'reviewer_name', reviewer.display_name,
      'priority', t.priority,
      'status', t.status,
      'planned_date', t.planned_date,
      'original_due_at', t.original_due_at,
      'due_at', t.due_at,
      'assigned_at', t.assigned_at,
      'visible_from', t.visible_from,
      'acknowledged_at', t.acknowledged_at,
      'started_at', t.started_at,
      'submitted_at', t.submitted_at,
      'completed_at', t.completed_at,
      'requires_review', t.requires_review,
      'requires_result', t.requires_result,
      'requires_attachment', t.requires_attachment,
      'allow_no_incident', t.allow_no_incident,
      'blocked_at', t.blocked_at,
      'blocker_reason', t.blocker_reason,
      'blocker_owner_member_id', t.blocker_owner_member_id,
      'current_submission_id', t.current_submission_id,
      'version', t.version,
      'checklist', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', item.id,
          'title', item.title,
          'sort_order', item.sort_order,
          'is_required', item.is_required,
          'checked_at', item.checked_at,
          'checked_by_member_id', item.checked_by_member_id
        ) order by item.sort_order, item.id), '[]'::jsonb)
        from public.task_checklist_items as item
        where item.organization_id = t.organization_id and item.task_id = t.id
      ),
      'submissions', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', sub.id,
          'revision', sub.revision,
          'submitted_by_member_id', sub.submitted_by_member_id,
          'result_text', sub.result_text,
          'no_incident', sub.no_incident,
          'evidence', sub.evidence,
          'review_state', sub.review_state,
          'reviewed_by_member_id', sub.reviewed_by_member_id,
          'reviewed_at', sub.reviewed_at,
          'review_reason', sub.review_reason,
          'revision_due_at', sub.revision_due_at,
          'submitted_at', sub.submitted_at
        ) order by sub.revision desc), '[]'::jsonb)
        from public.task_submissions as sub
        where sub.organization_id = t.organization_id and sub.task_id = t.id
      ),
      'events', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'id', ev.id,
          'task_version', ev.task_version,
          'event_type', ev.event_type,
          'actor_member_id', ev.actor_member_id,
          'actor_name', actor_member.display_name,
          'event_payload', ev.event_payload,
          'occurred_at', ev.occurred_at
        ) order by ev.task_version desc), '[]'::jsonb)
        from public.task_events as ev
        left join public.organization_members as actor_member
          on actor_member.organization_id = ev.organization_id and actor_member.id = ev.actor_member_id
        where ev.organization_id = t.organization_id and ev.task_id = t.id
      ),
      'permissions', jsonb_build_object(
        'is_assignee', v_actor_id = t.assignee_member_id,
        'can_review', v_actor_id <> t.assignee_member_id and (v_actor.role = 'admin' or v_actor_id = t.reviewer_member_id),
        'can_manage', private.current_actor_can_manage_task(t.organization_id, t.id)
      )
    )
    from public.tasks as t
    join public.organization_members as assignee
      on assignee.organization_id = t.organization_id and assignee.id = t.assignee_member_id
    join public.organization_members as creator
      on creator.organization_id = t.organization_id and creator.id = t.created_by_member_id
    left join public.organization_members as reviewer
      on reviewer.organization_id = t.organization_id and reviewer.id = t.reviewer_member_id
    left join public.sellers as s
      on s.organization_id = t.organization_id and s.id = t.seller_id
    where t.id = v_task.id
  );
end;
$$;

revoke all on function private.current_actor_can_read_task(uuid, uuid) from public, anon;
revoke all on function private.current_actor_can_manage_task(uuid, uuid) from public, anon;
revoke all on function private.assert_task_member_scope(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function private.task_idempotency_replay(uuid, uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function private.task_idempotency_store(uuid, uuid, text, text, jsonb, jsonb) from public, anon, authenticated;
grant execute on function private.current_actor_can_read_task(uuid, uuid) to authenticated;
grant execute on function private.current_actor_can_manage_task(uuid, uuid) to authenticated;

revoke all on function public.rpc_create_task(uuid, jsonb, text) from public, anon;
revoke all on function public.rpc_task_command(uuid, text, jsonb, integer, text) from public, anon;
revoke all on function public.rpc_list_tasks(uuid, boolean) from public, anon;
revoke all on function public.rpc_get_task(uuid) from public, anon;
grant execute on function public.rpc_create_task(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_task_command(uuid, text, jsonb, integer, text) to authenticated;
grant execute on function public.rpc_list_tasks(uuid, boolean) to authenticated;
grant execute on function public.rpc_get_task(uuid) to authenticated;

alter table public.tasks enable row level security;
alter table public.task_participants enable row level security;
alter table public.task_checklist_items enable row level security;
alter table public.task_submissions enable row level security;
alter table public.task_events enable row level security;
alter table private.outbox_events enable row level security;
alter table private.task_number_counters enable row level security;

create policy tasks_read_by_scope
on public.tasks for select to authenticated
using (private.current_actor_can_read_task(organization_id, id));

create policy task_participants_read_by_scope
on public.task_participants for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

create policy task_checklist_read_by_scope
on public.task_checklist_items for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

create policy task_submissions_read_by_scope
on public.task_submissions for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

create policy task_events_read_by_scope
on public.task_events for select to authenticated
using (private.current_actor_can_read_task(organization_id, task_id));

revoke all on public.tasks from anon;
revoke all on public.task_participants from anon;
revoke all on public.task_checklist_items from anon;
revoke all on public.task_submissions from anon;
revoke all on public.task_events from anon;
revoke all on private.outbox_events from anon, authenticated;
revoke all on private.task_number_counters from anon, authenticated;

revoke insert, update, delete, truncate, references, trigger
  on public.tasks, public.task_participants, public.task_checklist_items,
     public.task_submissions, public.task_events
  from authenticated;

grant select
  on public.tasks, public.task_participants, public.task_checklist_items,
     public.task_submissions, public.task_events
  to authenticated;

-- ============================================================================
-- END 00000000000003_p03b_task_core.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000004_p03b_task_core_hardening.sql
-- ============================================================================

-- P03B hardening: stable payload validation, batch create, task updates,
-- immutable report snapshots and assignment lifecycle fixes.

alter table public.tasks
  alter column requires_result set default true;

alter table public.task_events
  add column report_state_after jsonb not null default '{}'::jsonb;

alter table public.task_events
  add constraint task_events_report_state_after_object
  check (jsonb_typeof(report_state_after) = 'object');

create or replace function private.task_json_uuid(
  p_payload jsonb,
  p_key text,
  p_error text,
  p_required boolean default false
)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  v_text := nullif(trim(p_payload ->> p_key), '');
  if v_text is null then
    if p_required then
      raise exception using errcode = '22023', message = p_error;
    end if;
    return null;
  end if;

  begin
    return v_text::uuid;
  exception when invalid_text_representation then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_json_boolean(
  p_payload jsonb,
  p_key text,
  p_default boolean,
  p_error text
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if not (p_payload ? p_key) then
    return p_default;
  end if;
  if jsonb_typeof(p_payload -> p_key) <> 'boolean' then
    raise exception using errcode = '22023', message = p_error;
  end if;
  return (p_payload ->> p_key)::boolean;
end;
$$;

create or replace function private.task_json_integer(
  p_payload jsonb,
  p_key text,
  p_error text
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  if not (p_payload ? p_key) or jsonb_typeof(p_payload -> p_key) = 'null' then
    return null;
  end if;
  v_text := p_payload ->> p_key;
  if jsonb_typeof(p_payload -> p_key) <> 'number' or v_text !~ '^-?[0-9]+$' then
    raise exception using errcode = '22023', message = p_error;
  end if;
  begin
    return v_text::integer;
  exception when numeric_value_out_of_range then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_json_date(
  p_payload jsonb,
  p_key text,
  p_error text
)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  v_text := nullif(trim(p_payload ->> p_key), '');
  if v_text is null then
    return null;
  end if;
  begin
    return v_text::date;
  exception when datetime_field_overflow or invalid_datetime_format then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_json_timestamptz(
  p_payload jsonb,
  p_key text,
  p_error text
)
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_text text;
begin
  v_text := nullif(trim(p_payload ->> p_key), '');
  if v_text is null then
    return null;
  end if;
  begin
    return v_text::timestamptz;
  exception when datetime_field_overflow or invalid_datetime_format then
    raise exception using errcode = '22023', message = p_error;
  end;
end;
$$;

create or replace function private.task_report_state(p_task public.tasks)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'task_id', p_task.id,
    'task_number', p_task.task_number,
    'batch_id', p_task.batch_id,
    'seller_id', p_task.seller_id,
    'status', p_task.status,
    'priority', p_task.priority,
    'assignee_member_id', p_task.assignee_member_id,
    'reviewer_member_id', p_task.reviewer_member_id,
    'planned_date', p_task.planned_date,
    'original_due_at', p_task.original_due_at,
    'due_at', p_task.due_at,
    'assigned_at', p_task.assigned_at,
    'acknowledged_at', p_task.acknowledged_at,
    'started_at', p_task.started_at,
    'submitted_at', p_task.submitted_at,
    'completed_at', p_task.completed_at,
    'requires_review', p_task.requires_review,
    'requires_result', p_task.requires_result,
    'requires_attachment', p_task.requires_attachment,
    'blocked_at', p_task.blocked_at,
    'blocker_reason', p_task.blocker_reason,
    'blocker_owner_member_id', p_task.blocker_owner_member_id,
    'current_submission_id', p_task.current_submission_id,
    'version', p_task.version
  );
$$;

create or replace function private.normalize_task_draft(p_task jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_result jsonb;
  v_uuid uuid;
  v_date date;
  v_timestamp timestamptz;
  v_integer integer;
  v_boolean boolean;
  v_item jsonb;
  v_items jsonb := '[]'::jsonb;
  v_member jsonb;
  v_member_id uuid;
  v_members jsonb := '[]'::jsonb;
begin
  if p_task is null or jsonb_typeof(p_task) <> 'object' then
    raise exception using errcode = '22023', message = 'TASK_DRAFT_INVALID';
  end if;
  v_result := p_task;

  if p_task ? 'assignee_member_id' then
    v_uuid := private.task_json_uuid(p_task, 'assignee_member_id', 'TASK_ASSIGNEE_INVALID');
    v_result := jsonb_set(v_result, '{assignee_member_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
  end if;
  if p_task ? 'reviewer_member_id' then
    v_uuid := private.task_json_uuid(p_task, 'reviewer_member_id', 'TASK_REVIEWER_INVALID');
    v_result := jsonb_set(v_result, '{reviewer_member_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
  end if;
  if p_task ? 'seller_id' then
    v_uuid := private.task_json_uuid(p_task, 'seller_id', 'TASK_SELLER_INVALID');
    v_result := jsonb_set(v_result, '{seller_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
  end if;

  if p_task ? 'planned_date' then
    v_date := private.task_json_date(p_task, 'planned_date', 'TASK_PLANNED_DATE_INVALID');
    v_result := jsonb_set(v_result, '{planned_date}', coalesce(to_jsonb(v_date), 'null'::jsonb), true);
  end if;
  if p_task ? 'due_at' then
    v_timestamp := private.task_json_timestamptz(p_task, 'due_at', 'TASK_DUE_AT_INVALID');
    v_result := jsonb_set(v_result, '{due_at}', coalesce(to_jsonb(v_timestamp), 'null'::jsonb), true);
  end if;
  if p_task ? 'visible_from' then
    v_timestamp := private.task_json_timestamptz(p_task, 'visible_from', 'TASK_VISIBLE_FROM_INVALID');
    v_result := jsonb_set(v_result, '{visible_from}', coalesce(to_jsonb(v_timestamp), 'null'::jsonb), true);
  end if;

  v_boolean := private.task_json_boolean(p_task, 'requires_review', false, 'TASK_REQUIRES_REVIEW_INVALID');
  v_result := jsonb_set(v_result, '{requires_review}', to_jsonb(v_boolean), true);
  v_boolean := private.task_json_boolean(p_task, 'requires_result', true, 'TASK_REQUIRES_RESULT_INVALID');
  v_result := jsonb_set(v_result, '{requires_result}', to_jsonb(v_boolean), true);
  v_boolean := private.task_json_boolean(p_task, 'requires_attachment', false, 'TASK_REQUIRES_ATTACHMENT_INVALID');
  v_result := jsonb_set(v_result, '{requires_attachment}', to_jsonb(v_boolean), true);
  v_boolean := private.task_json_boolean(p_task, 'allow_no_incident', false, 'TASK_ALLOW_NO_INCIDENT_INVALID');
  v_result := jsonb_set(v_result, '{allow_no_incident}', to_jsonb(v_boolean), true);

  if p_task ? 'estimated_minutes' then
    v_integer := private.task_json_integer(p_task, 'estimated_minutes', 'TASK_ESTIMATED_MINUTES_INVALID');
    if v_integer is not null and v_integer <= 0 then
      raise exception using errcode = '22023', message = 'TASK_ESTIMATED_MINUTES_INVALID';
    end if;
    v_result := jsonb_set(v_result, '{estimated_minutes}', coalesce(to_jsonb(v_integer), 'null'::jsonb), true);
  end if;

  if p_task ? 'checklist' then
    if jsonb_typeof(p_task -> 'checklist') <> 'array' then
      raise exception using errcode = '22023', message = 'TASK_ARRAY_FIELD_INVALID';
    end if;
    for v_item in select value from jsonb_array_elements(p_task -> 'checklist')
    loop
      if jsonb_typeof(v_item) <> 'object' then
        raise exception using errcode = '22023', message = 'TASK_CHECKLIST_ITEM_INVALID';
      end if;
      if v_item ? 'sort_order' then
        v_integer := private.task_json_integer(v_item, 'sort_order', 'TASK_CHECKLIST_SORT_ORDER_INVALID');
        if v_integer is null or v_integer < 0 then
          raise exception using errcode = '22023', message = 'TASK_CHECKLIST_SORT_ORDER_INVALID';
        end if;
        v_item := jsonb_set(v_item, '{sort_order}', to_jsonb(v_integer), true);
      end if;
      v_boolean := private.task_json_boolean(v_item, 'is_required', true, 'TASK_CHECKLIST_REQUIRED_FLAG_INVALID');
      v_item := jsonb_set(v_item, '{is_required}', to_jsonb(v_boolean), true);
      v_items := v_items || jsonb_build_array(v_item);
    end loop;
    v_result := jsonb_set(v_result, '{checklist}', v_items, true);
  end if;

  if p_task ? 'participant_member_ids' then
    if jsonb_typeof(p_task -> 'participant_member_ids') <> 'array' then
      raise exception using errcode = '22023', message = 'TASK_ARRAY_FIELD_INVALID';
    end if;
    for v_member in select value from jsonb_array_elements(p_task -> 'participant_member_ids')
    loop
      if jsonb_typeof(v_member) <> 'string' then
        raise exception using errcode = '22023', message = 'TASK_PARTICIPANT_INVALID';
      end if;
      begin
        v_member_id := nullif(trim(v_member #>> '{}'), '')::uuid;
      exception when invalid_text_representation then
        raise exception using errcode = '22023', message = 'TASK_PARTICIPANT_INVALID';
      end;
      if v_member_id is null then
        raise exception using errcode = '22023', message = 'TASK_PARTICIPANT_INVALID';
      end if;
      v_members := v_members || jsonb_build_array(v_member_id::text);
    end loop;
    v_result := jsonb_set(v_result, '{participant_member_ids}', v_members, true);
  end if;

  return v_result;
end;
$$;

create or replace function private.normalize_task_command_payload(
  p_action text,
  p_payload jsonb
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_result jsonb := coalesce(p_payload, '{}'::jsonb);
  v_uuid uuid;
  v_timestamp timestamptz;
  v_boolean boolean;
begin
  if jsonb_typeof(v_result) <> 'object' then
    raise exception using errcode = '22023', message = 'TASK_COMMAND_PAYLOAD_INVALID';
  end if;

  if p_action = 'checklist' then
    v_uuid := private.task_json_uuid(v_result, 'item_id', 'TASK_CHECKLIST_ITEM_INVALID', true);
    v_result := jsonb_set(v_result, '{item_id}', to_jsonb(v_uuid), true);
    v_boolean := private.task_json_boolean(v_result, 'checked', false, 'TASK_CHECKLIST_CHECKED_INVALID');
    v_result := jsonb_set(v_result, '{checked}', to_jsonb(v_boolean), true);
  elsif p_action = 'submit' then
    v_boolean := private.task_json_boolean(v_result, 'no_incident', false, 'TASK_NO_INCIDENT_INVALID');
    v_result := jsonb_set(v_result, '{no_incident}', to_jsonb(v_boolean), true);
  elsif p_action = 'request_changes' then
    if v_result ? 'revision_due_at' then
      v_timestamp := private.task_json_timestamptz(v_result, 'revision_due_at', 'TASK_REVISION_DUE_AT_INVALID');
      v_result := jsonb_set(v_result, '{revision_due_at}', coalesce(to_jsonb(v_timestamp), 'null'::jsonb), true);
    end if;
  elsif p_action = 'report_blocker' then
    if v_result ? 'owner_member_id' then
      v_uuid := private.task_json_uuid(v_result, 'owner_member_id', 'TASK_BLOCKER_OWNER_INVALID');
      v_result := jsonb_set(v_result, '{owner_member_id}', coalesce(to_jsonb(v_uuid), 'null'::jsonb), true);
    end if;
  elsif p_action = 'reassign' then
    v_uuid := private.task_json_uuid(v_result, 'assignee_member_id', 'TASK_ASSIGNEE_INVALID', true);
    v_result := jsonb_set(v_result, '{assignee_member_id}', to_jsonb(v_uuid), true);
  elsif p_action = 'change_deadline' then
    v_timestamp := private.task_json_timestamptz(v_result, 'due_at', 'TASK_DUE_AT_INVALID');
    if v_timestamp is null then
      raise exception using errcode = '22023', message = 'TASK_DUE_AT_REQUIRED';
    end if;
    v_result := jsonb_set(v_result, '{due_at}', to_jsonb(v_timestamp), true);
  end if;

  return v_result;
end;
$$;

alter function public.rpc_create_task(uuid, jsonb, text)
  rename to rpc_create_task_p03b_legacy;

alter function public.rpc_task_command(uuid, text, jsonb, integer, text)
  rename to rpc_task_command_p03b_legacy;

revoke all on function public.rpc_create_task_p03b_legacy(uuid, jsonb, text)
  from public, anon, authenticated;
revoke all on function public.rpc_task_command_p03b_legacy(uuid, text, jsonb, integer, text)
  from public, anon, authenticated;

create or replace function public.rpc_create_task(
  p_organization_id uuid,
  p_task jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_task jsonb;
  v_replay jsonb;
  v_result jsonb;
  v_created public.tasks%rowtype;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  v_task := private.normalize_task_draft(p_task);
  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'task.create',
    p_idempotency_key,
    v_task
  );
  if v_replay is not null then
    return v_replay;
  end if;

  v_result := public.rpc_create_task_p03b_legacy(p_organization_id, v_task, p_idempotency_key);

  select t.* into v_created
  from public.tasks as t
  where t.organization_id = p_organization_id
    and t.id = (v_result ->> 'task_id')::uuid;

  update public.task_events
  set report_state_after = private.task_report_state(v_created)
  where organization_id = p_organization_id
    and task_id = v_created.id
    and task_version = v_created.version;

  return v_result;
end;
$$;

create or replace function public.rpc_task_command(
  p_task_id uuid,
  p_action text,
  p_payload jsonb,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before public.tasks%rowtype;
  v_after public.tasks%rowtype;
  v_actor_id uuid;
  v_action text := trim(coalesce(p_action, ''));
  v_payload jsonb;
  v_replay jsonb;
  v_result jsonb;
  v_reason text;
  v_version integer;
  v_outbox_type text;
begin
  select t.* into v_before
  from public.tasks as t
  where t.id = p_task_id;
  if v_before.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;

  v_actor_id := private.current_member_id(v_before.organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  v_payload := private.normalize_task_command_payload(v_action, p_payload);

  if v_action in ('reassign', 'change_deadline') then
    v_reason := nullif(trim(v_payload ->> 'reason'), '');
    if v_reason is null then
      raise exception using errcode = '22023', message = case
        when v_action = 'reassign' then 'TASK_REASSIGN_REASON_REQUIRED'
        else 'TASK_DEADLINE_CHANGE_REASON_REQUIRED'
      end;
    end if;
  end if;

  v_replay := private.task_idempotency_replay(
    v_before.organization_id,
    v_actor_id,
    'task.' || v_action,
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'payload', v_payload)
  );
  if v_replay is not null then
    return v_replay;
  end if;

  v_result := public.rpc_task_command_p03b_legacy(
    p_task_id,
    v_action,
    v_payload,
    p_expected_version,
    p_idempotency_key
  );
  v_version := (v_result ->> 'version')::integer;

  if v_action = 'reassign' then
    update public.tasks
    set assigned_at = timezone('utc', now())
    where id = p_task_id
    returning * into v_after;

    update public.task_events
    set event_payload = event_payload || jsonb_build_object(
      'reason', v_reason,
      'assigned_at', v_after.assigned_at
    )
    where organization_id = v_after.organization_id
      and task_id = v_after.id
      and task_version = v_version;

    update private.outbox_events
    set payload = payload || jsonb_build_object(
      'previous_assignee_member_id', v_before.assignee_member_id,
      'reason', v_reason,
      'assigned_at', v_after.assigned_at
    )
    where organization_id = v_after.organization_id
      and entity_id = v_after.id
      and dedupe_key = 'task:' || v_after.id::text || ':task-assigned:' || v_version::text;
  elsif v_action = 'withdraw_submission' then
    update public.tasks
    set current_submission_id = null
    where id = p_task_id
    returning * into v_after;
  else
    select t.* into v_after from public.tasks as t where t.id = p_task_id;
  end if;

  if v_action = 'change_deadline' then
    update public.task_events
    set event_payload = event_payload || jsonb_build_object('reason', v_reason)
    where organization_id = v_after.organization_id
      and task_id = v_after.id
      and task_version = v_version;
  end if;

  update public.task_events
  set report_state_after = private.task_report_state(v_after)
  where organization_id = v_after.organization_id
    and task_id = v_after.id
    and task_version = v_version;

  v_outbox_type := case
    when v_action in ('approve', 'request_changes', 'withdraw_submission') then 'task.review_resolved'
    when v_action = 'change_deadline' then 'task.deadline_changed'
    when v_action in ('cancel', 'waive') then 'task.reminders_invalidated'
    when v_action = 'reopen' then 'task.reopened'
    when v_action = 'report_blocker' then 'task.blocker_reported'
    when v_action = 'resolve_blocker' then 'task.blocker_resolved'
    else null
  end;

  if v_outbox_type is not null then
    insert into private.outbox_events (
      organization_id,
      event_type,
      entity_type,
      entity_id,
      dedupe_key,
      payload
    )
    values (
      v_after.organization_id,
      v_outbox_type,
      'task',
      v_after.id,
      'task:' || v_after.id::text || ':' || replace(v_outbox_type, '.', '-') || ':' || v_version::text,
      jsonb_build_object(
        'task_id', v_after.id,
        'task_version', v_version,
        'actor_member_id', v_actor_id,
        'status', v_after.status
      )
    )
    on conflict (organization_id, dedupe_key) do nothing;
  end if;

  return v_result;
end;
$$;

create or replace function public.rpc_create_task_batch(
  p_organization_id uuid,
  p_common_task jsonb,
  p_targets jsonb,
  p_idempotency_key text,
  p_mode text default 'atomic'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_mode text := lower(trim(coalesce(p_mode, 'atomic')));
  v_common jsonb;
  v_replay jsonb;
  v_batch_id uuid := extensions.gen_random_uuid();
  v_results jsonb := '[]'::jsonb;
  v_target jsonb;
  v_task jsonb;
  v_created jsonb;
  v_created_task public.tasks%rowtype;
  v_index integer := 0;
  v_created_count integer := 0;
  v_failed_count integer := 0;
  v_error text;
  v_sqlstate text;
  v_target_id text;
  v_invalid_key text;
  v_request jsonb;
  v_result jsonb;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  if v_mode not in ('atomic', 'valid_only') then
    raise exception using errcode = '22023', message = 'TASK_BATCH_MODE_INVALID';
  end if;
  if p_targets is null or jsonb_typeof(p_targets) <> 'array' then
    raise exception using errcode = '22023', message = 'TASK_BATCH_TARGETS_INVALID';
  end if;
  if jsonb_array_length(p_targets) = 0 then
    raise exception using errcode = '22023', message = 'TASK_BATCH_TARGETS_REQUIRED';
  end if;
  if jsonb_array_length(p_targets) > 50 then
    raise exception using errcode = '22023', message = 'TASK_BATCH_TOO_LARGE';
  end if;

  v_common := private.normalize_task_draft(p_common_task);
  v_request := jsonb_build_object('common_task', v_common, 'targets', p_targets, 'mode', v_mode);
  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'task.create_batch',
    p_idempotency_key,
    v_request
  );
  if v_replay is not null then
    return v_replay;
  end if;

  for v_target in select value from jsonb_array_elements(p_targets)
  loop
    v_index := v_index + 1;
    if jsonb_typeof(v_target) <> 'object' then
      if v_mode = 'atomic' then
        raise exception using
          errcode = '22023',
          message = 'TASK_BATCH_TARGET_INVALID',
          detail = jsonb_build_object('target_index', v_index, 'error_code', 'TASK_BATCH_TARGET_INVALID')::text;
      end if;
      v_failed_count := v_failed_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'ok', false,
        'error_code', 'TASK_BATCH_TARGET_INVALID'
      ));
      continue;
    end if;

    select key into v_invalid_key
    from jsonb_object_keys(v_target) as key
    where key not in ('target_id', 'seller_id', 'assignee_member_id', 'due_at')
    limit 1;
    if v_invalid_key is not null then
      if v_mode = 'atomic' then
        raise exception using
          errcode = '22023',
          message = 'TASK_BATCH_TARGET_FIELD_NOT_ALLOWED',
          detail = jsonb_build_object(
            'target_index', v_index,
            'field', v_invalid_key,
            'error_code', 'TASK_BATCH_TARGET_FIELD_NOT_ALLOWED'
          )::text;
      end if;
      v_failed_count := v_failed_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'target_id', nullif(v_target ->> 'target_id', ''),
        'ok', false,
        'error_code', 'TASK_BATCH_TARGET_FIELD_NOT_ALLOWED',
        'field', v_invalid_key
      ));
      continue;
    end if;

    v_target_id := nullif(v_target ->> 'target_id', '');
    v_task := v_common || (v_target - 'target_id');

    begin
      v_created := public.rpc_create_task(
        p_organization_id,
        v_task,
        p_idempotency_key || ':' || v_index::text
      );

      update public.tasks
      set batch_id = v_batch_id
      where organization_id = p_organization_id
        and id = (v_created ->> 'task_id')::uuid
      returning * into v_created_task;

      update public.task_events
      set report_state_after = private.task_report_state(v_created_task)
      where organization_id = p_organization_id
        and task_id = v_created_task.id
        and task_version = v_created_task.version;

      v_created_count := v_created_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'target_id', v_target_id,
        'seller_id', v_created_task.seller_id,
        'assignee_member_id', v_created_task.assignee_member_id,
        'ok', true,
        'task_id', v_created_task.id,
        'task_number', v_created_task.task_number,
        'version', v_created_task.version
      ));
    exception when others then
      get stacked diagnostics v_error = message_text, v_sqlstate = returned_sqlstate;
      if v_mode = 'atomic' then
        raise exception using
          errcode = '22023',
          message = 'TASK_BATCH_TARGET_INVALID',
          detail = jsonb_build_object(
            'target_index', v_index,
            'target_id', v_target_id,
            'error_code', v_error,
            'sqlstate', v_sqlstate
          )::text;
      end if;
      v_failed_count := v_failed_count + 1;
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'target_index', v_index,
        'target_id', v_target_id,
        'ok', false,
        'error_code', v_error
      ));
    end;
  end loop;

  v_result := jsonb_build_object(
    'batch_id', v_batch_id,
    'mode', v_mode,
    'created_count', v_created_count,
    'failed_count', v_failed_count,
    'results', v_results
  );

  perform private.task_idempotency_store(
    p_organization_id,
    v_actor_id,
    'task.create_batch',
    p_idempotency_key,
    v_request,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_update_task(
  p_task_id uuid,
  p_patch jsonb,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_actor_id uuid;
  v_actor public.organization_members%rowtype;
  v_patch jsonb := coalesce(p_patch, '{}'::jsonb);
  v_replay jsonb;
  v_result jsonb;
  v_now timestamptz := timezone('utc', now());
  v_title text;
  v_description text;
  v_priority text;
  v_planned_date date;
  v_due_at timestamptz;
  v_assignee_id uuid;
  v_reviewer_id uuid;
  v_requires_review boolean;
  v_requires_result boolean;
  v_requires_attachment boolean;
  v_allow_no_incident boolean;
  v_estimated_minutes integer;
  v_assigned_at timestamptz;
  v_acknowledged_at timestamptz;
  v_reason text;
  v_assignee_changed boolean := false;
  v_due_changed boolean := false;
  v_invalid_key text;
  v_before jsonb;
  v_after jsonb;
  v_request_id uuid := extensions.gen_random_uuid();
begin
  select t.* into v_task
  from public.tasks as t
  where t.id = p_task_id
  for update;
  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;

  v_actor_id := private.current_member_id(v_task.organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  select m.* into v_actor
  from public.organization_members as m
  where m.organization_id = v_task.organization_id and m.id = v_actor_id;

  if jsonb_typeof(v_patch) <> 'object' then
    raise exception using errcode = '22023', message = 'TASK_UPDATE_PATCH_INVALID';
  end if;
  select key into v_invalid_key
  from jsonb_object_keys(v_patch) as key
  where key not in (
    'title', 'description', 'priority', 'planned_date', 'due_at',
    'assignee_member_id', 'reviewer_member_id', 'requires_review',
    'requires_result', 'requires_attachment', 'allow_no_incident',
    'estimated_minutes', 'reason'
  )
  limit 1;
  if v_invalid_key is not null then
    raise exception using errcode = '22023', message = 'TASK_UPDATE_FIELD_NOT_ALLOWED', detail = v_invalid_key;
  end if;

  v_replay := private.task_idempotency_replay(
    v_task.organization_id,
    v_actor_id,
    'task.update',
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'patch', v_patch)
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if p_expected_version is null or p_expected_version <> v_task.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;
  if not private.current_actor_can_manage_task(v_task.organization_id, v_task.id) then
    raise exception using errcode = '42501', message = 'TASK_UPDATE_DENIED';
  end if;
  if v_task.status in ('in_review', 'done', 'canceled', 'waived') then
    raise exception using errcode = '23514', message = 'TASK_UPDATE_NOT_ALLOWED';
  end if;

  v_title := v_task.title;
  v_description := v_task.description;
  v_priority := v_task.priority;
  v_planned_date := v_task.planned_date;
  v_due_at := v_task.due_at;
  v_assignee_id := v_task.assignee_member_id;
  v_reviewer_id := v_task.reviewer_member_id;
  v_requires_review := v_task.requires_review;
  v_requires_result := v_task.requires_result;
  v_requires_attachment := v_task.requires_attachment;
  v_allow_no_incident := v_task.allow_no_incident;
  v_estimated_minutes := v_task.estimated_minutes;
  v_assigned_at := v_task.assigned_at;
  v_acknowledged_at := v_task.acknowledged_at;
  v_reason := nullif(trim(v_patch ->> 'reason'), '');

  if v_patch ? 'title' then
    v_title := nullif(trim(v_patch ->> 'title'), '');
    if v_title is null or char_length(v_title) > 240 then
      raise exception using errcode = '22023', message = 'TASK_TITLE_INVALID';
    end if;
  end if;
  if v_patch ? 'description' then
    v_description := coalesce(v_patch ->> 'description', '');
    if char_length(v_description) > 10000 then
      raise exception using errcode = '22023', message = 'TASK_DESCRIPTION_TOO_LONG';
    end if;
  end if;
  if v_patch ? 'priority' then
    v_priority := nullif(trim(v_patch ->> 'priority'), '');
    if v_priority not in ('low', 'normal', 'high', 'urgent') then
      raise exception using errcode = '22023', message = 'TASK_PRIORITY_INVALID';
    end if;
  end if;
  if v_patch ? 'planned_date' then
    v_planned_date := private.task_json_date(v_patch, 'planned_date', 'TASK_PLANNED_DATE_INVALID');
    if v_planned_date is null then
      raise exception using errcode = '22023', message = 'TASK_PLANNED_DATE_REQUIRED';
    end if;
  end if;
  if v_patch ? 'due_at' then
    v_due_at := private.task_json_timestamptz(v_patch, 'due_at', 'TASK_DUE_AT_INVALID');
    if v_due_at is null then
      raise exception using errcode = '22023', message = 'TASK_DUE_AT_REQUIRED';
    end if;
    v_due_changed := v_due_at is distinct from v_task.due_at;
    if v_due_changed and v_reason is null then
      raise exception using errcode = '22023', message = 'TASK_DEADLINE_CHANGE_REASON_REQUIRED';
    end if;
  end if;
  if v_patch ? 'assignee_member_id' then
    v_assignee_id := private.task_json_uuid(v_patch, 'assignee_member_id', 'TASK_ASSIGNEE_INVALID', true);
    v_assignee_changed := v_assignee_id is distinct from v_task.assignee_member_id;
    if v_assignee_changed then
      if v_task.status not in ('todo', 'in_progress') then
        raise exception using errcode = '23514', message = 'TASK_REASSIGN_DENIED';
      end if;
      if v_reason is null then
        raise exception using errcode = '22023', message = 'TASK_REASSIGN_REASON_REQUIRED';
      end if;
      if v_task.seller_id is null and v_actor.role <> 'admin' and v_assignee_id <> v_actor_id then
        raise exception using errcode = '42501', message = 'INTERNAL_TASK_REASSIGN_DENIED';
      end if;
      perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_assignee_id);
      v_assigned_at := v_now;
      v_acknowledged_at := null;
    end if;
  end if;
  if v_patch ? 'reviewer_member_id' then
    v_reviewer_id := private.task_json_uuid(v_patch, 'reviewer_member_id', 'TASK_REVIEWER_INVALID');
    if v_reviewer_id is not null then
      perform private.assert_task_member_scope(v_task.organization_id, v_task.seller_id, v_reviewer_id);
    end if;
  end if;
  if v_patch ? 'requires_review' then
    v_requires_review := private.task_json_boolean(v_patch, 'requires_review', v_task.requires_review, 'TASK_REQUIRES_REVIEW_INVALID');
  end if;
  if v_patch ? 'requires_result' then
    v_requires_result := private.task_json_boolean(v_patch, 'requires_result', v_task.requires_result, 'TASK_REQUIRES_RESULT_INVALID');
  end if;
  if v_patch ? 'requires_attachment' then
    v_requires_attachment := private.task_json_boolean(v_patch, 'requires_attachment', v_task.requires_attachment, 'TASK_REQUIRES_ATTACHMENT_INVALID');
  end if;
  if v_patch ? 'allow_no_incident' then
    v_allow_no_incident := private.task_json_boolean(v_patch, 'allow_no_incident', v_task.allow_no_incident, 'TASK_ALLOW_NO_INCIDENT_INVALID');
  end if;
  if v_patch ? 'estimated_minutes' then
    v_estimated_minutes := private.task_json_integer(v_patch, 'estimated_minutes', 'TASK_ESTIMATED_MINUTES_INVALID');
    if v_estimated_minutes is not null and v_estimated_minutes <= 0 then
      raise exception using errcode = '22023', message = 'TASK_ESTIMATED_MINUTES_INVALID';
    end if;
  end if;

  if v_requires_review and v_reviewer_id is null then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_REQUIRED';
  end if;
  if v_reviewer_id is not null and v_reviewer_id = v_assignee_id then
    raise exception using errcode = '22023', message = 'TASK_REVIEWER_CANNOT_BE_ASSIGNEE';
  end if;

  v_before := private.task_report_state(v_task);

  update public.tasks
  set title = v_title,
      description = v_description,
      priority = v_priority,
      planned_date = v_planned_date,
      due_at = v_due_at,
      assignee_member_id = v_assignee_id,
      reviewer_member_id = v_reviewer_id,
      requires_review = v_requires_review,
      requires_result = v_requires_result,
      requires_attachment = v_requires_attachment,
      allow_no_incident = v_allow_no_incident,
      estimated_minutes = v_estimated_minutes,
      assigned_at = v_assigned_at,
      acknowledged_at = v_acknowledged_at,
      last_meaningful_update_at = v_now,
      version = version + 1
  where id = v_task.id
  returning * into v_task;

  v_after := private.task_report_state(v_task);
  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload,
    report_state_after
  )
  values (
    v_task.organization_id,
    v_task.id,
    v_task.version,
    case when v_assignee_changed then 'reassigned' when v_due_changed then 'deadline_changed' else 'details_updated' end,
    v_actor_id,
    jsonb_build_object(
      'reason', v_reason,
      'before', v_before,
      'after', v_after
    ),
    v_after
  );

  perform private.write_audit(
    v_task.organization_id,
    case when v_assignee_changed then 'task.reassigned' when v_due_changed then 'task.deadline_changed' else 'task.details_updated' end,
    'task',
    v_task.id,
    jsonb_build_object('task_version', v_task.version, 'reason', v_reason),
    v_request_id
  );

  if v_assignee_changed then
    insert into private.outbox_events (
      organization_id, event_type, entity_type, entity_id, dedupe_key, payload
    )
    values (
      v_task.organization_id,
      'task.assigned',
      'task',
      v_task.id,
      'task:' || v_task.id::text || ':task-assigned:' || v_task.version::text,
      jsonb_build_object(
        'task_id', v_task.id,
        'task_version', v_task.version,
        'previous_assignee_member_id', (v_before ->> 'assignee_member_id')::uuid,
        'assignee_member_id', v_task.assignee_member_id,
        'reason', v_reason,
        'assigned_at', v_task.assigned_at
      )
    );
  end if;

  if v_due_changed then
    insert into private.outbox_events (
      organization_id, event_type, entity_type, entity_id, dedupe_key, payload
    )
    values (
      v_task.organization_id,
      'task.deadline_changed',
      'task',
      v_task.id,
      'task:' || v_task.id::text || ':task-deadline-changed:' || v_task.version::text,
      jsonb_build_object(
        'task_id', v_task.id,
        'task_version', v_task.version,
        'previous_due_at', v_before ->> 'due_at',
        'due_at', v_task.due_at,
        'reason', v_reason
      )
    )
    on conflict (organization_id, dedupe_key) do nothing;
  end if;

  v_result := jsonb_build_object(
    'task_id', v_task.id,
    'status', v_task.status,
    'version', v_task.version,
    'event_type', case when v_assignee_changed then 'reassigned' when v_due_changed then 'deadline_changed' else 'details_updated' end
  );

  perform private.task_idempotency_store(
    v_task.organization_id,
    v_actor_id,
    'task.update',
    p_idempotency_key,
    jsonb_build_object('task_id', p_task_id, 'expected_version', p_expected_version, 'patch', v_patch),
    v_result
  );

  return v_result;
end;
$$;

revoke all on function private.task_json_uuid(jsonb, text, text, boolean) from public, anon, authenticated;
revoke all on function private.task_json_boolean(jsonb, text, boolean, text) from public, anon, authenticated;
revoke all on function private.task_json_integer(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.task_json_date(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.task_json_timestamptz(jsonb, text, text) from public, anon, authenticated;
revoke all on function private.task_report_state(public.tasks) from public, anon, authenticated;
revoke all on function private.normalize_task_draft(jsonb) from public, anon, authenticated;
revoke all on function private.normalize_task_command_payload(text, jsonb) from public, anon, authenticated;

revoke all on function public.rpc_create_task(uuid, jsonb, text) from public, anon;
revoke all on function public.rpc_task_command(uuid, text, jsonb, integer, text) from public, anon;
revoke all on function public.rpc_create_task_batch(uuid, jsonb, jsonb, text, text) from public, anon;
revoke all on function public.rpc_update_task(uuid, jsonb, integer, text) from public, anon;

grant execute on function public.rpc_create_task(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_task_command(uuid, text, jsonb, integer, text) to authenticated;
grant execute on function public.rpc_create_task_batch(uuid, jsonb, jsonb, text, text) to authenticated;
grant execute on function public.rpc_update_task(uuid, jsonb, integer, text) to authenticated;

-- ============================================================================
-- END 00000000000004_p03b_task_core_hardening.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000005_p03b_reviewer_policy.sql
-- ============================================================================

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

-- ============================================================================
-- END 00000000000005_p03b_reviewer_policy.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000006_p04_recurring_tasks.sql
-- ============================================================================

-- P04: recurring task templates, version-forward schedules and safe materialization.
--
-- Design goals:
--   template -> immutable version snapshot -> target snapshot -> occurrence
--   one occurrence per template/target-key/work-date
--   projected calendar rows remain virtual until this materializer creates an occurrence
--   pause/resume never backfills the paused window
--   unavailable assignees become coverage issues instead of silent assignment/drop

create table public.recurring_task_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  status text not null default 'active'
    check (status in ('active', 'paused', 'ended', 'needs_attention')),
  current_version_number integer not null default 1 check (current_version_number > 0),
  generation_floor_date date not null,
  last_generated_work_date date,
  paused_at timestamptz,
  ended_at timestamptz,
  attention_code text,
  attention_context jsonb not null default '{}'::jsonb
    check (jsonb_typeof(attention_context) = 'object'),
  created_by_member_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((status = 'paused' and paused_at is not null) or status <> 'paused'),
  check ((status = 'ended' and ended_at is not null) or status <> 'ended')
);

create table public.recurring_task_template_versions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_id uuid not null,
  version_number integer not null check (version_number > 0),
  effective_from date not null,
  title text not null check (char_length(trim(title)) between 1 and 240),
  description text not null default '',
  schedule_kind text not null check (schedule_kind in ('working_days', 'every_day', 'weekdays')),
  weekdays smallint[] not null default '{}'::smallint[],
  start_date date not null,
  end_date date,
  due_time time without time zone not null,
  reviewer_member_id uuid,
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  requires_review boolean not null default false,
  requires_result boolean not null default true,
  requires_attachment boolean not null default false,
  allow_no_incident boolean not null default false,
  reminder_profile jsonb not null default '{}'::jsonb
    check (jsonb_typeof(reminder_profile) = 'object'),
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  checklist jsonb not null default '[]'::jsonb check (jsonb_typeof(checklist) = 'array'),
  created_by_member_id uuid not null,
  change_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, template_id, version_number),
  foreign key (organization_id, template_id)
    references public.recurring_task_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, reviewer_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (end_date is null or end_date >= start_date),
  check (
    (schedule_kind = 'weekdays' and cardinality(weekdays) between 1 and 7)
    or (schedule_kind in ('working_days', 'every_day') and cardinality(weekdays) = 0)
  ),
  check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (not requires_review or reviewer_member_id is not null),
  check (version_number = 1 or nullif(trim(change_reason), '') is not null)
);

create table public.recurring_task_targets (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_id uuid not null,
  version_id uuid not null,
  target_key text not null default 'primary'
    check (target_key ~ '^[a-z0-9][a-z0-9_-]{0,39}$'),
  seller_id uuid,
  assignment_mode text not null check (assignment_mode in ('fixed', 'seller_owner')),
  assignee_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, version_id, target_key),
  foreign key (organization_id, template_id)
    references public.recurring_task_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, version_id)
    references public.recurring_task_template_versions(organization_id, id)
    on delete restrict,
  foreign key (organization_id, seller_id)
    references public.sellers(organization_id, id)
    on delete restrict,
  foreign key (organization_id, assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((assignment_mode = 'fixed' and assignee_member_id is not null) or assignment_mode <> 'fixed'),
  check ((assignment_mode = 'seller_owner' and seller_id is not null) or assignment_mode <> 'seller_owner')
);

create table public.recurring_task_occurrences (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  template_id uuid not null,
  version_id uuid not null,
  target_id uuid not null,
  target_key text not null,
  work_date date not null,
  due_at timestamptz not null,
  state text not null default 'pending'
    check (state in ('pending', 'materialized', 'needs_assignment', 'skipped')),
  generation_kind text not null default 'scheduled'
    check (generation_kind in ('scheduled', 'system_delay', 'manual')),
  issue_code text,
  issue_context jsonb not null default '{}'::jsonb
    check (jsonb_typeof(issue_context) = 'object'),
  resolved_assignee_member_id uuid,
  assigned_by_member_id uuid,
  assignment_reason text,
  task_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, template_id, target_key, work_date),
  foreign key (organization_id, template_id)
    references public.recurring_task_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, version_id)
    references public.recurring_task_template_versions(organization_id, id)
    on delete restrict,
  foreign key (organization_id, target_id)
    references public.recurring_task_targets(organization_id, id)
    on delete restrict,
  foreign key (organization_id, resolved_assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, assigned_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (
    (resolved_assignee_member_id is null and assigned_by_member_id is null and assignment_reason is null)
    or (
      resolved_assignee_member_id is not null
      and assigned_by_member_id is not null
      and nullif(trim(assignment_reason), '') is not null
    )
  ),
  check ((state = 'materialized' and task_id is not null) or state <> 'materialized'),
  check ((state in ('needs_assignment', 'skipped') and task_id is null) or state not in ('needs_assignment', 'skipped'))
);

create unique index recurring_occurrences_task_idx
  on public.recurring_task_occurrences(organization_id, task_id)
  where task_id is not null;
create index recurring_versions_template_effective_idx
  on public.recurring_task_template_versions(organization_id, template_id, effective_from desc, version_number desc);
create index recurring_targets_template_version_idx
  on public.recurring_task_targets(organization_id, template_id, version_id, target_key);
create index recurring_occurrences_calendar_idx
  on public.recurring_task_occurrences(organization_id, work_date, state, due_at, id);
create index recurring_occurrences_issue_idx
  on public.recurring_task_occurrences(organization_id, state, work_date, id)
  where state = 'needs_assignment';

alter table public.recurring_task_occurrences
  add constraint recurring_occurrences_task_fk
  foreign key (organization_id, task_id)
  references public.tasks(organization_id, id)
  on delete restrict;

alter table public.tasks
  add constraint tasks_template_occurrence_fk
  foreign key (organization_id, template_occurrence_id)
  references public.recurring_task_occurrences(organization_id, id)
  on delete restrict;

create trigger recurring_task_templates_set_updated_at
before update on public.recurring_task_templates
for each row execute function private.set_updated_at();

create trigger recurring_task_occurrences_set_updated_at
before update on public.recurring_task_occurrences
for each row execute function private.set_updated_at();

create or replace function private.recurring_normalize_weekdays(p_weekdays jsonb)
returns smallint[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_result smallint[];
begin
  if coalesce(jsonb_typeof(p_weekdays), 'array') <> 'array' then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_INVALID';
  end if;

  select coalesce(array_agg(day_value order by day_value), '{}'::smallint[])
    into v_result
  from (
    select distinct
      case when raw_day = 0 then 7 else raw_day end::smallint as day_value
    from (
      select value::integer as raw_day
      from jsonb_array_elements_text(coalesce(p_weekdays, '[]'::jsonb))
    ) as parsed
    where raw_day between 0 and 7
  ) as normalized;

  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_weekdays, '[]'::jsonb)) as item(value)
    where value !~ '^[0-7]$'
  ) then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_INVALID';
  end if;

  return v_result;
end;
$$;

create or replace function private.recurring_schedule_matches(
  p_schedule_kind text,
  p_weekdays smallint[],
  p_start_date date,
  p_end_date date,
  p_work_date date
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_work_date >= p_start_date
    and (p_end_date is null or p_work_date <= p_end_date)
    and case
      when p_schedule_kind = 'every_day' then true
      when p_schedule_kind = 'working_days' then extract(isodow from p_work_date)::integer between 1 and 5
      when p_schedule_kind = 'weekdays' then extract(isodow from p_work_date)::smallint = any(p_weekdays)
      else false
    end;
$$;

create or replace function private.recurring_due_at(
  p_organization_id uuid,
  p_work_date date,
  p_due_time time without time zone
)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select (p_work_date + p_due_time) at time zone o.timezone
  from public.organizations as o
  where o.id = p_organization_id;
$$;

create or replace function private.recurring_member_available_for_work_date(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    left join public.member_hr_settings as hr
      on hr.organization_id = m.organization_id
     and hr.member_id = m.id
    where m.organization_id = p_organization_id
      and m.id = p_member_id
      and m.status = 'active'
      and (hr.member_id is null or hr.employment_start <= p_work_date)
      and (hr.member_id is null or hr.employment_end is null or hr.employment_end >= p_work_date)
      and (
        p_seller_id is null
        or exists (
          select 1
          from public.seller_members as sm
          where sm.organization_id = p_organization_id
            and sm.seller_id = p_seller_id
            and sm.member_id = p_member_id
            and sm.active_from <= p_work_date
            and (sm.active_until is null or sm.active_until >= p_work_date)
        )
      )
      and (
        p_seller_id is null
        or private.is_seller_member(p_organization_id, p_seller_id, p_member_id)
      )
  );
$$;

create or replace function private.recurring_reviewer_available_for_work_date(
  p_organization_id uuid,
  p_seller_id uuid,
  p_reviewer_member_id uuid,
  p_assignee_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_reviewer_member_id is null
    or (
      p_reviewer_member_id <> p_assignee_member_id
      and exists (
        select 1
        from public.organization_members as m
        where m.organization_id = p_organization_id
          and m.id = p_reviewer_member_id
          and m.status = 'active'
          and m.role in ('admin', 'manager')
      )
      and private.recurring_member_available_for_work_date(
        p_organization_id,
        p_seller_id,
        p_reviewer_member_id,
        p_work_date
      )
    );
$$;

create or replace function private.assert_recurring_manager(
  p_organization_id uuid,
  p_seller_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := private.current_member_id(p_organization_id);
  v_role text;
begin
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id and m.id = v_actor_id;

  if v_role = 'admin' then
    return v_actor_id;
  end if;

  if v_role = 'manager'
     and p_seller_id is not null
     and private.is_seller_manager(p_organization_id, p_seller_id, v_actor_id) then
    return v_actor_id;
  end if;

  raise exception using errcode = '42501', message = 'RECURRING_TEMPLATE_MANAGE_DENIED';
end;
$$;

create or replace function private.current_actor_can_read_recurring_template(
  p_organization_id uuid,
  p_template_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin(p_organization_id)
    or exists (
      select 1
      from public.recurring_task_templates as rt
      join public.recurring_task_template_versions as rv
        on rv.organization_id = rt.organization_id
       and rv.template_id = rt.id
       and rv.version_number = rt.current_version_number
      join public.recurring_task_targets as trg
        on trg.organization_id = rv.organization_id
       and trg.version_id = rv.id
      where rt.organization_id = p_organization_id
        and rt.id = p_template_id
        and (
          (trg.seller_id is not null and private.is_seller_member(p_organization_id, trg.seller_id))
          or trg.assignee_member_id = private.current_member_id(p_organization_id)
        )
    );
$$;

create or replace function private.insert_task_from_recurring_occurrence(
  p_occurrence_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occ public.recurring_task_occurrences%rowtype;
  v_template public.recurring_task_templates%rowtype;
  v_version public.recurring_task_template_versions%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_assignee_id uuid;
  v_task_id uuid := extensions.gen_random_uuid();
  v_task_number bigint;
  v_item jsonb;
begin
  select o.* into v_occ
  from public.recurring_task_occurrences as o
  where o.id = p_occurrence_id
  for update;

  if v_occ.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_OCCURRENCE_NOT_FOUND';
  end if;
  if v_occ.task_id is not null then
    return v_occ.task_id;
  end if;

  select t.* into v_template
  from public.recurring_task_templates as t
  where t.organization_id = v_occ.organization_id and t.id = v_occ.template_id;

  select v.* into v_version
  from public.recurring_task_template_versions as v
  where v.organization_id = v_occ.organization_id and v.id = v_occ.version_id;

  select trg.* into v_target
  from public.recurring_task_targets as trg
  where trg.organization_id = v_occ.organization_id and trg.id = v_occ.target_id;

  v_assignee_id := coalesce(v_occ.resolved_assignee_member_id, v_target.assignee_member_id);

  if v_assignee_id is null then
    raise exception using errcode = '23514', message = 'RECURRING_OCCURRENCE_NEEDS_ASSIGNMENT';
  end if;

  perform private.assert_task_member_scope(
    v_occ.organization_id,
    v_target.seller_id,
    v_assignee_id
  );

  if v_version.reviewer_member_id is not null then
    if v_target.seller_id is null then
      raise exception using errcode = '42501', message = 'RECURRING_INTERNAL_REVIEWER_NOT_SUPPORTED';
    end if;
    perform private.assert_task_reviewer_policy(
      v_occ.organization_id,
      v_target.seller_id,
      v_version.reviewer_member_id,
      v_assignee_id
    );
  end if;

  insert into private.task_number_counters (organization_id, next_number)
  values (v_occ.organization_id, 2)
  on conflict (organization_id) do update
    set next_number = private.task_number_counters.next_number + 1
  returning next_number - 1 into v_task_number;

  insert into public.tasks (
    id,
    organization_id,
    task_number,
    seller_id,
    template_occurrence_id,
    title,
    description,
    assignee_member_id,
    created_by_member_id,
    reviewer_member_id,
    priority,
    planned_date,
    original_due_at,
    due_at,
    visible_from,
    requires_review,
    requires_result,
    requires_attachment,
    allow_no_incident,
    reminder_profile,
    estimated_minutes
  )
  values (
    v_task_id,
    v_occ.organization_id,
    v_task_number,
    v_target.seller_id,
    v_occ.id,
    v_version.title,
    v_version.description,
    v_assignee_id,
    v_template.created_by_member_id,
    v_version.reviewer_member_id,
    v_version.priority,
    v_occ.work_date,
    v_occ.due_at,
    v_occ.due_at,
    least(timezone('utc', now()), v_occ.due_at),
    v_version.requires_review,
    v_version.requires_result,
    v_version.requires_attachment,
    v_version.allow_no_incident,
    v_version.reminder_profile,
    v_version.estimated_minutes
  );

  for v_item in select value from jsonb_array_elements(v_version.checklist)
  loop
    if nullif(trim(v_item ->> 'title'), '') is null then
      raise exception using errcode = '22023', message = 'TASK_CHECKLIST_TITLE_REQUIRED';
    end if;

    insert into public.task_checklist_items (
      organization_id,
      task_id,
      title,
      sort_order,
      is_required
    )
    values (
      v_occ.organization_id,
      v_task_id,
      trim(v_item ->> 'title'),
      coalesce((v_item ->> 'sort_order')::integer, 0),
      coalesce((v_item ->> 'is_required')::boolean, true)
    );
  end loop;

  insert into public.task_events (
    organization_id,
    task_id,
    task_version,
    event_type,
    actor_member_id,
    event_payload
  )
  values (
    v_occ.organization_id,
    v_task_id,
    1,
    'created',
    null,
    jsonb_build_object(
      'source', 'recurring_template',
      'template_id', v_occ.template_id,
      'occurrence_id', v_occ.id,
      'work_date', v_occ.work_date,
      'generation_kind', v_occ.generation_kind
    )
  );

  perform private.write_audit(
    v_occ.organization_id,
    'task.generated_from_recurring',
    'task',
    v_task_id,
    jsonb_build_object(
      'template_id', v_occ.template_id,
      'occurrence_id', v_occ.id,
      'task_number', v_task_number
    )
  );

  insert into private.outbox_events (
    organization_id,
    event_type,
    entity_type,
    entity_id,
    dedupe_key,
    payload
  )
  values (
    v_occ.organization_id,
    'task.assigned',
    'task',
    v_task_id,
    'task:' || v_task_id::text || ':assigned:1',
    jsonb_build_object(
      'task_id', v_task_id,
      'assignee_member_id', v_assignee_id,
      'task_version', 1,
      'template_occurrence_id', v_occ.id
    )
  );

  update public.recurring_task_occurrences
  set task_id = v_task_id,
      state = 'materialized',
      issue_code = null,
      issue_context = '{}'::jsonb
  where id = v_occ.id;

  return v_task_id;
end;
$$;

create or replace function public.rpc_create_recurring_template(
  p_organization_id uuid,
  p_definition jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_today date := private.organization_local_date(p_organization_id);
  v_template_id uuid := extensions.gen_random_uuid();
  v_version_id uuid := extensions.gen_random_uuid();
  v_target_id uuid := extensions.gen_random_uuid();
  v_schedule jsonb := coalesce(p_definition -> 'schedule', '{}'::jsonb);
  v_target jsonb := coalesce(p_definition -> 'target', '{}'::jsonb);
  v_kind text := nullif(v_schedule ->> 'kind', '');
  v_weekdays smallint[] := private.recurring_normalize_weekdays(v_schedule -> 'weekdays');
  v_start_date date := nullif(v_schedule ->> 'start_date', '')::date;
  v_end_date date := nullif(v_schedule ->> 'end_date', '')::date;
  v_due_time time := nullif(v_schedule ->> 'due_time', '')::time;
  v_seller_id uuid := nullif(v_target ->> 'seller_id', '')::uuid;
  v_assignment_mode text := coalesce(nullif(v_target ->> 'assignment_mode', ''), 'fixed');
  v_assignee_id uuid := nullif(v_target ->> 'assignee_member_id', '')::uuid;
  v_reviewer_id uuid := nullif(p_definition ->> 'reviewer_member_id', '')::uuid;
  v_replay jsonb;
  v_result jsonb;
begin
  v_actor_id := private.assert_recurring_manager(p_organization_id, v_seller_id);

  v_replay := private.task_idempotency_replay(
    p_organization_id,
    v_actor_id,
    'recurring.create',
    p_idempotency_key,
    p_definition
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if nullif(trim(p_definition ->> 'title'), '') is null
     or v_start_date is null
     or v_due_time is null
     or v_kind not in ('working_days', 'every_day', 'weekdays')
     or v_assignment_mode not in ('fixed', 'seller_owner') then
    raise exception using errcode = '22023', message = 'RECURRING_REQUIRED_FIELDS_MISSING';
  end if;
  if v_end_date is not null and v_end_date < v_start_date then
    raise exception using errcode = '22023', message = 'RECURRING_END_DATE_INVALID';
  end if;
  if v_kind = 'weekdays' and cardinality(v_weekdays) = 0 then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_REQUIRED';
  end if;
  if v_kind <> 'weekdays' then
    v_weekdays := '{}'::smallint[];
  end if;
  if v_assignment_mode = 'fixed' and v_assignee_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNEE_REQUIRED';
  end if;
  if v_assignment_mode = 'seller_owner' and v_seller_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_SELLER_OWNER_REQUIRES_SELLER';
  end if;
  if v_assignment_mode = 'fixed'
     and not private.recurring_member_available_for_work_date(
       p_organization_id,
       v_seller_id,
       v_assignee_id,
       greatest(v_start_date, v_today)
     ) then
    raise exception using errcode = '42501', message = 'RECURRING_ASSIGNEE_UNAVAILABLE';
  end if;
  if v_reviewer_id is not null then
    if v_seller_id is null then
      raise exception using errcode = '42501', message = 'RECURRING_INTERNAL_REVIEWER_NOT_SUPPORTED';
    end if;
    perform private.assert_task_reviewer_policy(
      p_organization_id,
      v_seller_id,
      v_reviewer_id,
      v_assignee_id
    );
  end if;

  insert into public.recurring_task_templates (
    id,
    organization_id,
    status,
    current_version_number,
    generation_floor_date,
    created_by_member_id
  )
  values (
    v_template_id,
    p_organization_id,
    'active',
    1,
    greatest(v_start_date, v_today),
    v_actor_id
  );

  insert into public.recurring_task_template_versions (
    id,
    organization_id,
    template_id,
    version_number,
    effective_from,
    title,
    description,
    schedule_kind,
    weekdays,
    start_date,
    end_date,
    due_time,
    reviewer_member_id,
    priority,
    requires_review,
    requires_result,
    requires_attachment,
    allow_no_incident,
    reminder_profile,
    estimated_minutes,
    checklist,
    created_by_member_id
  )
  values (
    v_version_id,
    p_organization_id,
    v_template_id,
    1,
    greatest(v_start_date, v_today),
    trim(p_definition ->> 'title'),
    coalesce(p_definition ->> 'description', ''),
    v_kind,
    v_weekdays,
    v_start_date,
    v_end_date,
    v_due_time,
    v_reviewer_id,
    coalesce(nullif(p_definition ->> 'priority', ''), 'normal'),
    coalesce((p_definition ->> 'requires_review')::boolean, false),
    coalesce((p_definition ->> 'requires_result')::boolean, true),
    coalesce((p_definition ->> 'requires_attachment')::boolean, false),
    coalesce((p_definition ->> 'allow_no_incident')::boolean, false),
    case when jsonb_typeof(coalesce(p_definition -> 'reminder_profile', '{}'::jsonb)) = 'object'
      then coalesce(p_definition -> 'reminder_profile', '{}'::jsonb) else '{}'::jsonb end,
    nullif(p_definition ->> 'estimated_minutes', '')::integer,
    case when jsonb_typeof(coalesce(p_definition -> 'checklist', '[]'::jsonb)) = 'array'
      then coalesce(p_definition -> 'checklist', '[]'::jsonb) else '[]'::jsonb end,
    v_actor_id
  );

  insert into public.recurring_task_targets (
    id,
    organization_id,
    template_id,
    version_id,
    target_key,
    seller_id,
    assignment_mode,
    assignee_member_id
  )
  values (
    v_target_id,
    p_organization_id,
    v_template_id,
    v_version_id,
    'primary',
    v_seller_id,
    v_assignment_mode,
    v_assignee_id
  );

  perform private.write_audit(
    p_organization_id,
    'recurring_template.created',
    'recurring_task_template',
    v_template_id,
    jsonb_build_object('version_number', 1, 'seller_id', v_seller_id)
  );

  v_result := jsonb_build_object(
    'template_id', v_template_id,
    'version_number', 1,
    'status', 'active',
    'generation_floor_date', greatest(v_start_date, v_today)
  );

  perform private.task_idempotency_store(
    p_organization_id,
    v_actor_id,
    'recurring.create',
    p_idempotency_key,
    p_definition,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_update_recurring_template(
  p_template_id uuid,
  p_definition jsonb,
  p_effective_from date,
  p_reason text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_template public.recurring_task_templates%rowtype;
  v_actor_id uuid;
  v_today date;
  v_version_id uuid := extensions.gen_random_uuid();
  v_target_id uuid := extensions.gen_random_uuid();
  v_next_version integer;
  v_schedule jsonb := coalesce(p_definition -> 'schedule', '{}'::jsonb);
  v_target jsonb := coalesce(p_definition -> 'target', '{}'::jsonb);
  v_kind text := nullif(v_schedule ->> 'kind', '');
  v_weekdays smallint[] := private.recurring_normalize_weekdays(v_schedule -> 'weekdays');
  v_start_date date := nullif(v_schedule ->> 'start_date', '')::date;
  v_end_date date := nullif(v_schedule ->> 'end_date', '')::date;
  v_due_time time := nullif(v_schedule ->> 'due_time', '')::time;
  v_seller_id uuid := nullif(v_target ->> 'seller_id', '')::uuid;
  v_assignment_mode text := coalesce(nullif(v_target ->> 'assignment_mode', ''), 'fixed');
  v_assignee_id uuid := nullif(v_target ->> 'assignee_member_id', '')::uuid;
  v_reviewer_id uuid := nullif(p_definition ->> 'reviewer_member_id', '')::uuid;
  v_replay jsonb;
  v_payload jsonb;
  v_result jsonb;
begin
  select t.* into v_template
  from public.recurring_task_templates as t
  where t.id = p_template_id
  for update;

  if v_template.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_TEMPLATE_NOT_FOUND';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'RECURRING_CHANGE_REASON_REQUIRED';
  end if;

  v_actor_id := private.assert_recurring_manager(v_template.organization_id, v_seller_id);
  v_payload := jsonb_build_object(
    'definition', p_definition,
    'effective_from', p_effective_from,
    'reason', p_reason,
    'expected_version', p_expected_version
  );
  v_replay := private.task_idempotency_replay(
    v_template.organization_id,
    v_actor_id,
    'recurring.update',
    p_idempotency_key,
    v_payload
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if v_template.status = 'ended' then
    raise exception using errcode = '23514', message = 'RECURRING_TEMPLATE_ENDED';
  end if;
  if p_expected_version is null or p_expected_version <> v_template.version then
    raise exception using errcode = '40001', message = 'RECURRING_VERSION_CONFLICT';
  end if;

  v_today := private.organization_local_date(v_template.organization_id);
  if p_effective_from is null or p_effective_from < v_today then
    raise exception using errcode = '22023', message = 'RECURRING_EFFECTIVE_DATE_INVALID';
  end if;

  if nullif(trim(p_definition ->> 'title'), '') is null
     or v_start_date is null
     or v_due_time is null
     or v_kind not in ('working_days', 'every_day', 'weekdays')
     or v_assignment_mode not in ('fixed', 'seller_owner') then
    raise exception using errcode = '22023', message = 'RECURRING_REQUIRED_FIELDS_MISSING';
  end if;
  if v_end_date is not null and v_end_date < v_start_date then
    raise exception using errcode = '22023', message = 'RECURRING_END_DATE_INVALID';
  end if;
  if v_kind = 'weekdays' and cardinality(v_weekdays) = 0 then
    raise exception using errcode = '22023', message = 'RECURRING_WEEKDAYS_REQUIRED';
  end if;
  if v_kind <> 'weekdays' then
    v_weekdays := '{}'::smallint[];
  end if;
  if v_assignment_mode = 'fixed' and v_assignee_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNEE_REQUIRED';
  end if;
  if v_assignment_mode = 'seller_owner' and v_seller_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_SELLER_OWNER_REQUIRES_SELLER';
  end if;
  if v_assignment_mode = 'fixed'
     and not private.recurring_member_available_for_work_date(
       v_template.organization_id,
       v_seller_id,
       v_assignee_id,
       greatest(v_start_date, p_effective_from)
     ) then
    raise exception using errcode = '42501', message = 'RECURRING_ASSIGNEE_UNAVAILABLE';
  end if;
  if v_reviewer_id is not null then
    if v_seller_id is null then
      raise exception using errcode = '42501', message = 'RECURRING_INTERNAL_REVIEWER_NOT_SUPPORTED';
    end if;
    perform private.assert_task_reviewer_policy(
      v_template.organization_id,
      v_seller_id,
      v_reviewer_id,
      v_assignee_id
    );
  end if;

  v_next_version := v_template.current_version_number + 1;

  insert into public.recurring_task_template_versions (
    id, organization_id, template_id, version_number, effective_from,
    title, description, schedule_kind, weekdays, start_date, end_date, due_time,
    reviewer_member_id, priority, requires_review, requires_result, requires_attachment,
    allow_no_incident, reminder_profile, estimated_minutes, checklist,
    created_by_member_id, change_reason
  ) values (
    v_version_id, v_template.organization_id, v_template.id, v_next_version, p_effective_from,
    trim(p_definition ->> 'title'), coalesce(p_definition ->> 'description', ''),
    v_kind, v_weekdays, v_start_date, v_end_date, v_due_time,
    v_reviewer_id, coalesce(nullif(p_definition ->> 'priority', ''), 'normal'),
    coalesce((p_definition ->> 'requires_review')::boolean, false),
    coalesce((p_definition ->> 'requires_result')::boolean, true),
    coalesce((p_definition ->> 'requires_attachment')::boolean, false),
    coalesce((p_definition ->> 'allow_no_incident')::boolean, false),
    case when jsonb_typeof(coalesce(p_definition -> 'reminder_profile', '{}'::jsonb)) = 'object'
      then coalesce(p_definition -> 'reminder_profile', '{}'::jsonb) else '{}'::jsonb end,
    nullif(p_definition ->> 'estimated_minutes', '')::integer,
    case when jsonb_typeof(coalesce(p_definition -> 'checklist', '[]'::jsonb)) = 'array'
      then coalesce(p_definition -> 'checklist', '[]'::jsonb) else '[]'::jsonb end,
    v_actor_id,
    trim(p_reason)
  );

  insert into public.recurring_task_targets (
    id, organization_id, template_id, version_id, target_key,
    seller_id, assignment_mode, assignee_member_id
  ) values (
    v_target_id, v_template.organization_id, v_template.id, v_version_id, 'primary',
    v_seller_id, v_assignment_mode, v_assignee_id
  );

  update public.recurring_task_templates
  set current_version_number = v_next_version,
      version = version + 1,
      attention_code = null,
      attention_context = '{}'::jsonb,
      status = case when status = 'needs_attention' then 'active' else status end
  where id = v_template.id;

  perform private.write_audit(
    v_template.organization_id,
    'recurring_template.version_created',
    'recurring_task_template',
    v_template.id,
    jsonb_build_object(
      'version_number', v_next_version,
      'effective_from', p_effective_from,
      'reason', trim(p_reason)
    )
  );

  v_result := jsonb_build_object(
    'template_id', v_template.id,
    'version_number', v_next_version,
    'status', case when v_template.status = 'needs_attention' then 'active' else v_template.status end,
    'version', v_template.version + 1
  );

  perform private.task_idempotency_store(
    v_template.organization_id,
    v_actor_id,
    'recurring.update',
    p_idempotency_key,
    v_payload,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_recurring_template_command(
  p_template_id uuid,
  p_command text,
  p_reason text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_template public.recurring_task_templates%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_actor_id uuid;
  v_today date;
  v_payload jsonb;
  v_replay jsonb;
  v_status text;
  v_result jsonb;
begin
  select t.* into v_template
  from public.recurring_task_templates as t
  where t.id = p_template_id
  for update;

  if v_template.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_TEMPLATE_NOT_FOUND';
  end if;
  if p_command not in ('pause', 'resume', 'end') then
    raise exception using errcode = '22023', message = 'RECURRING_COMMAND_INVALID';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'RECURRING_COMMAND_REASON_REQUIRED';
  end if;

  select trg.* into v_target
  from public.recurring_task_template_versions as rv
  join public.recurring_task_targets as trg
    on trg.organization_id = rv.organization_id and trg.version_id = rv.id
  where rv.organization_id = v_template.organization_id
    and rv.template_id = v_template.id
    and rv.version_number = v_template.current_version_number
    and trg.target_key = 'primary';

  v_actor_id := private.assert_recurring_manager(v_template.organization_id, v_target.seller_id);
  v_today := private.organization_local_date(v_template.organization_id);
  v_payload := jsonb_build_object(
    'template_id', p_template_id,
    'command', p_command,
    'reason', p_reason,
    'expected_version', p_expected_version
  );
  v_replay := private.task_idempotency_replay(
    v_template.organization_id,
    v_actor_id,
    'recurring.command.' || p_command,
    p_idempotency_key,
    v_payload
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if p_expected_version is null or p_expected_version <> v_template.version then
    raise exception using errcode = '40001', message = 'RECURRING_VERSION_CONFLICT';
  end if;

  if p_command = 'pause' then
    if v_template.status not in ('active', 'needs_attention') then
      raise exception using errcode = '23514', message = 'RECURRING_PAUSE_STATE_INVALID';
    end if;
    v_status := 'paused';
    update public.recurring_task_templates
    set status = 'paused',
        paused_at = timezone('utc', now()),
        attention_code = null,
        attention_context = '{}'::jsonb,
        version = version + 1
    where id = v_template.id;
  elsif p_command = 'resume' then
    if v_template.status <> 'paused' then
      raise exception using errcode = '23514', message = 'RECURRING_RESUME_STATE_INVALID';
    end if;
    v_status := 'active';
    update public.recurring_task_templates
    set status = 'active',
        paused_at = null,
        generation_floor_date = greatest(generation_floor_date, v_today),
        attention_code = null,
        attention_context = '{}'::jsonb,
        version = version + 1
    where id = v_template.id;
  else
    if v_template.status = 'ended' then
      raise exception using errcode = '23514', message = 'RECURRING_END_STATE_INVALID';
    end if;
    v_status := 'ended';
    update public.recurring_task_templates
    set status = 'ended',
        paused_at = null,
        ended_at = timezone('utc', now()),
        attention_code = null,
        attention_context = '{}'::jsonb,
        version = version + 1
    where id = v_template.id;
  end if;

  perform private.write_audit(
    v_template.organization_id,
    'recurring_template.' || p_command,
    'recurring_task_template',
    v_template.id,
    jsonb_build_object('reason', trim(p_reason))
  );

  v_result := jsonb_build_object(
    'template_id', v_template.id,
    'status', v_status,
    'version', v_template.version + 1,
    'generation_floor_date', case when p_command = 'resume'
      then greatest(v_template.generation_floor_date, v_today)
      else v_template.generation_floor_date end
  );

  perform private.task_idempotency_store(
    v_template.organization_id,
    v_actor_id,
    'recurring.command.' || p_command,
    p_idempotency_key,
    v_payload,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_assign_recurring_occurrence(
  p_occurrence_id uuid,
  p_assignee_member_id uuid,
  p_reason text,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_occ public.recurring_task_occurrences%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_version public.recurring_task_template_versions%rowtype;
  v_actor_id uuid;
  v_task_id uuid;
  v_payload jsonb;
  v_replay jsonb;
  v_result jsonb;
begin
  if p_assignee_member_id is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNEE_REQUIRED';
  end if;
  if nullif(trim(p_reason), '') is null then
    raise exception using errcode = '22023', message = 'RECURRING_ASSIGNMENT_REASON_REQUIRED';
  end if;

  select occ.* into v_occ
  from public.recurring_task_occurrences as occ
  where occ.id = p_occurrence_id
  for update;

  if v_occ.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_OCCURRENCE_NOT_FOUND';
  end if;

  select trg.* into v_target
  from public.recurring_task_targets as trg
  where trg.organization_id = v_occ.organization_id
    and trg.id = v_occ.target_id;

  select rv.* into v_version
  from public.recurring_task_template_versions as rv
  where rv.organization_id = v_occ.organization_id
    and rv.id = v_occ.version_id;

  v_actor_id := private.assert_recurring_manager(v_occ.organization_id, v_target.seller_id);
  v_payload := jsonb_build_object(
    'occurrence_id', p_occurrence_id,
    'assignee_member_id', p_assignee_member_id,
    'reason', p_reason
  );
  v_replay := private.task_idempotency_replay(
    v_occ.organization_id,
    v_actor_id,
    'recurring.assign_occurrence',
    p_idempotency_key,
    v_payload
  );
  if v_replay is not null then
    return v_replay;
  end if;

  if v_occ.state <> 'needs_assignment' or v_occ.task_id is not null then
    raise exception using errcode = '23514', message = 'RECURRING_OCCURRENCE_ASSIGNMENT_STATE_INVALID';
  end if;

  if not private.recurring_member_available_for_work_date(
    v_occ.organization_id,
    v_target.seller_id,
    p_assignee_member_id,
    v_occ.work_date
  ) then
    raise exception using errcode = '42501', message = 'RECURRING_ASSIGNEE_UNAVAILABLE';
  end if;

  if not private.recurring_reviewer_available_for_work_date(
    v_occ.organization_id,
    v_target.seller_id,
    v_version.reviewer_member_id,
    p_assignee_member_id,
    v_occ.work_date
  ) then
    raise exception using errcode = '42501', message = 'RECURRING_REVIEWER_UNAVAILABLE';
  end if;

  update public.recurring_task_occurrences
  set resolved_assignee_member_id = p_assignee_member_id,
      assigned_by_member_id = v_actor_id,
      assignment_reason = trim(p_reason)
  where id = v_occ.id;

  v_task_id := private.insert_task_from_recurring_occurrence(v_occ.id);

  update public.recurring_task_templates as rt
  set status = 'active',
      attention_code = null,
      attention_context = '{}'::jsonb
  where rt.organization_id = v_occ.organization_id
    and rt.id = v_occ.template_id
    and rt.status = 'needs_attention'
    and rt.attention_code in ('SELLER_COVERAGE_REQUIRED', 'ASSIGNEE_UNAVAILABLE')
    and not exists (
      select 1
      from public.recurring_task_occurrences as pending_issue
      where pending_issue.organization_id = rt.organization_id
        and pending_issue.template_id = rt.id
        and pending_issue.state = 'needs_assignment'
    );

  perform private.write_audit(
    v_occ.organization_id,
    'recurring_occurrence.assigned',
    'recurring_task_occurrence',
    v_occ.id,
    jsonb_build_object(
      'assignee_member_id', p_assignee_member_id,
      'assigned_by_member_id', v_actor_id,
      'reason', trim(p_reason),
      'task_id', v_task_id
    )
  );

  v_result := jsonb_build_object(
    'occurrence_id', v_occ.id,
    'task_id', v_task_id,
    'state', 'materialized',
    'assignee_member_id', p_assignee_member_id
  );

  perform private.task_idempotency_store(
    v_occ.organization_id,
    v_actor_id,
    'recurring.assign_occurrence',
    p_idempotency_key,
    v_payload,
    v_result
  );

  return v_result;
end;
$$;

create or replace function public.rpc_list_recurring_templates(
  p_organization_id uuid,
  p_include_ended boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(row_data order by row_data ->> 'title'), '[]'::jsonb)
  from (
    select jsonb_build_object(
      'id', rt.id,
      'status', rt.status,
      'version', rt.version,
      'current_version_number', rt.current_version_number,
      'generation_floor_date', rt.generation_floor_date,
      'last_generated_work_date', rt.last_generated_work_date,
      'attention_code', rt.attention_code,
      'attention_context', rt.attention_context,
      'title', rv.title,
      'description', rv.description,
      'schedule', jsonb_build_object(
        'kind', rv.schedule_kind,
        'weekdays', rv.weekdays,
        'start_date', rv.start_date,
        'end_date', rv.end_date,
        'due_time', to_char(rv.due_time, 'HH24:MI')
      ),
      'target', jsonb_build_object(
        'seller_id', trg.seller_id,
        'seller_name', s.name,
        'assignment_mode', trg.assignment_mode,
        'assignee_member_id', trg.assignee_member_id,
        'assignee_name', assignee.display_name
      ),
      'open_assignment_issues', (
        select count(*)
        from public.recurring_task_occurrences as occ
        where occ.organization_id = rt.organization_id
          and occ.template_id = rt.id
          and occ.state = 'needs_assignment'
      )
    ) as row_data
    from public.recurring_task_templates as rt
    join public.recurring_task_template_versions as rv
      on rv.organization_id = rt.organization_id
     and rv.template_id = rt.id
     and rv.version_number = rt.current_version_number
    join public.recurring_task_targets as trg
      on trg.organization_id = rv.organization_id
     and trg.version_id = rv.id
     and trg.target_key = 'primary'
    left join public.sellers as s
      on s.organization_id = trg.organization_id and s.id = trg.seller_id
    left join public.organization_members as assignee
      on assignee.organization_id = trg.organization_id and assignee.id = trg.assignee_member_id
    where rt.organization_id = p_organization_id
      and (p_include_ended or rt.status <> 'ended')
      and private.current_actor_can_read_recurring_template(rt.organization_id, rt.id)
  ) as rows;
$$;

create or replace function public.rpc_get_recurring_template(p_template_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_template public.recurring_task_templates%rowtype;
  v_result jsonb;
begin
  select rt.* into v_template
  from public.recurring_task_templates as rt
  where rt.id = p_template_id;

  if v_template.id is null then
    raise exception using errcode = '22023', message = 'RECURRING_TEMPLATE_NOT_FOUND';
  end if;
  if not private.current_actor_can_read_recurring_template(v_template.organization_id, v_template.id) then
    raise exception using errcode = '42501', message = 'RECURRING_TEMPLATE_READ_DENIED';
  end if;

  select jsonb_build_object(
    'id', v_template.id,
    'organization_id', v_template.organization_id,
    'status', v_template.status,
    'version', v_template.version,
    'generation_floor_date', v_template.generation_floor_date,
    'last_generated_work_date', v_template.last_generated_work_date,
    'attention_code', v_template.attention_code,
    'attention_context', v_template.attention_context,
    'versions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', rv.id,
          'version_number', rv.version_number,
          'effective_from', rv.effective_from,
          'title', rv.title,
          'description', rv.description,
          'schedule_kind', rv.schedule_kind,
          'weekdays', rv.weekdays,
          'start_date', rv.start_date,
          'end_date', rv.end_date,
          'due_time', to_char(rv.due_time, 'HH24:MI'),
          'change_reason', rv.change_reason,
          'target', jsonb_build_object(
            'seller_id', trg.seller_id,
            'assignment_mode', trg.assignment_mode,
            'assignee_member_id', trg.assignee_member_id
          )
        ) order by rv.version_number
      )
      from public.recurring_task_template_versions as rv
      join public.recurring_task_targets as trg
        on trg.organization_id = rv.organization_id
       and trg.version_id = rv.id
       and trg.target_key = 'primary'
      where rv.organization_id = v_template.organization_id
        and rv.template_id = v_template.id
    ), '[]'::jsonb),
    'recent_occurrences', coalesce((
      select jsonb_agg(occurrence_row order by occurrence_row ->> 'work_date' desc)
      from (
        select jsonb_build_object(
          'id', occ.id,
          'work_date', occ.work_date,
          'due_at', occ.due_at,
          'state', occ.state,
          'generation_kind', occ.generation_kind,
          'issue_code', occ.issue_code,
          'issue_context', occ.issue_context,
          'task_id', occ.task_id
        ) as occurrence_row
        from public.recurring_task_occurrences as occ
        where occ.organization_id = v_template.organization_id
          and occ.template_id = v_template.id
        order by occ.work_date desc, occ.id desc
        limit 30
      ) as recent
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

create or replace function private.materialize_recurring_occurrences(
  p_organization_id uuid,
  p_through_date date,
  p_catchup_limit integer default 7
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_today date := private.organization_local_date(p_organization_id);
  v_window_start date;
  v_template public.recurring_task_templates%rowtype;
  v_version public.recurring_task_template_versions%rowtype;
  v_target public.recurring_task_targets%rowtype;
  v_work_date date;
  v_occurrence_id uuid;
  v_due_at timestamptz;
  v_generation_kind text;
  v_created integer := 0;
  v_materialized integer := 0;
  v_issues integer := 0;
  v_delayed_templates integer := 0;
begin
  if p_through_date is null or p_through_date > v_today then
    raise exception using errcode = '22023', message = 'RECURRING_THROUGH_DATE_INVALID';
  end if;
  if p_catchup_limit is null or p_catchup_limit < 1 or p_catchup_limit > 31 then
    raise exception using errcode = '22023', message = 'RECURRING_CATCHUP_LIMIT_INVALID';
  end if;

  for v_template in
    select rt.*
    from public.recurring_task_templates as rt
    where rt.organization_id = p_organization_id
      and rt.status in ('active', 'needs_attention')
    order by rt.created_at, rt.id
  loop
    v_window_start := greatest(
      v_template.generation_floor_date,
      p_through_date - (p_catchup_limit - 1)
    );

    if v_template.generation_floor_date < p_through_date - (p_catchup_limit - 1)
       and coalesce(v_template.last_generated_work_date, v_template.generation_floor_date - 1)
           < p_through_date - (p_catchup_limit - 1) then
      update public.recurring_task_templates
      set status = 'needs_attention',
          attention_code = 'SYSTEM_DELAY_CATCHUP_LIMITED',
          attention_context = jsonb_build_object(
            'requested_through_date', p_through_date,
            'catchup_limit_days', p_catchup_limit,
            'window_start', v_window_start
          )
      where id = v_template.id;
      v_delayed_templates := v_delayed_templates + 1;
    end if;

    for v_work_date in
      select d::date
      from generate_series(v_window_start, p_through_date, interval '1 day') as d
    loop
      select rv.* into v_version
      from public.recurring_task_template_versions as rv
      where rv.organization_id = v_template.organization_id
        and rv.template_id = v_template.id
        and rv.effective_from <= v_work_date
      order by rv.effective_from desc, rv.version_number desc
      limit 1;

      if v_version.id is null
         or not private.recurring_schedule_matches(
           v_version.schedule_kind,
           v_version.weekdays,
           v_version.start_date,
           v_version.end_date,
           v_work_date
         ) then
        continue;
      end if;

      for v_target in
        select trg.*
        from public.recurring_task_targets as trg
        where trg.organization_id = v_template.organization_id
          and trg.template_id = v_template.id
          and trg.version_id = v_version.id
        order by trg.target_key, trg.id
      loop
        v_due_at := private.recurring_due_at(v_template.organization_id, v_work_date, v_version.due_time);
        v_generation_kind := case when v_work_date < v_today then 'system_delay' else 'scheduled' end;
        v_occurrence_id := extensions.gen_random_uuid();

        insert into public.recurring_task_occurrences (
          id, organization_id, template_id, version_id, target_id, target_key,
          work_date, due_at, state, generation_kind
        ) values (
          v_occurrence_id, v_template.organization_id, v_template.id, v_version.id,
          v_target.id, v_target.target_key, v_work_date, v_due_at, 'pending', v_generation_kind
        )
        on conflict (organization_id, template_id, target_key, work_date) do nothing;

        if not found then
          continue;
        end if;
        v_created := v_created + 1;

        if v_target.assignment_mode = 'seller_owner' then
          update public.recurring_task_occurrences
          set state = 'needs_assignment',
              issue_code = 'SELLER_COVERAGE_REQUIRED',
              issue_context = jsonb_build_object(
                'seller_id', v_target.seller_id,
                'reason', 'Roster/coverage owner must be selected explicitly'
              )
          where id = v_occurrence_id;
          update public.recurring_task_templates
          set status = 'needs_attention',
              attention_code = 'SELLER_COVERAGE_REQUIRED',
              attention_context = jsonb_build_object('occurrence_id', v_occurrence_id, 'work_date', v_work_date)
          where id = v_template.id;
          insert into private.outbox_events (
            organization_id, event_type, entity_type, entity_id, dedupe_key, payload
          ) values (
            v_template.organization_id,
            'recurring.assignment_needed',
            'recurring_task_occurrence',
            v_occurrence_id,
            'recurring:' || v_occurrence_id::text || ':assignment-needed',
            jsonb_build_object('template_id', v_template.id, 'work_date', v_work_date, 'seller_id', v_target.seller_id)
          ) on conflict (organization_id, dedupe_key) do nothing;
          v_issues := v_issues + 1;
          continue;
        end if;

        if not private.recurring_member_available_for_work_date(
          v_template.organization_id,
          v_target.seller_id,
          v_target.assignee_member_id,
          v_work_date
        ) then
          update public.recurring_task_occurrences
          set state = 'needs_assignment',
              issue_code = 'ASSIGNEE_UNAVAILABLE',
              issue_context = jsonb_build_object(
                'assignee_member_id', v_target.assignee_member_id,
                'seller_id', v_target.seller_id,
                'work_date', v_work_date
              )
          where id = v_occurrence_id;
          update public.recurring_task_templates
          set status = 'needs_attention',
              attention_code = 'ASSIGNEE_UNAVAILABLE',
              attention_context = jsonb_build_object('occurrence_id', v_occurrence_id, 'work_date', v_work_date)
          where id = v_template.id;
          insert into private.outbox_events (
            organization_id, event_type, entity_type, entity_id, dedupe_key, payload
          ) values (
            v_template.organization_id,
            'recurring.assignment_needed',
            'recurring_task_occurrence',
            v_occurrence_id,
            'recurring:' || v_occurrence_id::text || ':assignment-needed',
            jsonb_build_object(
              'template_id', v_template.id,
              'work_date', v_work_date,
              'assignee_member_id', v_target.assignee_member_id,
              'seller_id', v_target.seller_id
            )
          ) on conflict (organization_id, dedupe_key) do nothing;
          v_issues := v_issues + 1;
          continue;
        end if;

        if not private.recurring_reviewer_available_for_work_date(
          v_template.organization_id,
          v_target.seller_id,
          v_version.reviewer_member_id,
          v_target.assignee_member_id,
          v_work_date
        ) then
          update public.recurring_task_occurrences
          set state = 'needs_assignment',
              issue_code = 'REVIEWER_UNAVAILABLE',
              issue_context = jsonb_build_object(
                'reviewer_member_id', v_version.reviewer_member_id,
                'work_date', v_work_date
              )
          where id = v_occurrence_id;
          update public.recurring_task_templates
          set status = 'needs_attention',
              attention_code = 'REVIEWER_UNAVAILABLE',
              attention_context = jsonb_build_object('occurrence_id', v_occurrence_id, 'work_date', v_work_date)
          where id = v_template.id;
          v_issues := v_issues + 1;
          continue;
        end if;

        perform private.insert_task_from_recurring_occurrence(v_occurrence_id);
        v_materialized := v_materialized + 1;
      end loop;
    end loop;

    update public.recurring_task_templates
    set last_generated_work_date = greatest(coalesce(last_generated_work_date, v_window_start), p_through_date)
    where id = v_template.id;
  end loop;

  return jsonb_build_object(
    'organization_id', p_organization_id,
    'through_date', p_through_date,
    'created_occurrences', v_created,
    'materialized_tasks', v_materialized,
    'assignment_issues', v_issues,
    'delayed_templates', v_delayed_templates
  );
end;
$$;

revoke all on function private.recurring_normalize_weekdays(jsonb) from public, anon, authenticated;
revoke all on function private.recurring_schedule_matches(text, smallint[], date, date, date) from public, anon, authenticated;
revoke all on function private.recurring_due_at(uuid, date, time without time zone) from public, anon, authenticated;
revoke all on function private.recurring_member_available_for_work_date(uuid, uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.recurring_reviewer_available_for_work_date(uuid, uuid, uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.assert_recurring_manager(uuid, uuid) from public, anon, authenticated;
revoke all on function private.insert_task_from_recurring_occurrence(uuid) from public, anon, authenticated;
revoke all on function private.materialize_recurring_occurrences(uuid, date, integer) from public, anon, authenticated;

revoke all on function private.current_actor_can_read_recurring_template(uuid, uuid) from public, anon;
grant execute on function private.current_actor_can_read_recurring_template(uuid, uuid) to authenticated;
grant execute on function private.materialize_recurring_occurrences(uuid, date, integer) to service_role;

revoke all on function public.rpc_create_recurring_template(uuid, jsonb, text) from public, anon;
revoke all on function public.rpc_update_recurring_template(uuid, jsonb, date, text, integer, text) from public, anon;
revoke all on function public.rpc_recurring_template_command(uuid, text, text, integer, text) from public, anon;
revoke all on function public.rpc_assign_recurring_occurrence(uuid, uuid, text, text) from public, anon;
revoke all on function public.rpc_list_recurring_templates(uuid, boolean) from public, anon;
revoke all on function public.rpc_get_recurring_template(uuid) from public, anon;

grant execute on function public.rpc_create_recurring_template(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_update_recurring_template(uuid, jsonb, date, text, integer, text) to authenticated;
grant execute on function public.rpc_recurring_template_command(uuid, text, text, integer, text) to authenticated;
grant execute on function public.rpc_assign_recurring_occurrence(uuid, uuid, text, text) to authenticated;
grant execute on function public.rpc_list_recurring_templates(uuid, boolean) to authenticated;
grant execute on function public.rpc_get_recurring_template(uuid) to authenticated;

alter table public.recurring_task_templates enable row level security;
alter table public.recurring_task_template_versions enable row level security;
alter table public.recurring_task_targets enable row level security;
alter table public.recurring_task_occurrences enable row level security;

create policy recurring_templates_read_by_scope
on public.recurring_task_templates
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, id));

create policy recurring_versions_read_by_scope
on public.recurring_task_template_versions
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, template_id));

create policy recurring_targets_read_by_scope
on public.recurring_task_targets
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, template_id));

create policy recurring_occurrences_read_by_scope
on public.recurring_task_occurrences
for select to authenticated
using (private.current_actor_can_read_recurring_template(organization_id, template_id));

revoke all on public.recurring_task_templates from anon;
revoke all on public.recurring_task_template_versions from anon;
revoke all on public.recurring_task_targets from anon;
revoke all on public.recurring_task_occurrences from anon;

grant select on public.recurring_task_templates to authenticated;
grant select on public.recurring_task_template_versions to authenticated;
grant select on public.recurring_task_targets to authenticated;
grant select on public.recurring_task_occurrences to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.recurring_task_templates,
   public.recurring_task_template_versions,
   public.recurring_task_targets,
   public.recurring_task_occurrences
from authenticated;

-- ============================================================================
-- END 00000000000006_p04_recurring_tasks.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000007_p05_hr_requests.sql
-- ============================================================================

-- P05: work schedules, leave types, employee requests and HR approval boundaries.
--
-- This migration intentionally models time as shift snapshots and approved request segments.
-- Attendance events are deferred to P06; a correction remains a reviewed claim here.

create table public.offices (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 1 and 160),
  timezone text not null,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, name)
);

create table public.shift_templates (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  office_id uuid,
  name text not null check (char_length(trim(name)) between 1 and 160),
  start_local time without time zone not null,
  end_local time without time zone not null,
  end_day_offset smallint not null default 0 check (end_day_offset in (0, 1)),
  breaks jsonb not null default '[]'::jsonb check (jsonb_typeof(breaks) = 'array'),
  allowed_mode text not null default 'office' check (allowed_mode in ('office', 'remote', 'hybrid')),
  standard_day_minutes integer not null default 480 check (standard_day_minutes between 1 and 1440),
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, name),
  foreign key (organization_id, office_id)
    references public.offices(organization_id, id)
    on delete restrict,
  check (end_day_offset = 1 or end_local > start_local)
);

create table public.shift_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  shift_template_id uuid not null,
  weekdays smallint[] not null,
  effective_from date not null,
  effective_until date,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_template_id)
    references public.shift_templates(organization_id, id)
    on delete restrict,
  check (cardinality(weekdays) between 1 and 7),
  check (weekdays <@ array[1,2,3,4,5,6,7]::smallint[]),
  check (effective_until is null or effective_until >= effective_from)
);

create table public.calendar_overrides (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid,
  work_date date not null,
  kind text not null check (kind in ('nonworking', 'custom_shift', 'paid_holiday')),
  shift_template_id uuid,
  paid_credit_policy jsonb check (paid_credit_policy is null or jsonb_typeof(paid_credit_policy) = 'object'),
  reason text not null check (char_length(trim(reason)) between 1 and 500),
  created_by_member_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique nulls not distinct (organization_id, member_id, work_date),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_template_id)
    references public.shift_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check ((kind = 'custom_shift' and shift_template_id is not null) or kind <> 'custom_shift')
);

create table public.shift_instances (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  template_id uuid,
  work_date date not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  working_segments jsonb not null check (jsonb_typeof(working_segments) = 'array'),
  scheduled_seconds bigint not null check (scheduled_seconds >= 0),
  standard_day_minutes integer not null check (standard_day_minutes between 1 and 1440),
  allowed_mode text not null check (allowed_mode in ('office', 'remote', 'hybrid')),
  office_id uuid,
  policy_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(policy_snapshot) = 'object'),
  status text not null default 'scheduled' check (status in ('scheduled', 'canceled', 'closed')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, member_id, work_date),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, template_id)
    references public.shift_templates(organization_id, id)
    on delete restrict,
  foreign key (organization_id, office_id)
    references public.offices(organization_id, id)
    on delete restrict,
  check (ends_at > starts_at)
);

alter table public.shift_instances
  add constraint shift_instances_no_active_overlap
  exclude using gist (
    organization_id with =,
    member_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'scheduled');

create table public.leave_types (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  code text not null check (code = upper(trim(code)) and char_length(code) between 2 and 40),
  name text not null check (char_length(trim(name)) between 1 and 160),
  pay_treatment text not null check (pay_treatment in ('paid', 'unpaid', 'pending_hr')),
  consumes_balance boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, code)
);

create table public.employee_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  request_type text not null check (request_type in ('leave', 'early_leave', 'late_arrival', 'remote_work', 'attendance_correction', 'cancel_approved_request')),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'withdrawn', 'canceled')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  leave_type_id uuid,
  pay_treatment_snapshot text not null default 'not_applicable'
    check (pay_treatment_snapshot in ('paid', 'unpaid', 'pending_hr', 'not_applicable')),
  reason_private text not null check (char_length(trim(reason_private)) between 10 and 2000),
  handover_note text,
  target_request_id uuid,
  correction_payload jsonb check (correction_payload is null or jsonb_typeof(correction_payload) = 'object'),
  submitted_at timestamptz not null default timezone('utc', now()),
  decided_at timestamptz,
  decided_by_member_id uuid,
  decision_reason_private text,
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, member_id, idempotency_key),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, leave_type_id)
    references public.leave_types(organization_id, id)
    on delete restrict,
  foreign key (organization_id, target_request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, decided_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (ends_at > starts_at),
  check ((status = 'pending' and decided_at is null and decided_by_member_id is null) or status <> 'pending'),
  check ((request_type in ('leave', 'early_leave', 'late_arrival') and leave_type_id is not null) or request_type not in ('leave', 'early_leave', 'late_arrival')),
  check ((request_type = 'attendance_correction' and correction_payload is not null) or request_type <> 'attendance_correction')
);

create table public.request_segments (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_id uuid not null,
  shift_instance_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  affected_seconds bigint not null check (affected_seconds >= 0),
  pay_treatment_snapshot text not null check (pay_treatment_snapshot in ('paid', 'unpaid', 'pending_hr', 'not_applicable')),
  leave_type_version integer,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, request_id, shift_instance_id),
  foreign key (organization_id, request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_instance_id)
    references public.shift_instances(organization_id, id)
    on delete restrict,
  check (ends_at > starts_at)
);

create table public.request_decisions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_id uuid not null,
  decision text not null check (decision in ('approved', 'rejected', 'withdrawn', 'canceled')),
  actor_member_id uuid not null,
  reason_private text,
  before_state jsonb not null check (jsonb_typeof(before_state) = 'object'),
  after_state jsonb not null check (jsonb_typeof(after_state) = 'object'),
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  recorded_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, request_id, idempotency_key),
  foreign key (organization_id, request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.leave_balance_entries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  leave_type_id uuid not null,
  delta_seconds bigint not null,
  effective_date date not null,
  source_request_id uuid,
  reason text not null check (char_length(trim(reason)) between 1 and 500),
  created_by_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, source_request_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, leave_type_id)
    references public.leave_types(organization_id, id)
    on delete restrict,
  foreign key (organization_id, source_request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.task_handover_actions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  request_id uuid not null,
  task_id uuid,
  occurrence_id uuid,
  action text not null default 'pending' check (action in ('pending', 'reassign', 'reschedule', 'waive', 'keep')),
  new_assignee_member_id uuid,
  new_planned_date date,
  new_due_at timestamptz,
  reason text,
  resolved_by_member_id uuid,
  resolved_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, request_id, task_id),
  unique (organization_id, request_id, occurrence_id),
  foreign key (organization_id, request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, occurrence_id)
    references public.recurring_task_occurrences(organization_id, id)
    on delete restrict,
  foreign key (organization_id, new_assignee_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, resolved_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (num_nonnulls(task_id, occurrence_id) = 1),
  check ((action = 'pending' and resolved_at is null and resolved_by_member_id is null) or action <> 'pending')
);

create index shift_instances_member_work_date_idx
  on public.shift_instances(organization_id, member_id, work_date, status);
create index employee_requests_member_period_idx
  on public.employee_requests(organization_id, member_id, status, starts_at, ends_at);
create index employee_requests_approval_queue_idx
  on public.employee_requests(organization_id, status, submitted_at, id)
  where status = 'pending';
create index request_segments_request_idx
  on public.request_segments(organization_id, request_id, shift_instance_id);
create index task_handover_actions_pending_idx
  on public.task_handover_actions(organization_id, action, request_id, id)
  where action = 'pending';

create or replace function private.assert_shift_instance_segments()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_segment jsonb;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_previous_end timestamptz;
  v_total_seconds bigint := 0;
begin
  if jsonb_typeof(new.working_segments) <> 'array' then
    raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_INVALID';
  end if;

  for v_segment in select value from jsonb_array_elements(new.working_segments)
  loop
    if jsonb_typeof(v_segment) <> 'object'
       or not (v_segment ? 'start')
       or not (v_segment ? 'end') then
      raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_INVALID';
    end if;
    v_starts_at := (v_segment ->> 'start')::timestamptz;
    v_ends_at := (v_segment ->> 'end')::timestamptz;
    if v_starts_at < new.starts_at or v_ends_at > new.ends_at or v_ends_at <= v_starts_at then
      raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_INVALID';
    end if;
    if v_previous_end is not null and v_starts_at < v_previous_end then
      raise exception using errcode = '22023', message = 'SHIFT_WORKING_SEGMENTS_OVERLAP';
    end if;
    v_total_seconds := v_total_seconds + extract(epoch from v_ends_at - v_starts_at)::bigint;
    v_previous_end := v_ends_at;
  end loop;

  if v_total_seconds <> new.scheduled_seconds then
    raise exception using errcode = '22023', message = 'SHIFT_SCHEDULED_SECONDS_INVALID';
  end if;
  return new;
end;
$$;

create or replace function private.request_affected_seconds(
  p_working_segments jsonb,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns bigint
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_segment jsonb;
  v_segment_start timestamptz;
  v_segment_end timestamptz;
  v_overlap_start timestamptz;
  v_overlap_end timestamptz;
  v_seconds bigint := 0;
begin
  if p_ends_at <= p_starts_at then
    return 0;
  end if;
  for v_segment in select value from jsonb_array_elements(p_working_segments)
  loop
    v_segment_start := (v_segment ->> 'start')::timestamptz;
    v_segment_end := (v_segment ->> 'end')::timestamptz;
    v_overlap_start := greatest(v_segment_start, p_starts_at);
    v_overlap_end := least(v_segment_end, p_ends_at);
    if v_overlap_end > v_overlap_start then
      v_seconds := v_seconds + extract(epoch from v_overlap_end - v_overlap_start)::bigint;
    end if;
  end loop;
  return v_seconds;
end;
$$;

create or replace function private.assert_request_submitter(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  return v_member_id;
end;
$$;

create or replace function private.assert_request_approver(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
begin
  if v_member_id is null or not private.has_capability(p_organization_id, 'can_approve_requests') then
    raise exception using errcode = '42501', message = 'REQUEST_APPROVAL_DENIED';
  end if;
  return v_member_id;
end;
$$;

create or replace function private.current_actor_can_read_employee_request(
  p_organization_id uuid,
  p_request_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_capability(p_organization_id, 'can_approve_requests')
    or exists (
      select 1
      from public.employee_requests as er
      where er.organization_id = p_organization_id
        and er.id = p_request_id
        and er.member_id = private.current_member_id(p_organization_id)
    );
$$;

create or replace function private.recurring_member_on_approved_full_day_leave(
  p_organization_id uuid,
  p_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.employee_requests as er
    join public.request_segments as rs
      on rs.organization_id = er.organization_id
     and rs.request_id = er.id
    join public.shift_instances as si
      on si.organization_id = rs.organization_id
     and si.id = rs.shift_instance_id
    where er.organization_id = p_organization_id
      and er.member_id = p_member_id
      and er.request_type = 'leave'
      and er.status = 'approved'
      and si.work_date = p_work_date
      and rs.affected_seconds >= si.scheduled_seconds
  );
$$;

create or replace function private.create_leave_coverage_actions(p_request_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employee_requests%rowtype;
  v_org_timezone text;
  v_start_date date;
  v_end_date date;
  v_count integer := 0;
begin
  select * into v_request from public.employee_requests where id = p_request_id;
  if v_request.id is null or v_request.status <> 'approved'
     or v_request.request_type not in ('leave', 'early_leave', 'late_arrival') then
    return 0;
  end if;
  select timezone into v_org_timezone from public.organizations where id = v_request.organization_id;
  v_start_date := (v_request.starts_at at time zone v_org_timezone)::date;
  v_end_date := (v_request.ends_at at time zone v_org_timezone)::date;

  insert into public.task_handover_actions (
    organization_id, request_id, task_id, action
  )
  select v_request.organization_id, v_request.id, t.id, 'pending'
  from public.tasks as t
  where t.organization_id = v_request.organization_id
    and t.assignee_member_id = v_request.member_id
    and t.planned_date between v_start_date and v_end_date
    and t.status not in ('done', 'canceled', 'waived')
  on conflict (organization_id, request_id, task_id) do nothing;
  get diagnostics v_count = row_count;

  insert into public.task_handover_actions (
    organization_id, request_id, occurrence_id, action
  )
  select o.organization_id, v_request.id, o.id, 'pending'
  from public.recurring_task_occurrences as o
  join public.recurring_task_targets as rt
    on rt.organization_id = o.organization_id and rt.id = o.target_id
  where o.organization_id = v_request.organization_id
    and o.work_date between v_start_date and v_end_date
    and o.state = 'pending'
    and o.task_id is null
    and coalesce(o.resolved_assignee_member_id, rt.assignee_member_id) = v_request.member_id
    and private.recurring_member_on_approved_full_day_leave(o.organization_id, v_request.member_id, o.work_date)
  on conflict (organization_id, request_id, occurrence_id) do nothing;

  update public.recurring_task_occurrences as o
  set state = 'needs_assignment',
      issue_code = 'APPROVED_LEAVE_COVERAGE_REQUIRED',
      issue_context = jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id),
      updated_at = timezone('utc', now())
  from public.recurring_task_targets as rt
  where rt.organization_id = o.organization_id
    and rt.id = o.target_id
    and o.organization_id = v_request.organization_id
    and o.work_date between v_start_date and v_end_date
    and o.state = 'pending'
    and o.task_id is null
    and coalesce(o.resolved_assignee_member_id, rt.assignee_member_id) = v_request.member_id
    and private.recurring_member_on_approved_full_day_leave(o.organization_id, v_request.member_id, o.work_date);

  insert into private.outbox_events (
    organization_id, event_type, entity_type, entity_id, dedupe_key, payload
  ) values (
    v_request.organization_id,
    'leave.coverage_required',
    'employee_request',
    v_request.id,
    'leave:' || v_request.id::text || ':coverage',
    jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id)
  ) on conflict (organization_id, dedupe_key) do nothing;

  insert into private.outbox_events (
    organization_id, event_type, entity_type, entity_id, dedupe_key, payload
  ) values (
    v_request.organization_id,
    'leave.reminder_suppression_requested',
    'employee_request',
    v_request.id,
    'leave:' || v_request.id::text || ':suppress-reminders',
    jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id)
  ) on conflict (organization_id, dedupe_key) do nothing;

  return v_count;
end;
$$;

create or replace function public.rpc_create_employee_request(
  p_organization_id uuid,
  p_payload jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.assert_request_submitter(p_organization_id);
  v_request public.employee_requests%rowtype;
  v_shift public.shift_instances%rowtype;
  v_request_id uuid := extensions.gen_random_uuid();
  v_request_type text := lower(coalesce(p_payload ->> 'request_type', ''));
  v_starts_at timestamptz := nullif(p_payload ->> 'starts_at', '')::timestamptz;
  v_ends_at timestamptz := nullif(p_payload ->> 'ends_at', '')::timestamptz;
  v_leave_type_id uuid := nullif(p_payload ->> 'leave_type_id', '')::uuid;
  v_target_request_id uuid := nullif(p_payload ->> 'target_request_id', '')::uuid;
  v_reason text := trim(coalesce(p_payload ->> 'reason_private', ''));
  v_handover_note text := nullif(trim(coalesce(p_payload ->> 'handover_note', '')), '');
  v_correction_payload jsonb := p_payload -> 'correction_payload';
  v_pay_treatment text := 'not_applicable';
  v_affected_seconds bigint;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception using errcode = '22023', message = 'REQUEST_PAYLOAD_INVALID';
  end if;
  if char_length(trim(coalesce(p_idempotency_key, ''))) < 8 then
    raise exception using errcode = '22023', message = 'REQUEST_IDEMPOTENCY_KEY_INVALID';
  end if;
  if v_request_type not in ('leave', 'early_leave', 'late_arrival', 'remote_work', 'attendance_correction', 'cancel_approved_request') then
    raise exception using errcode = '22023', message = 'REQUEST_TYPE_INVALID';
  end if;
  if v_starts_at is null or v_ends_at is null or v_ends_at <= v_starts_at then
    raise exception using errcode = '22023', message = 'REQUEST_INTERVAL_INVALID';
  end if;
  if char_length(v_reason) not between 10 and 2000 then
    raise exception using errcode = '22023', message = 'REQUEST_REASON_INVALID';
  end if;
  if v_request_type = 'attendance_correction' and (v_correction_payload is null or jsonb_typeof(v_correction_payload) <> 'object') then
    raise exception using errcode = '22023', message = 'REQUEST_CORRECTION_PAYLOAD_INVALID';
  end if;
  if v_request_type = 'cancel_approved_request' and not exists (
    select 1 from public.employee_requests as target
    where target.organization_id = p_organization_id
      and target.id = v_target_request_id
      and target.member_id = v_member_id
      and target.status = 'approved'
  ) then
    raise exception using errcode = '22023', message = 'REQUEST_CANCELLATION_TARGET_INVALID';
  end if;

  select * into v_request
  from public.employee_requests
  where organization_id = p_organization_id
    and member_id = v_member_id
    and idempotency_key = p_idempotency_key;
  if v_request.id is not null then
    return jsonb_build_object('request_id', v_request.id, 'status', v_request.status, 'idempotent_replay', true);
  end if;

  if v_request_type in ('leave', 'early_leave', 'late_arrival') then
    select lt.pay_treatment into v_pay_treatment
    from public.leave_types as lt
    where lt.organization_id = p_organization_id and lt.id = v_leave_type_id and lt.active;
    if v_pay_treatment is null then
      raise exception using errcode = '22023', message = 'REQUEST_LEAVE_TYPE_INVALID';
    end if;
    if exists (
      select 1
      from public.employee_requests as er
      where er.organization_id = p_organization_id
        and er.member_id = v_member_id
        and er.status = 'approved'
        and er.request_type in ('leave', 'early_leave', 'late_arrival')
        and tstzrange(er.starts_at, er.ends_at, '[)') && tstzrange(v_starts_at, v_ends_at, '[)')
    ) then
      raise exception using errcode = '23505', message = 'REQUEST_APPROVED_OVERLAP';
    end if;
  else
    v_leave_type_id := null;
  end if;

  insert into public.employee_requests (
    id, organization_id, member_id, request_type, starts_at, ends_at, leave_type_id,
    pay_treatment_snapshot, reason_private, handover_note, target_request_id, correction_payload, idempotency_key
  ) values (
    v_request_id, p_organization_id, v_member_id, v_request_type, v_starts_at, v_ends_at, v_leave_type_id,
    v_pay_treatment, v_reason, v_handover_note, v_target_request_id, v_correction_payload, p_idempotency_key
  );

  for v_shift in
    select * from public.shift_instances
    where organization_id = p_organization_id
      and member_id = v_member_id
      and status = 'scheduled'
      and starts_at < v_ends_at and ends_at > v_starts_at
  loop
    v_affected_seconds := private.request_affected_seconds(v_shift.working_segments, v_starts_at, v_ends_at);
    insert into public.request_segments (
      organization_id, request_id, shift_instance_id, starts_at, ends_at, affected_seconds, pay_treatment_snapshot
    ) values (
      p_organization_id, v_request_id, v_shift.id,
      greatest(v_starts_at, v_shift.starts_at), least(v_ends_at, v_shift.ends_at),
      v_affected_seconds, v_pay_treatment
    ) on conflict (organization_id, request_id, shift_instance_id) do nothing;
  end loop;

  perform private.write_audit(
    p_organization_id,
    'request.created',
    'employee_request',
    v_request_id,
    jsonb_build_object('request_type', v_request_type, 'starts_at', v_starts_at, 'ends_at', v_ends_at)
  );

  return jsonb_build_object('request_id', v_request_id, 'status', 'pending', 'idempotent_replay', false);
end;
$$;

create or replace function public.rpc_decide_employee_request(
  p_request_id uuid,
  p_decision text,
  p_reason_private text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employee_requests%rowtype;
  v_after public.employee_requests%rowtype;
  v_actor_member_id uuid;
  v_decision text := lower(trim(coalesce(p_decision, '')));
  v_reason text := nullif(trim(coalesce(p_reason_private, '')), '');
  v_existing_decision public.request_decisions%rowtype;
  v_affected_seconds bigint;
  v_target_request public.employee_requests%rowtype;
  v_target_affected_seconds bigint;
begin
  select * into v_request from public.employee_requests where id = p_request_id for update;
  if v_request.id is null then
    raise exception using errcode = 'P0002', message = 'REQUEST_NOT_FOUND';
  end if;
  v_actor_member_id := private.assert_request_approver(v_request.organization_id);
  if v_request.member_id = v_actor_member_id then
    raise exception using errcode = '42501', message = 'REQUEST_SELF_APPROVAL_DENIED';
  end if;
  if char_length(trim(coalesce(p_idempotency_key, ''))) < 8 then
    raise exception using errcode = '22023', message = 'REQUEST_IDEMPOTENCY_KEY_INVALID';
  end if;
  select * into v_existing_decision from public.request_decisions
  where organization_id = v_request.organization_id and request_id = p_request_id and idempotency_key = p_idempotency_key;
  if v_existing_decision.id is not null then
    return jsonb_build_object('request_id', p_request_id, 'status', v_existing_decision.decision, 'idempotent_replay', true);
  end if;
  if v_decision not in ('approved', 'rejected') then
    raise exception using errcode = '22023', message = 'REQUEST_DECISION_INVALID';
  end if;
  if v_decision = 'rejected' and char_length(coalesce(v_reason, '')) < 10 then
    raise exception using errcode = '22023', message = 'REQUEST_REJECTION_REASON_REQUIRED';
  end if;
  if v_request.status <> 'pending' then
    raise exception using errcode = '40901', message = 'REQUEST_ALREADY_DECIDED';
  end if;
  if p_expected_version is null or p_expected_version <> v_request.version then
    raise exception using errcode = '40901', message = 'REQUEST_VERSION_CONFLICT';
  end if;
  if v_decision = 'approved'
     and v_request.request_type in ('leave', 'early_leave', 'late_arrival')
     and exists (
       select 1 from public.employee_requests as other
       where other.organization_id = v_request.organization_id
         and other.member_id = v_request.member_id
         and other.status = 'approved'
         and other.request_type in ('leave', 'early_leave', 'late_arrival')
         and other.id <> v_request.id
         and tstzrange(other.starts_at, other.ends_at, '[)') && tstzrange(v_request.starts_at, v_request.ends_at, '[)')
     ) then
    raise exception using errcode = '23505', message = 'REQUEST_APPROVED_OVERLAP';
  end if;

  update public.employee_requests
  set status = v_decision,
      decided_at = timezone('utc', now()),
      decided_by_member_id = v_actor_member_id,
      decision_reason_private = v_reason,
      version = version + 1,
      updated_at = timezone('utc', now())
  where id = v_request.id
  returning * into v_after;

  insert into public.request_decisions (
    organization_id, request_id, decision, actor_member_id, reason_private,
    before_state, after_state, idempotency_key
  ) values (
    v_request.organization_id, v_request.id, v_decision, v_actor_member_id, v_reason,
    to_jsonb(v_request), to_jsonb(v_after), p_idempotency_key
  );

  if v_decision = 'approved' then
    select coalesce(sum(affected_seconds), 0) into v_affected_seconds
    from public.request_segments where organization_id = v_request.organization_id and request_id = v_request.id;

    if v_request.leave_type_id is not null and v_request.pay_treatment_snapshot = 'paid'
       and exists (
         select 1 from public.leave_types where id = v_request.leave_type_id and consumes_balance
       ) then
      insert into public.leave_balance_entries (
        organization_id, member_id, leave_type_id, delta_seconds, effective_date,
        source_request_id, reason, created_by_member_id
      ) values (
        v_request.organization_id, v_request.member_id, v_request.leave_type_id, -v_affected_seconds,
        (v_request.starts_at at time zone (select timezone from public.organizations where id = v_request.organization_id))::date,
        v_request.id, 'Approved employee request', v_actor_member_id
      ) on conflict (organization_id, source_request_id) do nothing;
    end if;
    perform private.create_leave_coverage_actions(v_request.id);

    if v_request.request_type = 'attendance_correction' then
      insert into private.outbox_events (
        organization_id, event_type, entity_type, entity_id, dedupe_key, payload
      ) values (
        v_request.organization_id,
        'attendance.correction_approved',
        'employee_request',
        v_request.id,
        'request:' || v_request.id::text || ':attendance-correction',
        jsonb_build_object('request_id', v_request.id, 'member_id', v_request.member_id)
      ) on conflict (organization_id, dedupe_key) do nothing;
    end if;

    if v_request.request_type = 'cancel_approved_request' then
      select * into v_target_request
      from public.employee_requests as target
      where target.organization_id = v_request.organization_id
        and target.id = v_request.target_request_id
        and target.status = 'approved'
      for update;
      if v_target_request.id is null then
        raise exception using errcode = '40901', message = 'REQUEST_CANCELLATION_TARGET_NOT_APPROVED';
      end if;
      update public.employee_requests as target
      set status = 'canceled', version = version + 1, updated_at = timezone('utc', now())
      where target.organization_id = v_request.organization_id
        and target.id = v_request.target_request_id
        and target.status = 'approved';
      if v_target_request.leave_type_id is not null and v_target_request.pay_treatment_snapshot = 'paid'
         and exists (
           select 1 from public.leave_types where id = v_target_request.leave_type_id and consumes_balance
         ) then
        select coalesce(sum(affected_seconds), 0) into v_target_affected_seconds
        from public.request_segments
        where organization_id = v_target_request.organization_id and request_id = v_target_request.id;
        insert into public.leave_balance_entries (
          organization_id, member_id, leave_type_id, delta_seconds, effective_date,
          source_request_id, reason, created_by_member_id
        ) values (
          v_target_request.organization_id, v_target_request.member_id, v_target_request.leave_type_id,
          v_target_affected_seconds,
          (v_target_request.starts_at at time zone (select timezone from public.organizations where id = v_target_request.organization_id))::date,
          v_request.id, 'Approved cancellation of leave request', v_actor_member_id
        ) on conflict (organization_id, source_request_id) do nothing;
      end if;
      insert into private.outbox_events (
        organization_id, event_type, entity_type, entity_id, dedupe_key, payload
      ) values (
        v_request.organization_id,
        'leave.cancellation_approved',
        'employee_request',
        v_request.id,
        'request:' || v_request.id::text || ':cancellation',
        jsonb_build_object('request_id', v_request.id, 'target_request_id', v_target_request.id)
      ) on conflict (organization_id, dedupe_key) do nothing;
    end if;
  end if;

  perform private.write_audit(
    v_request.organization_id,
    'request.' || v_decision,
    'employee_request',
    v_request.id,
    jsonb_build_object('request_type', v_request.request_type, 'decision', v_decision, 'version', v_after.version)
  );
  return jsonb_build_object('request_id', v_request.id, 'status', v_decision, 'version', v_after.version, 'idempotent_replay', false);
end;
$$;

create or replace function public.rpc_withdraw_employee_request(
  p_request_id uuid,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.employee_requests%rowtype;
  v_actor_member_id uuid;
  v_after public.employee_requests%rowtype;
begin
  select * into v_request from public.employee_requests where id = p_request_id for update;
  if v_request.id is null then
    raise exception using errcode = 'P0002', message = 'REQUEST_NOT_FOUND';
  end if;
  v_actor_member_id := private.assert_request_submitter(v_request.organization_id);
  if v_request.member_id <> v_actor_member_id then
    raise exception using errcode = '42501', message = 'REQUEST_WITHDRAW_DENIED';
  end if;
  if v_request.status <> 'pending' then
    raise exception using errcode = '40901', message = 'REQUEST_WITHDRAW_NOT_PENDING';
  end if;
  if p_expected_version is null or p_expected_version <> v_request.version then
    raise exception using errcode = '40901', message = 'REQUEST_VERSION_CONFLICT';
  end if;
  update public.employee_requests
  set status = 'withdrawn', version = version + 1, updated_at = timezone('utc', now())
  where id = v_request.id returning * into v_after;
  insert into public.request_decisions (
    organization_id, request_id, decision, actor_member_id, before_state, after_state, idempotency_key
  ) values (
    v_request.organization_id, v_request.id, 'withdrawn', v_actor_member_id,
    to_jsonb(v_request), to_jsonb(v_after), p_idempotency_key
  ) on conflict (organization_id, request_id, idempotency_key) do nothing;
  perform private.write_audit(
    v_request.organization_id, 'request.withdrawn', 'employee_request', v_request.id,
    jsonb_build_object('request_type', v_request.request_type, 'version', v_after.version)
  );
  return jsonb_build_object('request_id', v_request.id, 'status', 'withdrawn', 'version', v_after.version);
end;
$$;

create or replace function public.rpc_list_request_availability(
  p_organization_id uuid,
  p_from_date date,
  p_to_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.assert_request_submitter(p_organization_id);
  if p_from_date is null or p_to_date is null or p_to_date < p_from_date or p_to_date - p_from_date > 31 then
    raise exception using errcode = '22023', message = 'REQUEST_AVAILABILITY_RANGE_INVALID';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'member_id', er.member_id,
      'starts_at', er.starts_at,
      'ends_at', er.ends_at,
      'availability', case when er.request_type = 'remote_work' then 'remote' else 'unavailable' end
    ) order by er.starts_at, er.id)
    from public.employee_requests as er
    where er.organization_id = p_organization_id
      and er.status = 'approved'
      and er.request_type in ('leave', 'early_leave', 'late_arrival', 'remote_work')
      and er.starts_at < ((p_to_date + 1)::timestamp at time zone (select timezone from public.organizations where id = p_organization_id))
      and er.ends_at > (p_from_date::timestamp at time zone (select timezone from public.organizations where id = p_organization_id))
  ), '[]'::jsonb);
end;
$$;

-- An approved full-day leave makes future Daily occurrences coverage work, never silent deletion.
create or replace function private.recurring_member_available_for_work_date(
  p_organization_id uuid,
  p_seller_id uuid,
  p_member_id uuid,
  p_work_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_members as m
    left join public.member_hr_settings as hr
      on hr.organization_id = m.organization_id and hr.member_id = m.id
    where m.organization_id = p_organization_id
      and m.id = p_member_id
      and m.status = 'active'
      and (hr.member_id is null or hr.employment_start <= p_work_date)
      and (hr.member_id is null or hr.employment_end is null or hr.employment_end >= p_work_date)
      and not private.recurring_member_on_approved_full_day_leave(p_organization_id, p_member_id, p_work_date)
      and (
        p_seller_id is null or exists (
          select 1 from public.seller_members as sm
          where sm.organization_id = p_organization_id and sm.seller_id = p_seller_id
            and sm.member_id = p_member_id and sm.active_from <= p_work_date
            and (sm.active_until is null or sm.active_until >= p_work_date)
        )
      )
      and (p_seller_id is null or private.is_seller_member(p_organization_id, p_seller_id, p_member_id))
  );
$$;

create trigger offices_set_updated_at before update on public.offices
for each row execute function private.set_updated_at();
create trigger shift_templates_set_updated_at before update on public.shift_templates
for each row execute function private.set_updated_at();
create trigger shift_assignments_set_updated_at before update on public.shift_assignments
for each row execute function private.set_updated_at();
create trigger calendar_overrides_set_updated_at before update on public.calendar_overrides
for each row execute function private.set_updated_at();
create trigger shift_instances_set_updated_at before update on public.shift_instances
for each row execute function private.set_updated_at();
create trigger shift_instances_validate_segments before insert or update on public.shift_instances
for each row execute function private.assert_shift_instance_segments();
create trigger leave_types_set_updated_at before update on public.leave_types
for each row execute function private.set_updated_at();
create trigger employee_requests_set_updated_at before update on public.employee_requests
for each row execute function private.set_updated_at();
create trigger task_handover_actions_set_updated_at before update on public.task_handover_actions
for each row execute function private.set_updated_at();

alter table public.offices enable row level security;
alter table public.shift_templates enable row level security;
alter table public.shift_assignments enable row level security;
alter table public.calendar_overrides enable row level security;
alter table public.shift_instances enable row level security;
alter table public.leave_types enable row level security;
alter table public.employee_requests enable row level security;
alter table public.request_segments enable row level security;
alter table public.request_decisions enable row level security;
alter table public.leave_balance_entries enable row level security;
alter table public.task_handover_actions enable row level security;

create policy offices_read_active_member on public.offices for select to authenticated
using (private.current_member_id(organization_id) is not null);
create policy shift_templates_read_active_member on public.shift_templates for select to authenticated
using (private.current_member_id(organization_id) is not null);
create policy shift_assignments_read_own_or_hr on public.shift_assignments for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));
create policy calendar_overrides_read_own_or_hr on public.calendar_overrides for select to authenticated
using (member_id is null or member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));
create policy shift_instances_read_own_or_hr on public.shift_instances for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));
create policy leave_types_read_active_member on public.leave_types for select to authenticated
using (private.current_member_id(organization_id) is not null);
create policy employee_requests_read_owner_or_approver on public.employee_requests for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, id));
create policy request_segments_read_owner_or_approver on public.request_segments for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, request_id));
create policy request_decisions_read_owner_or_approver on public.request_decisions for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, request_id));
create policy leave_balance_entries_read_owner_or_approver on public.leave_balance_entries for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_approve_requests'));
create policy task_handover_actions_read_owner_or_approver on public.task_handover_actions for select to authenticated
using (private.current_actor_can_read_employee_request(organization_id, request_id));

revoke all on function private.assert_shift_instance_segments() from public, anon, authenticated;
revoke all on function private.request_affected_seconds(jsonb, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.assert_request_submitter(uuid) from public, anon;
revoke all on function private.assert_request_approver(uuid) from public, anon;
revoke all on function private.current_actor_can_read_employee_request(uuid, uuid) from public, anon;
revoke all on function private.recurring_member_on_approved_full_day_leave(uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.create_leave_coverage_actions(uuid) from public, anon, authenticated;
grant execute on function private.assert_request_submitter(uuid) to authenticated;
grant execute on function private.assert_request_approver(uuid) to authenticated;
grant execute on function private.current_actor_can_read_employee_request(uuid, uuid) to authenticated;
grant execute on function public.rpc_create_employee_request(uuid, jsonb, text) to authenticated;
grant execute on function public.rpc_decide_employee_request(uuid, text, text, integer, text) to authenticated;
grant execute on function public.rpc_withdraw_employee_request(uuid, integer, text) to authenticated;
grant execute on function public.rpc_list_request_availability(uuid, date, date) to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.offices, public.shift_templates, public.shift_assignments, public.calendar_overrides,
  public.shift_instances, public.leave_types, public.employee_requests, public.request_segments,
  public.request_decisions, public.leave_balance_entries, public.task_handover_actions
from authenticated;

-- ============================================================================
-- END 00000000000007_p05_hr_requests.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000008_p06_attendance.sql
-- ============================================================================

-- P06 Attendance: server-authoritative office Wi-Fi / trusted ingress and remote selfie flows.
-- Raw attendance events are immutable. The client never supplies the official attendance timestamp.

create table public.office_networks (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  office_id uuid not null,
  ssid_label text not null check (char_length(trim(ssid_label)) between 1 and 160),
  bssid text not null check (bssid = lower(bssid) and bssid ~ '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'),
  valid_from timestamptz not null default timezone('utc', now()),
  valid_until timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, office_id)
    references public.offices(organization_id, id)
    on delete restrict,
  check (valid_until is null or valid_until > valid_from)
);

create unique index office_network_active_bssid_idx
  on public.office_networks(organization_id, office_id, bssid)
  where valid_until is null;

create table public.office_ip_ranges (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  office_id uuid not null,
  ip_range cidr not null,
  valid_from timestamptz not null default timezone('utc', now()),
  valid_until timestamptz,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, office_id)
    references public.offices(organization_id, id)
    on delete restrict,
  check (valid_until is null or valid_until > valid_from)
);

create table public.user_devices (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  installation_id text not null check (char_length(trim(installation_id)) between 8 and 240),
  platform text not null check (platform in ('web', 'ios', 'android')),
  label text not null default '',
  last_seen_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, member_id, installation_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.files (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  uploaded_by_member_id uuid not null,
  bucket_id text not null check (char_length(trim(bucket_id)) between 1 and 120),
  object_path text not null check (char_length(trim(object_path)) between 1 and 600),
  original_name text not null check (char_length(trim(original_name)) between 1 and 240),
  mime_type text not null,
  size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 15728640),
  sha256 text,
  purpose text not null check (purpose in ('task', 'attendance', 'request', 'export')),
  state text not null default 'pending' check (state in ('pending', 'ready', 'quarantined', 'deleted')),
  retention_until timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (organization_id, id),
  unique (bucket_id, object_path),
  foreign key (organization_id, uploaded_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attendance-evidence',
  'attendance-evidence',
  false,
  15728640,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create table public.attendance_challenges (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  shift_instance_id uuid not null,
  action text not null check (action in ('check_in', 'check_out')),
  mode text not null check (mode in ('office', 'remote')),
  nonce_hash text not null check (char_length(nonce_hash) = 64),
  device_id uuid not null,
  issued_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null,
  consumed_at timestamptz,
  file_id uuid,
  laptop_session_id uuid,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  unique (organization_id, id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_instance_id)
    references public.shift_instances(organization_id, id)
    on delete restrict,
  foreign key (organization_id, device_id)
    references public.user_devices(organization_id, id)
    on delete restrict,
  foreign key (organization_id, file_id)
    references public.files(organization_id, id)
    on delete restrict,
  check (expires_at > issued_at),
  check (expires_at <= issued_at + interval '5 minutes')
);

create table public.remote_laptop_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  shift_instance_id uuid not null,
  challenge_id uuid,
  code_hash text not null check (char_length(code_hash) = 64),
  resolve_attempt_count integer not null default 0 check (resolve_attempt_count between 0 and 5),
  locked_at timestamptz,
  invalidated_at timestamptz,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_instance_id)
    references public.shift_instances(organization_id, id)
    on delete restrict,
  foreign key (organization_id, challenge_id)
    references public.attendance_challenges(organization_id, id)
    on delete restrict,
  check (locked_at is null or resolve_attempt_count = 5),
  check (expires_at > created_at),
  check (expires_at <= created_at + interval '10 minutes')
);

alter table public.attendance_challenges
  add constraint attendance_challenges_laptop_session_fk
  foreign key (organization_id, laptop_session_id)
  references public.remote_laptop_sessions(organization_id, id)
  on delete restrict;

create table public.upload_intents (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  file_id uuid not null,
  target_kind text not null check (target_kind in ('attendance', 'request', 'task', 'export')),
  target_id uuid,
  challenge_id uuid,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, file_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, file_id)
    references public.files(organization_id, id)
    on delete restrict,
  foreign key (organization_id, challenge_id)
    references public.attendance_challenges(organization_id, id)
    on delete restrict,
  check (expires_at > created_at)
);

create table public.attendance_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  shift_instance_id uuid not null,
  event_kind text not null check (event_kind in ('check_in', 'check_out', 'adjustment')),
  effective_at timestamptz not null,
  recorded_at timestamptz not null default timezone('utc', now()),
  mode text not null check (mode in ('office', 'remote', 'manual_adjustment')),
  challenge_id uuid,
  source_request_id uuid,
  supersedes_event_id uuid,
  verification_status text not null check (verification_status in ('verified', 'approved_adjustment', 'flagged')),
  created_by_member_id uuid,
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  unique (organization_id, id),
  unique (organization_id, member_id, idempotency_key),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_instance_id)
    references public.shift_instances(organization_id, id)
    on delete restrict,
  foreign key (organization_id, challenge_id)
    references public.attendance_challenges(organization_id, id)
    on delete restrict,
  foreign key (organization_id, source_request_id)
    references public.employee_requests(organization_id, id)
    on delete restrict,
  foreign key (organization_id, supersedes_event_id)
    references public.attendance_events(organization_id, id)
    on delete restrict,
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.attendance_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  attendance_event_id uuid not null,
  file_id uuid,
  source_ip inet,
  office_network_id uuid,
  device_id uuid not null,
  wifi_claim_snapshot jsonb check (wifi_claim_snapshot is null or jsonb_typeof(wifi_claim_snapshot) = 'object'),
  verification_details jsonb not null default '{}'::jsonb check (jsonb_typeof(verification_details) = 'object'),
  retention_until timestamptz,
  legal_hold boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, attendance_event_id),
  foreign key (organization_id, attendance_event_id)
    references public.attendance_events(organization_id, id)
    on delete restrict,
  foreign key (organization_id, file_id)
    references public.files(organization_id, id)
    on delete restrict,
  foreign key (organization_id, office_network_id)
    references public.office_networks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, device_id)
    references public.user_devices(organization_id, id)
    on delete restrict
);

create table public.attendance_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  shift_instance_id uuid not null,
  check_in_event_id uuid not null,
  check_out_event_id uuid,
  starts_at timestamptz not null,
  ends_at timestamptz,
  mode text not null check (mode in ('office', 'remote')),
  status text not null default 'open' check (status in ('open', 'closed', 'superseded')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, shift_instance_id)
    references public.shift_instances(organization_id, id)
    on delete restrict,
  foreign key (organization_id, check_in_event_id)
    references public.attendance_events(organization_id, id)
    on delete restrict,
  foreign key (organization_id, check_out_event_id)
    references public.attendance_events(organization_id, id)
    on delete restrict,
  check ((status = 'open' and check_out_event_id is null and ends_at is null) or status <> 'open'),
  check (ends_at is null or ends_at >= starts_at)
);

create unique index attendance_one_open_session_idx
  on public.attendance_sessions(organization_id, member_id)
  where status = 'open';

create index attendance_member_time_idx
  on public.attendance_events(organization_id, member_id, effective_at desc);
create index attendance_shift_idx
  on public.attendance_events(organization_id, shift_instance_id, effective_at);

create trigger attendance_events_immutable
before update or delete on public.attendance_events
for each row execute function private.prevent_immutable_mutation();

create trigger attendance_evidence_immutable
before update or delete on public.attendance_evidence
for each row execute function private.prevent_immutable_mutation();

create or replace function private.member_has_remote_permission(
  p_organization_id uuid,
  p_member_id uuid,
  p_shift public.shift_instances,
  p_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_shift.allowed_mode in ('remote', 'hybrid')
    or exists (
      select 1
      from public.employee_requests r
      where r.organization_id = p_organization_id
        and r.member_id = p_member_id
        and r.request_type = 'remote_work'
        and r.status = 'approved'
        and p_at >= r.starts_at
        and p_at < r.ends_at
    );
$$;

create or replace function public.rpc_internal_create_attendance_challenge(
  p_organization_id uuid,
  p_member_id uuid,
  p_shift_instance_id uuid,
  p_action text,
  p_mode text,
  p_device_id uuid,
  p_nonce_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shift public.shift_instances%rowtype;
  v_challenge public.attendance_challenges%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if p_action not in ('check_in', 'check_out') or p_mode not in ('office', 'remote') then
    raise exception using errcode = '22023', message = 'ATTENDANCE_CHALLENGE_INVALID';
  end if;
  if p_nonce_hash is null or char_length(p_nonce_hash) <> 64 then
    raise exception using errcode = '22023', message = 'ATTENDANCE_NONCE_INVALID';
  end if;

  select * into v_shift
  from public.shift_instances s
  where s.organization_id = p_organization_id
    and s.id = p_shift_instance_id
    and s.member_id = p_member_id
    and s.status = 'scheduled'
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'SHIFT_NOT_FOUND';
  end if;
  if v_now < v_shift.starts_at - interval '3 hours' or v_now > v_shift.ends_at + interval '6 hours' then
    raise exception using errcode = '22023', message = 'OUTSIDE_ATTENDANCE_WINDOW';
  end if;
  if p_mode = 'office' and (v_shift.allowed_mode not in ('office', 'hybrid') or v_shift.office_id is null) then
    raise exception using errcode = '42501', message = 'OFFICE_NOT_ALLOWED';
  end if;
  if p_mode = 'remote' and not private.member_has_remote_permission(p_organization_id, p_member_id, v_shift, v_now) then
    raise exception using errcode = '42501', message = 'REMOTE_NOT_APPROVED';
  end if;
  if not exists (
    select 1 from public.user_devices d
    where d.organization_id = p_organization_id
      and d.id = p_device_id
      and d.member_id = p_member_id
      and d.revoked_at is null
  ) then
    raise exception using errcode = '42501', message = 'DEVICE_NOT_REGISTERED';
  end if;

  insert into public.attendance_challenges (
    organization_id, member_id, shift_instance_id, action, mode, nonce_hash, device_id, issued_at, expires_at
  ) values (
    p_organization_id, p_member_id, p_shift_instance_id, p_action, p_mode, lower(p_nonce_hash), p_device_id,
    v_now, v_now + interval '120 seconds'
  ) returning * into v_challenge;

  return jsonb_build_object(
    'challenge_id', v_challenge.id,
    'expires_at', v_challenge.expires_at,
    'server_now', v_now,
    'requirements', jsonb_build_object(
      'wifi_required', p_mode = 'office',
      'trusted_network_required', p_mode = 'office',
      'selfie_required', p_mode = 'remote',
      'laptop_session_required', p_mode = 'remote'
    )
  );
end;
$$;

create or replace function public.rpc_internal_create_remote_laptop_session(
  p_organization_id uuid,
  p_member_id uuid,
  p_shift_instance_id uuid,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shift public.shift_instances%rowtype;
  v_session public.remote_laptop_sessions%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if p_code_hash is null or char_length(p_code_hash) <> 64 then
    raise exception using errcode = '22023', message = 'LAPTOP_SESSION_CODE_INVALID';
  end if;

  select * into v_shift
  from public.shift_instances s
  where s.organization_id = p_organization_id
    and s.id = p_shift_instance_id
    and s.member_id = p_member_id
    and s.status = 'scheduled';

  if not found then
    raise exception using errcode = 'P0002', message = 'SHIFT_NOT_FOUND';
  end if;
  if not private.member_has_remote_permission(p_organization_id, p_member_id, v_shift, v_now) then
    raise exception using errcode = '42501', message = 'REMOTE_NOT_APPROVED';
  end if;

  update public.remote_laptop_sessions
  set invalidated_at = v_now
  where organization_id = p_organization_id
    and member_id = p_member_id
    and shift_instance_id = p_shift_instance_id
    and consumed_at is null
    and invalidated_at is null
    and expires_at > v_now;

  insert into public.remote_laptop_sessions (
    organization_id, member_id, shift_instance_id, code_hash, expires_at, created_at
  ) values (
    p_organization_id, p_member_id, p_shift_instance_id, lower(p_code_hash),
    v_now + interval '5 minutes', v_now
  ) returning * into v_session;

  return jsonb_build_object(
    'session_id', v_session.id,
    'expires_at', v_session.expires_at,
    'server_now', v_now
  );
end;
$$;

create or replace function public.rpc_internal_resolve_remote_laptop_session(
  p_organization_id uuid,
  p_member_id uuid,
  p_shift_instance_id uuid,
  p_code_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session public.remote_laptop_sessions%rowtype;
  v_attempts integer;
  v_now timestamptz := clock_timestamp();
begin
  if p_code_hash is null or char_length(p_code_hash) <> 64 then
    return jsonb_build_object('matched', false, 'code', 'LAPTOP_SESSION_INVALID');
  end if;

  select * into v_session
  from public.remote_laptop_sessions ls
  where ls.organization_id = p_organization_id
    and ls.member_id = p_member_id
    and ls.shift_instance_id = p_shift_instance_id
    and ls.consumed_at is null
    and ls.invalidated_at is null
    and ls.expires_at > v_now
  order by ls.created_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('matched', false, 'code', 'LAPTOP_SESSION_INVALID');
  end if;
  if v_session.locked_at is not null or v_session.resolve_attempt_count >= 5 then
    return jsonb_build_object('matched', false, 'code', 'LAPTOP_SESSION_LOCKED');
  end if;

  if lower(p_code_hash) <> v_session.code_hash then
    v_attempts := v_session.resolve_attempt_count + 1;
    update public.remote_laptop_sessions
    set resolve_attempt_count = v_attempts,
        locked_at = case when v_attempts >= 5 then v_now else null end
    where organization_id = v_session.organization_id
      and id = v_session.id;
    return jsonb_build_object(
      'matched', false,
      'code', case when v_attempts >= 5 then 'LAPTOP_SESSION_LOCKED' else 'LAPTOP_SESSION_INVALID' end,
      'remaining_attempts', greatest(0, 5 - v_attempts)
    );
  end if;

  return jsonb_build_object(
    'matched', true,
    'session_id', v_session.id,
    'expires_at', v_session.expires_at
  );
end;
$$;

create or replace function public.rpc_internal_finalize_attendance(
  p_challenge_id uuid,
  p_nonce_hash text,
  p_bssid text,
  p_source_ip inet,
  p_file_id uuid,
  p_laptop_session_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_challenge public.attendance_challenges%rowtype;
  v_shift public.shift_instances%rowtype;
  v_existing public.attendance_events%rowtype;
  v_event public.attendance_events%rowtype;
  v_open public.attendance_sessions%rowtype;
  v_upload_intent public.upload_intents%rowtype;
  v_session_id uuid;
  v_network_id uuid;
  v_now timestamptz := clock_timestamp();
begin
  select * into v_challenge
  from public.attendance_challenges c
  where c.id = p_challenge_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'CHALLENGE_NOT_FOUND';
  end if;

  select * into v_existing
  from public.attendance_events e
  where e.organization_id = v_challenge.organization_id
    and e.member_id = v_challenge.member_id
    and e.idempotency_key = p_idempotency_key;
  if found then
    select s.id into v_session_id
    from public.attendance_sessions s
    where s.organization_id = v_existing.organization_id
      and (s.check_in_event_id = v_existing.id or s.check_out_event_id = v_existing.id)
    limit 1;
    return jsonb_build_object(
      'event_id', v_existing.id,
      'session_id', v_session_id,
      'event_kind', v_existing.event_kind,
      'mode', v_existing.mode,
      'effective_at', v_existing.effective_at,
      'recorded_at', v_existing.recorded_at,
      'duplicate', true
    );
  end if;

  if v_challenge.consumed_at is not null then
    raise exception using errcode = '40901', message = 'CHALLENGE_ALREADY_CONSUMED';
  end if;
  if v_challenge.expires_at <= v_now then
    raise exception using errcode = '22023', message = 'CHALLENGE_EXPIRED';
  end if;
  if lower(coalesce(p_nonce_hash, '')) <> v_challenge.nonce_hash then
    raise exception using errcode = '42501', message = 'CHALLENGE_NONCE_MISMATCH';
  end if;

  select * into v_shift
  from public.shift_instances s
  where s.organization_id = v_challenge.organization_id
    and s.id = v_challenge.shift_instance_id
    and s.member_id = v_challenge.member_id
    and s.status = 'scheduled'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'SHIFT_NOT_FOUND';
  end if;

  if v_challenge.mode = 'office' then
    if p_bssid is null or p_source_ip is null then
      raise exception using errcode = '42501', message = 'OFFICE_NETWORK_REQUIRED';
    end if;
    select n.id into v_network_id
    from public.office_networks n
    where n.organization_id = v_challenge.organization_id
      and n.office_id = v_shift.office_id
      and n.bssid = lower(p_bssid)
      and n.valid_from <= v_now
      and (n.valid_until is null or n.valid_until > v_now)
    limit 1;
    if v_network_id is null then
      raise exception using errcode = '42501', message = 'WIFI_BSSID_MISMATCH';
    end if;
    if not exists (
      select 1 from public.office_ip_ranges r
      where r.organization_id = v_challenge.organization_id
        and r.office_id = v_shift.office_id
        and p_source_ip <<= r.ip_range
        and r.valid_from <= v_now
        and (r.valid_until is null or r.valid_until > v_now)
    ) then
      raise exception using errcode = '42501', message = 'SOURCE_IP_MISMATCH';
    end if;
  else
    if not private.member_has_remote_permission(v_challenge.organization_id, v_challenge.member_id, v_shift, v_now) then
      raise exception using errcode = '42501', message = 'REMOTE_NOT_APPROVED';
    end if;
    if p_file_id is null then
      raise exception using errcode = '42501', message = 'REMOTE_EVIDENCE_REQUIRED';
    end if;
    select * into v_upload_intent
    from public.upload_intents ui
    where ui.organization_id = v_challenge.organization_id
      and ui.member_id = v_challenge.member_id
      and ui.file_id = p_file_id
      and ui.target_kind = 'attendance'
      and ui.challenge_id = v_challenge.id
      and ui.consumed_at is null
      and ui.expires_at > v_now
    for update;
    if not found then
      raise exception using errcode = '42501', message = 'REMOTE_UPLOAD_INTENT_INVALID';
    end if;
    if not exists (
      select 1 from public.files f
      where f.organization_id = v_challenge.organization_id
        and f.id = p_file_id
        and f.uploaded_by_member_id = v_challenge.member_id
        and f.purpose = 'attendance'
        and f.state = 'ready'
    ) then
      raise exception using errcode = '42501', message = 'REMOTE_EVIDENCE_REQUIRED';
    end if;
    if p_laptop_session_id is null then
      raise exception using errcode = '42501', message = 'LAPTOP_SESSION_REQUIRED';
    end if;
    if not exists (
      select 1
      from public.remote_laptop_sessions ls
      where ls.organization_id = v_challenge.organization_id
        and ls.id = p_laptop_session_id
        and ls.member_id = v_challenge.member_id
        and ls.shift_instance_id = v_challenge.shift_instance_id
        and ls.consumed_at is null
        and ls.invalidated_at is null
        and ls.locked_at is null
        and ls.resolve_attempt_count < 5
        and ls.expires_at > v_now
    ) then
      raise exception using errcode = '42501', message = 'LAPTOP_SESSION_INVALID';
    end if;
  end if;

  select * into v_open
  from public.attendance_sessions s
  where s.organization_id = v_challenge.organization_id
    and s.member_id = v_challenge.member_id
    and s.status = 'open'
  for update;

  if v_challenge.action = 'check_in' and found then
    raise exception using errcode = '23505', message = 'ATTENDANCE_SESSION_ALREADY_OPEN';
  end if;
  if v_challenge.action = 'check_out' and not found then
    raise exception using errcode = '22023', message = 'ATTENDANCE_CHECK_IN_REQUIRED';
  end if;

  insert into public.attendance_events (
    organization_id, member_id, shift_instance_id, event_kind, effective_at, recorded_at,
    mode, challenge_id, verification_status, idempotency_key
  ) values (
    v_challenge.organization_id, v_challenge.member_id, v_challenge.shift_instance_id,
    v_challenge.action, v_now, v_now, v_challenge.mode, v_challenge.id, 'verified', p_idempotency_key
  ) returning * into v_event;

  insert into public.attendance_evidence (
    organization_id, attendance_event_id, file_id, source_ip, office_network_id, device_id,
    wifi_claim_snapshot, verification_details
  ) values (
    v_challenge.organization_id, v_event.id, case when v_challenge.mode = 'remote' then p_file_id else null end,
    p_source_ip, v_network_id, v_challenge.device_id,
    case when v_challenge.mode = 'office' then jsonb_build_object('bssid', lower(p_bssid)) else null end,
    jsonb_build_object('server_verified', true, 'mode', v_challenge.mode)
  );

  if v_challenge.action = 'check_in' then
    insert into public.attendance_sessions (
      organization_id, member_id, shift_instance_id, check_in_event_id, starts_at, mode
    ) values (
      v_challenge.organization_id, v_challenge.member_id, v_challenge.shift_instance_id,
      v_event.id, v_event.effective_at, v_challenge.mode
    ) returning id into v_session_id;
  else
    update public.attendance_sessions
    set check_out_event_id = v_event.id,
        ends_at = v_event.effective_at,
        status = 'closed',
        updated_at = v_now,
        version = version + 1
    where id = v_open.id
    returning id into v_session_id;
  end if;

  update public.attendance_challenges
  set consumed_at = v_now,
      file_id = case when v_challenge.mode = 'remote' then p_file_id else file_id end,
      laptop_session_id = case when v_challenge.mode = 'remote' then p_laptop_session_id else laptop_session_id end,
      attempt_count = attempt_count + 1
  where id = v_challenge.id;

  if v_challenge.mode = 'remote' and p_laptop_session_id is not null then
    update public.remote_laptop_sessions
    set consumed_at = v_now,
        challenge_id = v_challenge.id
    where organization_id = v_challenge.organization_id
      and id = p_laptop_session_id
      and consumed_at is null;

    update public.upload_intents
    set consumed_at = v_now
    where organization_id = v_challenge.organization_id
      and id = v_upload_intent.id
      and consumed_at is null;
    if not found then
      raise exception using errcode = '40901', message = 'REMOTE_UPLOAD_INTENT_ALREADY_CONSUMED';
    end if;
  end if;

  return jsonb_build_object(
    'event_id', v_event.id,
    'session_id', v_session_id,
    'event_kind', v_event.event_kind,
    'mode', v_event.mode,
    'effective_at', v_event.effective_at,
    'recorded_at', v_event.recorded_at,
    'duplicate', false
  );
end;
$$;

create or replace function public.rpc_get_attendance_day(
  p_organization_id uuid,
  p_member_id uuid default null,
  p_work_date date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.current_member_id(p_organization_id);
  v_member uuid := coalesce(p_member_id, v_actor);
begin
  if v_actor is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  if v_member <> v_actor and not private.has_capability(p_organization_id, 'can_manage_attendance') then
    raise exception using errcode = '42501', message = 'ATTENDANCE_READ_DENIED';
  end if;

  return jsonb_build_object(
    'member_id', v_member,
    'work_date', p_work_date,
    'shift', (
      select jsonb_build_object(
        'id', si.id,
        'starts_at', si.starts_at,
        'ends_at', si.ends_at,
        'scheduled_seconds', si.scheduled_seconds,
        'allowed_mode', si.allowed_mode,
        'office_id', si.office_id,
        'status', si.status
      )
      from public.shift_instances si
      where si.organization_id = p_organization_id
        and si.member_id = v_member
        and si.work_date = p_work_date
      order by si.starts_at
      limit 1
    ),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id,
        'shift_instance_id', s.shift_instance_id,
        'starts_at', s.starts_at,
        'ends_at', s.ends_at,
        'mode', s.mode,
        'status', s.status
      ) order by s.starts_at)
      from public.attendance_sessions s
      join public.shift_instances si
        on si.organization_id = s.organization_id and si.id = s.shift_instance_id
      where s.organization_id = p_organization_id
        and s.member_id = v_member
        and si.work_date = p_work_date
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'event_kind', e.event_kind,
        'effective_at', e.effective_at,
        'recorded_at', e.recorded_at,
        'mode', e.mode,
        'verification_status', e.verification_status
      ) order by e.effective_at)
      from public.attendance_events e
      join public.shift_instances si
        on si.organization_id = e.organization_id and si.id = e.shift_instance_id
      where e.organization_id = p_organization_id
        and e.member_id = v_member
        and si.work_date = p_work_date
    ), '[]'::jsonb)
  );
end;
$$;

alter table public.office_networks enable row level security;
alter table public.office_ip_ranges enable row level security;
alter table public.user_devices enable row level security;
alter table public.files enable row level security;
alter table public.upload_intents enable row level security;
alter table public.attendance_challenges enable row level security;
alter table public.remote_laptop_sessions enable row level security;
alter table public.attendance_events enable row level security;
alter table public.attendance_evidence enable row level security;
alter table public.attendance_sessions enable row level security;

create policy attendance_events_read_owner_or_hr
on public.attendance_events for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));

create policy attendance_sessions_read_owner_or_hr
on public.attendance_sessions for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));

create policy attendance_evidence_read_owner_or_evidence_hr
on public.attendance_evidence for select to authenticated
using (
  exists (
    select 1 from public.attendance_events e
    where e.organization_id = attendance_evidence.organization_id
      and e.id = attendance_evidence.attendance_event_id
      and e.member_id = private.current_member_id(attendance_evidence.organization_id)
  )
  or private.has_capability(organization_id, 'can_view_attendance_evidence')
);

create policy user_devices_read_owner
on public.user_devices for select to authenticated
using (member_id = private.current_member_id(organization_id));

grant select on public.attendance_events, public.attendance_sessions, public.attendance_evidence, public.user_devices to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.office_networks, public.office_ip_ranges, public.user_devices, public.files, public.upload_intents,
   public.attendance_challenges, public.remote_laptop_sessions, public.attendance_events,
   public.attendance_evidence, public.attendance_sessions
from authenticated;

revoke all on function private.member_has_remote_permission(uuid, uuid, public.shift_instances, timestamptz) from public, anon, authenticated;
grant execute on function private.member_has_remote_permission(uuid, uuid, public.shift_instances, timestamptz) to service_role;

revoke all on function public.rpc_internal_create_attendance_challenge(uuid, uuid, uuid, text, text, uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_internal_create_remote_laptop_session(uuid, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_internal_resolve_remote_laptop_session(uuid, uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_internal_finalize_attendance(uuid, text, text, inet, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.rpc_internal_create_attendance_challenge(uuid, uuid, uuid, text, text, uuid, text) to service_role;
grant execute on function public.rpc_internal_create_remote_laptop_session(uuid, uuid, uuid, text) to service_role;
grant execute on function public.rpc_internal_resolve_remote_laptop_session(uuid, uuid, uuid, text) to service_role;
grant execute on function public.rpc_internal_finalize_attendance(uuid, text, text, inet, uuid, uuid, text) to service_role;

revoke all on function public.rpc_get_attendance_day(uuid, uuid, date) from public, anon;
grant execute on function public.rpc_get_attendance_day(uuid, uuid, date) to authenticated;

-- ============================================================================
-- END 00000000000008_p06_attendance.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000009_p07_timesheets.sql
-- ============================================================================

-- P07 - Timesheet summaries, monthly reconciliation and immutable close/reopen snapshots.
-- Raw attendance remains append-only; closing a period snapshots calculated rows instead of mutating sources.

create table public.attendance_day_summaries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  work_date date not null,
  scheduled_seconds bigint not null check (scheduled_seconds >= 0),
  worked_office_seconds bigint not null default 0 check (worked_office_seconds >= 0),
  worked_remote_seconds bigint not null default 0 check (worked_remote_seconds >= 0),
  paid_leave_seconds bigint not null default 0 check (paid_leave_seconds >= 0),
  unpaid_leave_seconds bigint not null default 0 check (unpaid_leave_seconds >= 0),
  unexplained_seconds bigint not null default 0 check (unexplained_seconds >= 0),
  unknown_seconds bigint not null default 0 check (unknown_seconds >= 0),
  late_seconds bigint not null default 0 check (late_seconds >= 0),
  early_seconds bigint not null default 0 check (early_seconds >= 0),
  outside_schedule_seconds bigint not null default 0 check (outside_schedule_seconds >= 0),
  standard_day_minutes integer not null check (standard_day_minutes between 1 and 1440),
  state text not null check (state in ('provisional', 'needs_review', 'verified')),
  exceptions jsonb not null default '[]'::jsonb check (jsonb_typeof(exceptions) = 'array'),
  calculation_version integer not null check (calculation_version > 0),
  source_revision_hash text not null check (char_length(source_revision_hash) = 64),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, member_id, work_date),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.timesheet_periods (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  month_start date not null,
  status text not null default 'open' check (status in ('open', 'reconciling', 'closed', 'reopened')),
  revision integer not null default 1 check (revision > 0),
  closed_at timestamptz,
  closed_by uuid,
  reopen_reason text,
  policy_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(policy_snapshot) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, month_start),
  foreign key (organization_id, closed_by)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (month_start = date_trunc('month', month_start)::date),
  check ((status = 'closed' and closed_at is not null and closed_by is not null) or status <> 'closed')
);

create table public.timesheet_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  period_id uuid not null,
  revision integer not null check (revision > 0),
  member_id uuid not null,
  daily_rows jsonb not null check (jsonb_typeof(daily_rows) = 'object'),
  totals jsonb not null check (jsonb_typeof(totals) = 'object'),
  source_hash text not null check (char_length(source_hash) = 64),
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, period_id, revision, member_id),
  foreign key (organization_id, period_id)
    references public.timesheet_periods(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.timesheet_period_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  period_id uuid not null,
  event_type text not null check (event_type in ('reconciliation_started', 'closed', 'reopened')),
  actor_member_id uuid not null,
  reason text not null check (char_length(trim(reason)) between 3 and 1000),
  recorded_at timestamptz not null default timezone('utc', now()),
  payload jsonb not null default '{}'::jsonb check (jsonb_typeof(payload) = 'object'),
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  unique (organization_id, id),
  unique (organization_id, idempotency_key),
  foreign key (organization_id, period_id)
    references public.timesheet_periods(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create index attendance_day_summaries_member_day_idx
  on public.attendance_day_summaries(organization_id, member_id, work_date);
create index timesheet_snapshots_period_idx
  on public.timesheet_snapshots(organization_id, period_id, revision, member_id);
create index timesheet_period_events_period_idx
  on public.timesheet_period_events(organization_id, period_id, recorded_at desc);

create trigger attendance_day_summaries_set_updated_at
before update on public.attendance_day_summaries
for each row execute function private.set_updated_at();

create trigger timesheet_periods_set_updated_at
before update on public.timesheet_periods
for each row execute function private.set_updated_at();

create trigger timesheet_snapshots_immutable
before update or delete on public.timesheet_snapshots
for each row execute function private.prevent_immutable_mutation();

create trigger timesheet_period_events_immutable
before update or delete on public.timesheet_period_events
for each row execute function private.prevent_immutable_mutation();

create or replace function private.prevent_closed_timesheet_day_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid := coalesce(new.organization_id, old.organization_id);
  v_work_date date := coalesce(new.work_date, old.work_date);
begin
  if exists (
    select 1
    from public.timesheet_periods p
    where p.organization_id = v_org
      and p.month_start = date_trunc('month', v_work_date)::date
      and p.status = 'closed'
  ) then
    raise exception using errcode = '55000', message = 'PERIOD_CLOSED';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger attendance_day_summaries_closed_guard
before insert or update or delete on public.attendance_day_summaries
for each row execute function private.prevent_closed_timesheet_day_mutation();

create or replace function private.assert_timesheet_hr(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
begin
  v_actor_id := private.current_member_id(p_organization_id);
  if v_actor_id is null or not private.has_capability(p_organization_id, 'can_manage_attendance') then
    raise exception using errcode = '42501', message = 'TIMESHEET_HR_PERMISSION_REQUIRED';
  end if;
  return v_actor_id;
end;
$$;

create or replace function private.assert_timesheet_admin(p_organization_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
begin
  select m.id into v_actor_id
  from public.organization_members m
  where m.organization_id = p_organization_id
    and m.id = private.current_member_id(p_organization_id)
    and m.status = 'active'
    and m.role = 'admin';
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'TIMESHEET_ADMIN_PERMISSION_REQUIRED';
  end if;
  return v_actor_id;
end;
$$;

create or replace function private.timesheet_live_member_json(
  p_organization_id uuid,
  p_member_id uuid,
  p_month_start date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rows jsonb;
  v_totals jsonb;
  v_timezone text;
begin
  select o.timezone into v_timezone
  from public.organizations o
  where o.id = p_organization_id;
  if v_timezone is null then
    raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'work_date', s.work_date,
        'shift_label', case when si.id is null then '—'
          else to_char(si.starts_at at time zone v_timezone, 'HH24:MI') || '–' ||
               to_char(si.ends_at at time zone v_timezone, 'HH24:MI') end,
        'allowed_mode', coalesce(si.allowed_mode, 'office'),
        'first_check_in_at', session_bounds.first_check_in_at,
        'last_check_out_at', session_bounds.last_check_out_at,
        'state', case when s.state = 'verified' then 'ready' else s.state end,
        'scheduled_seconds', s.scheduled_seconds,
        'worked_seconds', s.worked_office_seconds + s.worked_remote_seconds,
        'worked_office_seconds', s.worked_office_seconds,
        'worked_remote_seconds', s.worked_remote_seconds,
        'paid_leave_seconds', s.paid_leave_seconds,
        'unpaid_leave_seconds', s.unpaid_leave_seconds,
        'unknown_seconds', s.unknown_seconds,
        'unexplained_seconds', s.unexplained_seconds,
        'outside_schedule_seconds', s.outside_schedule_seconds,
        'conflict_seconds', 0,
        'scheduled_units', s.scheduled_seconds::numeric / (s.standard_day_minutes * 60),
        'worked_units', (s.worked_office_seconds + s.worked_remote_seconds)::numeric / (s.standard_day_minutes * 60),
        'paid_leave_units', s.paid_leave_seconds::numeric / (s.standard_day_minutes * 60),
        'unpaid_leave_units', s.unpaid_leave_seconds::numeric / (s.standard_day_minutes * 60),
        'schedule_snapshot_ref', coalesce(si.id::text, 'summary:' || s.id::text),
        'policy_snapshot_version', coalesce(si.version, 1),
        'exceptions', s.exceptions
      ) order by s.work_date
    ),
    '[]'::jsonb
  ) into v_rows
  from public.attendance_day_summaries s
  left join public.shift_instances si
    on si.organization_id = s.organization_id
   and si.member_id = s.member_id
   and si.work_date = s.work_date
  left join lateral (
    select min(a.starts_at) as first_check_in_at, max(a.ends_at) as last_check_out_at
    from public.attendance_sessions a
    where a.organization_id = s.organization_id
      and a.member_id = s.member_id
      and a.shift_instance_id = si.id
      and a.status <> 'superseded'
  ) session_bounds on true
  where s.organization_id = p_organization_id
    and s.member_id = p_member_id
    and s.work_date >= p_month_start
    and s.work_date < (p_month_start + interval '1 month')::date;

  select jsonb_build_object(
    'scheduled_seconds', coalesce(sum(s.scheduled_seconds), 0),
    'worked_seconds', coalesce(sum(s.worked_office_seconds + s.worked_remote_seconds), 0),
    'worked_office_seconds', coalesce(sum(s.worked_office_seconds), 0),
    'worked_remote_seconds', coalesce(sum(s.worked_remote_seconds), 0),
    'paid_leave_seconds', coalesce(sum(s.paid_leave_seconds), 0),
    'unpaid_leave_seconds', coalesce(sum(s.unpaid_leave_seconds), 0),
    'unknown_seconds', coalesce(sum(s.unknown_seconds), 0),
    'unexplained_seconds', coalesce(sum(s.unexplained_seconds), 0),
    'outside_schedule_seconds', coalesce(sum(s.outside_schedule_seconds), 0),
    'scheduled_units', coalesce(sum(s.scheduled_seconds::numeric / (s.standard_day_minutes * 60)), 0),
    'worked_units', coalesce(sum((s.worked_office_seconds + s.worked_remote_seconds)::numeric / (s.standard_day_minutes * 60)), 0),
    'paid_leave_units', coalesce(sum(s.paid_leave_seconds::numeric / (s.standard_day_minutes * 60)), 0),
    'unpaid_leave_units', coalesce(sum(s.unpaid_leave_seconds::numeric / (s.standard_day_minutes * 60)), 0),
    'scheduled_days', count(*) filter (where s.scheduled_seconds > 0),
    'requires_reconciliation_days', count(*) filter (where s.state <> 'verified')
  ) into v_totals
  from public.attendance_day_summaries s
  where s.organization_id = p_organization_id
    and s.member_id = p_member_id
    and s.work_date >= p_month_start
    and s.work_date < (p_month_start + interval '1 month')::date;

  return jsonb_build_object('rows', v_rows, 'totals', v_totals);
end;
$$;

create or replace function public.rpc_internal_upsert_attendance_day_summary(
  p_organization_id uuid,
  p_member_id uuid,
  p_work_date date,
  p_summary jsonb,
  p_source_revision_hash text
)
returns public.attendance_day_summaries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.attendance_day_summaries%rowtype;
begin
  if p_summary is null or jsonb_typeof(p_summary) <> 'object' then
    raise exception using errcode = '22023', message = 'TIMESHEET_SUMMARY_INVALID';
  end if;
  if p_source_revision_hash is null or char_length(p_source_revision_hash) <> 64 then
    raise exception using errcode = '22023', message = 'SOURCE_REVISION_HASH_INVALID';
  end if;
  if exists (
    select 1 from public.timesheet_periods p
    where p.organization_id = p_organization_id
      and p.month_start = date_trunc('month', p_work_date)::date
      and p.status = 'closed'
  ) then
    raise exception using errcode = '55000', message = 'PERIOD_CLOSED';
  end if;

  insert into public.attendance_day_summaries (
    organization_id, member_id, work_date, scheduled_seconds, worked_office_seconds,
    worked_remote_seconds, paid_leave_seconds, unpaid_leave_seconds, unexplained_seconds,
    unknown_seconds, late_seconds, early_seconds, outside_schedule_seconds, standard_day_minutes,
    state, exceptions, calculation_version, source_revision_hash
  ) values (
    p_organization_id, p_member_id, p_work_date,
    (p_summary->>'scheduled_seconds')::bigint,
    coalesce((p_summary->>'worked_office_seconds')::bigint, 0),
    coalesce((p_summary->>'worked_remote_seconds')::bigint, 0),
    coalesce((p_summary->>'paid_leave_seconds')::bigint, 0),
    coalesce((p_summary->>'unpaid_leave_seconds')::bigint, 0),
    coalesce((p_summary->>'unexplained_seconds')::bigint, 0),
    coalesce((p_summary->>'unknown_seconds')::bigint, 0),
    coalesce((p_summary->>'late_seconds')::bigint, 0),
    coalesce((p_summary->>'early_seconds')::bigint, 0),
    coalesce((p_summary->>'outside_schedule_seconds')::bigint, 0),
    (p_summary->>'standard_day_minutes')::integer,
    case when p_summary->>'state' = 'ready' then 'verified' else p_summary->>'state' end,
    coalesce(p_summary->'exceptions', '[]'::jsonb),
    coalesce((p_summary->>'calculation_version')::integer, 1),
    lower(p_source_revision_hash)
  )
  on conflict (organization_id, member_id, work_date) do update
  set scheduled_seconds = excluded.scheduled_seconds,
      worked_office_seconds = excluded.worked_office_seconds,
      worked_remote_seconds = excluded.worked_remote_seconds,
      paid_leave_seconds = excluded.paid_leave_seconds,
      unpaid_leave_seconds = excluded.unpaid_leave_seconds,
      unexplained_seconds = excluded.unexplained_seconds,
      unknown_seconds = excluded.unknown_seconds,
      late_seconds = excluded.late_seconds,
      early_seconds = excluded.early_seconds,
      outside_schedule_seconds = excluded.outside_schedule_seconds,
      standard_day_minutes = excluded.standard_day_minutes,
      state = excluded.state,
      exceptions = excluded.exceptions,
      calculation_version = excluded.calculation_version,
      source_revision_hash = excluded.source_revision_hash,
      version = public.attendance_day_summaries.version + 1
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.rpc_get_timesheet(
  p_organization_id uuid,
  p_month_start date,
  p_member_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_member_id uuid;
  v_member public.organization_members%rowtype;
  v_period public.timesheet_periods%rowtype;
  v_snapshot public.timesheet_snapshots%rowtype;
  v_live jsonb;
begin
  if p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception using errcode = '22023', message = 'MONTH_START_REQUIRED';
  end if;
  v_actor_id := private.current_member_id(p_organization_id);
  if v_actor_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  v_member_id := coalesce(p_member_id, v_actor_id);
  if v_member_id <> v_actor_id and not private.has_capability(p_organization_id, 'can_manage_attendance') then
    raise exception using errcode = '42501', message = 'TIMESHEET_SCOPE_DENIED';
  end if;
  select * into v_member from public.organization_members m
  where m.organization_id = p_organization_id and m.id = v_member_id;
  if not found then raise exception using errcode = 'P0002', message = 'MEMBER_NOT_FOUND'; end if;

  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.month_start = p_month_start;

  if v_period.id is not null and v_period.status = 'closed' then
    select * into v_snapshot from public.timesheet_snapshots s
    where s.organization_id = p_organization_id
      and s.period_id = v_period.id
      and s.revision = v_period.revision
      and s.member_id = v_member_id;
    return jsonb_build_object(
      'organization_id', p_organization_id,
      'member_id', v_member_id,
      'member_name', v_member.display_name,
      'employee_code', v_member.employee_code,
      'month_start', p_month_start,
      'period_id', v_period.id,
      'period_status', 'closed',
      'period_version', v_period.version,
      'revision', v_period.revision,
      'source', 'snapshot',
      'rows', coalesce(v_snapshot.daily_rows->'rows', '[]'::jsonb),
      'totals', coalesce(
        v_snapshot.totals,
        jsonb_build_object(
          'scheduled_seconds', 0,
          'worked_seconds', 0,
          'worked_office_seconds', 0,
          'worked_remote_seconds', 0,
          'paid_leave_seconds', 0,
          'unpaid_leave_seconds', 0,
          'unknown_seconds', 0,
          'unexplained_seconds', 0,
          'outside_schedule_seconds', 0,
          'scheduled_units', 0,
          'worked_units', 0,
          'paid_leave_units', 0,
          'unpaid_leave_units', 0,
          'scheduled_days', 0,
          'requires_reconciliation_days', 0
        )
      )
    );
  end if;

  v_live := private.timesheet_live_member_json(p_organization_id, v_member_id, p_month_start);
  return jsonb_build_object(
    'organization_id', p_organization_id,
    'member_id', v_member_id,
    'member_name', v_member.display_name,
    'employee_code', v_member.employee_code,
    'month_start', p_month_start,
    'period_id', v_period.id,
    'period_status', coalesce(v_period.status, 'open'),
    'period_version', coalesce(v_period.version, 1),
    'revision', coalesce(v_period.revision, 1),
    'source', 'live',
    'rows', v_live->'rows',
    'totals', v_live->'totals'
  );
end;
$$;

create or replace function public.rpc_begin_timesheet_reconciliation(
  p_organization_id uuid,
  p_month_start date,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_period public.timesheet_periods%rowtype;
  v_existing_type text;
begin
  if p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception using errcode = '22023', message = 'MONTH_START_REQUIRED';
  end if;
  v_actor_id := private.assert_timesheet_hr(p_organization_id);
  select e.event_type into v_existing_type from public.timesheet_period_events e
  where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_type <> 'reconciliation_started' then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    select p.* into v_period from public.timesheet_periods p join public.timesheet_period_events e on e.period_id = p.id
    where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
    return to_jsonb(v_period);
  end if;

  insert into public.timesheet_periods (organization_id, month_start, policy_snapshot)
  values (p_organization_id, p_month_start, jsonb_build_object('calculation_version', 1, 'schema_version', 1))
  on conflict (organization_id, month_start) do nothing;
  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.month_start = p_month_start for update;
  if v_period.version <> p_expected_version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;
  if v_period.status = 'closed' then
    raise exception using errcode = '55000', message = 'PERIOD_CLOSED';
  end if;

  update public.timesheet_periods
  set status = 'reconciling', version = version + 1
  where organization_id = p_organization_id and id = v_period.id
  returning * into v_period;
  insert into public.timesheet_period_events (
    organization_id, period_id, event_type, actor_member_id, reason, payload, idempotency_key
  ) values (
    p_organization_id, v_period.id, 'reconciliation_started', v_actor_id,
    'Bắt đầu đối soát công tháng', jsonb_build_object('revision', v_period.revision), p_idempotency_key
  );
  return to_jsonb(v_period);
end;
$$;

create or replace function public.rpc_close_timesheet(
  p_organization_id uuid,
  p_month_start date,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_period public.timesheet_periods%rowtype;
  v_existing_type text;
  v_blocking_count integer;
  v_member_id uuid;
  v_live jsonb;
  v_daily_rows jsonb;
  v_totals jsonb;
  v_source_hash text;
  v_now timestamptz := clock_timestamp();
begin
  if p_month_start <> date_trunc('month', p_month_start)::date then
    raise exception using errcode = '22023', message = 'MONTH_START_REQUIRED';
  end if;
  v_actor_id := private.assert_timesheet_admin(p_organization_id);
  select e.event_type into v_existing_type from public.timesheet_period_events e
  where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_type <> 'closed' then raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    select p.* into v_period from public.timesheet_periods p join public.timesheet_period_events e on e.period_id = p.id
    where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
    return to_jsonb(v_period);
  end if;
  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.month_start = p_month_start for update;
  if not found then raise exception using errcode = 'P0002', message = 'TIMESHEET_PERIOD_NOT_FOUND'; end if;
  if v_period.version <> p_expected_version then raise exception using errcode = '40001', message = 'VERSION_CONFLICT'; end if;
  if v_period.status not in ('reconciling', 'reopened') then
    raise exception using errcode = '55000', message = 'TIMESHEET_NOT_RECONCILING';
  end if;

  select count(*) into v_blocking_count
  from public.shift_instances si
  left join public.attendance_day_summaries s
    on s.organization_id = si.organization_id and s.member_id = si.member_id and s.work_date = si.work_date
  where si.organization_id = p_organization_id
    and si.work_date >= p_month_start
    and si.work_date < (p_month_start + interval '1 month')::date
    and si.status <> 'canceled'
    and (s.id is null or s.state <> 'verified');
  if v_blocking_count > 0 then
    raise exception using errcode = '55000', message = 'TIMESHEET_BLOCKING_EXCEPTIONS';
  end if;

  for v_member_id in
    select distinct q.member_id from (
      select si.member_id from public.shift_instances si
      where si.organization_id = p_organization_id
        and si.work_date >= p_month_start and si.work_date < (p_month_start + interval '1 month')::date
        and si.status <> 'canceled'
      union
      select s.member_id from public.attendance_day_summaries s
      where s.organization_id = p_organization_id
        and s.work_date >= p_month_start and s.work_date < (p_month_start + interval '1 month')::date
    ) q
  loop
    v_live := private.timesheet_live_member_json(p_organization_id, v_member_id, p_month_start);
    v_daily_rows := jsonb_build_object('schema_version', 1, 'rows', v_live->'rows');
    v_totals := v_live->'totals';
    v_source_hash := pg_catalog.encode(
      extensions.digest(convert_to(v_daily_rows::text || v_totals::text || v_period.policy_snapshot::text, 'UTF8'), 'sha256'),
      'hex'
    );
    insert into public.timesheet_snapshots (
      organization_id, period_id, revision, member_id, daily_rows, totals, source_hash
    ) values (
      p_organization_id, v_period.id, v_period.revision, v_member_id, v_daily_rows, v_totals, v_source_hash
    );
  end loop;

  update public.timesheet_periods
  set status = 'closed', closed_at = v_now, closed_by = v_actor_id, reopen_reason = null, version = version + 1
  where organization_id = p_organization_id and id = v_period.id
  returning * into v_period;
  insert into public.timesheet_period_events (
    organization_id, period_id, event_type, actor_member_id, reason, payload, idempotency_key, recorded_at
  ) values (
    p_organization_id, v_period.id, 'closed', v_actor_id, 'Chốt bảng công tháng',
    jsonb_build_object('revision', v_period.revision, 'closed_at', v_now), p_idempotency_key, v_now
  );
  return to_jsonb(v_period);
end;
$$;

create or replace function public.rpc_reopen_timesheet(
  p_organization_id uuid,
  p_period_id uuid,
  p_reason text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid;
  v_period public.timesheet_periods%rowtype;
  v_existing_type text;
begin
  if p_reason is null or char_length(trim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'TIMESHEET_REOPEN_REASON_REQUIRED';
  end if;
  v_actor_id := private.assert_timesheet_admin(p_organization_id);
  select e.event_type into v_existing_type from public.timesheet_period_events e
  where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
  if found then
    if v_existing_type <> 'reopened' then raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED'; end if;
    select p.* into v_period from public.timesheet_periods p join public.timesheet_period_events e on e.period_id = p.id
    where e.organization_id = p_organization_id and e.idempotency_key = p_idempotency_key;
    return to_jsonb(v_period);
  end if;
  select * into v_period from public.timesheet_periods p
  where p.organization_id = p_organization_id and p.id = p_period_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'TIMESHEET_PERIOD_NOT_FOUND'; end if;
  if v_period.version <> p_expected_version then raise exception using errcode = '40001', message = 'VERSION_CONFLICT'; end if;
  if v_period.status <> 'closed' then raise exception using errcode = '55000', message = 'TIMESHEET_NOT_CLOSED'; end if;

  update public.timesheet_periods
  set status = 'reopened', revision = revision + 1, closed_at = null, closed_by = null,
      reopen_reason = trim(p_reason), version = version + 1
  where organization_id = p_organization_id and id = p_period_id
  returning * into v_period;
  insert into public.timesheet_period_events (
    organization_id, period_id, event_type, actor_member_id, reason, payload, idempotency_key
  ) values (
    p_organization_id, v_period.id, 'reopened', v_actor_id, trim(p_reason),
    jsonb_build_object('new_revision', v_period.revision), p_idempotency_key
  );
  return to_jsonb(v_period);
end;
$$;

alter table public.attendance_day_summaries enable row level security;
alter table public.timesheet_periods enable row level security;
alter table public.timesheet_snapshots enable row level security;
alter table public.timesheet_period_events enable row level security;

create policy attendance_day_summaries_read_own_or_hr on public.attendance_day_summaries
for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));

create policy timesheet_periods_read_active_member on public.timesheet_periods
for select to authenticated
using (private.current_member_id(organization_id) is not null);

create policy timesheet_snapshots_read_own_or_hr on public.timesheet_snapshots
for select to authenticated
using (member_id = private.current_member_id(organization_id) or private.has_capability(organization_id, 'can_manage_attendance'));

create policy timesheet_period_events_read_hr on public.timesheet_period_events
for select to authenticated
using (private.has_capability(organization_id, 'can_manage_attendance'));

grant select on public.attendance_day_summaries, public.timesheet_periods, public.timesheet_snapshots, public.timesheet_period_events to authenticated;
revoke insert, update, delete, truncate, references, trigger
on public.attendance_day_summaries, public.timesheet_periods, public.timesheet_snapshots, public.timesheet_period_events
from authenticated;

revoke all on function private.prevent_closed_timesheet_day_mutation() from public, anon, authenticated;
revoke all on function private.assert_timesheet_hr(uuid) from public, anon, authenticated;
revoke all on function private.assert_timesheet_admin(uuid) from public, anon, authenticated;
revoke all on function private.timesheet_live_member_json(uuid, uuid, date) from public, anon, authenticated;
revoke all on function public.rpc_internal_upsert_attendance_day_summary(uuid, uuid, date, jsonb, text) from public, anon, authenticated;
grant execute on function public.rpc_internal_upsert_attendance_day_summary(uuid, uuid, date, jsonb, text) to service_role;

revoke all on function public.rpc_get_timesheet(uuid, date, uuid) from public, anon;
revoke all on function public.rpc_begin_timesheet_reconciliation(uuid, date, integer, text) from public, anon;
revoke all on function public.rpc_close_timesheet(uuid, date, integer, text) from public, anon;
revoke all on function public.rpc_reopen_timesheet(uuid, uuid, text, integer, text) from public, anon;
grant execute on function public.rpc_get_timesheet(uuid, date, uuid) to authenticated;
grant execute on function public.rpc_begin_timesheet_reconciliation(uuid, date, integer, text) to authenticated;
grant execute on function public.rpc_close_timesheet(uuid, date, integer, text) to authenticated;
grant execute on function public.rpc_reopen_timesheet(uuid, uuid, text, integer, text) to authenticated;

-- ============================================================================
-- END 00000000000009_p07_timesheets.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000010_p08_notifications.sql
-- ============================================================================

-- P08: durable notification inbox, reminder engine, push endpoints and leased outbox workers.
-- Business mutations continue to enqueue outbox rows transactionally; delivery is server-side and retryable.

alter table private.outbox_events
  add column if not exists lease_owner uuid,
  add column if not exists lease_until timestamptz,
  add column if not exists last_error_code text,
  add column if not exists dead_lettered_at timestamptz;

update private.outbox_events
set status = 'done'
where status = 'published';

alter table private.outbox_events
  drop constraint if exists outbox_events_status_check;

alter table private.outbox_events
  add constraint outbox_events_status_check
  check (status in ('pending', 'processing', 'done', 'failed'));

create index if not exists private_outbox_claim_idx
  on private.outbox_events(status, available_at, lease_until, created_at)
  where status in ('pending', 'processing', 'failed') and dead_lettered_at is null;

create table public.push_endpoints (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  device_id uuid not null,
  provider text not null check (provider in ('expo', 'webpush')),
  token_encrypted text not null check (char_length(token_encrypted) between 16 and 8192),
  token_hash text not null check (char_length(token_hash) between 32 and 256),
  active boolean not null default true,
  last_error_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, provider, token_hash),
  foreign key (organization_id, device_id)
    references public.user_devices(organization_id, id)
    on delete restrict
);

create index push_endpoints_device_idx
  on public.push_endpoints(organization_id, device_id, active, provider);

create table public.notification_preferences (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  member_id uuid not null,
  push_enabled boolean not null default true,
  email_enabled boolean not null default false,
  quiet_hours jsonb not null default '{}'::jsonb check (jsonb_typeof(quiet_hours) = 'object'),
  closer_reminder_mode boolean not null default false,
  closer_mode_reason text,
  closer_mode_review_at date,
  daily_push_limit integer not null default 8 check (daily_push_limit between 0 and 50),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  primary key (organization_id, member_id),
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (
    not closer_reminder_mode
    or (nullif(trim(closer_mode_reason), '') is not null and closer_mode_review_at is not null)
  )
);

create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  recipient_member_id uuid not null,
  kind text not null check (kind in (
    'task_assigned',
    'task_unacknowledged',
    'task_due_soon',
    'task_overdue',
    'task_blocked',
    'task_review_requested',
    'request_result',
    'report_ready',
    'digest',
    'system'
  )),
  title text not null check (char_length(trim(title)) between 1 and 180),
  body text not null check (char_length(trim(body)) between 1 and 500),
  target_type text not null check (target_type in ('task', 'request', 'report', 'system')),
  target_id uuid,
  safe_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(safe_payload) = 'object'),
  dedupe_key text not null check (char_length(trim(dedupe_key)) between 1 and 240),
  created_at timestamptz not null default timezone('utc', now()),
  read_at timestamptz,
  expires_at timestamptz,
  unique (organization_id, id),
  unique (organization_id, recipient_member_id, dedupe_key),
  foreign key (organization_id, recipient_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (expires_at is null or expires_at > created_at)
);

create index notifications_recipient_feed_idx
  on public.notifications(organization_id, recipient_member_id, created_at desc, id desc);
create index notifications_recipient_unread_idx
  on public.notifications(organization_id, recipient_member_id, created_at desc)
  where read_at is null;

create table public.notification_deliveries (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  notification_id uuid not null,
  endpoint_id uuid,
  channel text not null check (channel in ('in_app', 'push', 'email')),
  status text not null default 'pending'
    check (status in ('pending', 'sending', 'accepted', 'provider_confirmed', 'failed', 'expired')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default timezone('utc', now()),
  provider_ticket_id text,
  last_error_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, notification_id)
    references public.notifications(organization_id, id)
    on delete restrict,
  foreign key (organization_id, endpoint_id)
    references public.push_endpoints(organization_id, id)
    on delete restrict,
  check ((channel = 'push' and endpoint_id is not null) or (channel <> 'push' and endpoint_id is null))
);

create unique index notification_deliveries_push_unique_idx
  on public.notification_deliveries(notification_id, channel, endpoint_id)
  where endpoint_id is not null;
create unique index notification_deliveries_non_endpoint_unique_idx
  on public.notification_deliveries(notification_id, channel)
  where endpoint_id is null;
create index notification_deliveries_retry_idx
  on public.notification_deliveries(status, next_attempt_at, channel)
  where status in ('pending', 'failed', 'accepted');

create table public.task_reminder_snoozes (
  organization_id uuid not null references public.organizations(id) on delete restrict,
  task_id uuid not null,
  member_id uuid not null,
  rule_key text not null check (rule_key in ('unack', 'due_soon', 'overdue', 'blocked', 'reviewer')),
  snoozed_until timestamptz not null,
  set_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  primary key (organization_id, task_id, member_id, rule_key),
  foreign key (organization_id, task_id)
    references public.tasks(organization_id, id)
    on delete restrict,
  foreign key (organization_id, member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (snoozed_until > set_at)
);

create index task_reminder_snoozes_expiry_idx
  on public.task_reminder_snoozes(snoozed_until);

create trigger push_endpoints_set_updated_at
before update on public.push_endpoints
for each row execute function private.set_updated_at();

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function private.set_updated_at();

create trigger notification_deliveries_set_updated_at
before update on public.notification_deliveries
for each row execute function private.set_updated_at();

create or replace function private.deactivate_push_endpoints_for_revoked_device()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.revoked_at is null and new.revoked_at is not null then
    update public.push_endpoints
    set active = false,
        last_error_code = 'DEVICE_REVOKED'
    where organization_id = new.organization_id
      and device_id = new.id
      and active;
  end if;
  return new;
end;
$$;

create trigger user_devices_deactivate_push_endpoints
after update of revoked_at on public.user_devices
for each row execute function private.deactivate_push_endpoints_for_revoked_device();

create or replace function private.notification_member_on_approved_leave(
  p_organization_id uuid,
  p_member_id uuid,
  p_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.employee_requests as r
    where r.organization_id = p_organization_id
      and r.member_id = p_member_id
      and r.status = 'approved'
      and r.request_type in ('leave', 'early_leave', 'late_arrival')
      and r.starts_at <= p_at
      and r.ends_at > p_at
  );
$$;

create or replace function private.notification_working_seconds_between(
  p_organization_id uuid,
  p_member_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  with segments as (
    select
      greatest((segment ->> 'start')::timestamptz, p_starts_at) as starts_at,
      least((segment ->> 'end')::timestamptz, p_ends_at) as ends_at
    from public.shift_instances as s
    cross join lateral jsonb_array_elements(s.working_segments) as segment
    where s.organization_id = p_organization_id
      and s.member_id = p_member_id
      and s.status = 'scheduled'
      and s.ends_at > p_starts_at
      and s.starts_at < p_ends_at
  ),
  valid_segments as (
    select starts_at, ends_at
    from segments
    where ends_at > starts_at
  ),
  approved_leave as (
    select rs.starts_at, rs.ends_at
    from public.request_segments as rs
    join public.employee_requests as r
      on r.organization_id = rs.organization_id
     and r.id = rs.request_id
    where r.organization_id = p_organization_id
      and r.member_id = p_member_id
      and r.status = 'approved'
      and r.request_type in ('leave', 'early_leave', 'late_arrival')
      and rs.ends_at > p_starts_at
      and rs.starts_at < p_ends_at
  )
  select coalesce(sum(greatest(
    0,
    extract(epoch from (v.ends_at - v.starts_at))::bigint - coalesce((
      select sum(extract(epoch from (
        least(v.ends_at, l.ends_at) - greatest(v.starts_at, l.starts_at)
      )))::bigint
      from approved_leave as l
      where l.ends_at > v.starts_at
        and l.starts_at < v.ends_at
    ), 0)
  )), 0)::bigint
  from valid_segments as v;
$$;

create or replace function private.notification_reminder_policy(
  p_organization_id uuid,
  p_at timestamptz
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select p.config
    from public.policy_versions as p
    where p.organization_id = p_organization_id
      and p.policy_kind = 'reminders'
      and p.effective_from <= p_at
    order by p.effective_from desc, p.version_number desc
    limit 1
  ), '{}'::jsonb);
$$;

create or replace function private.notification_unack_threshold_minutes(
  p_reminder_profile jsonb,
  p_profile_reason text,
  p_default integer
)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case
    when coalesce(p_reminder_profile ->> 'mode', 'standard') = 'closer'
      and nullif(trim(coalesce(p_profile_reason, '')), '') is not null
      then greatest(5, least(p_default, coalesce((p_reminder_profile ->> 'unack_minutes')::integer, 15)))
    else p_default
  end;
$$;

create or replace function private.enqueue_task_reminders(p_now timestamptz default clock_timestamp())
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_org_timezone text;
  v_policy jsonb;
  v_default_unack integer;
  v_due_soon integer;
  v_recipient uuid;
  v_rule text;
  v_threshold integer;
  v_working_seconds bigint;
  v_count integer := 0;
  v_dedupe_key text;
begin
  for v_task in
    select t.*
    from public.tasks as t
    join public.organization_members as m
      on m.organization_id = t.organization_id
     and m.id = t.assignee_member_id
     and m.status = 'active'
    where t.status not in ('done', 'canceled', 'waived')
      and t.visible_from <= p_now
  loop
    select o.timezone into v_org_timezone
    from public.organizations as o
    where o.id = v_task.organization_id;

    v_policy := private.notification_reminder_policy(v_task.organization_id, p_now);
    v_default_unack := greatest(5, least(240, coalesce((v_policy ->> 'unack_minutes')::integer, 30)));
    v_due_soon := greatest(5, least(1440, coalesce((v_policy ->> 'due_soon_minutes')::integer, 60)));
    v_threshold := private.notification_unack_threshold_minutes(
      v_task.reminder_profile,
      v_task.reminder_profile_reason,
      v_default_unack
    );

    v_recipient := null;
    v_rule := null;

    if v_task.blocked_at is not null and v_task.blocker_owner_member_id is not null then
      v_recipient := v_task.blocker_owner_member_id;
      v_rule := 'blocked';
    elsif v_task.status = 'in_review' and v_task.reviewer_member_id is not null then
      v_recipient := v_task.reviewer_member_id;
      v_rule := 'reviewer';
    elsif v_task.acknowledged_at is null then
      v_working_seconds := private.notification_working_seconds_between(
        v_task.organization_id,
        v_task.assignee_member_id,
        v_task.assigned_at,
        p_now
      );
      if v_working_seconds >= v_threshold * 60 then
        v_recipient := v_task.assignee_member_id;
        v_rule := 'unack';
      end if;
    end if;

    if v_rule is null and v_task.due_at <= p_now then
      v_recipient := v_task.assignee_member_id;
      v_rule := 'overdue';
    elsif v_rule is null and v_task.due_at <= p_now + make_interval(mins => v_due_soon) then
      v_recipient := v_task.assignee_member_id;
      v_rule := 'due_soon';
    end if;

    if v_rule is null or v_recipient is null then
      continue;
    end if;

    if exists (
      select 1
      from public.task_reminder_snoozes as s
      where s.organization_id = v_task.organization_id
        and s.task_id = v_task.id
        and s.member_id = v_recipient
        and s.rule_key = v_rule
        and s.snoozed_until > p_now
    ) then
      continue;
    end if;

    v_dedupe_key := 'reminder:' || v_task.id::text || ':' || v_recipient::text || ':' || v_rule || ':' ||
      v_task.version::text || ':' || (p_now at time zone v_org_timezone)::date::text;

    insert into private.outbox_events (
      organization_id,
      event_type,
      entity_type,
      entity_id,
      dedupe_key,
      payload,
      available_at
    ) values (
      v_task.organization_id,
      'reminder.task_' || v_rule,
      'task',
      v_task.id,
      v_dedupe_key,
      jsonb_build_object(
        'task_id', v_task.id,
        'recipient_member_id', v_recipient,
        'rule_key', v_rule,
        'task_version', v_task.version,
        'threshold_minutes', case when v_rule = 'unack' then v_threshold else null end
      ),
      p_now
    ) on conflict (organization_id, dedupe_key) do nothing;

    if found then
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

create or replace function public.rpc_internal_enqueue_task_reminders(p_now timestamptz default clock_timestamp())
returns integer
language sql
security definer
set search_path = ''
as $$
  select private.enqueue_task_reminders(p_now);
$$;

create or replace function private.notification_outbox_recipient(p_event private.outbox_events)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    case
      when nullif(p_event.payload ->> 'recipient_member_id', '') is not null
        then (p_event.payload ->> 'recipient_member_id')::uuid
      when nullif(p_event.payload ->> 'assignee_member_id', '') is not null
        then (p_event.payload ->> 'assignee_member_id')::uuid
      when nullif(p_event.payload ->> 'reviewer_member_id', '') is not null
        then (p_event.payload ->> 'reviewer_member_id')::uuid
      when nullif(p_event.payload ->> 'member_id', '') is not null
        then (p_event.payload ->> 'member_id')::uuid
      else null
    end,
    case when p_event.entity_type = 'task' then (
      select case
        when p_event.event_type = 'task.review_requested' then t.reviewer_member_id
        else t.assignee_member_id
      end
      from public.tasks as t
      where t.organization_id = p_event.organization_id
        and t.id = p_event.entity_id
    ) end,
    case when p_event.entity_type = 'employee_request' then (
      select r.member_id
      from public.employee_requests as r
      where r.organization_id = p_event.organization_id
        and r.id = p_event.entity_id
    ) end
  );
$$;

create or replace function private.notification_kind_for_event(p_event_type text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_event_type = 'task.assigned' then 'task_assigned'
    when p_event_type = 'task.review_requested' then 'task_review_requested'
    when p_event_type = 'reminder.task_unack' then 'task_unacknowledged'
    when p_event_type = 'reminder.task_due_soon' then 'task_due_soon'
    when p_event_type = 'reminder.task_overdue' then 'task_overdue'
    when p_event_type = 'reminder.task_blocked' then 'task_blocked'
    when p_event_type = 'reminder.task_reviewer' then 'task_review_requested'
    when p_event_type like 'request.%' or p_event_type like 'leave.%' then 'request_result'
    when p_event_type like 'report.%' then 'report_ready'
    else 'system'
  end;
$$;

create or replace function private.notification_copy_for_event(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_task_title text;
begin
  if p_entity_type = 'task' then
    select t.title into v_task_title
    from public.tasks as t
    where t.id = p_entity_id;
  end if;

  return case
    when p_event_type = 'task.assigned' then jsonb_build_object(
      'title', 'Bạn có công việc mới',
      'body', coalesce(v_task_title, 'Một công việc mới đã được giao cho bạn.')
    )
    when p_event_type = 'task.review_requested' or p_event_type = 'reminder.task_reviewer' then jsonb_build_object(
      'title', 'Có công việc chờ duyệt',
      'body', coalesce(v_task_title, 'Mở công việc để xem nội dung cần duyệt.')
    )
    when p_event_type = 'reminder.task_unack' then jsonb_build_object(
      'title', 'Công việc đang chờ nhận',
      'body', coalesce(v_task_title, 'Bạn có công việc chưa xác nhận nhận việc.')
    )
    when p_event_type = 'reminder.task_due_soon' then jsonb_build_object(
      'title', 'Công việc sắp đến hạn',
      'body', coalesce(v_task_title, 'Một công việc của bạn sắp đến hạn.')
    )
    when p_event_type = 'reminder.task_overdue' then jsonb_build_object(
      'title', 'Công việc đã quá hạn',
      'body', coalesce(v_task_title, 'Một công việc của bạn đã quá hạn.')
    )
    when p_event_type = 'reminder.task_blocked' then jsonb_build_object(
      'title', 'Có công việc đang bị vướng',
      'body', coalesce(v_task_title, 'Bạn đang được chỉ định hỗ trợ tháo gỡ một công việc.')
    )
    when p_event_type like 'request.%' or p_event_type like 'leave.%' then jsonb_build_object(
      'title', 'Yêu cầu của bạn đã có cập nhật',
      'body', 'Mở ứng dụng để xem trạng thái mới nhất.'
    )
    when p_event_type like 'report.%' then jsonb_build_object(
      'title', 'Báo cáo đã sẵn sàng',
      'body', 'Mở ứng dụng để xem báo cáo mới.'
    )
    else jsonb_build_object(
      'title', 'Có cập nhật mới',
      'body', 'Mở ứng dụng để xem chi tiết.'
    )
  end;
end;
$$;

create or replace function private.notification_daily_push_limit(
  p_organization_id uuid,
  p_member_id uuid,
  p_at timestamptz
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select np.daily_push_limit
     from public.notification_preferences as np
     where np.organization_id = p_organization_id and np.member_id = p_member_id),
    greatest(0, least(50, coalesce((private.notification_reminder_policy(p_organization_id, p_at) ->> 'daily_push_limit')::integer, 8)))
  );
$$;

create or replace function private.notification_push_count_today(
  p_organization_id uuid,
  p_member_id uuid,
  p_at timestamptz
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.notification_deliveries as d
  join public.notifications as n
    on n.organization_id = d.organization_id
   and n.id = d.notification_id
  join public.organizations as o on o.id = n.organization_id
  where n.organization_id = p_organization_id
    and n.recipient_member_id = p_member_id
    and d.channel = 'push'
    and d.status in ('sending', 'accepted', 'provider_confirmed')
    and (d.created_at at time zone o.timezone)::date = (p_at at time zone o.timezone)::date;
$$;

create or replace function public.rpc_internal_claim_outbox(
  p_worker_id uuid,
  p_limit integer default 25
)
returns setof private.outbox_events
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_worker_id is null then
    raise exception using errcode = '22023', message = 'WORKER_ID_REQUIRED';
  end if;

  return query
  with candidates as (
    select e.id
    from private.outbox_events as e
    where e.dead_lettered_at is null
      and e.attempts < 5
      and e.available_at <= clock_timestamp()
      and (
        e.status in ('pending', 'failed')
        or (e.status = 'processing' and e.lease_until < clock_timestamp())
      )
    order by e.created_at, e.id
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 25), 25))
  )
  update private.outbox_events as e
  set status = 'processing',
      lease_owner = p_worker_id,
      lease_until = clock_timestamp() + interval '60 seconds',
      attempts = e.attempts + 1,
      last_error_code = null
  from candidates as c
  where e.id = c.id
  returning e.*;
end;
$$;

create or replace function public.rpc_internal_ack_outbox(
  p_event_id uuid,
  p_worker_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  update private.outbox_events
  set status = 'done',
      published_at = coalesce(published_at, clock_timestamp()),
      lease_owner = null,
      lease_until = null,
      last_error_code = null
  where id = p_event_id
    and status = 'processing'
    and lease_owner = p_worker_id;
  get diagnostics v_updated = row_count;
  return v_updated = 1;
end;
$$;

create or replace function public.rpc_internal_fail_outbox(
  p_event_id uuid,
  p_worker_id uuid,
  p_error_code text,
  p_retryable boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event private.outbox_events%rowtype;
  v_delay interval;
  v_dead boolean;
begin
  select * into v_event
  from private.outbox_events
  where id = p_event_id
  for update;

  if v_event.id is null or v_event.status <> 'processing' or v_event.lease_owner <> p_worker_id then
    return jsonb_build_object('updated', false, 'reason', 'LEASE_MISMATCH');
  end if;

  v_dead := not coalesce(p_retryable, true) or v_event.attempts >= 5;
  v_delay := case v_event.attempts
    when 1 then interval '1 minute'
    when 2 then interval '5 minutes'
    when 3 then interval '15 minutes'
    else interval '1 hour'
  end;

  update private.outbox_events
  set status = 'failed',
      available_at = case when v_dead then available_at else clock_timestamp() + v_delay end,
      lease_owner = null,
      lease_until = null,
      last_error_code = left(coalesce(nullif(trim(p_error_code), ''), 'UNKNOWN_ERROR'), 120),
      dead_lettered_at = case when v_dead then clock_timestamp() else null end
  where id = p_event_id;

  return jsonb_build_object('updated', true, 'dead_lettered', v_dead, 'attempts', v_event.attempts);
end;
$$;

create or replace function public.rpc_internal_materialize_notification(
  p_event_id uuid,
  p_worker_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event private.outbox_events%rowtype;
  v_recipient uuid;
  v_copy jsonb;
  v_kind text;
  v_target_type text;
  v_notification public.notifications%rowtype;
  v_push_enabled boolean;
  v_push_limit integer;
  v_push_count integer;
  v_suppress_push boolean;
  v_org_timezone text;
  v_digest_id uuid;
begin
  select * into v_event
  from private.outbox_events
  where id = p_event_id;

  if v_event.id is null or v_event.status <> 'processing' or v_event.lease_owner <> p_worker_id then
    raise exception using errcode = '42501', message = 'OUTBOX_LEASE_MISMATCH';
  end if;

  v_recipient := private.notification_outbox_recipient(v_event);
  if v_recipient is null then
    return jsonb_build_object('materialized', false, 'reason', 'NO_RECIPIENT');
  end if;

  if not exists (
    select 1 from public.organization_members as m
    where m.organization_id = v_event.organization_id
      and m.id = v_recipient
      and m.status = 'active'
  ) then
    return jsonb_build_object('materialized', false, 'reason', 'RECIPIENT_INACTIVE');
  end if;

  v_copy := private.notification_copy_for_event(v_event.event_type, v_event.entity_type, v_event.entity_id);
  v_kind := private.notification_kind_for_event(v_event.event_type);
  v_target_type := case
    when v_event.entity_type = 'task' then 'task'
    when v_event.entity_type = 'employee_request' then 'request'
    when v_event.entity_type like 'report%' then 'report'
    else 'system'
  end;

  insert into public.notifications (
    organization_id,
    recipient_member_id,
    kind,
    title,
    body,
    target_type,
    target_id,
    safe_payload,
    dedupe_key
  ) values (
    v_event.organization_id,
    v_recipient,
    v_kind,
    v_copy ->> 'title',
    v_copy ->> 'body',
    v_target_type,
    case when v_target_type = 'system' then null else v_event.entity_id end,
    jsonb_build_object(
      'kind', v_kind,
      'target_type', v_target_type,
      'target_id', case when v_target_type = 'system' then null else v_event.entity_id end,
      'notification_source', 'outbox'
    ),
    v_event.dedupe_key
  )
  on conflict (organization_id, recipient_member_id, dedupe_key)
  do update set dedupe_key = excluded.dedupe_key
  returning * into v_notification;

  insert into public.notification_deliveries (
    organization_id, notification_id, endpoint_id, channel, status, attempts, next_attempt_at
  ) values (
    v_notification.organization_id, v_notification.id, null, 'in_app', 'provider_confirmed', 1, clock_timestamp()
  ) on conflict do nothing;

  select coalesce(np.push_enabled, true)
  into v_push_enabled
  from public.organization_members as m
  left join public.notification_preferences as np
    on np.organization_id = m.organization_id and np.member_id = m.id
  where m.organization_id = v_notification.organization_id and m.id = v_recipient;

  v_suppress_push := v_event.event_type like 'reminder.%'
    and private.notification_member_on_approved_leave(v_event.organization_id, v_recipient, clock_timestamp());
  v_push_limit := private.notification_daily_push_limit(v_event.organization_id, v_recipient, clock_timestamp());
  v_push_count := private.notification_push_count_today(v_event.organization_id, v_recipient, clock_timestamp());

  if v_push_enabled and not v_suppress_push and v_push_count < v_push_limit then
    insert into public.notification_deliveries (
      organization_id, notification_id, endpoint_id, channel, status, attempts, next_attempt_at
    )
    select
      v_notification.organization_id,
      v_notification.id,
      pe.id,
      'push',
      'pending',
      0,
      clock_timestamp()
    from public.push_endpoints as pe
    join public.user_devices as d
      on d.organization_id = pe.organization_id and d.id = pe.device_id
    where pe.organization_id = v_notification.organization_id
      and d.member_id = v_recipient
      and d.revoked_at is null
      and pe.active
    on conflict do nothing;
  elsif v_push_enabled and not v_suppress_push and v_push_count >= v_push_limit then
    select o.timezone into v_org_timezone from public.organizations as o where o.id = v_event.organization_id;
    insert into public.notifications (
      organization_id, recipient_member_id, kind, title, body, target_type, target_id, safe_payload, dedupe_key
    ) values (
      v_event.organization_id,
      v_recipient,
      'digest',
      'Bạn còn thông báo mới',
      'Một số thông báo đã được gộp vào hộp thư để tránh gửi push quá nhiều.',
      'system',
      null,
      jsonb_build_object('kind', 'digest', 'delivery_mode', 'inbox_only'),
      'digest:' || (clock_timestamp() at time zone v_org_timezone)::date::text
    )
    on conflict (organization_id, recipient_member_id, dedupe_key)
    do update set dedupe_key = excluded.dedupe_key
    returning id into v_digest_id;

    insert into public.notification_deliveries (
      organization_id, notification_id, endpoint_id, channel, status, attempts, next_attempt_at
    ) values (
      v_event.organization_id, v_digest_id, null, 'in_app', 'provider_confirmed', 1, clock_timestamp()
    ) on conflict do nothing;
  end if;

  return jsonb_build_object(
    'materialized', true,
    'notification_id', v_notification.id,
    'push_suppressed_for_leave', v_suppress_push,
    'daily_push_limit', v_push_limit,
    'push_count_before', v_push_count
  );
end;
$$;

create or replace function public.rpc_list_notifications(
  p_organization_id uuid,
  p_limit integer default 100,
  p_before timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  return coalesce((
    select jsonb_agg(to_jsonb(n) - 'dedupe_key' order by n.created_at desc, n.id desc)
    from (
      select *
      from public.notifications
      where organization_id = p_organization_id
        and recipient_member_id = v_member_id
        and (expires_at is null or expires_at > clock_timestamp())
        and (p_before is null or created_at < p_before)
      order by created_at desc, id desc
      limit greatest(1, least(coalesce(p_limit, 100), 200))
    ) as n
  ), '[]'::jsonb);
end;
$$;

create or replace function public.rpc_mark_notification_read(p_notification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notification public.notifications%rowtype;
  v_member_id uuid;
begin
  select * into v_notification
  from public.notifications
  where id = p_notification_id
  for update;

  if v_notification.id is null then
    raise exception using errcode = 'P0002', message = 'NOTIFICATION_NOT_FOUND';
  end if;

  v_member_id := private.current_member_id(v_notification.organization_id);
  if v_member_id is null or v_member_id <> v_notification.recipient_member_id then
    raise exception using errcode = '42501', message = 'NOTIFICATION_ACCESS_DENIED';
  end if;

  update public.notifications
  set read_at = coalesce(read_at, clock_timestamp())
  where id = v_notification.id
  returning * into v_notification;

  return jsonb_build_object('notification_id', v_notification.id, 'read_at', v_notification.read_at);
end;
$$;

create or replace function public.rpc_mark_all_notifications_read(
  p_organization_id uuid,
  p_cutoff timestamptz
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_count integer;
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  update public.notifications
  set read_at = coalesce(read_at, clock_timestamp())
  where organization_id = p_organization_id
    and recipient_member_id = v_member_id
    and read_at is null
    and created_at <= least(coalesce(p_cutoff, clock_timestamp()), clock_timestamp());
  get diagnostics v_count = row_count;
  return jsonb_build_object('updated_count', v_count);
end;
$$;

create or replace function public.rpc_snooze_reminder(
  p_task_id uuid,
  p_rule_key text,
  p_until timestamptz,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.tasks%rowtype;
  v_member_id uuid;
  v_existing public.task_reminder_snoozes%rowtype;
  v_payload_hash text;
  v_previous private.command_idempotency%rowtype;
  v_result jsonb;
begin
  select * into v_task from public.tasks where id = p_task_id for update;
  if v_task.id is null then
    raise exception using errcode = 'P0002', message = 'TASK_NOT_FOUND';
  end if;
  v_member_id := private.current_member_id(v_task.organization_id);
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  if not (
    v_member_id = v_task.assignee_member_id
    or v_member_id = v_task.reviewer_member_id
    or v_member_id = v_task.blocker_owner_member_id
  ) then
    raise exception using errcode = '42501', message = 'REMINDER_SNOOZE_ACCESS_DENIED';
  end if;
  if p_rule_key not in ('unack', 'due_soon', 'overdue', 'blocked', 'reviewer') then
    raise exception using errcode = '22023', message = 'REMINDER_RULE_INVALID';
  end if;
  if p_until <= clock_timestamp() or p_until > clock_timestamp() + interval '24 hours' then
    raise exception using errcode = '22023', message = 'REMINDER_SNOOZE_RANGE_INVALID';
  end if;

  v_payload_hash := encode(extensions.digest(
    convert_to(jsonb_build_object(
      'task_id', p_task_id,
      'rule_key', p_rule_key,
      'until', p_until,
      'expected_version', p_expected_version
    )::text, 'utf8'),
    'sha256'
  ), 'hex');

  select * into v_previous
  from private.command_idempotency
  where organization_id = v_task.organization_id
    and actor_key = v_member_id::text
    and command_name = 'notification.snooze_reminder'
    and idempotency_key = p_idempotency_key;

  if v_previous.organization_id is not null then
    if v_previous.payload_hash <> v_payload_hash then
      raise exception using errcode = '22023', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return v_previous.result;
  end if;

  select * into v_existing
  from public.task_reminder_snoozes
  where organization_id = v_task.organization_id
    and task_id = v_task.id
    and member_id = v_member_id
    and rule_key = p_rule_key
  for update;

  if v_existing.task_id is null then
    if coalesce(p_expected_version, 0) <> 0 then
      raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
    end if;
    insert into public.task_reminder_snoozes (
      organization_id, task_id, member_id, rule_key, snoozed_until, set_at, version
    ) values (
      v_task.organization_id, v_task.id, v_member_id, p_rule_key, p_until, clock_timestamp(), 1
    );
    v_result := jsonb_build_object('task_id', v_task.id, 'rule_key', p_rule_key, 'snoozed_until', p_until, 'version', 1);
    insert into private.command_idempotency (
      organization_id, actor_key, command_name, idempotency_key, payload_hash, result
    ) values (
      v_task.organization_id, v_member_id::text, 'notification.snooze_reminder', p_idempotency_key, v_payload_hash, v_result
    );
    return v_result;
  end if;

  if p_expected_version <> v_existing.version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  update public.task_reminder_snoozes
  set snoozed_until = p_until,
      set_at = clock_timestamp(),
      version = version + 1
  where organization_id = v_task.organization_id
    and task_id = v_task.id
    and member_id = v_member_id
    and rule_key = p_rule_key
  returning * into v_existing;

  perform private.write_audit(
    v_task.organization_id,
    'task.reminder_snoozed',
    'task',
    v_task.id,
    jsonb_build_object('rule_key', p_rule_key, 'snoozed_until', p_until, 'idempotency_key', p_idempotency_key)
  );

  v_result := jsonb_build_object(
    'task_id', v_task.id,
    'rule_key', p_rule_key,
    'snoozed_until', v_existing.snoozed_until,
    'version', v_existing.version
  );
  insert into private.command_idempotency (
    organization_id, actor_key, command_name, idempotency_key, payload_hash, result
  ) values (
    v_task.organization_id, v_member_id::text, 'notification.snooze_reminder', p_idempotency_key, v_payload_hash, v_result
  );
  return v_result;
end;
$$;

create or replace function public.rpc_revoke_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device public.user_devices%rowtype;
  v_member_id uuid;
begin
  select * into v_device from public.user_devices where id = p_device_id for update;
  if v_device.id is null then
    raise exception using errcode = 'P0002', message = 'DEVICE_NOT_FOUND';
  end if;
  v_member_id := private.current_member_id(v_device.organization_id);
  if v_member_id is null or v_member_id <> v_device.member_id then
    raise exception using errcode = '42501', message = 'DEVICE_ACCESS_DENIED';
  end if;
  update public.user_devices
  set revoked_at = coalesce(revoked_at, clock_timestamp())
  where id = v_device.id;
  return jsonb_build_object('device_id', v_device.id, 'revoked', true);
end;
$$;

alter table public.push_endpoints enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.task_reminder_snoozes enable row level security;

create policy push_endpoints_read_owner
on public.push_endpoints for select to authenticated
using (
  exists (
    select 1 from public.user_devices as d
    where d.organization_id = push_endpoints.organization_id
      and d.id = push_endpoints.device_id
      and d.member_id = private.current_member_id(push_endpoints.organization_id)
  )
);

create policy notification_preferences_read_self
on public.notification_preferences for select to authenticated
using (member_id = private.current_member_id(organization_id));

create policy notifications_read_recipient
on public.notifications for select to authenticated
using (recipient_member_id = private.current_member_id(organization_id));

create policy notification_deliveries_read_recipient
on public.notification_deliveries for select to authenticated
using (
  exists (
    select 1 from public.notifications as n
    where n.organization_id = notification_deliveries.organization_id
      and n.id = notification_deliveries.notification_id
      and n.recipient_member_id = private.current_member_id(notification_deliveries.organization_id)
  )
);

create policy task_reminder_snoozes_read_self
on public.task_reminder_snoozes for select to authenticated
using (member_id = private.current_member_id(organization_id));

grant select on public.push_endpoints, public.notification_preferences, public.notifications,
  public.notification_deliveries, public.task_reminder_snoozes to authenticated;

revoke insert, update, delete, truncate, references, trigger
on public.push_endpoints, public.notification_preferences, public.notifications,
  public.notification_deliveries, public.task_reminder_snoozes
from authenticated;

revoke all on function private.notification_member_on_approved_leave(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_working_seconds_between(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_reminder_policy(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_unack_threshold_minutes(jsonb, text, integer) from public, anon, authenticated;
revoke all on function private.enqueue_task_reminders(timestamptz) from public, anon, authenticated;
revoke all on function private.notification_outbox_recipient(private.outbox_events) from public, anon, authenticated;
revoke all on function private.notification_kind_for_event(text) from public, anon, authenticated;
revoke all on function private.notification_copy_for_event(text, text, uuid) from public, anon, authenticated;
revoke all on function private.notification_daily_push_limit(uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.notification_push_count_today(uuid, uuid, timestamptz) from public, anon, authenticated;

grant execute on function private.enqueue_task_reminders(timestamptz) to service_role;
grant execute on function public.rpc_internal_enqueue_task_reminders(timestamptz) to service_role;
grant execute on function public.rpc_internal_claim_outbox(uuid, integer) to service_role;
grant execute on function public.rpc_internal_ack_outbox(uuid, uuid) to service_role;
grant execute on function public.rpc_internal_fail_outbox(uuid, uuid, text, boolean) to service_role;
grant execute on function public.rpc_internal_materialize_notification(uuid, uuid) to service_role;

grant execute on function public.rpc_list_notifications(uuid, integer, timestamptz) to authenticated;
grant execute on function public.rpc_mark_notification_read(uuid) to authenticated;
grant execute on function public.rpc_mark_all_notifications_read(uuid, timestamptz) to authenticated;
grant execute on function public.rpc_snooze_reminder(uuid, text, timestamptz, integer, text) to authenticated;
grant execute on function public.rpc_revoke_device(uuid) to authenticated;

revoke execute on function public.rpc_internal_claim_outbox(uuid, integer) from authenticated, anon;
revoke execute on function public.rpc_internal_enqueue_task_reminders(timestamptz) from authenticated, anon;
revoke execute on function public.rpc_internal_ack_outbox(uuid, uuid) from authenticated, anon;
revoke execute on function public.rpc_internal_fail_outbox(uuid, uuid, text, boolean) from authenticated, anon;
revoke execute on function public.rpc_internal_materialize_notification(uuid, uuid) from authenticated, anon;

-- ============================================================================
-- END 00000000000010_p08_notifications.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000011_p09_reports.sql
-- ============================================================================

-- P09 - 18:00 report snapshots, scoped recipients and idempotent server generation.
-- Facts are reconstructed from task event state at cutoff, never from current task state on retry.

create table public.report_runs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  report_date date not null,
  cutoff_at timestamptz not null,
  timezone text not null check (char_length(trim(timezone)) between 1 and 120),
  revision integer not null default 1 check (revision > 0),
  status text not null default 'generating' check (status in ('generating', 'ready', 'failed')),
  generated_at timestamptz,
  is_late boolean not null default false,
  source_hash text check (source_hash is null or char_length(source_hash) = 64),
  error_code text,
  revision_reason text,
  created_by_member_id uuid,
  supersedes_run_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, report_date, cutoff_at, revision),
  foreign key (organization_id, created_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, supersedes_run_id)
    references public.report_runs(organization_id, id)
    on delete restrict,
  check (revision_reason is null or char_length(trim(revision_reason)) between 3 and 500),
  check ((status = 'ready' and generated_at is not null and source_hash is not null) or status <> 'ready')
);

create table public.report_recipient_snapshots (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  run_id uuid not null,
  recipient_member_id uuid not null,
  scope jsonb not null check (jsonb_typeof(scope) = 'object'),
  facts jsonb not null check (jsonb_typeof(facts) = 'object'),
  summary_template text not null check (char_length(trim(summary_template)) between 1 and 2000),
  source_hash text not null check (char_length(source_hash) = 64),
  created_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  unique (organization_id, run_id, recipient_member_id),
  foreign key (organization_id, run_id)
    references public.report_runs(organization_id, id)
    on delete restrict,
  foreign key (organization_id, recipient_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create table public.report_run_events (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  run_id uuid not null,
  event_type text not null check (event_type in ('ready', 'failed', 'revision_created')),
  actor_member_id uuid,
  reason text,
  safe_metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(safe_metadata) = 'object'),
  recorded_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, id),
  foreign key (organization_id, run_id)
    references public.report_runs(organization_id, id)
    on delete restrict,
  foreign key (organization_id, actor_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict,
  check (reason is null or char_length(trim(reason)) between 3 and 500)
);

create index report_runs_org_date_idx
  on public.report_runs(organization_id, report_date desc, revision desc);
create index report_snapshots_recipient_idx
  on public.report_recipient_snapshots(organization_id, recipient_member_id, created_at desc);
create index report_run_events_run_idx
  on public.report_run_events(organization_id, run_id, recorded_at desc);

create trigger report_runs_set_updated_at
before update on public.report_runs
for each row execute function private.set_updated_at();

create trigger report_recipient_snapshots_immutable
before update or delete on public.report_recipient_snapshots
for each row execute function private.prevent_immutable_mutation();

create trigger report_run_events_immutable
before update or delete on public.report_run_events
for each row execute function private.prevent_immutable_mutation();

-- Future task events include a display-safe title in their report state. Historical events remain untouched;
-- missing historical fields are surfaced as a report warning instead of being invented from current state.
create or replace function private.task_report_state(p_task public.tasks)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'task_id', p_task.id,
    'task_number', p_task.task_number,
    'batch_id', p_task.batch_id,
    'seller_id', p_task.seller_id,
    'title', p_task.title,
    'status', p_task.status,
    'priority', p_task.priority,
    'assignee_member_id', p_task.assignee_member_id,
    'reviewer_member_id', p_task.reviewer_member_id,
    'planned_date', p_task.planned_date,
    'original_due_at', p_task.original_due_at,
    'due_at', p_task.due_at,
    'assigned_at', p_task.assigned_at,
    'acknowledged_at', p_task.acknowledged_at,
    'started_at', p_task.started_at,
    'submitted_at', p_task.submitted_at,
    'completed_at', p_task.completed_at,
    'requires_review', p_task.requires_review,
    'requires_result', p_task.requires_result,
    'requires_attachment', p_task.requires_attachment,
    'blocked_at', p_task.blocked_at,
    'blocker_reason', p_task.blocker_reason,
    'blocker_owner_member_id', p_task.blocker_owner_member_id,
    'current_submission_id', p_task.current_submission_id,
    'version', p_task.version
  );
$$;

create or replace function private.report_cutoff_at(
  p_organization_id uuid,
  p_report_date date
)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_timezone text;
  v_cutoff_text text := '18:00';
  v_cutoff_time time;
begin
  select o.timezone into v_timezone
  from public.organizations as o
  where o.id = p_organization_id;
  if v_timezone is null then
    raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND';
  end if;

  select coalesce(nullif(trim(p.config ->> 'cutoff_local'), ''), '18:00')
  into v_cutoff_text
  from public.policy_versions as p
  where p.organization_id = p_organization_id
    and p.policy_kind = 'report'
    and p.effective_from <= ((p_report_date + time '23:59:59') at time zone v_timezone)
  order by p.effective_from desc, p.version_number desc
  limit 1;
  v_cutoff_text := coalesce(v_cutoff_text, '18:00');

  begin
    v_cutoff_time := v_cutoff_text::time;
  exception when invalid_datetime_format or datetime_field_overflow then
    raise exception using errcode = '22023', message = 'REPORT_CUTOFF_INVALID';
  end;

  return (p_report_date + v_cutoff_time) at time zone v_timezone;
end;
$$;

create or replace function private.report_task_states_at_cutoff(
  p_organization_id uuid,
  p_cutoff_at timestamptz
)
returns table (
  task_id uuid,
  task_version integer,
  occurred_at timestamptz,
  state jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct on (e.task_id)
    e.task_id,
    e.task_version,
    e.occurred_at,
    e.report_state_after
  from public.task_events as e
  where e.organization_id = p_organization_id
    and e.occurred_at <= p_cutoff_at
  order by e.task_id, e.occurred_at desc, e.task_version desc;
$$;

create or replace function private.report_scope_for_recipient(
  p_organization_id uuid,
  p_member_id uuid,
  p_report_date date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_seller_ids jsonb;
begin
  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = p_member_id
    and m.status = 'active';
  if v_role is null then
    return null;
  end if;

  if v_role = 'admin' then
    return jsonb_build_object('kind', 'organization');
  end if;

  if v_role = 'manager' then
    select coalesce(jsonb_agg(sm.seller_id order by sm.seller_id), '[]'::jsonb)
    into v_seller_ids
    from public.seller_members as sm
    where sm.organization_id = p_organization_id
      and sm.member_id = p_member_id
      and sm.is_manager
      and sm.active_from <= p_report_date
      and (sm.active_until is null or sm.active_until >= p_report_date);
    if jsonb_array_length(v_seller_ids) > 0 then
      return jsonb_build_object('kind', 'sellers', 'seller_ids', v_seller_ids);
    end if;
  end if;

  return jsonb_build_object('kind', 'personal', 'member_id', p_member_id);
end;
$$;

create or replace function private.report_scope_still_allowed(
  p_organization_id uuid,
  p_member_id uuid,
  p_scope jsonb
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text;
  v_kind text := p_scope ->> 'kind';
  v_local_date date;
begin
  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = p_member_id
    and m.status = 'active';
  if v_role is null then return false; end if;
  if v_role = 'admin' then return true; end if;
  if v_kind = 'personal' then return p_scope ->> 'member_id' = p_member_id::text; end if;
  if v_kind <> 'sellers' or v_role <> 'manager' then return false; end if;

  select (clock_timestamp() at time zone o.timezone)::date
  into v_local_date
  from public.organizations as o
  where o.id = p_organization_id;

  return not exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_scope -> 'seller_ids', '[]'::jsonb)) as wanted(seller_id)
    where not exists (
      select 1
      from public.seller_members as sm
      where sm.organization_id = p_organization_id
        and sm.member_id = p_member_id
        and sm.seller_id = wanted.seller_id::uuid
        and sm.is_manager
        and sm.active_from <= v_local_date
        and (sm.active_until is null or sm.active_until >= v_local_date)
    )
  );
end;
$$;

create or replace function private.report_build_facts(
  p_organization_id uuid,
  p_report_date date,
  p_cutoff_at timestamptz,
  p_timezone text,
  p_scope jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_people jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_member record;
  v_due integer;
  v_done integer;
  v_review integer;
  v_open integer;
  v_blocked integer;
  v_due_ids jsonb;
  v_overdue_ids jsonb;
  v_after_ids jsonb;
  v_canceled_ids jsonb;
  v_availability text;
  v_total_due integer := 0;
  v_total_done integer := 0;
  v_total_review integer := 0;
  v_total_open integer := 0;
  v_total_blocked integer := 0;
begin
  if p_scope ->> 'kind' not in ('organization', 'sellers', 'personal') then
    raise exception using errcode = '22023', message = 'REPORT_SCOPE_INVALID';
  end if;

  if exists (
    select 1
    from private.report_task_states_at_cutoff(p_organization_id, p_cutoff_at) as s
    where s.state = '{}'::jsonb
  ) then
    v_warnings := v_warnings || jsonb_build_array('TASK_HISTORY_INCOMPLETE');
  end if;

  for v_member in
    select m.id, m.display_name
    from public.organization_members as m
    where m.organization_id = p_organization_id
      and m.status = 'active'
      and (
        p_scope ->> 'kind' = 'organization'
        or (p_scope ->> 'kind' = 'personal' and p_scope ->> 'member_id' = m.id::text)
        or (
          p_scope ->> 'kind' = 'sellers'
          and (
            exists (
              select 1
              from public.seller_members as sm
              where sm.organization_id = p_organization_id
                and sm.member_id = m.id
                and (p_scope -> 'seller_ids') ? sm.seller_id::text
                and sm.active_from <= p_report_date
                and (sm.active_until is null or sm.active_until >= p_report_date)
            )
            or exists (
              select 1
              from private.report_task_states_at_cutoff(p_organization_id, p_cutoff_at) as sx
              where sx.state ->> 'assignee_member_id' = m.id::text
                and (p_scope -> 'seller_ids') ? coalesce(sx.state ->> 'seller_id', '')
            )
          )
        )
      )
    order by m.display_name, m.id
  loop
    select
      count(*) filter (
        where st not in ('canceled', 'waived')
          and due_local = p_report_date and due_at <= p_cutoff_at
          and st in ('done', 'in_review', 'todo', 'in_progress')
      )::integer,
      count(*) filter (where due_local = p_report_date and due_at <= p_cutoff_at and st = 'done')::integer,
      count(*) filter (where due_local = p_report_date and due_at <= p_cutoff_at and st = 'in_review')::integer,
      count(*) filter (where due_local = p_report_date and due_at <= p_cutoff_at and st in ('todo', 'in_progress'))::integer,
      count(*) filter (
        where due_local = p_report_date and due_at <= p_cutoff_at and st in ('todo', 'in_progress')
          and nullif(state ->> 'blocked_at', '') is not null
      )::integer,
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where st not in ('canceled', 'waived')
          and due_local = p_report_date and due_at <= p_cutoff_at
          and st in ('done', 'in_review', 'todo', 'in_progress')
      ), '[]'::jsonb),
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where due_local < p_report_date and st in ('todo', 'in_progress', 'in_review')
      ), '[]'::jsonb),
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where due_local = p_report_date and due_at > p_cutoff_at and st not in ('canceled', 'waived')
      ), '[]'::jsonb),
      coalesce(jsonb_agg(task_id order by task_id) filter (
        where due_local = p_report_date and st in ('canceled', 'waived')
      ), '[]'::jsonb)
    into v_due, v_done, v_review, v_open, v_blocked, v_due_ids, v_overdue_ids, v_after_ids, v_canceled_ids
    from (
      select
        s.task_id,
        s.state,
        s.state ->> 'status' as st,
        (s.state ->> 'due_at')::timestamptz as due_at,
        ((s.state ->> 'due_at')::timestamptz at time zone p_timezone)::date as due_local
      from private.report_task_states_at_cutoff(p_organization_id, p_cutoff_at) as s
      where s.state ->> 'assignee_member_id' = v_member.id::text
        and nullif(s.state ->> 'due_at', '') is not null
        and (
          p_scope ->> 'kind' <> 'sellers'
          or (p_scope -> 'seller_ids') ? coalesce(s.state ->> 'seller_id', '')
        )
    ) as scoped;

    v_availability := case when exists (
      select 1
      from public.attendance_sessions as a
      where a.organization_id = p_organization_id
        and a.member_id = v_member.id
        and a.starts_at <= p_cutoff_at
        and (a.ends_at is null or a.ends_at > p_cutoff_at)
        and a.status in ('open', 'closed')
    ) then 'working' else 'unknown' end;

    v_people := v_people || jsonb_build_array(jsonb_build_object(
      'member_id', v_member.id,
      'display_name', v_member.display_name,
      'counts', jsonb_build_object(
        'due_count', coalesce(v_due, 0),
        'done_count', coalesce(v_done, 0),
        'review_count', coalesce(v_review, 0),
        'open_count', coalesce(v_open, 0),
        'blocked_count', coalesce(v_blocked, 0)
      ),
      'due_task_ids', coalesce(v_due_ids, '[]'::jsonb),
      'overdue_previous_day_task_ids', coalesce(v_overdue_ids, '[]'::jsonb),
      'due_after_cutoff_task_ids', coalesce(v_after_ids, '[]'::jsonb),
      'canceled_or_waived_task_ids', coalesce(v_canceled_ids, '[]'::jsonb),
      'availability', v_availability
    ));

    v_total_due := v_total_due + coalesce(v_due, 0);
    v_total_done := v_total_done + coalesce(v_done, 0);
    v_total_review := v_total_review + coalesce(v_review, 0);
    v_total_open := v_total_open + coalesce(v_open, 0);
    v_total_blocked := v_total_blocked + coalesce(v_blocked, 0);
  end loop;

  return jsonb_build_object(
    'schema_version', 1,
    'report_date', p_report_date,
    'cutoff_at', p_cutoff_at,
    'timezone', p_timezone,
    'scope', p_scope,
    'totals', jsonb_build_object(
      'due_count', v_total_due,
      'done_count', v_total_done,
      'review_count', v_total_review,
      'open_count', v_total_open,
      'blocked_count', v_total_blocked
    ),
    'people', v_people,
    'sellers', '[]'::jsonb,
    'manager_actions', '[]'::jsonb,
    'warnings', v_warnings
  );
end;
$$;

create or replace function private.generate_report_run(
  p_organization_id uuid,
  p_report_date date,
  p_revision integer,
  p_revision_reason text default null,
  p_created_by_member_id uuid default null,
  p_now timestamptz default clock_timestamp()
)
returns public.report_runs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.organizations%rowtype;
  v_cutoff timestamptz;
  v_run public.report_runs%rowtype;
  v_recipient record;
  v_scope jsonb;
  v_facts jsonb;
  v_snapshot public.report_recipient_snapshots%rowtype;
  v_snapshot_hash text;
  v_run_hash text;
  v_summary text;
begin
  if p_revision < 1 then
    raise exception using errcode = '22023', message = 'REPORT_REVISION_INVALID';
  end if;
  if p_revision > 1 and (p_revision_reason is null or char_length(trim(p_revision_reason)) < 3) then
    raise exception using errcode = '22023', message = 'REPORT_REVISION_REASON_REQUIRED';
  end if;

  select * into v_org
  from public.organizations as o
  where o.id = p_organization_id and o.status = 'active';
  if v_org.id is null then
    raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND';
  end if;
  v_cutoff := private.report_cutoff_at(p_organization_id, p_report_date);
  if p_now < v_cutoff then
    raise exception using errcode = '55000', message = 'REPORT_NOT_DUE';
  end if;

  select * into v_run
  from public.report_runs as r
  where r.organization_id = p_organization_id
    and r.report_date = p_report_date
    and r.cutoff_at = v_cutoff
    and r.revision = p_revision
  for update;

  if v_run.id is not null and v_run.status = 'ready' then
    return v_run;
  end if;

  if v_run.id is null then
    insert into public.report_runs (
      organization_id, report_date, cutoff_at, timezone, revision, status, is_late,
      revision_reason, created_by_member_id
    ) values (
      p_organization_id, p_report_date, v_cutoff, v_org.timezone, p_revision, 'generating',
      p_now > v_cutoff + interval '2 minutes', nullif(trim(p_revision_reason), ''), p_created_by_member_id
    ) returning * into v_run;
  else
    update public.report_runs
    set status = 'generating', error_code = null,
        revision_reason = coalesce(revision_reason, nullif(trim(p_revision_reason), '')),
        created_by_member_id = coalesce(created_by_member_id, p_created_by_member_id)
    where id = v_run.id
    returning * into v_run;
  end if;

  for v_recipient in
    select m.id
    from public.organization_members as m
    where m.organization_id = p_organization_id and m.status = 'active'
    order by m.id
  loop
    v_scope := private.report_scope_for_recipient(p_organization_id, v_recipient.id, p_report_date);
    if v_scope is null then continue; end if;
    v_facts := private.report_build_facts(
      p_organization_id, p_report_date, v_cutoff, v_org.timezone, v_scope
    );
    v_snapshot_hash := pg_catalog.encode(
      extensions.digest(convert_to(v_scope::text || v_facts::text, 'UTF8'), 'sha256'),
      'hex'
    );
    v_summary := format(
      'Chốt %s: %s việc đến hạn, %s hoàn thành, %s chờ duyệt, %s còn mở, %s có vướng mắc.',
      to_char(p_report_date, 'DD/MM/YYYY'),
      v_facts #>> '{totals,due_count}',
      v_facts #>> '{totals,done_count}',
      v_facts #>> '{totals,review_count}',
      v_facts #>> '{totals,open_count}',
      v_facts #>> '{totals,blocked_count}'
    );

    insert into public.report_recipient_snapshots (
      organization_id, run_id, recipient_member_id, scope, facts, summary_template, source_hash
    ) values (
      p_organization_id, v_run.id, v_recipient.id, v_scope, v_facts, v_summary, v_snapshot_hash
    ) returning * into v_snapshot;

    insert into private.outbox_events (
      organization_id, event_type, entity_type, entity_id, dedupe_key, payload, status, available_at
    ) values (
      p_organization_id,
      'report.ready',
      'report_run',
      v_run.id,
      'report:' || v_run.id::text || ':' || v_snapshot.id::text || ':' || v_recipient.id::text,
      jsonb_build_object(
        'recipient_member_id', v_recipient.id,
        'run_id', v_run.id,
        'snapshot_id', v_snapshot.id,
        'report_date', p_report_date,
        'revision', p_revision
      ),
      'pending',
      p_now
    ) on conflict (organization_id, dedupe_key) do nothing;
  end loop;

  select pg_catalog.encode(
    extensions.digest(
      convert_to(coalesce(string_agg(s.source_hash, ',' order by s.recipient_member_id), ''), 'UTF8'),
      'sha256'
    ),
    'hex'
  ) into v_run_hash
  from public.report_recipient_snapshots as s
  where s.organization_id = p_organization_id and s.run_id = v_run.id;

  update public.report_runs
  set status = 'ready', generated_at = p_now, source_hash = v_run_hash, error_code = null
  where id = v_run.id
  returning * into v_run;

  insert into public.report_run_events (
    organization_id, run_id, event_type, actor_member_id, reason, safe_metadata, recorded_at
  ) values (
    p_organization_id,
    v_run.id,
    case when p_revision > 1 then 'revision_created' else 'ready' end,
    p_created_by_member_id,
    nullif(trim(p_revision_reason), ''),
    jsonb_build_object('revision', p_revision, 'cutoff_at', v_cutoff, 'is_late', v_run.is_late),
    p_now
  );

  return v_run;
end;
$$;

create or replace function public.rpc_internal_generate_due_reports(
  p_now timestamptz default clock_timestamp(),
  p_limit integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org record;
  v_date date;
  v_cutoff timestamptz;
  v_generated integer := 0;
  v_failed integer := 0;
  v_run_id uuid;
begin
  for v_org in
    select o.id, o.timezone
    from public.organizations as o
    where o.status = 'active'
    order by o.id
    limit greatest(1, least(coalesce(p_limit, 10), 50))
  loop
    v_date := (p_now at time zone v_org.timezone)::date;
    v_cutoff := private.report_cutoff_at(v_org.id, v_date);
    if p_now < v_cutoff then continue; end if;
    if exists (
      select 1 from public.report_runs as r
      where r.organization_id = v_org.id
        and r.report_date = v_date
        and r.cutoff_at = v_cutoff
        and r.revision = 1
        and r.status = 'ready'
    ) then continue; end if;

    begin
      perform private.generate_report_run(v_org.id, v_date, 1, null, null, p_now);
      v_generated := v_generated + 1;
    exception when others then
      insert into public.report_runs (
        organization_id, report_date, cutoff_at, timezone, revision, status, is_late, error_code
      ) values (
        v_org.id, v_date, v_cutoff, v_org.timezone, 1, 'failed',
        p_now > v_cutoff + interval '2 minutes', left(sqlerrm, 120)
      )
      on conflict (organization_id, report_date, cutoff_at, revision)
      do update set status = 'failed', error_code = excluded.error_code
      returning id into v_run_id;

      insert into public.report_run_events (
        organization_id, run_id, event_type, actor_member_id, reason, safe_metadata, recorded_at
      ) values (
        v_org.id, v_run_id, 'failed', null, 'Report generation failed',
        jsonb_build_object('error_code', left(sqlerrm, 120)), p_now
      );
      v_failed := v_failed + 1;
    end;
  end loop;

  return jsonb_build_object('generated', v_generated, 'failed', v_failed, 'evaluated_at', p_now);
end;
$$;

create or replace function public.rpc_list_reports(
  p_organization_id uuid,
  p_limit integer default 31
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_result jsonb;
begin
  if v_member_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  select coalesce(jsonb_agg(row_value order by report_date desc, revision desc), '[]'::jsonb)
  into v_result
  from (
    select
      r.report_date,
      r.revision,
      jsonb_build_object(
        'run_id', r.id,
        'snapshot_id', s.id,
        'report_date', r.report_date,
        'cutoff_at', r.cutoff_at,
        'generated_at', r.generated_at,
        'timezone', r.timezone,
        'revision', r.revision,
        'is_late', r.is_late,
        'scope', s.scope,
        'totals', s.facts -> 'totals',
        'people_count', jsonb_array_length(coalesce(s.facts -> 'people', '[]'::jsonb)),
        'warnings', coalesce(s.facts -> 'warnings', '[]'::jsonb)
      ) as row_value
    from public.report_runs as r
    join public.report_recipient_snapshots as s
      on s.organization_id = r.organization_id and s.run_id = r.id
    where r.organization_id = p_organization_id
      and r.status = 'ready'
      and s.recipient_member_id = v_member_id
      and private.report_scope_still_allowed(p_organization_id, v_member_id, s.scope)
    order by r.report_date desc, r.revision desc
    limit greatest(1, least(coalesce(p_limit, 31), 100))
  ) as visible;
  return v_result;
end;
$$;

create or replace function public.rpc_get_report(p_run_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_run public.report_runs%rowtype;
  v_member_id uuid;
  v_snapshot public.report_recipient_snapshots%rowtype;
begin
  select * into v_run from public.report_runs as r where r.id = p_run_id and r.status = 'ready';
  if v_run.id is null then raise exception using errcode = 'P0002', message = 'REPORT_NOT_FOUND'; end if;
  v_member_id := private.current_member_id(v_run.organization_id);
  if v_member_id is null then raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;

  select * into v_snapshot
  from public.report_recipient_snapshots as s
  where s.organization_id = v_run.organization_id
    and s.run_id = v_run.id
    and s.recipient_member_id = v_member_id;
  if v_snapshot.id is null then raise exception using errcode = '42501', message = 'REPORT_ACCESS_DENIED'; end if;
  if not private.report_scope_still_allowed(v_run.organization_id, v_member_id, v_snapshot.scope) then
    raise exception using errcode = '42501', message = 'REPORT_SCOPE_CHANGED';
  end if;

  return jsonb_build_object(
    'run_id', v_run.id,
    'snapshot_id', v_snapshot.id,
    'report_date', v_run.report_date,
    'cutoff_at', v_run.cutoff_at,
    'generated_at', v_run.generated_at,
    'timezone', v_run.timezone,
    'revision', v_run.revision,
    'is_late', v_run.is_late,
    'revision_reason', v_run.revision_reason,
    'scope', v_snapshot.scope,
    'facts', v_snapshot.facts,
    'summary_template', v_snapshot.summary_template,
    'source_hash', v_snapshot.source_hash
  );
end;
$$;

create or replace function public.rpc_create_report_revision(
  p_organization_id uuid,
  p_run_id uuid,
  p_reason text,
  p_expected_version integer,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor public.organization_members%rowtype;
  v_base public.report_runs%rowtype;
  v_current_revision integer;
  v_payload jsonb;
  v_replay jsonb;
  v_new public.report_runs%rowtype;
  v_result jsonb;
begin
  select * into v_actor
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.user_id = auth.uid()
    and m.status = 'active';
  if v_actor.id is null or v_actor.role <> 'admin' then
    raise exception using errcode = '42501', message = 'ADMIN_REQUIRED';
  end if;
  if p_reason is null or char_length(trim(p_reason)) < 3 then
    raise exception using errcode = '22023', message = 'REPORT_REVISION_REASON_REQUIRED';
  end if;

  v_payload := jsonb_build_object(
    'run_id', p_run_id,
    'reason', trim(p_reason),
    'expected_version', p_expected_version
  );
  v_replay := private.task_idempotency_replay(
    p_organization_id, v_actor.id, 'report.create_revision', p_idempotency_key, v_payload
  );
  if v_replay is not null then return v_replay; end if;

  select * into v_base
  from public.report_runs as r
  where r.organization_id = p_organization_id and r.id = p_run_id and r.status = 'ready';
  if v_base.id is null then raise exception using errcode = 'P0002', message = 'REPORT_NOT_FOUND'; end if;

  select max(r.revision) into v_current_revision
  from public.report_runs as r
  where r.organization_id = p_organization_id
    and r.report_date = v_base.report_date
    and r.cutoff_at = v_base.cutoff_at;
  if v_current_revision <> p_expected_version then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;

  v_new := private.generate_report_run(
    p_organization_id,
    v_base.report_date,
    v_current_revision + 1,
    trim(p_reason),
    v_actor.id,
    clock_timestamp()
  );
  update public.report_runs set supersedes_run_id = v_base.id where id = v_new.id;
  select * into v_new from public.report_runs where id = v_new.id;

  perform private.write_audit(
    p_organization_id,
    'report.revision_created',
    'report_run',
    v_new.id,
    jsonb_build_object(
      'previous_run_id', v_base.id,
      'revision', v_new.revision,
      'reason', trim(p_reason)
    )
  );

  v_result := jsonb_build_object(
    'run_id', v_new.id,
    'revision', v_new.revision,
    'report_date', v_new.report_date,
    'status', v_new.status
  );
  perform private.task_idempotency_store(
    p_organization_id, v_actor.id, 'report.create_revision', p_idempotency_key, v_payload, v_result
  );
  return v_result;
end;
$$;

alter table public.report_runs enable row level security;
alter table public.report_recipient_snapshots enable row level security;
alter table public.report_run_events enable row level security;

create policy report_runs_read_active_member
on public.report_runs for select to authenticated
using (private.current_member_id(organization_id) is not null);

create policy report_snapshots_read_recipient_current_scope
on public.report_recipient_snapshots for select to authenticated
using (
  recipient_member_id = private.current_member_id(organization_id)
  and private.report_scope_still_allowed(organization_id, recipient_member_id, scope)
);

create policy report_run_events_read_admin
on public.report_run_events for select to authenticated
using (
  exists (
    select 1 from public.organization_members as m
    where m.organization_id = report_run_events.organization_id
      and m.id = private.current_member_id(report_run_events.organization_id)
      and m.status = 'active'
      and m.role = 'admin'
  )
);

grant select on public.report_runs, public.report_recipient_snapshots, public.report_run_events to authenticated;
revoke insert, update, delete, truncate, references, trigger
on public.report_runs, public.report_recipient_snapshots, public.report_run_events
from authenticated;

revoke all on function private.report_cutoff_at(uuid, date) from public, anon, authenticated;
revoke all on function private.report_task_states_at_cutoff(uuid, timestamptz) from public, anon, authenticated;
revoke all on function private.report_scope_for_recipient(uuid, uuid, date) from public, anon, authenticated;
revoke all on function private.report_scope_still_allowed(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function private.report_build_facts(uuid, date, timestamptz, text, jsonb) from public, anon, authenticated;
revoke all on function private.generate_report_run(uuid, date, integer, text, uuid, timestamptz) from public, anon, authenticated;

revoke all on function public.rpc_internal_generate_due_reports(timestamptz, integer) from public, anon, authenticated;
grant execute on function public.rpc_internal_generate_due_reports(timestamptz, integer) to service_role;

revoke all on function public.rpc_list_reports(uuid, integer) from public, anon;
revoke all on function public.rpc_get_report(uuid) from public, anon;
revoke all on function public.rpc_create_report_revision(uuid, uuid, text, integer, text) from public, anon;
grant execute on function public.rpc_list_reports(uuid, integer) to authenticated;
grant execute on function public.rpc_get_report(uuid) to authenticated;
grant execute on function public.rpc_create_report_revision(uuid, uuid, text, integer, text) to authenticated;

-- ============================================================================
-- END 00000000000011_p09_reports.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000012_p10_security_ops.sql
-- ============================================================================

-- P10 - file security, privacy, retention, export, audit and backup-readiness boundaries.
-- Storage bytes remain private; clients receive only short-lived signed URLs after server-side ACL checks.

alter table public.files
  add column if not exists legal_hold boolean not null default false,
  add column if not exists verified_at timestamptz,
  add column if not exists verification_code text;

alter table public.files drop constraint if exists files_size_bytes_check;
alter table public.files
  add constraint files_size_bytes_check check (
    size_bytes > 0
    and (
      (purpose = 'attendance' and size_bytes <= 5242880)
      or (purpose = 'request' and size_bytes <= 10485760)
      or (purpose = 'task' and size_bytes <= 20971520)
      or (purpose = 'export' and size_bytes <= 52428800)
    )
  );

alter table public.files drop constraint if exists files_bucket_matches_purpose;
alter table public.files
  add constraint files_bucket_matches_purpose check (
    (purpose = 'attendance' and bucket_id = 'attendance-evidence')
    or (purpose = 'request' and bucket_id = 'request-evidence')
    or (purpose = 'task' and bucket_id = 'task-files')
    or (purpose = 'export' and bucket_id = 'exports')
  );

alter table public.files drop constraint if exists files_object_path_server_generated;
alter table public.files
  add constraint files_object_path_server_generated check (
    object_path ~ ('^' || organization_id::text || '/(task|attendance|request|export)/[0-9a-f-]{36}/[0-9a-f-]{36}\.[a-z0-9]{1,8}$')
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'attendance-evidence', 'attendance-evidence', false, 5242880,
    array['image/jpeg', 'image/webp']::text[]
  ),
  (
    'request-evidence', 'request-evidence', false, 10485760,
    array['image/jpeg', 'image/webp', 'application/pdf']::text[]
  ),
  (
    'task-files', 'task-files', false, 20971520,
    array[
      'image/jpeg', 'image/webp', 'image/png', 'application/pdf',
      'text/plain', 'text/csv',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    ]::text[]
  ),
  (
    'exports', 'exports', false, 52428800,
    array['text/csv']::text[]
  )
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- No authenticated bucket policy is created for business objects. The Storage service keeps
-- its own admin access while application users cannot query/mutate storage.objects directly.
revoke all on storage.objects from anon, authenticated;

create table public.export_jobs (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  requested_by uuid not null,
  export_kind text not null check (export_kind in ('timesheet', 'report', 'tasks', 'audit')),
  format text not null default 'csv' check (format = 'csv'),
  scope_snapshot jsonb not null check (jsonb_typeof(scope_snapshot) = 'object'),
  parameters jsonb not null default '{}'::jsonb check (jsonb_typeof(parameters) = 'object'),
  source_period_id uuid,
  source_revision integer,
  status text not null default 'queued' check (status in ('queued', 'processing', 'ready', 'failed', 'expired')),
  file_id uuid,
  idempotency_key text not null check (char_length(trim(idempotency_key)) between 8 and 240),
  requested_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  expires_at timestamptz,
  error_code text,
  worker_id uuid,
  processing_started_at timestamptz,
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  unique (organization_id, id),
  unique (organization_id, requested_by, idempotency_key),
  foreign key (organization_id, requested_by)
    references public.organization_members(organization_id, id)
    on delete restrict,
  foreign key (organization_id, file_id)
    references public.files(organization_id, id)
    on delete restrict,
  check (source_revision is null or source_revision > 0),
  check ((status = 'ready' and file_id is not null and completed_at is not null and expires_at is not null) or status <> 'ready')
);

create index export_jobs_requester_idx
  on public.export_jobs(organization_id, requested_by, requested_at desc);
create index export_jobs_worker_idx
  on public.export_jobs(status, requested_at)
  where status in ('queued', 'processing');
create index files_retention_idx
  on public.files(retention_until, created_at)
  where state <> 'deleted' and legal_hold = false;

create trigger export_jobs_set_updated_at
before update on public.export_jobs
for each row execute function private.set_updated_at();

create or replace function private.current_export_scope(p_organization_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid := private.current_member_id(p_organization_id);
  v_role text;
  v_sellers jsonb;
begin
  select m.role into v_role
  from public.organization_members as m
  where m.organization_id = p_organization_id
    and m.id = v_member_id
    and m.status = 'active';

  if v_role is null then return null; end if;
  if v_role = 'admin' then return jsonb_build_object('kind', 'organization'); end if;

  if v_role = 'manager' then
    select coalesce(jsonb_agg(sm.seller_id order by sm.seller_id), '[]'::jsonb)
    into v_sellers
    from public.seller_members as sm
    where sm.organization_id = p_organization_id
      and sm.member_id = v_member_id
      and sm.is_manager
      and sm.active_from <= private.organization_local_date(p_organization_id)
      and (sm.active_until is null or sm.active_until >= private.organization_local_date(p_organization_id));
    if jsonb_array_length(v_sellers) > 0 then
      return jsonb_build_object('kind', 'sellers', 'seller_ids', v_sellers);
    end if;
  end if;

  return jsonb_build_object('kind', 'personal', 'member_id', v_member_id);
end;
$$;

create or replace function private.export_scope_still_allowed(
  p_organization_id uuid,
  p_requested_by uuid,
  p_scope jsonb
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_current jsonb;
begin
  if private.current_member_id(p_organization_id) <> p_requested_by then return false; end if;
  v_current := private.current_export_scope(p_organization_id);
  if v_current is null then return false; end if;
  if v_current ->> 'kind' = 'organization' then return true; end if;
  if p_scope ->> 'kind' = 'organization' then return false; end if;
  if p_scope ->> 'kind' = 'personal' then
    return v_current ->> 'kind' = 'personal'
      and p_scope ->> 'member_id' = p_requested_by::text
      and v_current ->> 'member_id' = p_requested_by::text;
  end if;
  if p_scope ->> 'kind' <> 'sellers' or v_current ->> 'kind' <> 'sellers' then return false; end if;
  return not exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_scope -> 'seller_ids', '[]'::jsonb)) as wanted(seller_id)
    where not (coalesce(v_current -> 'seller_ids', '[]'::jsonb) ? wanted.seller_id)
  );
end;
$$;

create or replace function private.file_access_allowed(
  p_organization_id uuid,
  p_file_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_file public.files%rowtype;
  v_actor uuid := private.current_member_id(p_organization_id);
begin
  if v_actor is null then return false; end if;
  select * into v_file
  from public.files
  where organization_id = p_organization_id and id = p_file_id;
  if not found or v_file.state <> 'ready' or v_file.deleted_at is not null then return false; end if;

  if v_file.purpose = 'attendance' then
    return exists (
      select 1
      from public.attendance_evidence ae
      join public.attendance_events e
        on e.organization_id = ae.organization_id and e.id = ae.attendance_event_id
      where ae.organization_id = v_file.organization_id
        and ae.file_id = v_file.id
        and (e.member_id = v_actor or private.has_capability(v_file.organization_id, 'can_view_attendance_evidence'))
    );
  end if;

  if v_file.purpose = 'request' then
    return exists (
      select 1
      from public.upload_intents ui
      where ui.organization_id = v_file.organization_id
        and ui.file_id = v_file.id
        and ui.target_kind = 'request'
        and ui.target_id is not null
        and private.current_actor_can_read_employee_request(v_file.organization_id, ui.target_id)
    );
  end if;

  if v_file.purpose = 'task' then
    return exists (
      select 1
      from public.upload_intents ui
      where ui.organization_id = v_file.organization_id
        and ui.file_id = v_file.id
        and ui.target_kind = 'task'
        and ui.target_id is not null
        and private.current_actor_can_read_task(v_file.organization_id, ui.target_id)
    );
  end if;

  if v_file.purpose = 'export' then
    return exists (
      select 1
      from public.export_jobs ej
      where ej.organization_id = v_file.organization_id
        and ej.file_id = v_file.id
        and ej.requested_by = v_actor
        and ej.status = 'ready'
        and ej.expires_at > timezone('utc', now())
        and private.export_scope_still_allowed(ej.organization_id, ej.requested_by, ej.scope_snapshot)
    );
  end if;

  return false;
end;
$$;

create or replace function public.rpc_authorize_file_download(p_file_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_file public.files%rowtype;
  v_actor uuid;
begin
  select * into v_file from public.files where id = p_file_id;
  if not found then raise exception using errcode = 'P0002', message = 'FILE_NOT_FOUND'; end if;
  v_actor := private.current_member_id(v_file.organization_id);
  if v_actor is null or not private.file_access_allowed(v_file.organization_id, v_file.id) then
    raise exception using errcode = 'P0002', message = 'FILE_NOT_FOUND';
  end if;

  if v_file.purpose in ('attendance', 'request') then
    perform private.write_audit(
      v_file.organization_id,
      'evidence.view_authorized',
      'file',
      v_file.id,
      jsonb_build_object('purpose', v_file.purpose, 'bucket_id', v_file.bucket_id)
    );
  end if;

  return jsonb_build_object(
    'file_id', v_file.id,
    'bucket_id', v_file.bucket_id,
    'object_path', v_file.object_path,
    'original_name', v_file.original_name,
    'mime_type', v_file.mime_type,
    'size_bytes', v_file.size_bytes,
    'purpose', v_file.purpose
  );
end;
$$;

create or replace function public.rpc_create_export_job(
  p_organization_id uuid,
  p_export_kind text,
  p_parameters jsonb,
  p_idempotency_key text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.current_member_id(p_organization_id);
  v_scope jsonb;
  v_job public.export_jobs%rowtype;
  v_retention_days integer;
begin
  if v_actor is null then raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED'; end if;
  if p_export_kind not in ('timesheet', 'report', 'tasks', 'audit') then
    raise exception using errcode = '22023', message = 'EXPORT_KIND_INVALID';
  end if;
  if p_export_kind = 'audit' and not private.is_admin(p_organization_id) then
    raise exception using errcode = '42501', message = 'EXPORT_SCOPE_DENIED';
  end if;
  v_scope := private.current_export_scope(p_organization_id);

  select (p.config ->> 'export_retention_days')::integer
  into v_retention_days
  from public.policy_versions p
  where p.organization_id = p_organization_id
    and p.policy_kind = 'retention'
    and p.effective_from <= timezone('utc', now())
  order by p.effective_from desc, p.version_number desc
  limit 1;
  if v_retention_days is null or v_retention_days < 1 or v_retention_days > 365 then
    raise exception using errcode = '22023', message = 'RETENTION_POLICY_REQUIRED';
  end if;

  insert into public.export_jobs (
    organization_id, requested_by, export_kind, scope_snapshot, parameters,
    idempotency_key, expires_at
  ) values (
    p_organization_id, v_actor, p_export_kind, v_scope, coalesce(p_parameters, '{}'::jsonb),
    p_idempotency_key, timezone('utc', now()) + make_interval(days => v_retention_days)
  )
  on conflict (organization_id, requested_by, idempotency_key) do update
    set idempotency_key = excluded.idempotency_key
  returning * into v_job;

  perform private.write_audit(
    p_organization_id,
    'export.requested',
    'export_job',
    v_job.id,
    jsonb_build_object('export_kind', v_job.export_kind, 'scope_kind', v_scope ->> 'kind')
  );

  return jsonb_build_object(
    'id', v_job.id,
    'organization_id', v_job.organization_id,
    'requested_by', v_job.requested_by,
    'export_kind', v_job.export_kind,
    'format', v_job.format,
    'status', v_job.status,
    'scope_snapshot', v_job.scope_snapshot,
    'parameters', v_job.parameters,
    'file_id', v_job.file_id,
    'requested_at', v_job.requested_at,
    'completed_at', v_job.completed_at,
    'expires_at', v_job.expires_at,
    'error_code', v_job.error_code
  );
end;
$$;

create or replace function public.rpc_get_export_job(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_job public.export_jobs%rowtype;
begin
  select * into v_job from public.export_jobs where id = p_job_id;
  if not found
     or private.current_member_id(v_job.organization_id) <> v_job.requested_by
     or not private.export_scope_still_allowed(v_job.organization_id, v_job.requested_by, v_job.scope_snapshot) then
    raise exception using errcode = 'P0002', message = 'EXPORT_NOT_FOUND';
  end if;
  return jsonb_build_object(
    'id', v_job.id,
    'organization_id', v_job.organization_id,
    'requested_by', v_job.requested_by,
    'export_kind', v_job.export_kind,
    'format', v_job.format,
    'status', v_job.status,
    'scope_snapshot', v_job.scope_snapshot,
    'parameters', v_job.parameters,
    'file_id', v_job.file_id,
    'requested_at', v_job.requested_at,
    'completed_at', v_job.completed_at,
    'expires_at', v_job.expires_at,
    'error_code', v_job.error_code
  );
end;
$$;

create or replace function public.rpc_list_audit_logs(
  p_organization_id uuid,
  p_before timestamptz default null,
  p_limit integer default 50,
  p_action text default null,
  p_entity_type text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_items jsonb;
  v_next timestamptz;
begin
  if not private.is_admin(p_organization_id) then
    raise exception using errcode = '42501', message = 'AUDIT_READ_DENIED';
  end if;

  with rows as (
    select a.*, m.display_name as actor_display_name
    from public.audit_logs a
    left join public.organization_members m
      on m.organization_id = a.organization_id and m.id = a.actor_member_id
    where a.organization_id = p_organization_id
      and (p_before is null or a.recorded_at < p_before)
      and (p_action is null or a.action = p_action)
      and (p_entity_type is null or a.entity_type = p_entity_type)
    order by a.recorded_at desc, a.id desc
    limit greatest(1, least(coalesce(p_limit, 50), 100))
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', id,
      'organization_id', organization_id,
      'actor_member_id', actor_member_id,
      'actor_kind', actor_kind,
      'actor_display_name', actor_display_name,
      'action', action,
      'entity_type', entity_type,
      'entity_id', entity_id,
      'recorded_at', recorded_at,
      'request_id', request_id,
      'safe_metadata', safe_metadata
    ) order by recorded_at desc, id desc), '[]'::jsonb),
    min(recorded_at)
  into v_items, v_next
  from rows;

  return jsonb_build_object('items', v_items, 'next_before', v_next);
end;
$$;

create or replace function public.rpc_internal_claim_retention_cleanup(
  p_now timestamptz default timezone('utc', now()),
  p_limit integer default 100
)
returns table (
  file_id uuid,
  organization_id uuid,
  bucket_id text,
  object_path text
)
language sql
volatile
security definer
set search_path = ''
as $$
  select f.id, f.organization_id, f.bucket_id, f.object_path
  from public.files f
  where f.state in ('ready', 'quarantined')
    and f.deleted_at is null
    and not f.legal_hold
    and f.retention_until is not null
    and f.retention_until <= p_now
  order by f.retention_until, f.id
  for update skip locked
  limit greatest(1, least(coalesce(p_limit, 100), 500));
$$;

create or replace function public.rpc_internal_claim_export_jobs(
  p_worker_id uuid,
  p_limit integer default 10,
  p_now timestamptz default timezone('utc', now())
)
returns table (
  id uuid,
  organization_id uuid,
  requested_by uuid,
  export_kind text,
  format text,
  scope_snapshot jsonb,
  parameters jsonb,
  expires_at timestamptz
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  return query
  with candidates as (
    select ej.id
    from public.export_jobs ej
    where ej.status = 'queued'
      or (
        ej.status = 'processing'
        and ej.processing_started_at < p_now - interval '10 minutes'
      )
    order by ej.requested_at, ej.id
    for update skip locked
    limit greatest(1, least(coalesce(p_limit, 10), 50))
  ), claimed as (
    update public.export_jobs ej
    set status = 'processing',
        worker_id = p_worker_id,
        processing_started_at = p_now,
        error_code = null,
        version = version + 1
    from candidates c
    where ej.id = c.id
    returning ej.*
  )
  select
    c.id, c.organization_id, c.requested_by, c.export_kind, c.format,
    c.scope_snapshot, c.parameters, c.expires_at
  from claimed c;
end;
$$;

create or replace function public.rpc_internal_complete_export_job(
  p_job_id uuid,
  p_worker_id uuid,
  p_file_id uuid,
  p_completed_at timestamptz default timezone('utc', now())
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_job public.export_jobs%rowtype;
begin
  select * into v_job
  from public.export_jobs
  where id = p_job_id and status = 'processing' and worker_id = p_worker_id
  for update;
  if not found then raise exception using errcode = '40001', message = 'EXPORT_LEASE_LOST'; end if;
  if not exists (
    select 1 from public.files f
    where f.organization_id = v_job.organization_id
      and f.id = p_file_id
      and f.purpose = 'export'
      and f.state = 'ready'
  ) then
    raise exception using errcode = '22023', message = 'EXPORT_FILE_NOT_READY';
  end if;

  update public.export_jobs
  set status = 'ready',
      file_id = p_file_id,
      completed_at = p_completed_at,
      worker_id = null,
      processing_started_at = null,
      version = version + 1
  where id = p_job_id;

  perform private.write_audit(
    v_job.organization_id,
    'export.ready',
    'export_job',
    v_job.id,
    jsonb_build_object('export_kind', v_job.export_kind)
  );
end;
$$;

create or replace function public.rpc_internal_fail_export_job(
  p_job_id uuid,
  p_worker_id uuid,
  p_error_code text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  update public.export_jobs
  set status = 'failed',
      error_code = left(coalesce(nullif(trim(p_error_code), ''), 'EXPORT_FAILED'), 120),
      worker_id = null,
      processing_started_at = null,
      version = version + 1
  where id = p_job_id
    and status = 'processing'
    and worker_id = p_worker_id;
end;
$$;

create or replace function public.rpc_internal_mark_file_deleted(p_file_id uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_file public.files%rowtype;
begin
  select * into v_file from public.files where id = p_file_id for update;
  if not found then return; end if;
  if v_file.legal_hold then raise exception using errcode = '42501', message = 'FILE_LEGAL_HOLD'; end if;
  update public.files
  set state = 'deleted', deleted_at = timezone('utc', now())
  where id = p_file_id and state <> 'deleted';
  perform private.write_audit(
    v_file.organization_id,
    'file.retention_deleted',
    'file',
    v_file.id,
    jsonb_build_object('purpose', v_file.purpose, 'bucket_id', v_file.bucket_id)
  );
end;
$$;

alter table public.export_jobs enable row level security;

create policy export_jobs_read_own_current_scope
on public.export_jobs for select to authenticated
using (
  requested_by = private.current_member_id(organization_id)
  and private.export_scope_still_allowed(organization_id, requested_by, scope_snapshot)
);

grant select on public.export_jobs to authenticated;
revoke insert, update, delete, truncate, references, trigger on public.export_jobs from authenticated;
revoke select, insert, update, delete, truncate, references, trigger on public.files, public.upload_intents from authenticated;

revoke all on function private.current_export_scope(uuid) from public, anon, authenticated;
revoke all on function private.export_scope_still_allowed(uuid, uuid, jsonb) from public, anon, authenticated;
revoke all on function private.file_access_allowed(uuid, uuid) from public, anon, authenticated;
grant execute on function private.current_export_scope(uuid) to service_role;
grant execute on function private.export_scope_still_allowed(uuid, uuid, jsonb) to service_role;
grant execute on function private.file_access_allowed(uuid, uuid) to service_role;
grant execute on function private.export_scope_still_allowed(uuid, uuid, jsonb) to authenticated;

revoke all on function public.rpc_authorize_file_download(uuid) from public, anon;
revoke all on function public.rpc_create_export_job(uuid, text, jsonb, text) from public, anon;
revoke all on function public.rpc_get_export_job(uuid) from public, anon;
revoke all on function public.rpc_list_audit_logs(uuid, timestamptz, integer, text, text) from public, anon;
grant execute on function public.rpc_authorize_file_download(uuid) to authenticated;
grant execute on function public.rpc_create_export_job(uuid, text, jsonb, text) to authenticated;
grant execute on function public.rpc_get_export_job(uuid) to authenticated;
grant execute on function public.rpc_list_audit_logs(uuid, timestamptz, integer, text, text) to authenticated;

revoke all on function public.rpc_internal_claim_retention_cleanup(timestamptz, integer) from public, anon, authenticated;
revoke all on function public.rpc_internal_mark_file_deleted(uuid) from public, anon, authenticated;
revoke all on function public.rpc_internal_claim_export_jobs(uuid, integer, timestamptz) from public, anon, authenticated;
revoke all on function public.rpc_internal_complete_export_job(uuid, uuid, uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.rpc_internal_fail_export_job(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.rpc_internal_claim_retention_cleanup(timestamptz, integer) to service_role;
grant execute on function public.rpc_internal_mark_file_deleted(uuid) to service_role;
grant execute on function public.rpc_internal_claim_export_jobs(uuid, integer, timestamptz) to service_role;
grant execute on function public.rpc_internal_complete_export_job(uuid, uuid, uuid, timestamptz) to service_role;
grant execute on function public.rpc_internal_fail_export_job(uuid, uuid, text) to service_role;

-- ============================================================================
-- END 00000000000012_p10_security_ops.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000013_p11_context_contract.sql
-- ============================================================================

-- P11: context contract must remain valid while an organization is being bootstrapped.

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

-- ============================================================================
-- END 00000000000013_p11_context_contract.sql
-- ============================================================================


-- ============================================================================
-- BEGIN 00000000000014_p12_attendance_admin_settings.sql
-- ============================================================================

-- P12: administrator-configured attendance settings.
--
-- Office attendance can be completed from a browser only when the request reaches
-- a trusted ingress and its source IP matches an administrator-configured office
-- CIDR. Browsers never claim SSID/BSSID. Native clients may additionally supply a
-- BSSID, which remains verified against office_networks.

create table public.attendance_settings (
  organization_id uuid primary key references public.organizations(id) on delete restrict,
  allow_web_office_attendance boolean not null default false,
  remote_photo_required boolean not null default true,
  updated_by_member_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  version integer not null default 1 check (version > 0),
  foreign key (organization_id, updated_by_member_id)
    references public.organization_members(organization_id, id)
    on delete restrict
);

create trigger attendance_settings_set_updated_at before update on public.attendance_settings
for each row execute function private.set_updated_at();

alter table public.attendance_settings enable row level security;

create policy attendance_settings_read_active_member
on public.attendance_settings for select to authenticated
using (private.is_active_member(organization_id));

update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp']::text[]
where id = 'attendance-evidence';

-- A remote attendance challenge now needs a fresh camera/upload evidence file only.
-- The prior laptop hand-off session remains in the schema for historical rows but is
-- no longer a requirement for newly issued remote challenges.
create or replace function public.rpc_internal_create_attendance_challenge(
  p_organization_id uuid,
  p_member_id uuid,
  p_shift_instance_id uuid,
  p_action text,
  p_mode text,
  p_device_id uuid,
  p_nonce_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shift public.shift_instances%rowtype;
  v_challenge public.attendance_challenges%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if p_action not in ('check_in', 'check_out') or p_mode not in ('office', 'remote') then
    raise exception using errcode = '22023', message = 'ATTENDANCE_CHALLENGE_INVALID';
  end if;
  if p_nonce_hash is null or char_length(p_nonce_hash) <> 64 then
    raise exception using errcode = '22023', message = 'ATTENDANCE_NONCE_INVALID';
  end if;

  select * into v_shift
  from public.shift_instances s
  where s.organization_id = p_organization_id
    and s.id = p_shift_instance_id
    and s.member_id = p_member_id
    and s.status = 'scheduled'
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'SHIFT_NOT_FOUND';
  end if;
  if v_now < v_shift.starts_at - interval '3 hours' or v_now > v_shift.ends_at + interval '6 hours' then
    raise exception using errcode = '22023', message = 'OUTSIDE_ATTENDANCE_WINDOW';
  end if;
  if p_mode = 'office' and (v_shift.allowed_mode not in ('office', 'hybrid') or v_shift.office_id is null) then
    raise exception using errcode = '42501', message = 'OFFICE_NOT_ALLOWED';
  end if;
  if p_mode = 'remote' and not private.member_has_remote_permission(p_organization_id, p_member_id, v_shift, v_now) then
    raise exception using errcode = '42501', message = 'REMOTE_NOT_APPROVED';
  end if;
  if not exists (
    select 1 from public.user_devices d
    where d.organization_id = p_organization_id
      and d.id = p_device_id
      and d.member_id = p_member_id
      and d.revoked_at is null
  ) then
    raise exception using errcode = '42501', message = 'DEVICE_NOT_REGISTERED';
  end if;

  insert into public.attendance_challenges (
    organization_id, member_id, shift_instance_id, action, mode, nonce_hash, device_id, issued_at, expires_at
  ) values (
    p_organization_id, p_member_id, p_shift_instance_id, p_action, p_mode, lower(p_nonce_hash), p_device_id,
    v_now, v_now + interval '120 seconds'
  ) returning * into v_challenge;

  return jsonb_build_object(
    'challenge_id', v_challenge.id,
    'expires_at', v_challenge.expires_at,
    'server_now', v_now,
    'requirements', jsonb_build_object(
      'wifi_required', p_mode = 'office',
      'trusted_network_required', p_mode = 'office',
      'selfie_required', p_mode = 'remote',
      'laptop_session_required', false
    )
  );
end;
$$;

create or replace function public.rpc_internal_finalize_attendance(
  p_challenge_id uuid,
  p_nonce_hash text,
  p_bssid text,
  p_source_ip inet,
  p_file_id uuid,
  p_laptop_session_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_challenge public.attendance_challenges%rowtype;
  v_shift public.shift_instances%rowtype;
  v_existing public.attendance_events%rowtype;
  v_event public.attendance_events%rowtype;
  v_open public.attendance_sessions%rowtype;
  v_upload_intent public.upload_intents%rowtype;
  v_session_id uuid;
  v_network_id uuid;
  v_now timestamptz := clock_timestamp();
begin
  select * into v_challenge
  from public.attendance_challenges c
  where c.id = p_challenge_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'CHALLENGE_NOT_FOUND';
  end if;

  select * into v_existing
  from public.attendance_events e
  where e.organization_id = v_challenge.organization_id
    and e.member_id = v_challenge.member_id
    and e.idempotency_key = p_idempotency_key;
  if found then
    select s.id into v_session_id
    from public.attendance_sessions s
    where s.organization_id = v_existing.organization_id
      and (s.check_in_event_id = v_existing.id or s.check_out_event_id = v_existing.id)
    limit 1;
    return jsonb_build_object(
      'event_id', v_existing.id,
      'session_id', v_session_id,
      'event_kind', v_existing.event_kind,
      'mode', v_existing.mode,
      'effective_at', v_existing.effective_at,
      'recorded_at', v_existing.recorded_at,
      'duplicate', true
    );
  end if;

  if v_challenge.consumed_at is not null then
    raise exception using errcode = '40901', message = 'CHALLENGE_ALREADY_CONSUMED';
  end if;
  if v_challenge.expires_at <= v_now then
    raise exception using errcode = '22023', message = 'CHALLENGE_EXPIRED';
  end if;
  if lower(coalesce(p_nonce_hash, '')) <> v_challenge.nonce_hash then
    raise exception using errcode = '42501', message = 'CHALLENGE_NONCE_MISMATCH';
  end if;

  select * into v_shift
  from public.shift_instances s
  where s.organization_id = v_challenge.organization_id
    and s.id = v_challenge.shift_instance_id
    and s.member_id = v_challenge.member_id
    and s.status = 'scheduled'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'SHIFT_NOT_FOUND';
  end if;

  if v_challenge.mode = 'office' then
    if p_source_ip is null then
      raise exception using errcode = '42501', message = 'OFFICE_NETWORK_REQUIRED';
    end if;
    if p_bssid is null and not exists (
      select 1 from public.attendance_settings settings
      where settings.organization_id = v_challenge.organization_id
        and settings.allow_web_office_attendance
    ) then
      raise exception using errcode = '42501', message = 'WEB_OFFICE_ATTENDANCE_DISABLED';
    end if;
    if p_bssid is not null then
      select n.id into v_network_id
      from public.office_networks n
      where n.organization_id = v_challenge.organization_id
        and n.office_id = v_shift.office_id
        and n.bssid = lower(p_bssid)
        and n.valid_from <= v_now
        and (n.valid_until is null or n.valid_until > v_now)
      limit 1;
      if v_network_id is null then
        raise exception using errcode = '42501', message = 'WIFI_BSSID_MISMATCH';
      end if;
    end if;
    if not exists (
      select 1 from public.office_ip_ranges r
      where r.organization_id = v_challenge.organization_id
        and r.office_id = v_shift.office_id
        and p_source_ip <<= r.ip_range
        and r.valid_from <= v_now
        and (r.valid_until is null or r.valid_until > v_now)
    ) then
      raise exception using errcode = '42501', message = 'SOURCE_IP_MISMATCH';
    end if;
  else
    if not private.member_has_remote_permission(v_challenge.organization_id, v_challenge.member_id, v_shift, v_now) then
      raise exception using errcode = '42501', message = 'REMOTE_NOT_APPROVED';
    end if;
    if p_file_id is null then
      raise exception using errcode = '42501', message = 'REMOTE_EVIDENCE_REQUIRED';
    end if;
    select * into v_upload_intent
    from public.upload_intents ui
    where ui.organization_id = v_challenge.organization_id
      and ui.member_id = v_challenge.member_id
      and ui.file_id = p_file_id
      and ui.target_kind = 'attendance'
      and ui.challenge_id = v_challenge.id
      and ui.consumed_at is null
      and ui.expires_at > v_now
    for update;
    if not found then
      raise exception using errcode = '42501', message = 'REMOTE_UPLOAD_INTENT_INVALID';
    end if;
    if not exists (
      select 1 from public.files f
      where f.organization_id = v_challenge.organization_id
        and f.id = p_file_id
        and f.uploaded_by_member_id = v_challenge.member_id
        and f.purpose = 'attendance'
        and f.state = 'ready'
    ) then
      raise exception using errcode = '42501', message = 'REMOTE_EVIDENCE_REQUIRED';
    end if;
  end if;

  select * into v_open
  from public.attendance_sessions s
  where s.organization_id = v_challenge.organization_id
    and s.member_id = v_challenge.member_id
    and s.status = 'open'
  for update;

  if v_challenge.action = 'check_in' and found then
    raise exception using errcode = '23505', message = 'ATTENDANCE_SESSION_ALREADY_OPEN';
  end if;
  if v_challenge.action = 'check_out' and not found then
    raise exception using errcode = '22023', message = 'ATTENDANCE_CHECK_IN_REQUIRED';
  end if;

  insert into public.attendance_events (
    organization_id, member_id, shift_instance_id, event_kind, effective_at, recorded_at,
    mode, challenge_id, verification_status, idempotency_key
  ) values (
    v_challenge.organization_id, v_challenge.member_id, v_challenge.shift_instance_id,
    v_challenge.action, v_now, v_now, v_challenge.mode, v_challenge.id, 'verified', p_idempotency_key
  ) returning * into v_event;

  insert into public.attendance_evidence (
    organization_id, attendance_event_id, file_id, source_ip, office_network_id, device_id,
    wifi_claim_snapshot, verification_details
  ) values (
    v_challenge.organization_id, v_event.id, case when v_challenge.mode = 'remote' then p_file_id else null end,
    p_source_ip, v_network_id, v_challenge.device_id,
    case
      when v_challenge.mode <> 'office' then null
      when p_bssid is null then jsonb_build_object('verification', 'source_ip')
      else jsonb_build_object('bssid', lower(p_bssid), 'verification', 'bssid_and_source_ip')
    end,
    jsonb_build_object('server_verified', true, 'mode', v_challenge.mode)
  );

  if v_challenge.action = 'check_in' then
    insert into public.attendance_sessions (
      organization_id, member_id, shift_instance_id, check_in_event_id, starts_at, mode
    ) values (
      v_challenge.organization_id, v_challenge.member_id, v_challenge.shift_instance_id,
      v_event.id, v_event.effective_at, v_challenge.mode
    ) returning id into v_session_id;
  else
    update public.attendance_sessions
    set check_out_event_id = v_event.id,
        ends_at = v_event.effective_at,
        status = 'closed',
        updated_at = v_now,
        version = version + 1
    where id = v_open.id
    returning id into v_session_id;
  end if;

  update public.attendance_challenges
  set consumed_at = v_now,
      file_id = case when v_challenge.mode = 'remote' then p_file_id else file_id end,
      attempt_count = attempt_count + 1
  where id = v_challenge.id;

  if v_challenge.mode = 'remote' then
    update public.upload_intents
    set consumed_at = v_now
    where organization_id = v_challenge.organization_id
      and id = v_upload_intent.id
      and consumed_at is null;
    if not found then
      raise exception using errcode = '40901', message = 'REMOTE_UPLOAD_INTENT_ALREADY_CONSUMED';
    end if;
  end if;

  return jsonb_build_object(
    'event_id', v_event.id,
    'session_id', v_session_id,
    'event_kind', v_event.event_kind,
    'mode', v_event.mode,
    'effective_at', v_event.effective_at,
    'recorded_at', v_event.recorded_at,
    'duplicate', false
  );
end;
$$;

revoke all on public.attendance_settings from anon;
grant select on public.attendance_settings to authenticated;
revoke insert, update, delete, truncate, references, trigger on public.attendance_settings from authenticated;
revoke all on function public.rpc_internal_create_attendance_challenge(uuid, uuid, uuid, text, text, uuid, text) from public, anon, authenticated;
revoke all on function public.rpc_internal_finalize_attendance(uuid, text, text, inet, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.rpc_internal_create_attendance_challenge(uuid, uuid, uuid, text, text, uuid, text) to service_role;
grant execute on function public.rpc_internal_finalize_attendance(uuid, text, text, inet, uuid, uuid, text) to service_role;

-- ============================================================================
-- END 00000000000014_p12_attendance_admin_settings.sql
-- ============================================================================

