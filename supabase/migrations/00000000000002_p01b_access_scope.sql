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

