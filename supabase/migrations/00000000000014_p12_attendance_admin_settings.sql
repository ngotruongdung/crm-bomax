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
