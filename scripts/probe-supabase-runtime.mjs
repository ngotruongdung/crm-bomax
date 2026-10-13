import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';

const requireFromWeb = createRequire(resolve(process.cwd(), 'apps/web/package.json'));
const { createClient } = requireFromWeb('@supabase/supabase-js');

const envPath = resolve(process.cwd(), '.env.local');
if (existsSync(envPath)) process.loadEnvFile(envPath);

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceRoleKey) {
  console.error('SUPABASE_RUNTIME_PROBE_CONFIGURATION_REQUIRED');
  process.exitCode = 1;
} else {
  const client = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const tables = [
    'organizations',
    'sellers',
    'tasks',
    'recurring_task_templates',
    'employee_requests',
    'attendance_challenges',
    'timesheet_periods',
    'notifications',
    'report_runs',
    'files',
    'export_jobs',
  ];
  const results = await Promise.all(
    tables.map(async (table) => {
      const { error } = await client
        .from(table)
        .select('id', { head: true, count: 'exact' })
        .limit(1);
      return { table, ok: !error };
    }),
  );
  const { data: buckets, error: bucketsError } = await client.storage.listBuckets();
  const bucketIds = new Set((buckets ?? []).map((bucket) => bucket.id));
  const expectedBuckets = ['attendance-evidence', 'exports'];
  const missingTables = results.filter((result) => !result.ok).map((result) => result.table);
  const missingBuckets = bucketsError
    ? expectedBuckets
    : expectedBuckets.filter((bucket) => !bucketIds.has(bucket));

  console.log(`Schema P01-P10: ${missingTables.length === 0 ? 'PASS' : 'INCOMPLETE'}`);
  console.log(`Private Storage: ${missingBuckets.length === 0 ? 'PASS' : 'INCOMPLETE'}`);
  if (missingTables.length > 0) {
    console.log(`Missing or inaccessible tables: ${missingTables.join(', ')}`);
  }
  if (missingBuckets.length > 0) {
    console.log(`Missing or inaccessible buckets: ${missingBuckets.join(', ')}`);
  }

  if (missingTables.length > 0 || missingBuckets.length > 0) process.exitCode = 1;
}
