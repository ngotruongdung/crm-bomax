import { describe, expect, it } from 'vitest';
import {
  attendanceDiagnosticFor,
  isRecordedAttendance,
  officeBrowserDiagnostic,
} from '../lib/attendance/attendance-policy';

describe('P06 attendance fail-closed policy', () => {
  it('ATT-06: browsers never claim strict office Wi-Fi verification', () => {
    expect(officeBrowserDiagnostic().code).toBe('BROWSER_WIFI_NOT_VERIFIABLE');
  });

  it('ATT-09: expired challenge asks for a new challenge', () => {
    expect(attendanceDiagnosticFor('CHALLENGE_EXPIRED').action).toBe('Lấy challenge mới');
  });

  it('ATT-13: remote permission is an explicit diagnostic', () => {
    expect(attendanceDiagnosticFor('REMOTE_NOT_APPROVED').title).toContain('Chưa có quyền');
  });

  it('ATT-03/04: wrong office network has distinct diagnostics', () => {
    expect(attendanceDiagnosticFor('WIFI_BSSID_MISMATCH').title).toContain('Wi-Fi');
    expect(attendanceDiagnosticFor('SOURCE_IP_MISMATCH').title).toContain('public IP');
  });

  it('ATT-05: trusted ingress failures never become a generic success state', () => {
    expect(attendanceDiagnosticFor('TRUSTED_INGRESS_NOT_CONFIGURED').description).toContain(
      'fail-closed',
    );
    expect(attendanceDiagnosticFor('TRUSTED_SOURCE_IP_UNAVAILABLE').title).toContain('public IP');
  });

  it('ATT-15: laptop session invalid and locked states are distinguishable', () => {
    expect(attendanceDiagnosticFor('LAPTOP_SESSION_INVALID').title).toContain('không hợp lệ');
    expect(attendanceDiagnosticFor('LAPTOP_SESSION_LOCKED').title).toContain('bị khóa');
  });

  it('ATT-18: failed upload is never an attendance success', () => {
    expect(
      isRecordedAttendance({
        state: 'failed',
        event_id: 'event-id',
        recorded_at: '2026-10-05T00:00:00Z',
      }),
    ).toBe(false);
  });

  it('ATT-17: only a committed server event is displayed as recorded', () => {
    expect(isRecordedAttendance({ state: 'pending', event_id: null, recorded_at: null })).toBe(
      false,
    );
    expect(
      isRecordedAttendance({
        state: 'recorded',
        event_id: 'event-id',
        recorded_at: '2026-10-05T00:00:00Z',
      }),
    ).toBe(true);
  });
});
