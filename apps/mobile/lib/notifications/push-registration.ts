import { pushRegistrationResponseSchema } from '@opsdesk/contracts';
import * as Notifications from 'expo-notifications';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';
import { registerAttendanceDevice } from '../attendance/attendance-api';
import { createSupabaseMobileClient } from '../supabase';

const PUSH_DEVICE_KEY = 'opsdesk.notifications.device-id';

function apiBaseUrl() {
  const value = process.env.EXPO_PUBLIC_OPSDESK_WEB_URL?.replace(/\/$/, '');
  if (!value) throw new Error('NOTIFICATION_API_NOT_CONFIGURED');
  return value;
}

async function accessToken() {
  const client = createSupabaseMobileClient();
  const { data, error } = await client.auth.getSession();
  if (error || !data.session?.access_token) throw new Error('MOBILE_AUTHENTICATION_REQUIRED');
  return data.session.access_token;
}

async function notificationFetch(path: string, init?: RequestInit) {
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
  if (!response.ok || !payload?.ok) {
    throw new Error(payload?.error?.code ?? 'NOTIFICATION_API_FAILED');
  }
  return payload.data;
}

export type PushRegistrationOutcome =
  | { status: 'registered'; deviceId: string }
  | { status: 'skipped'; reason: 'unsupported_platform' | 'permission_denied' }
  | { status: 'unavailable'; reason: string };

export async function registerMobilePush(organizationId: string): Promise<PushRegistrationOutcome> {
  if (Platform.OS !== 'ios' && Platform.OS !== 'android') {
    return { status: 'skipped', reason: 'unsupported_platform' };
  }

  try {
    const platform = Platform.OS;
    const device = await registerAttendanceDevice(organizationId, platform);
    await SecureStore.setItemAsync(PUSH_DEVICE_KEY, device.device_id);

    if (platform === 'android') {
      await Notifications.setNotificationChannelAsync('default', {
        name: 'OpsDesk',
        importance: Notifications.AndroidImportance.DEFAULT,
      });
    }

    const current = await Notifications.getPermissionsAsync();
    const permission =
      current.status === 'granted' ? current : await Notifications.requestPermissionsAsync();
    if (permission.status !== 'granted') {
      return { status: 'skipped', reason: 'permission_denied' };
    }

    const projectId = process.env.EXPO_PUBLIC_EAS_PROJECT_ID?.trim();
    if (!projectId) return { status: 'unavailable', reason: 'EAS_PROJECT_ID_NOT_CONFIGURED' };

    const tokenResult = await Notifications.getExpoPushTokenAsync({ projectId });
    const data = await jsonData(
      await notificationFetch('/api/notifications/register-push', {
        method: 'POST',
        body: JSON.stringify({
          organization_id: organizationId,
          device_id: device.device_id,
          provider: 'expo',
          token: tokenResult.data,
        }),
      }),
    );
    const parsed = pushRegistrationResponseSchema.safeParse(data);
    if (!parsed.success) throw new Error('PUSH_REGISTRATION_CONTRACT_INVALID');

    return { status: 'registered', deviceId: device.device_id };
  } catch (error) {
    return {
      status: 'unavailable',
      reason: error instanceof Error ? error.message : 'PUSH_REGISTRATION_FAILED',
    };
  }
}

export async function revokeCurrentMobileDevice() {
  const deviceId = await SecureStore.getItemAsync(PUSH_DEVICE_KEY);
  if (!deviceId) return;

  const client = createSupabaseMobileClient();
  const { error } = await client.rpc('rpc_revoke_device', { p_device_id: deviceId });
  if (error) throw new Error('DEVICE_REVOKE_FAILED');
  await SecureStore.deleteItemAsync(PUSH_DEVICE_KEY);
}
