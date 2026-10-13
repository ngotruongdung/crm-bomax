import {
  attendanceChallengeResponseSchema,
  attendanceCommitSchema,
  attendanceDaySchema,
  attendanceDeviceRegistrationResponseSchema,
  attendanceUploadIntentResponseSchema,
  remoteLaptopSessionResolveResponseSchema,
  type AttendanceAction,
  type AttendanceDay,
  type AttendanceMode,
  type WifiReadResult,
} from '@opsdesk/contracts';
import * as SecureStore from 'expo-secure-store';
import { createSupabaseMobileClient } from '../supabase';

const INSTALLATION_KEY = 'opsdesk.attendance.installation-id';

function apiBaseUrl() {
  const value = process.env.EXPO_PUBLIC_OPSDESK_WEB_URL?.replace(/\/$/, '');
  if (!value) throw new Error('ATTENDANCE_API_NOT_CONFIGURED');
  return value;
}

async function accessToken() {
  const client = createSupabaseMobileClient();
  const { data, error } = await client.auth.getSession();
  if (error || !data.session?.access_token) throw new Error('MOBILE_AUTHENTICATION_REQUIRED');
  return data.session.access_token;
}

async function attendanceFetch(path: string, init?: RequestInit) {
  const token = await accessToken();
  return fetch(`${apiBaseUrl()}${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${token}`,
      'content-type': 'application/json',
      ...init?.headers,
    },
  });
}

async function jsonData(response: Response) {
  const payload = (await response.json().catch(() => null)) as {
    ok?: boolean;
    data?: unknown;
    error?: { code?: string };
  } | null;
  if (!response.ok || !payload?.ok)
    throw new Error(payload?.error?.code ?? 'ATTENDANCE_API_FAILED');
  return payload.data;
}

function makeOpaqueId(prefix: string) {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 14)}`;
}

export async function getOrCreateAttendanceInstallationId() {
  const existing = await SecureStore.getItemAsync(INSTALLATION_KEY);
  if (existing) return existing;
  const next = makeOpaqueId('install');
  await SecureStore.setItemAsync(INSTALLATION_KEY, next);
  return next;
}

export async function registerAttendanceDevice(
  organizationId: string,
  platform: 'ios' | 'android',
) {
  const installationId = await getOrCreateAttendanceInstallationId();
  const data = await jsonData(
    await attendanceFetch('/api/attendance/device', {
      method: 'POST',
      body: JSON.stringify({
        organization_id: organizationId,
        installation_id: installationId,
        platform,
        label: 'OpsDesk mobile',
      }),
    }),
  );
  const parsed = attendanceDeviceRegistrationResponseSchema.safeParse(data);
  if (!parsed.success) throw new Error('DEVICE_CONTRACT_INVALID');
  return parsed.data;
}

export async function loadAttendanceDay(
  organizationId: string,
  workDate: string,
): Promise<AttendanceDay> {
  const query = new URLSearchParams({ organization_id: organizationId, work_date: workDate });
  const data = await jsonData(await attendanceFetch(`/api/attendance/day?${query.toString()}`));
  const parsed = attendanceDaySchema.safeParse(data);
  if (!parsed.success) throw new Error('ATTENDANCE_DAY_CONTRACT_INVALID');
  return parsed.data;
}

export async function createAttendanceChallenge(input: {
  organizationId: string;
  shiftInstanceId: string;
  action: AttendanceAction;
  mode: AttendanceMode;
  deviceId: string;
}) {
  const data = await jsonData(
    await attendanceFetch('/api/attendance/challenge', {
      method: 'POST',
      body: JSON.stringify({
        organization_id: input.organizationId,
        shift_instance_id: input.shiftInstanceId,
        action: input.action,
        mode: input.mode,
        device_id: input.deviceId,
      }),
    }),
  );
  const parsed = attendanceChallengeResponseSchema.safeParse(data);
  if (!parsed.success) throw new Error('ATTENDANCE_CHALLENGE_CONTRACT_INVALID');
  return parsed.data;
}

export async function finalizeOfficeAttendance(input: {
  challengeId: string;
  nonce: string;
  deviceId: string;
  wifi: Extract<WifiReadResult, { status: 'available' }>;
}) {
  const data = await jsonData(
    await attendanceFetch('/api/attendance/finalize', {
      method: 'POST',
      body: JSON.stringify({
        challenge_id: input.challengeId,
        nonce: input.nonce,
        device_id: input.deviceId,
        idempotency_key: makeOpaqueId('attendance'),
        wifi_claim: {
          ssid: input.wifi.ssid,
          bssid: input.wifi.bssid,
          captured_at_device: input.wifi.capturedAtDevice,
        },
      }),
    }),
  );
  const parsed = attendanceCommitSchema.safeParse(data);
  if (!parsed.success) throw new Error('ATTENDANCE_COMMIT_CONTRACT_INVALID');
  return parsed.data;
}

export async function resolveRemoteLaptopSession(input: {
  organizationId: string;
  shiftInstanceId: string;
  displayCode: string;
}) {
  const data = await jsonData(
    await attendanceFetch('/api/attendance/laptop-session/resolve', {
      method: 'POST',
      body: JSON.stringify({
        organization_id: input.organizationId,
        shift_instance_id: input.shiftInstanceId,
        display_code: input.displayCode,
      }),
    }),
  );
  const parsed = remoteLaptopSessionResolveResponseSchema.safeParse(data);
  if (!parsed.success) throw new Error('LAPTOP_SESSION_CONTRACT_INVALID');
  return parsed.data;
}

export async function createAttendanceUploadIntent(input: {
  challengeId: string;
  mimeType: 'image/jpeg' | 'image/webp';
  sizeBytes: number;
}) {
  const data = await jsonData(
    await attendanceFetch('/api/attendance/upload-intent', {
      method: 'POST',
      body: JSON.stringify({
        challenge_id: input.challengeId,
        mime_type: input.mimeType,
        size_bytes: input.sizeBytes,
      }),
    }),
  );
  const parsed = attendanceUploadIntentResponseSchema.safeParse(data);
  if (!parsed.success) throw new Error('UPLOAD_INTENT_CONTRACT_INVALID');
  return parsed.data;
}

export async function finalizeRemoteAttendance(input: {
  challengeId: string;
  nonce: string;
  deviceId: string;
  fileId: string;
}) {
  const data = await jsonData(
    await attendanceFetch('/api/attendance/finalize', {
      method: 'POST',
      body: JSON.stringify({
        challenge_id: input.challengeId,
        nonce: input.nonce,
        device_id: input.deviceId,
        idempotency_key: makeOpaqueId('attendance-remote'),
        file_id: input.fileId,
      }),
    }),
  );
  const parsed = attendanceCommitSchema.safeParse(data);
  if (!parsed.success) throw new Error('ATTENDANCE_COMMIT_CONTRACT_INVALID');
  return parsed.data;
}
