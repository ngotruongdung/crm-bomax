import { execFile } from 'node:child_process';
import { copyFile, mkdtemp, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { promisify } from 'node:util';

const root = resolve(import.meta.dirname, '..');
const targetPath = resolve(root, 'packages/api-client/src/database.types.ts');
const execFileAsync = promisify(execFile);

async function runSupabase() {
  try {
    const { stdout } = await execFileAsync('supabase', ['gen', 'types', 'typescript', '--local'], {
      cwd: root,
      maxBuffer: 10 * 1024 * 1024,
      windowsHide: true,
    });

    return stdout;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    const stderr =
      typeof error === 'object' && error !== null && 'stderr' in error ? String(error.stderr) : '';
    throw new Error([message, stderr].filter(Boolean).join('\n'));
  }
}

const temporaryDirectory = await mkdtemp(join(tmpdir(), 'opsdesk-db-types-'));
const temporaryPath = join(temporaryDirectory, 'database.types.ts');

try {
  const generated = await runSupabase();

  if (!generated.includes('export type Database') || generated.trim().length === 0) {
    throw new Error('Supabase returned an empty or invalid database type snapshot.');
  }

  await writeFile(temporaryPath, generated, 'utf8');
  await copyFile(temporaryPath, targetPath);
  console.log(`Database types written to ${targetPath}`);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Database types were not changed: ${message}`);
  process.exitCode = 1;
} finally {
  await rm(temporaryDirectory, { force: true, recursive: true });
}
