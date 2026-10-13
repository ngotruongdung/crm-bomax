import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const supportedPlatforms = new Set(['all', 'android', 'ios', 'web']);
const platform = process.argv[2] ?? 'all';

if (!supportedPlatforms.has(platform)) {
  console.error(`Unsupported Expo export platform: ${platform}`);
  process.exitCode = 1;
} else {
  const expoCommand = process.platform === 'win32' ? 'expo.cmd' : 'expo';
  const result = spawnSync(expoCommand, ['export', '--platform', platform], {
    stdio: 'inherit',
    shell: process.platform === 'win32',
    env: {
      ...process.env,
      CI: '1',
      EXPO_NO_TELEMETRY: '1',
      EXPO_HOME: resolve(process.cwd(), '.expo'),
    },
  });

  if (result.error) {
    console.error(`Không thể bundle mobile bằng Expo: ${result.error.message}`);
  }

  process.exitCode = result.status ?? 1;
}
