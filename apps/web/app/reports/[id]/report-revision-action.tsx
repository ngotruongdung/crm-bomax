'use client';

import { useRef, useState } from 'react';
import { useRouter } from 'next/navigation';

export function ReportRevisionAction({
  demo,
  isAdmin,
  organizationId,
  revision,
  runId,
}: {
  demo: boolean;
  isAdmin: boolean;
  organizationId: string;
  revision: number;
  runId: string;
}) {
  const router = useRouter();
  const keyRef = useRef<string | null>(null);
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isAdmin) return null;

  async function submit() {
    const normalized = reason.trim();
    if (normalized.length < 3 || busy || demo) return;
    keyRef.current ??= crypto.randomUUID();
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/reports/revision', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          organization_id: organizationId,
          run_id: runId,
          expected_version: revision,
          reason: normalized,
          idempotency_key: keyRef.current,
        }),
      });
      const payload = (await response.json().catch(() => ({}))) as {
        data?: { run_id?: string };
        error?: { code?: string };
      };
      if (!response.ok) {
        const code = payload.error?.code ?? '';
        setError(
          code.includes('VERSION_CONFLICT')
            ? 'Báo cáo đã có revision mới. Hãy tải lại trước khi tạo revision khác.'
            : 'Không thể tạo revision báo cáo.',
        );
        return;
      }
      keyRef.current = null;
      setOpen(false);
      setReason('');
      if (payload.data?.run_id) router.replace(`/reports/${payload.data.run_id}`);
      else router.refresh();
    } catch {
      setError('Không thể kết nối server report.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="report-revision-action">
      <button disabled={demo || busy} onClick={() => setOpen((value) => !value)} type="button">
        Tạo revision
      </button>
      {demo ? <span>Revision bị khóa trong demo.</span> : null}
      {open ? (
        <div className="report-revision-panel">
          <label htmlFor="report-revision-reason">Lý do revision</label>
          <textarea
            id="report-revision-reason"
            maxLength={500}
            onChange={(event) => {
              setReason(event.target.value);
              keyRef.current = null;
            }}
            rows={3}
            value={reason}
          />
          <div>
            <button disabled={busy} onClick={() => setOpen(false)} type="button">
              Hủy
            </button>
            <button
              disabled={busy || reason.trim().length < 3}
              onClick={() => void submit()}
              type="button"
            >
              {busy ? 'Đang tạo…' : 'Xác nhận revision'}
            </button>
          </div>
        </div>
      ) : null}
      {error ? <p role="alert">{error}</p> : null}
    </section>
  );
}
