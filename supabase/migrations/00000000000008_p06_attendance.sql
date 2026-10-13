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
