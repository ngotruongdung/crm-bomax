import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = process.cwd();
const migrationsDirectory = resolve(root, 'supabase', 'migrations');
const manualDirectory = resolve(root, 'supabase', 'manual');
const schemaOutput = resolve(manualDirectory, 'OPSDesk_Supabase_Schema.sql');
const demoOutput = resolve(manualDirectory, 'OPSDesk_Supabase_Demo_Data.sql');
const attendanceSettingsPatchOutput = resolve(
  manualDirectory,
  'OPSDesk_P12_Attendance_Admin_Settings.sql',
);

function read(relativePath) {
  return readFileSync(resolve(root, relativePath), 'utf8').trim();
}

function heading(title) {
  return `\n-- ============================================================================\n-- ${title}\n-- ============================================================================\n`;
}

const migrationFiles = readdirSync(migrationsDirectory)
  .filter((file) => file.endsWith('.sql'))
  .sort();

const schemaSql = [
  '-- GENERATED FILE. DO NOT EDIT BY HAND.',
  '-- Source: supabase/migrations/*.sql',
  '-- Generate again with: pnpm build:supabase:dashboard-sql',
  '--',
  '-- Run once only in Supabase Dashboard > SQL Editor on a new, empty project.',
  '-- Do not use this file for a project that already has any OPSDesk migration applied.',
  ...migrationFiles.flatMap((file) => [
    heading(`BEGIN ${file}`),
    read(`supabase/migrations/${file}`),
    heading(`END ${file}`),
  ]),
].join('\n');

const demoSql = [
  '-- GENERATED FILE. DO NOT EDIT BY HAND.',
  '-- Sources: supabase/demo/seed_dashboard_bomax.sql, supabase/demo/seed_p03c_demo.sql',
  '-- Generate again with: pnpm build:supabase:dashboard-sql',
  '--',
  '-- Run after OPSDesk_Supabase_Schema.sql and after creating the four demo Auth users.',
  heading('BEGIN dashboard demo organization, members and sellers'),
  read('supabase/demo/seed_dashboard_bomax.sql'),
  heading('END dashboard demo organization, members and sellers'),
  heading('BEGIN P03C task/checklist/history demo data'),
  read('supabase/demo/seed_p03c_demo.sql'),
  heading('END P03C task/checklist/history demo data'),
].join('\n');

mkdirSync(manualDirectory, { recursive: true });
writeFileSync(schemaOutput, `${schemaSql}\n`, 'utf8');
writeFileSync(demoOutput, `${demoSql}\n`, 'utf8');
writeFileSync(
  attendanceSettingsPatchOutput,
  [
    '-- GENERATED FILE. DO NOT EDIT BY HAND.',
    '-- Source: supabase/migrations/00000000000014_p12_attendance_admin_settings.sql',
    '--',
    '-- Run once in Supabase Dashboard > SQL Editor on an existing OPSDesk P00-P11 project.',
    '-- It adds the admin-configurable attendance policy and changes remote attendance to',
    '-- require a fresh uploaded photo rather than a laptop hand-off code.',
    read('supabase/migrations/00000000000014_p12_attendance_admin_settings.sql'),
    '',
  ].join('\n'),
  'utf8',
);

console.log(`Created ${schemaOutput}`);
console.log(`Created ${demoOutput}`);
console.log(`Created ${attendanceSettingsPatchOutput}`);
