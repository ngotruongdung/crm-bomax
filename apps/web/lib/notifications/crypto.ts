import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

function encryptionKey() {
  const raw = process.env.PUSH_TOKEN_ENCRYPTION_KEY?.trim() ?? '';
  const key = /^[0-9a-f]{64}$/i.test(raw) ? Buffer.from(raw, 'hex') : Buffer.from(raw, 'base64');
  if (key.length !== 32) throw new Error('PUSH_TOKEN_ENCRYPTION_KEY_INVALID');
  return key;
}

export function pushTokenHash(token: string) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

export function encryptPushToken(token: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', encryptionKey(), iv);
  const ciphertext = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [
    'v1',
    iv.toString('base64url'),
    tag.toString('base64url'),
    ciphertext.toString('base64url'),
  ].join('.');
}

export function decryptPushToken(value: string) {
  const [version, ivText, tagText, ciphertextText] = value.split('.');
  if (version !== 'v1' || !ivText || !tagText || !ciphertextText) {
    throw new Error('PUSH_TOKEN_CIPHERTEXT_INVALID');
  }
  const decipher = createDecipheriv(
    'aes-256-gcm',
    encryptionKey(),
    Buffer.from(ivText, 'base64url'),
  );
  decipher.setAuthTag(Buffer.from(tagText, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(ciphertextText, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}

export function automationSecretMatches(value: string | null) {
  const expected = process.env.AUTOMATION_SECRET?.trim() ?? '';
  if (!expected || !value) return false;
  const actualHash = createHash('sha256').update(value, 'utf8').digest();
  const expectedHash = createHash('sha256').update(expected, 'utf8').digest();
  return actualHash.equals(expectedHash);
}
