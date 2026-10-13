const localAliases = new Set(['localhost', '127.0.0.1', '::1']);

export function canonicalAppUrl(value = process.env.NEXT_PUBLIC_APP_URL) {
  if (!value) return null;

  try {
    const parsed = new URL(value);
    if (!['http:', 'https:'].includes(parsed.protocol)) return null;
    return parsed;
  } catch {
    return null;
  }
}

export function canonicalizeLocalUrl(requestUrl: string, appUrl = canonicalAppUrl()) {
  if (!appUrl) return null;

  const request = new URL(requestUrl);
  if (!localAliases.has(request.hostname) || !localAliases.has(appUrl.hostname)) return null;

  const requestPort = request.port || (request.protocol === 'https:' ? '443' : '80');
  const appPort = appUrl.port || (appUrl.protocol === 'https:' ? '443' : '80');
  const alreadyCanonical =
    request.protocol === appUrl.protocol &&
    request.hostname === appUrl.hostname &&
    requestPort === appPort;

  if (alreadyCanonical) return null;

  request.protocol = appUrl.protocol;
  request.hostname = appUrl.hostname;
  request.port = appUrl.port;
  return request;
}
