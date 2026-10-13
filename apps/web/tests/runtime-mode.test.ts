import { describe, expect, it } from 'vitest';
import { demoWorkspaceAllowed, workspaceDataSourceFor } from '../lib/demo/opsdesk-demo';

describe('P11 runtime mode guard', () => {
  it('never enables demo workspace in production even when explicitly requested', () => {
    expect(demoWorkspaceAllowed({ nodeEnv: 'production', demoMode: 'true' })).toBe(false);
    expect(() =>
      workspaceDataSourceFor({
        supabaseConfigured: false,
        nodeEnv: 'production',
        demoMode: 'true',
      }),
    ).toThrow(/Supabase public environment/);
  });

  it('keeps local demo available by default and allows it to be explicitly disabled', () => {
    expect(demoWorkspaceAllowed({ nodeEnv: 'development' })).toBe(true);
    expect(workspaceDataSourceFor({ supabaseConfigured: false, nodeEnv: 'development' })).toBe(
      'demo',
    );
    expect(demoWorkspaceAllowed({ nodeEnv: 'development', demoMode: 'false' })).toBe(false);
  });

  it('always prefers configured Supabase over demo mode', () => {
    expect(
      workspaceDataSourceFor({
        supabaseConfigured: true,
        nodeEnv: 'development',
        demoMode: 'true',
      }),
    ).toBe('supabase');
  });
});
