import type { OfficeWifiModule, WifiReadResult } from '@opsdesk/contracts';
import { wifiReadResultSchema } from '@opsdesk/contracts';
import { Platform } from 'react-native';

type NativeModuleLoader = () => OfficeWifiModule;

function unavailable(message: string): WifiReadResult {
  return { status: 'unavailable', message };
}

export async function readCurrentOfficeWifi(
  loadModule: NativeModuleLoader,
): Promise<WifiReadResult> {
  try {
    const result = await loadModule().getCurrentNetwork();
    const parsed = wifiReadResultSchema.safeParse(result);
    return parsed.success
      ? parsed.data
      : unavailable('Native Wi-Fi module trả dữ liệu không hợp lệ.');
  } catch {
    return unavailable('Native Wi-Fi module chưa có trong development/production build hiện tại.');
  }
}

export async function openOfficeWifiPermissionSettings(loadModule: NativeModuleLoader) {
  try {
    await loadModule().openPermissionSettings();
  } catch {
    // Fail closed. The calling screen keeps attendance disabled and can show manual guidance.
  }
}

async function loadBundledModule(): Promise<OfficeWifiModule> {
  if (Platform.OS === 'web') {
    throw new Error('NATIVE_WIFI_UNAVAILABLE_ON_WEB');
  }
  const module = await import('../../modules/office-wifi');
  return module.default;
}

export async function readCurrentOfficeWifiNative(): Promise<WifiReadResult> {
  try {
    const module = await loadBundledModule();
    return readCurrentOfficeWifi(() => module);
  } catch {
    return unavailable('Native Wi-Fi module chưa sẵn sàng trên build hiện tại.');
  }
}

export async function openOfficeWifiPermissionSettingsNative() {
  try {
    const module = await loadBundledModule();
    await openOfficeWifiPermissionSettings(() => module);
  } catch {
    // Keep fail-closed behavior on unsupported builds.
  }
}
