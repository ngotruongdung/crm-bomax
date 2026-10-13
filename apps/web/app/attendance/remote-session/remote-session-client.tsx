'use client';

import { attendanceDaySchema, remoteLaptopSessionSchema } from '@opsdesk/contracts';
import { useState } from 'react';

type RemoteSessionClientProps = {
  enabled: boolean;
  organizationId: string;
  timezone: string;
};

function organizationDate(timezone: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

export function RemoteSessionClient({
  enabled,
  organizationId,
  timezone,
}: RemoteSessionClientProps) {
  const [code, setCode] = useState<string | null>(null);
  const [expiresAt, setExpiresAt] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function createSession() {
    if (!enabled || busy) return;
    setBusy(true);
    setMessage(null);
    try {
      const workDate = organizationDate(timezone);
      const dayResponse = await fetch(
        `/api/attendance/day?organization_id=${encodeURIComponent(organizationId)}&work_date=${workDate}`,
      );
      const dayPayload = (await dayResponse.json()) as { ok?: boolean; data?: unknown };
      const day = attendanceDaySchema.safeParse(dayPayload.data);
      if (!dayResponse.ok || !dayPayload.ok || !day.success || !day.data.shift) {
        throw new Error('Không có ca làm việc hợp lệ cho hôm nay.');
      }
      if (!['remote', 'hybrid'].includes(day.data.shift.allowed_mode)) {
        throw new Error('Ca hiện tại chưa cho phép chấm công online.');
      }

      const response = await fetch('/api/attendance/laptop-session', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          organization_id: organizationId,
          shift_instance_id: day.data.shift.id,
        }),
      });
      const payload = (await response.json()) as {
        ok?: boolean;
        data?: unknown;
        error?: { code?: string };
      };
      const parsed = remoteLaptopSessionSchema.safeParse(payload.data);
      if (!response.ok || !payload.ok || !parsed.success) {
        throw new Error(payload.error?.code ?? 'Không thể tạo phiên online.');
      }
      setCode(parsed.data.display_code);
      setExpiresAt(parsed.data.expires_at);
    } catch (error) {
      setCode(null);
      setExpiresAt(null);
      setMessage(error instanceof Error ? error.message : 'Không thể tạo phiên online.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className="remote-session-code" aria-label="Trạng thái mã phiên">
        <span>Mã phiên</span>
        <strong>{code ? code.split('').join(' ') : '— — — — — —'}</strong>
        <small>
          {expiresAt
            ? `Hết hạn lúc ${new Date(expiresAt).toLocaleTimeString('vi-VN')}`
            : enabled
              ? 'Tạo mã khi bạn đã sẵn sàng chụp selfie'
              : 'Cần Supabase thật để tạo phiên server'}
        </small>
      </div>
      <div className="remote-session-actions">
        <button disabled={!enabled || busy} onClick={() => void createSession()} type="button">
          {busy ? 'Đang tạo mã...' : code ? 'Tạo mã mới' : 'Tạo mã 6 số'}
        </button>
        {message ? <p className="remote-session-error">{message}</p> : null}
      </div>
    </>
  );
}
