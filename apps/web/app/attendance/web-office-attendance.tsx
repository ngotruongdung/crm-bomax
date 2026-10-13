'use client';

import {
  attendanceChallengeResponseSchema,
  attendanceCommitSchema,
  attendanceDaySchema,
  attendanceDeviceRegistrationResponseSchema,
} from '@opsdesk/contracts';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

type Props = {
  enabled: boolean;
  organizationId: string;
  timezone: string;
};

function organizationDate(timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    day: '2-digit',
    month: '2-digit',
    timeZone: timezone,
    year: 'numeric',
  }).formatToParts(new Date());
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function opaqueInstallationId(organizationId: string) {
  const key = `opsdesk.attendance.web-device.${organizationId}`;
  const current = window.localStorage.getItem(key);
  if (current) return current;
  const next = `web-${crypto.randomUUID()}`;
  window.localStorage.setItem(key, next);
  return next;
}

function opaqueId() {
  return `web-attendance-${Date.now().toString(36)}-${crypto.randomUUID()}`;
}

async function apiData(response: Response) {
  const payload = (await response.json().catch(() => null)) as {
    data?: unknown;
    error?: { code?: string };
    ok?: boolean;
  } | null;
  if (!response.ok || !payload?.ok)
    throw new Error(payload?.error?.code ?? 'ATTENDANCE_API_FAILED');
  return payload.data;
}

function messageFor(code: string) {
  const messages: Record<string, string> = {
    OFFICE_NOT_ALLOWED: 'Ca hôm nay không cho phép chấm tại văn phòng.',
    SOURCE_IP_MISMATCH: 'Bạn chưa dùng đúng Wi‑Fi văn phòng hoặc public IP chưa được cấu hình.',
    TRUSTED_INGRESS_NOT_CONFIGURED:
      'Máy chủ chưa bật trusted ingress. Admin cần triển khai qua Vercel hoặc Cloudflare.',
    TRUSTED_SOURCE_IP_UNAVAILABLE: 'Không lấy được public IP đáng tin cậy từ gateway triển khai.',
    WEB_OFFICE_ATTENDANCE_DISABLED: 'Admin chưa bật chấm công Wi‑Fi bằng website.',
    WIFI_CLAIM_STALE_OR_MISSING: 'Phiên chấm công không hợp lệ. Hãy thử lại từ website.',
  };
  return messages[code] ?? 'Không thể chấm công lúc này. Vui lòng thử lại.';
}

export function WebOfficeAttendance({ enabled, organizationId, timezone }: Props) {
  const router = useRouter();
  const [deviceId, setDeviceId] = useState<string | null>(null);
  const [day, setDay] = useState<ReturnType<typeof attendanceDaySchema.parse> | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const workDate = useMemo(() => organizationDate(timezone), [timezone]);

  useEffect(() => {
    if (!enabled) return;
    let active = true;
    async function prepare() {
      try {
        const devicePayload = await apiData(
          await fetch('/api/attendance/device', {
            body: JSON.stringify({
              installation_id: opaqueInstallationId(organizationId),
              label: 'OpsDesk web',
              organization_id: organizationId,
              platform: 'web',
            }),
            headers: { 'content-type': 'application/json' },
            method: 'POST',
          }),
        );
        const registered = attendanceDeviceRegistrationResponseSchema.safeParse(devicePayload);
        if (!registered.success) throw new Error('DEVICE_CONTRACT_INVALID');
        const query = new URLSearchParams({ organization_id: organizationId, work_date: workDate });
        const dayPayload = await apiData(await fetch(`/api/attendance/day?${query.toString()}`));
        const nextDay = attendanceDaySchema.safeParse(dayPayload);
        if (!nextDay.success) throw new Error('ATTENDANCE_DAY_CONTRACT_INVALID');
        if (!active) return;
        setDeviceId(registered.data.device_id);
        setDay(nextDay.data);
      } catch (error) {
        if (active) setMessage(messageFor(error instanceof Error ? error.message : ''));
      }
    }
    void prepare();
    return () => {
      active = false;
    };
  }, [enabled, organizationId, workDate]);

  const openSession = day?.sessions.find((session) => session.status === 'open') ?? null;
  const officeAllowed = Boolean(
    day?.shift && ['office', 'hybrid'].includes(day.shift.allowed_mode),
  );
  const action = openSession ? 'check_out' : 'check_in';

  async function submit() {
    if (!enabled || !day?.shift || !deviceId || !officeAllowed || busy) return;
    setBusy(true);
    setMessage(null);
    try {
      const challengePayload = await apiData(
        await fetch('/api/attendance/challenge', {
          body: JSON.stringify({
            action,
            device_id: deviceId,
            mode: 'office',
            organization_id: organizationId,
            shift_instance_id: day.shift.id,
          }),
          headers: { 'content-type': 'application/json' },
          method: 'POST',
        }),
      );
      const challenge = attendanceChallengeResponseSchema.safeParse(challengePayload);
      if (!challenge.success) throw new Error('ATTENDANCE_CHALLENGE_CONTRACT_INVALID');

      const commitPayload = await apiData(
        await fetch('/api/attendance/finalize', {
          body: JSON.stringify({
            challenge_id: challenge.data.challenge_id,
            device_id: deviceId,
            idempotency_key: opaqueId(),
            nonce: challenge.data.nonce,
          }),
          headers: { 'content-type': 'application/json' },
          method: 'POST',
        }),
      );
      const commit = attendanceCommitSchema.safeParse(commitPayload);
      if (!commit.success) throw new Error('ATTENDANCE_COMMIT_CONTRACT_INVALID');
      setMessage(
        `Đã ${commit.data.event_kind === 'check_in' ? 'chấm vào' : 'chấm ra'} lúc ${new Date(commit.data.recorded_at).toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })}.`,
      );
      router.refresh();
    } catch (error) {
      setMessage(messageFor(error instanceof Error ? error.message : ''));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="attendance-web-action">
      <button
        disabled={!enabled || !day?.shift || !deviceId || !officeAllowed || busy}
        onClick={() => void submit()}
        type="button"
      >
        {busy
          ? 'Đang xác minh Wi‑Fi...'
          : action === 'check_in'
            ? 'Chấm vào bằng Wi‑Fi'
            : 'Chấm ra bằng Wi‑Fi'}
      </button>
      <small>
        {day?.shift
          ? officeAllowed
            ? 'Máy chủ đối chiếu public IP của Wi‑Fi với dải IP do admin cấu hình.'
            : 'Ca này chỉ cho phép chấm công online.'
          : 'Đang tải ca làm việc hôm nay...'}
      </small>
      {message ? <p role="status">{message}</p> : null}
    </div>
  );
}
