# Architecture Decisions

## ADR-001 — New repository uses the proposed monorepo baseline

- Date: 2026-10-04
- Status: Accepted for P00
- Decision: Use pnpm workspaces with `apps/web`, `apps/mobile`, shared packages and `supabase/`.
- Reason: The repository had no existing stack, and the product specification explicitly defines this
  structure for a new repository.

## ADR-002 — P00 stops before business features

- Date: 2026-10-04
- Status: Accepted for P00
- Decision: Only bootstrap/status UI is included in this phase; task, attendance, daily recurrence,
  report and dashboard behavior remain out of scope.
- Reason: The implementation plan requires one phase per session and prohibits fake feature screens.

## ADR-003 — Supabase local verification is an external setup gate

- Date: 2026-10-04
- Status: Open blocker
- Decision: Keep the Supabase config/migration skeleton in the repository, but do not claim local DB
  readiness while Docker and Supabase CLI are unavailable.
- Reason: A missing local runtime cannot be replaced with a mock or a false PASS.

## ADR-004 — Keep workspace dependency hoisting disabled

- Date: 2026-10-04
- Status: Accepted for P00
- Decision: Set `hoist=false` in `.npmrc` and align web/mobile React versions at `19.0.0`.
- Reason: Expo SDK 53 and Next.js must resolve one exact React/ReactDOM pair, while ESLint must
  resolve its own AJV 6 dependency. Isolated workspace links make clean installs deterministic.

## ADR-005 — Share design tokens between web and mobile

- Date: 2026-10-04
- Status: Accepted for P02
- Decision: Keep the canonical color, spacing, typography, control and layout values in
  `@opsdesk/design-tokens`; web maps them into CSS variables and mobile imports them directly.
- Reason: The supplied UX specification requires one design system across platforms. A shared token
  package prevents web/mobile color, density and touch-target drift while retaining platform-native
  presentation code.

## ADR-006 — Validate Expo through Metro bundles for all target platforms

- Date: 2026-10-04
- Status: Accepted for P02
- Decision: `pnpm build:mobile` exports Metro bundles for web, iOS and Android. The mobile app keeps
  direct runtime dependencies required by Expo Router and SDK 53, including the compatible native
  navigation peers and `query-string@7.1.3`.
- Reason: Web-only export can conceal native module resolution failures. The all-platform export is a
  reproducible pre-device validation, while not being represented as a substitute for emulator/device QA.

