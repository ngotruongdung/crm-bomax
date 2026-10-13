import { existsSync } from 'node:fs';
import { resolve } from 'node:path';

const localEnvPath = resolve(process.cwd(), '.env.local');
if (existsSync(localEnvPath)) {
  process.loadEnvFile(localEnvPath);
}

const isStrict = process.argv.includes('--strict');
const requiresInvitationService = process.argv.includes('--require-invitation-service');
const isProductionPreflight = process.argv.includes('--production');
const shouldFail = isStrict || isProductionPreflight || process.env.NODE_ENV === 'production';

const publicVariables = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY',
  'EXPO_PUBLIC_SUPABASE_URL',
  'EXPO_PUBLIC_SUPABASE_ANON_KEY',
];
const optionalPublicVariables = ['EXPO_PUBLIC_OPSDESK_WEB_URL'];
const optionalServer = ['SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_ACCESS_TOKEN'];
const missing = publicVariables.filter((name) => !process.env[name]);
const errors = [];

function isPlaceholder(value) {
  return /replace-with|your-project-ref|placeholder|example/i.test(value);
}

function parseHttpUrl(name, value) {
  try {
    const url = new URL(value);
    if (!['http:', 'https:'].includes(url.protocol)) {
      errors.push(`${name} phải dùng URL http hoặc https.`);
      return null;
    }
    return url;
  } catch {
    errors.push(`${name} không phải URL hợp lệ.`);
    return null;
  }
}

function isValidPushEncryptionKey(value) {
  if (/^[0-9a-f]{64}$/i.test(value)) return true;
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return false;
  try {
    return Buffer.from(value, 'base64').length === 32;
  } catch {
    return false;
  }
}

if (missing.length > 0) {
  const message = `Thiếu public Supabase environment: ${missing.join(', ')}`;
  if (isStrict) {
    errors.push(message);
  } else {
    console.log(`Environment chưa cấu hình (chấp nhận ở P00): ${missing.join(', ')}`);
    console.log('Copy .env.example thành .env.local khi bắt đầu tích hợp Supabase.');
  }
}

for (const name of publicVariables) {
  const value = process.env[name];
  if (!value) continue;

  if (isPlaceholder(value)) {
    errors.push(`${name} vẫn dùng giá trị placeholder.`);
  }

  if (name.endsWith('_URL')) {
    parseHttpUrl(name, value);
  }

  if (name.endsWith('_ANON_KEY') && /service_role|sb_secret_/i.test(value)) {
    errors.push(`${name} không được chứa service-role hoặc secret key.`);
  }
}

for (const name of optionalPublicVariables) {
  const value = process.env[name];
  if (!value) continue;
  parseHttpUrl(name, value);
}

const appUrlValue = process.env.NEXT_PUBLIC_APP_URL?.trim();
const appUrl = appUrlValue ? parseHttpUrl('NEXT_PUBLIC_APP_URL', appUrlValue) : null;
if (isProductionPreflight && !appUrlValue) {
  errors.push('Thiếu NEXT_PUBLIC_APP_URL cho production deployment.');
}
if (isProductionPreflight && appUrl) {
  if (appUrl.protocol !== 'https:') {
    errors.push('NEXT_PUBLIC_APP_URL production phải dùng HTTPS.');
  }
  if (['localhost', '127.0.0.1', '::1'].includes(appUrl.hostname)) {
    errors.push('NEXT_PUBLIC_APP_URL production không được trỏ localhost.');
  }
}

const demoMode = process.env.NEXT_PUBLIC_DEMO_MODE?.trim().toLowerCase();
if (demoMode && !['true', 'false', '1', '0', 'on', 'off', 'yes', 'no'].includes(demoMode)) {
  errors.push('NEXT_PUBLIC_DEMO_MODE chỉ nhận true/false, 1/0, on/off hoặc yes/no.');
}
if (isProductionPreflight && !['false', '0', 'off', 'no'].includes(demoMode ?? '')) {
  errors.push('Production bắt buộc NEXT_PUBLIC_DEMO_MODE=false.');
}

const webUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const mobileUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
if (webUrl && mobileUrl && webUrl !== mobileUrl) {
  errors.push(
    'NEXT_PUBLIC_SUPABASE_URL và EXPO_PUBLIC_SUPABASE_URL phải trỏ cùng một Supabase project.',
  );
}

const presentServerSecrets = optionalServer.filter((name) => Boolean(process.env[name]));
if (presentServerSecrets.length > 0) {
  console.log(`Server-only variables đang có trong process: ${presentServerSecrets.join(', ')}`);
}

const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (requiresInvitationService && !serviceRoleKey) {
  errors.push('Thiếu SUPABASE_SERVICE_ROLE_KEY cho server invitation delivery.');
}
if (serviceRoleKey && isPlaceholder(serviceRoleKey)) {
  errors.push('SUPABASE_SERVICE_ROLE_KEY vẫn dùng giá trị placeholder.');
}
if (
  serviceRoleKey &&
  (serviceRoleKey === process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    serviceRoleKey === process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY)
) {
  errors.push('SUPABASE_SERVICE_ROLE_KEY không được trùng public anon key.');
}

if (isProductionPreflight && !serviceRoleKey) {
  errors.push('Thiếu SUPABASE_SERVICE_ROLE_KEY cho production workers/server operations.');
}

const automationSecret = process.env.AUTOMATION_SECRET?.trim();
if (isProductionPreflight && !automationSecret) {
  errors.push('Thiếu AUTOMATION_SECRET cho production automation endpoints.');
} else if (automationSecret) {
  if (isPlaceholder(automationSecret)) {
    errors.push('AUTOMATION_SECRET vẫn dùng giá trị placeholder.');
  }
  if (automationSecret.length < 32) {
    errors.push('AUTOMATION_SECRET phải có tối thiểu 32 ký tự.');
  }
}

const pushEncryptionKey = process.env.PUSH_TOKEN_ENCRYPTION_KEY?.trim();
if (isProductionPreflight && !pushEncryptionKey) {
  errors.push('Thiếu PUSH_TOKEN_ENCRYPTION_KEY cho production push token storage.');
} else if (pushEncryptionKey) {
  if (isPlaceholder(pushEncryptionKey)) {
    errors.push('PUSH_TOKEN_ENCRYPTION_KEY vẫn dùng giá trị placeholder.');
  } else if (!isValidPushEncryptionKey(pushEncryptionKey)) {
    errors.push('PUSH_TOKEN_ENCRYPTION_KEY phải giải mã đúng 32 bytes (hex hoặc base64).');
  }
}

const trustedIngress = process.env.ATTENDANCE_TRUSTED_INGRESS?.trim().toLowerCase();
if (trustedIngress && !['none', 'vercel', 'cloudflare'].includes(trustedIngress)) {
  errors.push('ATTENDANCE_TRUSTED_INGRESS chỉ nhận none, vercel hoặc cloudflare.');
}
if (isProductionPreflight && (!trustedIngress || trustedIngress === 'none')) {
  errors.push('Production attendance bắt buộc cấu hình trusted ingress (vercel hoặc cloudflare).');
}

if (errors.length > 0) {
  console.error(errors.join('\n'));
  process.exitCode = shouldFail ? 1 : 0;
} else if (missing.length === 0) {
  console.log(
    isProductionPreflight
      ? 'Production environment đã qua deployment preflight.'
      : isStrict
        ? 'Deployment environment web/mobile Supabase đã qua preflight nghiêm ngặt.'
        : 'Browser/mobile Supabase environment đã có đủ.',
  );
}
