import { defineConfig } from '@playwright/test';

const e2ePort = 3101;

export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: `http://127.0.0.1:${e2ePort}`,
  },
  webServer: {
    command: `pnpm dev --hostname 127.0.0.1 --port ${e2ePort}`,
    env: {
      NEXT_PUBLIC_DEMO_MODE: 'true',
      NEXT_PUBLIC_SUPABASE_ANON_KEY: '',
      NEXT_PUBLIC_SUPABASE_URL: '',
    },
    url: `http://127.0.0.1:${e2ePort}`,
    reuseExistingServer: false,
  },
});
