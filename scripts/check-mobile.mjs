import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const mobileRequire = createRequire(resolve(process.cwd(), 'package.json'));
const requiredRuntimeDependencies = [
  '@opsdesk/design-tokens',
  'react-dom',
  'react-native-web',
  'query-string',
  'react-native-safe-area-context',
  'react-native-screens',
];
const missingRuntimeDependencies = requiredRuntimeDependencies.filter((dependency) => {
  try {
    mobileRequire.resolve(
      dependency.startsWith('@opsdesk/') ? dependency : `${dependency}/package.json`,
    );
    return false;
  } catch {
    return true;
  }
});

if (missingRuntimeDependencies.length > 0) {
  console.error(
    `Mobile runtime dependencies are missing: ${missingRuntimeDependencies.join(', ')}. Run pnpm install.`,
  );
  process.exitCode = 1;
} else {
  console.log(`Mobile runtime dependencies resolved: ${requiredRuntimeDependencies.join(', ')}.`);
}

const expoCommand = process.platform === 'win32' ? 'expo.cmd' : 'expo';
const result = spawnSync(expoCommand, ['config', '--type', 'public'], {
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
  console.error(`Không thể chạy Expo CLI: ${result.error.message}`);
}

if (result.status !== 0) {
  process.exitCode = result.status ?? 1;
}
