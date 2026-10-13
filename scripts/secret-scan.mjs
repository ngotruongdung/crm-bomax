import { readFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';

const trackedFiles = (() => {
  try {
    execFileSync('git', ['rev-parse', '--is-inside-work-tree'], { stdio: 'ignore' });
    return execFileSync('git', ['ls-files'], { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean);
  } catch {
    return [];
  }
})();

const files =
  trackedFiles.length > 0 ? trackedFiles : ['.env.example', 'package.json', 'README.md'];
const suspicious =
  /(-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|sk-[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|(?:SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ACCESS_TOKEN)\s*[=:]\s*["']?(?!replace-with|process\.env|\$\{)[^"'\s,}#]+)/i;
const findings = [];

for (const file of files) {
  try {
    const contents = await readFile(file, 'utf8');
    if (suspicious.test(contents) && !file.endsWith('.env.example')) {
      findings.push(file);
    }
  } catch {
    // Ignore files that disappear between git listing and scan.
  }
}

if (findings.length > 0) {
  console.error(`Secret scan phát hiện pattern cần kiểm tra: ${findings.join(', ')}`);
  process.exitCode = 1;
} else {
  console.log('Secret scan cơ bản: PASS (không phát hiện secret pattern trong file được quét).');
}
