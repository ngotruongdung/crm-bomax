import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

function source(relativePath: string) {
  return readFileSync(fileURLToPath(new URL(relativePath, import.meta.url)), 'utf8');
}

describe('P11 browser source guards', () => {
  it('UI-07 provides a real route loading surface', () => {
    const loading = source('../app/loading.tsx');

    expect(loading).toContain('aria-busy="true"');
    expect(loading).toContain('<Skeleton count={3} />');
  });

  it('UI-09 reserves mobile safe-area space for fixed navigation and drawer actions', () => {
    const css = source('../app/globals.css');

    expect(css).toContain('env(safe-area-inset-bottom)');
    expect(css).toMatch(/\.workspace-mobile-nav[\s\S]*safe-area-inset-bottom/);
    expect(css).toMatch(/\.ui-drawer \.ui-dialog-footer[\s\S]*safe-area-inset-bottom/);
  });

  it('UI-11 performs a full history-replacing logout and keeps workspace data out of browser caches', () => {
    const signOut = source('../app/sign-out-button.tsx');
    const workspace = source('../app/workspace-shell.tsx');

    expect(signOut).toContain("window.location.replace('/login')");
    expect(`${signOut}\n${workspace}`).not.toMatch(
      /localStorage|sessionStorage|indexedDB|QueryClient|SWR/,
    );
  });

  it('production response config includes baseline browser security headers', () => {
    const config = source('../next.config.ts');

    expect(config).toContain('X-Content-Type-Options');
    expect(config).toContain('X-Frame-Options');
    expect(config).toContain('Content-Security-Policy');
    expect(config).toContain('Strict-Transport-Security');
  });
});
