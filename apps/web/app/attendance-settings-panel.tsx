'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';
import type { FormEvent } from 'react';
import type { AttendanceSettingsWorkspace } from '../lib/data/attendance-settings-data';

type Props = { data: AttendanceSettingsWorkspace };

type CommandResult = { error?: { code?: string }; ok?: boolean };

const weekdayOptions = [
  { label: 'T2', value: 1 },
  { label: 'T3', value: 2 },
  { label: 'T4', value: 3 },
  { label: 'T5', value: 4 },
  { label: 'T6', value: 5 },
  { label: 'T7', value: 6 },
  { label: 'CN', value: 7 },
];

function todayInTimezone(timezone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    day: '2-digit',
    month: '2-digit',
    timeZone: timezone,
    year: 'numeric',
  }).formatToParts(new Date());
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

function errorMessage(code: string | undefined) {
  const messages: Record<string, string> = {
    ATTENDANCE_ADMIN_REQUIRED: 'Bạn chưa có quyền quản lý chấm công.',
    ATTENDANCE_SETTINGS_MIGRATION_REQUIRED: 'Cần chạy SQL cập nhật P12 trước khi lưu cấu hình.',
    OFFICE_IP_RANGE_SAVE_FAILED: 'Không lưu được dải IP. Kiểm tra lại CIDR, ví dụ 203.0.113.0/24.',
    OFFICE_NETWORK_SAVE_FAILED: 'Không lưu được Wi‑Fi. Kiểm tra BSSID hoặc cấu hình bị trùng.',
    SHIFT_ASSIGNMENT_SAVE_FAILED: 'Không lưu được lịch gán ca.',
    SHIFT_ASSIGNMENT_TARGET_INVALID: 'Nhân viên hoặc mẫu ca không còn hợp lệ.',
    SHIFT_BREAK_INCOMPLETE: 'Cần nhập đủ cả giờ bắt đầu và kết thúc của giờ nghỉ.',
    SHIFT_BREAK_INVALID: 'Khoảng nghỉ phải nằm trong giờ ca làm việc.',
    SHIFT_OFFICE_REQUIRED: 'Ca chỉ tại văn phòng cần chọn một văn phòng.',
    SHIFT_OFFICE_INVALID: 'Văn phòng gắn với ca không còn hợp lệ.',
    SHIFT_MATERIALIZATION_FAILED:
      'Không thể tạo lịch ca tương lai. Kiểm tra lịch hiện có của nhân viên.',
    SHIFT_TEMPLATE_SAVE_FAILED: 'Không lưu được mẫu ca. Tên ca có thể đã tồn tại.',
  };
  return messages[code ?? ''] ?? 'Không thể lưu thay đổi. Vui lòng thử lại.';
}

export function AttendanceSettingsPanel({ data }: Props) {
  const router = useRouter();
  const [busy, setBusy] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [webOfficeEnabled, setWebOfficeEnabled] = useState(data.webOfficeAttendanceEnabled);
  const [shiftWeekdays, setShiftWeekdays] = useState<number[]>([1, 2, 3, 4, 5]);
  const defaultOfficeId = data.offices[0]?.id ?? '';
  const defaultShiftId = data.shifts[0]?.id ?? '';
  const defaultMemberId = data.members[0]?.id ?? '';
  const defaultDate = useMemo(
    () => todayInTimezone(data.context.timezone),
    [data.context.timezone],
  );

  async function submit(action: string, values: Record<string, unknown>) {
    setBusy(action);
    setMessage(null);
    try {
      const response = await fetch('/api/admin/attendance-settings', {
        body: JSON.stringify({ action, organization_id: data.context.organization_id, ...values }),
        headers: { 'content-type': 'application/json' },
        method: 'POST',
      });
      const payload = (await response.json().catch(() => null)) as CommandResult | null;
      if (!response.ok || !payload?.ok) throw new Error(payload?.error?.code);
      setMessage('Đã lưu. Dữ liệu cấu hình vừa được làm mới.');
      router.refresh();
      return true;
    } catch (error) {
      setMessage(errorMessage(error instanceof Error ? error.message : undefined));
      return false;
    } finally {
      setBusy(null);
    }
  }

  if (!data.canManage) {
    return (
      <section className="attendance-settings-empty">
        Bạn cần quyền quản trị hoặc capability quản lý chấm công để mở khu vực này.
      </section>
    );
  }

  if (!data.schemaReady) {
    return (
      <section className="attendance-settings-empty">
        <strong>Cần cập nhật schema chấm công</strong>
        <p>
          Hãy chạy file SQL P12 trong Supabase SQL Editor, sau đó tải lại trang để cấu hình Wi‑Fi,
          chấm công web và ca làm việc.
        </p>
      </section>
    );
  }

  return (
    <div className="attendance-settings-stack">
      {message ? (
        <p className="attendance-settings-message" role="status">
          {message}
        </p>
      ) : null}

      <section className="attendance-settings-card">
        <div className="attendance-settings-heading">
          <div>
            <p className="workspace-eyebrow">WEB OFFICE ATTENDANCE</p>
            <h2>Chấm công Wi‑Fi từ website</h2>
            <p>
              Website không đọc SSID/BSSID. Hệ thống chỉ ghi nhận khi IP công khai từ Wi‑Fi đang
              dùng khớp một dải CIDR của văn phòng, qua Vercel hoặc Cloudflare tin cậy.
            </p>
          </div>
          <label className="attendance-settings-switch">
            <input
              checked={webOfficeEnabled}
              onChange={(event) => setWebOfficeEnabled(event.target.checked)}
              type="checkbox"
            />
            <span>Cho phép trên web</span>
          </label>
        </div>
        <div className="attendance-settings-actions">
          <button
            className="attendance-settings-primary"
            disabled={busy !== null}
            onClick={() =>
              void submit('save_policy', { allow_web_office_attendance: webOfficeEnabled })
            }
            type="button"
          >
            {busy === 'save_policy' ? 'Đang lưu...' : 'Lưu chính sách web'}
          </button>
          <small>
            Khi triển khai, đặt <code>ATTENDANCE_TRUSTED_INGRESS</code> là <code>vercel</code> hoặc{' '}
            <code>cloudflare</code>. Localhost không có nguồn IP tin cậy nên không thể ghi công
            thật.
          </small>
        </div>
      </section>

      <section className="attendance-settings-grid">
        <form
          className="attendance-settings-card"
          onSubmit={(event: FormEvent<HTMLFormElement>) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            void submit('save_office', {
              name: form.get('name'),
              timezone: form.get('timezone'),
            }).then((saved) => saved && event.currentTarget.reset());
          }}
        >
          <div className="attendance-settings-heading compact">
            <div>
              <p className="workspace-eyebrow">OFFICE</p>
              <h2>Văn phòng</h2>
            </div>
          </div>
          <label>
            Tên văn phòng
            <input defaultValue="Văn phòng chính" name="name" required />
          </label>
          <label>
            Múi giờ
            <input defaultValue={data.context.timezone} name="timezone" required />
          </label>
          <button className="attendance-settings-secondary" disabled={busy !== null} type="submit">
            Thêm / cập nhật văn phòng
          </button>
          {data.offices.length ? (
            <ul className="attendance-settings-list">
              {data.offices.map((office) => (
                <li key={office.id}>
                  <strong>{office.name}</strong>
                  <span>{office.timezone}</span>
                </li>
              ))}
            </ul>
          ) : null}
        </form>

        <form
          className="attendance-settings-card"
          onSubmit={(event: FormEvent<HTMLFormElement>) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            void submit('save_network', {
              bssid: String(form.get('bssid') ?? '').toLowerCase(),
              office_id: form.get('office_id'),
              ssid_label: form.get('ssid_label'),
            }).then((saved) => saved && event.currentTarget.reset());
          }}
        >
          <div className="attendance-settings-heading compact">
            <div>
              <p className="workspace-eyebrow">NATIVE WI-FI</p>
              <h2>Wi‑Fi xác thực mobile</h2>
            </div>
          </div>
          <label>
            Văn phòng
            <select
              defaultValue={defaultOfficeId}
              disabled={!data.offices.length}
              name="office_id"
              required
            >
              <option value="">Chọn văn phòng</option>
              {data.offices.map((office) => (
                <option key={office.id} value={office.id}>
                  {office.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Tên Wi‑Fi (SSID)
            <input name="ssid_label" placeholder="BOMAX-STAFF" required />
          </label>
          <label>
            BSSID / MAC access point
            <input
              name="bssid"
              pattern="[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}"
              placeholder="aa:bb:cc:dd:ee:ff"
              required
            />
          </label>
          <button
            className="attendance-settings-secondary"
            disabled={busy !== null || !data.offices.length}
            type="submit"
          >
            Thêm Wi‑Fi mobile
          </button>
          {data.networks.length ? (
            <ul className="attendance-settings-list">
              {data.networks.map((network) => (
                <li key={network.id}>
                  <strong>{network.ssid_label}</strong>
                  <span>{network.bssid}</span>
                </li>
              ))}
            </ul>
          ) : null}
        </form>

        <form
          className="attendance-settings-card"
          onSubmit={(event: FormEvent<HTMLFormElement>) => {
            event.preventDefault();
            const form = new FormData(event.currentTarget);
            void submit('save_ip_range', {
              ip_range: form.get('ip_range'),
              note: form.get('note'),
              office_id: form.get('office_id'),
            }).then((saved) => saved && event.currentTarget.reset());
          }}
        >
          <div className="attendance-settings-heading compact">
            <div>
              <p className="workspace-eyebrow">WEB IP RANGE</p>
              <h2>Public IP của Wi‑Fi</h2>
            </div>
          </div>
          <label>
            Văn phòng
            <select
              defaultValue={defaultOfficeId}
              disabled={!data.offices.length}
              name="office_id"
              required
            >
              <option value="">Chọn văn phòng</option>
              {data.offices.map((office) => (
                <option key={office.id} value={office.id}>
                  {office.name}
                </option>
              ))}
            </select>
          </label>
          <label>
            Dải public IP (CIDR)
            <input name="ip_range" placeholder="203.0.113.0/24" required />
          </label>
          <label>
            Ghi chú
            <input name="note" placeholder="Gateway văn phòng tầng 3" />
          </label>
          <button
            className="attendance-settings-secondary"
            disabled={busy !== null || !data.offices.length}
            type="submit"
          >
            Thêm dải IP web
          </button>
          {data.ipRanges.length ? (
            <ul className="attendance-settings-list">
              {data.ipRanges.map((range) => (
                <li key={range.id}>
                  <strong>{range.ip_range}</strong>
                  <span>{range.note || 'Không có ghi chú'}</span>
                </li>
              ))}
            </ul>
          ) : null}
        </form>
      </section>

      <section className="attendance-settings-card">
        <div className="attendance-settings-heading">
          <div>
            <p className="workspace-eyebrow">WORK SHIFTS</p>
            <h2>Giờ vào ca, ra ca và lịch nhân viên</h2>
            <p>
              Tạo mẫu ca rồi gán cho nhân viên. Hệ thống sinh lịch ca còn trống trong 90 ngày tiếp
              theo; lịch đã tồn tại không bị ghi đè.
            </p>
          </div>
        </div>
        <div className="attendance-settings-grid shift-grid">
          <form
            className="attendance-settings-subform"
            onSubmit={(event: FormEvent<HTMLFormElement>) => {
              event.preventDefault();
              const form = new FormData(event.currentTarget);
              void submit('save_shift_template', {
                allowed_mode: form.get('allowed_mode'),
                break_end: form.get('break_end') || undefined,
                break_start: form.get('break_start') || undefined,
                end_local: form.get('end_local'),
                name: form.get('name'),
                office_id: form.get('office_id') || null,
                start_local: form.get('start_local'),
              }).then((saved) => saved && event.currentTarget.reset());
            }}
          >
            <strong>Tạo mẫu ca</strong>
            <label>
              Tên ca
              <input name="name" placeholder="Ca hành chính 09:00–18:00" required />
            </label>
            <div className="attendance-settings-inline-fields">
              <label>
                Vào ca
                <input defaultValue="09:00" name="start_local" type="time" required />
              </label>
              <label>
                Ra ca
                <input defaultValue="18:00" name="end_local" type="time" required />
              </label>
            </div>
            <div className="attendance-settings-inline-fields">
              <label>
                Nghỉ từ
                <input name="break_start" type="time" />
              </label>
              <label>
                Đến
                <input name="break_end" type="time" />
              </label>
            </div>
            <label>
              Hình thức
              <select defaultValue="hybrid" name="allowed_mode">
                <option value="office">Chỉ tại văn phòng</option>
                <option value="remote">Chỉ online</option>
                <option value="hybrid">Linh hoạt (văn phòng / online)</option>
              </select>
            </label>
            <label>
              Văn phòng (bắt buộc với ca tại văn phòng)
              <select defaultValue={defaultOfficeId} name="office_id">
                <option value="">Không áp dụng</option>
                {data.offices.map((office) => (
                  <option key={office.id} value={office.id}>
                    {office.name}
                  </option>
                ))}
              </select>
            </label>
            <button className="attendance-settings-primary" disabled={busy !== null} type="submit">
              Tạo mẫu ca
            </button>
          </form>

          <form
            className="attendance-settings-subform"
            onSubmit={(event: FormEvent<HTMLFormElement>) => {
              event.preventDefault();
              const form = new FormData(event.currentTarget);
              void submit('assign_shift', {
                effective_from: form.get('effective_from'),
                member_id: form.get('member_id'),
                shift_template_id: form.get('shift_template_id'),
                weekdays: shiftWeekdays,
              });
            }}
          >
            <strong>Gán lịch cho nhân viên</strong>
            <label>
              Nhân viên
              <select defaultValue={defaultMemberId} name="member_id" required>
                <option value="">Chọn nhân viên</option>
                {data.members.map((member) => (
                  <option key={member.id} value={member.id}>
                    {member.display_name} · {member.employee_code}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Mẫu ca
              <select defaultValue={defaultShiftId} name="shift_template_id" required>
                <option value="">Chọn mẫu ca</option>
                {data.shifts.map((shift) => (
                  <option key={shift.id} value={shift.id}>
                    {shift.name} · {shift.start_local.slice(0, 5)}–{shift.end_local.slice(0, 5)}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Áp dụng từ ngày
              <input defaultValue={defaultDate} name="effective_from" type="date" required />
            </label>
            <fieldset className="attendance-settings-weekdays">
              <legend>Ngày làm việc</legend>
              {weekdayOptions.map((weekday) => (
                <label key={weekday.value}>
                  <input
                    checked={shiftWeekdays.includes(weekday.value)}
                    onChange={(event) =>
                      setShiftWeekdays((current) =>
                        event.target.checked
                          ? [...current, weekday.value]
                          : current.filter((value) => value !== weekday.value),
                      )
                    }
                    type="checkbox"
                  />
                  {weekday.label}
                </label>
              ))}
            </fieldset>
            <button
              className="attendance-settings-primary"
              disabled={
                busy !== null ||
                !shiftWeekdays.length ||
                !data.members.length ||
                !data.shifts.length
              }
              type="submit"
            >
              {busy === 'assign_shift' ? 'Đang tạo lịch...' : 'Gán ca và tạo lịch 90 ngày'}
            </button>
          </form>
        </div>
        {data.shifts.length ? (
          <div className="attendance-settings-shifts">
            {data.shifts.map((shift) => (
              <article key={shift.id}>
                <strong>{shift.name}</strong>
                <span>
                  {shift.start_local.slice(0, 5)}–{shift.end_local.slice(0, 5)} ·{' '}
                  {shift.allowed_mode}
                </span>
                <small>
                  {shift.standard_day_minutes} phút chuẩn
                  {shift.breaks.length
                    ? ` · nghỉ ${shift.breaks.map((item) => `${item.start}–${item.end}`).join(', ')}`
                    : ''}
                </small>
              </article>
            ))}
          </div>
        ) : null}
      </section>
    </div>
  );
}
