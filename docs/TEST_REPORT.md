# Test Report

## FE-R5 — Task Board and Calendar redesign

| Check | Result | Evidence |
| --- | --- | --- |
| URL projection compatibility | PASS | Legacy `view=review` links still load as the saved-review filter; new URLs reserve `view` for `list`, `board` and `calendar`. |
| Task view state | PASS | `saved`, view, group, sort and calendar month parse/serialize tests are covered in `apps/web/tests/task-projections.test.ts`. |
| Web typecheck | PASS | `pnpm --filter @opsdesk/web typecheck` |
| Web unit tests | PASS | `pnpm --filter @opsdesk/web test` — 79 tests passed. |
| Formatting | PASS | `pnpm format:check` |

Browser and physical-device visual QA remain part of the later FE-R10/FE-R11 validation pass.

## FE-R6 — Today and Action Inbox redesign

| Check | Result | Evidence |
| --- | --- | --- |
| Today task scope | PASS | Existing `groupTodayTasks` projection remains the sole source for Today; FE-R6 only reorders visual sections and adds navigation shortcuts. |
| Action-inbox projection | PASS | `notification-projections.test.ts` verifies that actionable task/HR/report rows remain while digest rows are excluded, and URL tabs are validated. |
| Web lint/typecheck/unit tests | PASS | `pnpm --filter @opsdesk/web lint`, `typecheck`, `test` — 21 files / 81 tests passed. |
| Formatting | PASS | `pnpm format:check` |
| Playwright responsive check | BLOCKED_SANDBOX | Chromium could not launch in this Windows sandbox (`browserType.launch: spawn EPERM`) before any test page loaded. The FE-R6 desktop/mobile cases are committed in `apps/web/e2e/p11-ui.spec.ts` for execution on a permitted runner. |

## P00 — Repo audit, bootstrap, CI and conventions

### Automated

| Check                        | Result                 | Evidence                                                                                                                 |
| ---------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| Node/pnpm availability       | PASS                   | Node `v22.19.0`, pnpm `11.19.0`                                                                                          |
| Docker availability          | BLOCKED_EXTERNAL_SETUP | `docker` not found on PATH                                                                                               |
| Supabase CLI availability    | BLOCKED_EXTERNAL_SETUP | `supabase` not found on PATH                                                                                             |
| Clean install                | PASS                   | `pnpm install` completed with pinned lockfile                                                                            |
| Lint                         | PASS                   | `pnpm lint`                                                                                                              |
| Typecheck                    | PASS                   | `pnpm typecheck`                                                                                                         |
| Unit test runner             | PASS                   | 13 tests passed via `pnpm test`                                                                                          |
| Web build                    | PASS                   | `pnpm build`, Next.js production build                                                                                   |
| Mobile bootstrap             | PASS                   | `pnpm check:mobile`, Expo SDK 53 config resolved                                                                         |
| Mobile cross-platform bundle | PASS                   | `pnpm build:mobile`, Expo/Metro exported web, iOS and Android bundles successfully                                       |
| Supabase local reset         | BLOCKED_EXTERNAL_SETUP | Requires Docker + Supabase CLI                                                                                           |
| Secret scan                  | PASS                   | `pnpm secret-scan`                                                                                                       |
| Strict environment preflight | PASS                   | `pnpm verify:env` passes with safe synthetic web/mobile local identifiers; production values remain unsupplied           |
| Format check                 | PASS                   | `pnpm format:check`                                                                                                      |
| Web E2E                      | PASS                   | `pnpm test:e2e`, 5 Playwright tests passed                                                                               |
| CI workflow                  | CONFIGURED             | `.github/workflows/ci.yml` runs baseline, mobile, static DB and browser checks; remote run pending repository connection |
| Full P00 baseline            | PASS                   | Lint, typecheck, unit, build, format and secret checks passed; DB runtime remains blocked                                |

### Manual checks

- [x] Repository identified as new.
- [x] Specification documents read as product/technical requirements.
- [x] `UI_REFERENCE.png` inspected for visual language.
- [x] `.env.example` contains names only and no real secret.
- [x] P00 does not add business feature mocks.

### Open failures/blockers

- Install Docker Desktop and Supabase CLI, then run `supabase start` and `pnpm test:db`.

## Final phase result

`BLOCKED_EXTERNAL_SETUP` until the local Supabase gate can be verified. This is not a project-complete claim.

## P01A — Supabase core schema, organization, membership and auth foundation

### Automated

| Check                                  | Result                 | Evidence                                                                           |
| -------------------------------------- | ---------------------- | ---------------------------------------------------------------------------------- |
| Static migration/seed contract checks  | PASS                   | `pnpm test:db:static`                                                              |
| P01A lint                              | PASS                   | `pnpm lint`                                                                        |
| P01A typecheck                         | PASS                   | `pnpm typecheck`                                                                   |
| P01A unit/domain checks                | PASS                   | `pnpm test`                                                                        |
| Web production build with auth helper  | PASS                   | `pnpm build`                                                                       |
| Web/auth/workspace E2E                 | PASS                   | 5 Playwright specs via `pnpm --filter @opsdesk/web run test:e2e`                   |
| Mobile Supabase auth and routing       | PASS                   | Mobile lint/typecheck and `pnpm check:mobile`; shared context guard routes by role |
| Local Auth demo seed preflight         | PASS                   | Static checker verifies local-only URL, env-only password and membership upsert    |
| Server auth helper contract tests      | PASS                   | Unauthenticated, active, inactive and invalid-context branches                     |
| Supabase reset and migration execution | BLOCKED_EXTERNAL_SETUP | `supabase` CLI is unavailable; Docker is unavailable                               |
| pgTAP RLS suite                        | BLOCKED_EXTERNAL_SETUP | Requires `supabase test db` against local Supabase                                 |
| CLI-generated database types           | BLOCKED_EXTERNAL_SETUP | `pnpm types:db` requires Supabase CLI/local database                               |
| Database type snapshot safety          | PASS                   | Missing-CLI `pnpm types:db` exits without truncating the compile-safe snapshot     |

### Required cases represented in the database suite

- AUTH-01 anonymous private-data access
- AUTH-02 direct employee membership mutation
- AUTH-03 inactive membership access
- AUTH-04 organization/membership tenant isolation foundation
- AUTH-11 metadata role must not elevate membership role
- AUTH-04 owner must be an active admin in the same organization
- AUTH-04 employee membership SELECT is self-only; admin roster access remains available
- AUTH-03 suspended organization access is denied even while membership/JWT remains present
- SEC-12 private helper grants and fixed search path
- SEC-14 migration-from-zero schema/RLS coverage, including private idempotency storage

P01A remains `IN_PROGRESS_UNVERIFIED`; no runtime DB/RLS PASS is claimed.

## P01B — Invite, role/capability and seller scope

### Automated

| Check                                  | Result                 | Evidence                                                                                                                                  |
| -------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Static migration/invitation contract   | PASS                   | `pnpm test:db:static` now checks P01A plus P01B schema, grants, RLS, invite server boundary and invite client RPC wiring.                 |
| Type/lint/unit/build                   | PASS                   | `pnpm typecheck`, `pnpm lint`, `pnpm test` (17 tests), `pnpm build`.                                                                      |
| Browser E2E                            | PASS                   | `pnpm test:e2e` — 5 Playwright specs passed; invitation URLs do not surface untrusted organization details.                               |
| Invitation primitive tests             | PASS                   | Token is high-entropy and hashed; Auth redirect passes through the PKCE callback; raw DB error details do not become client error codes.  |
| P01B pgTAP access suite                | BLOCKED_EXTERNAL_SETUP | Test file covers AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-09, AUTH-10, AUTH-12, SEC-12 and SEC-14; execution needs Supabase CLI + Docker. |
| Migration execution/generated DB types | BLOCKED_EXTERNAL_SETUP | Requires a local Supabase PostgreSQL runtime.                                                                                             |

### Scope boundary

- P01B static checks and application checks pass, but no SQL/RLS runtime PASS is claimed.
- `POST /api/admin/invitations` is intentionally unavailable until a real server-only service key is
  configured; it returns a configuration/delivery error rather than claiming an invite was sent.
- A failed delivery may leave an open database invitation but never grants app membership; retry replaces
  that invitation token. This must be exercised with actual Supabase Auth delivery during local verification.

## P03A — Seller and Team Management UI

### Automated

| Check                        | Result                 | Evidence                                                                                                             |
| ---------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Route build                  | PASS                   | Production build lists dynamic `/sellers` and `/team` routes.                                                        |
| Setup-state E2E              | PASS                   | `pnpm test:e2e` visits both routes without Supabase configuration and receives the explicit safe setup state.        |
| Type/lint/static DB contract | PASS                   | UI command arguments typecheck; database schema/RPC/grant static verifier passes.                                    |
| Permission/data command E2E  | BLOCKED_EXTERNAL_SETUP | Requires real Supabase Auth, database migrations and credentials to exercise owner/admin/manager/employee scenarios. |

### Scope boundary

- P03A does not fabricate seller or team records if no database is configured.
- UI visibility is not treated as authorization: each mutation goes through the P01B server/RPC boundary,
  which must still be verified at runtime.

## P03B — Task Core

### Automated

| Check                                         | Result                 | Evidence                                                                                                                                                                                                                                                             |
| --------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Static P03B migration/RPC contract            | PASS                   | `pnpm test:db:static` checks task core, hardening, reviewer policy and required task cases including TASK-21.                                                                                                                                                        |
| Task UI/unit policy suite                     | PASS                   | Web tests cover create validation preservation/focus, single-flight duplicate protection, malformed mutation responses, state/permission action visibility, in-review freezes, blocker semantics, submit gates, version conflict feedback and no-avatar regressions. |
| Task detail loader suite                      | PASS                   | Deep-link route id is fetched fresh; access denial and malformed payloads produce explicit errors rather than stale/empty success.                                                                                                                                   |
| Type/lint/build/format                        | PASS                   | `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`, `pnpm format:check`.                                                                                                                                                                                       |
| Task setup-state E2E                          | PASS                   | Playwright setup-state coverage includes `/tasks`, `/tasks/new` and a `/tasks/[id]` deep link when public Supabase configuration is absent.                                                                                                                          |
| Strict environment preflight with real values | BLOCKED_EXTERNAL_SETUP | `pnpm verify:env` reports missing `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_ANON_KEY`.                                                                                                          |
| Supabase runtime reset/types/pgTAP            | BLOCKED_EXTERNAL_SETUP | `docker` and `supabase` are not available on PATH in the current environment.                                                                                                                                                                                        |
| Authenticated task lifecycle E2E              | BLOCKED_EXTERNAL_SETUP | Requires the real Supabase runtime, migrations, Auth users and public project credentials.                                                                                                                                                                           |

### Scope boundary

- P03B static/unit/build/setup-state gates pass, but no SQL/RLS runtime PASS is claimed.
- Reviewer permissions, task state-machine transitions and optimistic version conflicts remain runtime-critical
  until the pgTAP/authenticated E2E suite executes against Supabase.
- P03B runtime gates remain required for final backend verification, but are intentionally deferred while P03C
  frontend/product work proceeds against deterministic demo data.

## P03C — DEMO_DATA operational workspace

### Current evidence

| Check                         | Result   | Evidence                                                                                                                                |
| ----------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Demo data fallback            | PASS     | Missing public Supabase config selects deterministic demo context/tasks rather than blocking the workspace.                             |
| Today / My Tasks              | PASS     | Projection logic and responsive panels implemented; future planned tasks stay out of Today.                                             |
| All Tasks                     | PASS     | URL-synced filters, search, saved views and row selection implemented; no bulk-complete bypass exists.                                  |
| Overview                      | PASS     | Operational task KPIs, attention ordering and seller workload summary implemented without revenue/attendance fabrication.               |
| Demo mutation safety          | PASS     | Task create/detail mutation paths are disabled and hard-guarded in demo mode.                                                           |
| Manual SQL fixture            | PREPARED | `supabase/demo/seed_p03c_demo.sql` resolves real org/member/seller prerequisites and never creates Auth users or plaintext credentials. |
| Supabase runtime/RLS/Auth E2E | DEFERRED | Deliberately postponed to the final database/setup stage; no runtime PASS is claimed.                                                   |

### Policy

Frontend/product validation continues with non-Supabase gates. Missing Docker, Supabase CLI and real public
credentials are tracked as deferred setup work rather than blockers for current UI/product development.

## P02 — Design-system-aligned web shell slice

### Automated

| Check                                | Result | Evidence                                                                                                                                                                                                            |
| ------------------------------------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Web shell routes                     | PASS   | `/overview` and `/today` build as dynamic server-rendered routes                                                                                                                                                    |
| Setup-state E2E                      | PASS   | Both workspace routes show an explicit Supabase setup state without fake data                                                                                                                                       |
| Invite/design-system E2E             | PASS   | 5 Playwright specs passed, including invite security, focus trap, Escape close/focus return and 390px drawer behavior                                                                                               |
| Mobile auth slice                    | PASS   | Mobile lint, typecheck and `pnpm check:mobile`; shared contracts and design-token dependencies linked in lockfile                                                                                                   |
| Mobile cross-platform bundling       | PASS   | Expo/Metro bundle succeeded after adding direct `react-dom`, `react-native-web`, SDK 53-compatible native navigation peers, safe-area provider/insets, and the Expo Router-compatible `query-string@7.1.3` resolver |
| UI primitive set                     | PASS   | `apps/web/components/ui.tsx` includes Select/Combobox, shell, fields, overlays, table, badges and feedback states                                                                                                   |
| Real sign-out action                 | PASS   | Workspace button calls `supabase.auth.signOut()` and passes build/E2E smoke checks                                                                                                                                  |
| Invite entry security state          | PASS   | `/auth/accept-invite` rejects missing/invalid entry and ignores untrusted organization URL data                                                                                                                     |
| Full repository check                | PASS   | `pnpm check` after shell implementation                                                                                                                                                                             |
| Responsive navigation implementation | PASS   | Desktop sidebar and mobile bottom navigation are present in the shared shell                                                                                                                                        |
| Visual QA                            | PASS   | Web desktop/mobile login, 1024px setup state, app-shell 1440px/390px captures under `apps/web/visual-check/`, plus Expo mobile login 390px under `apps/mobile/visual-check/`                                        |
| Primitive visual QA                  | PASS   | `/design-system` desktop/mobile captures; danger/warning token gap fixed from visual review                                                                                                                         |
| Overlay accessibility                | PASS   | Dialog/drawer trap keyboard focus, Escape closes when a close action exists, focus returns to the trigger and the mobile drawer becomes a full-screen sheet                                                         |

### Scope boundary

- The shell uses the real `OrganizationContext` contract when Supabase is configured and the user has
  an active membership.
- No dashboard metrics, task records, attendance records, avatars or fake success responses were added.
- P02 is not complete and no database runtime pass is claimed until the P00/P01A external gates run.
- Invite token validation, Auth account provisioning and membership activation are intentionally not
  claimed here; P01B server commands are required before those steps can be wired.

## P04 — Daily / Recurring Tasks

### Current evidence

| Check                       | Result   | Evidence                                                                                                                                                                          |
| --------------------------- | -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Recurring frontend/demo     | PASS     | Daily Task create option, recurring management and Calendar projections use deterministic demo data.                                                                              |
| Recurring projection policy | PASS     | Future projected rows remain virtual/dashed and do not expose completion actions before materialization.                                                                          |
| Migration contract          | PREPARED | `00000000000006_p04_recurring_tasks.sql` defines immutable versions, targets, occurrences, RLS/RPC boundaries and service-only materialization.                                   |
| Assignment recovery         | PREPARED | Unavailable fixed assignee becomes `needs_assignment`; manager/admin resolution validates scope/availability, requires reason and is idempotent.                                  |
| Manual SQL fixture          | PREPARED | `supabase/demo/seed_p04_recurring_demo.sql` mirrors the three frontend recurring demo templates without creating Auth users or credentials.                                       |
| pgTAP DAILY-01..DAILY-14    | PREPARED | `supabase/tests/0004_p04_recurring_tasks.sql`; DAILY-07 is explicitly TODO until attendance/approved-leave backend exists.                                                        |
| Static P04 DB contract      | PASS     | `pnpm test:db:static` passes with P01A/P01B/P03B/P04 migration checks.                                                                                                            |
| Application gate            | PASS     | `pnpm check` passes across env precheck, secret scan, lint, typecheck, domain/web tests and production web build; missing Supabase credentials remain allowed in demo-first mode. |
| Formatting gate             | PASS     | `pnpm format:check` passes after normalizing `apps/web/app/globals.css`.                                                                                                          |
| Supabase runtime/RLS/Auth   | DEFERRED | Docker, Supabase CLI and real public credentials are intentionally deferred to final setup; no runtime PASS is claimed.                                                           |

### Runtime-critical cases represented

- DAILY-03 repeated same-day generation remains one occurrence/task.
- DAILY-06 unavailable fixed assignee becomes `needs_assignment`, then explicit manager assignment materializes once.
- DAILY-08 pause/resume advances the generation floor and prevents paused-window backfill.
- DAILY-09 edits append an immutable version and leave existing occurrences pinned to their prior version.
- DAILY-10 inactive assignee surfaces a manager issue.
- DAILY-11 same-day generation is allowed when the schedule is valid.
- DAILY-12 delayed catch-up is bounded and historical occurrences are marked `system_delay`.
- DAILY-13 future projection is not persisted as a completable task before materialization.
- DAILY-14 weekday matching follows ISO weekday/work_date semantics.

### Scope boundary

P04 remains `IN_PROGRESS_DEMO_DATA`. Application/static gates can pass now, while DB execution, RLS behavior
and authenticated runtime flows remain unverified until Supabase setup is completed.

## P05 — Shifts, Leave Requests and Approvals

### Current evidence

| Check                           | Result   | Evidence                                                                                                                                       |
| ------------------------------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| HR demo UI                      | PREPARED | `/requests`, `/approvals` and `/schedule` are source-swappable workspace pages; demo actions remain disabled.                                  |
| Availability privacy            | PREPARED | Calendar/Schedule use minimal availability rows only; reasons and handover notes remain off the manager surface.                               |
| P05 migration contract          | PREPARED | `00000000000007_p05_hr_requests.sql` defines schedule snapshots, request/decision/ledger history, RLS and command boundaries.                  |
| Full-day leave task treatment   | PREPARED | Approved leave keeps tasks, creates coverage actions and marks unmaterialized recurring work for explicit assignment.                          |
| Manual SQL fixture              | PREPARED | `supabase/demo/seed_p05_hr_demo.sql` creates representative schedule/request data only after real organization members exist.                  |
| pgTAP REQ-01..REQ-13 + DAILY-07 | PREPARED | `supabase/tests/0005_p05_hr_requests.sql` covers request/approval/privacy/correction contracts.                                                |
| Static P05 DB contract          | PASS     | `pnpm test:db:static` passes with P01A/P01B/P03B/P04/P05 migration checks.                                                                     |
| Application gate                | PASS     | `pnpm check` passes; the P05 demo policy suite contributes 5 tests and `/requests`, `/approvals`, `/schedule` compile in the production build. |
| Formatting gate                 | PASS     | `pnpm format:check` passes after the P05 route and stylesheet additions.                                                                       |
| Supabase runtime/RLS/Auth       | DEFERRED | Docker, Supabase CLI and real public credentials are intentionally deferred; no runtime PASS is claimed.                                       |

### Scope boundary

P05 remains `IN_PROGRESS_DEMO_DATA` until the prepared migration and pgTAP suite run in a real Supabase
environment. P06 attendance events, selfie/Wi-Fi checks and payroll calculations remain out of scope.

## P06 — Attendance Native

| Check                              | Result   | Evidence                                                                                                                                                                                                                       |
| ---------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Fail-closed web/mobile UX          | PASS     | `/attendance`, `/attendance/monitor` and mobile Attendance show no recorded event without a server commit.                                                                                                                     |
| Policy/server unit tests           | PASS     | 10 tests cover fail-closed UI, trusted-ingress default denial, forwarded-IP parsing, Wi-Fi freshness, same-origin laptop-code creation and server-event-only success.                                                          |
| Shared contract + TypeScript       | PASS     | Attendance challenge/finalize/Wi-Fi contracts compile in shared contracts and the mobile project.                                                                                                                              |
| Static P06 DB contract             | PASS     | `node scripts/verify-db-migrations.mjs` includes P06 tables/RLS, service-only internal RPCs, BSSID/IP checks, upload-intent binding, laptop-code lockout, immutable raw events and ATT-01..29 test IDs.                        |
| P06 pgTAP source                   | PREPARED | `supabase/tests/0006_p06_attendance.sql` checks schema/privilege invariants and documents device-only ATT cases; it has not been executed against Supabase yet.                                                                |
| Native Wi-Fi bridge                | PREPARED | Android/iOS local Expo module exists and TypeScript compiles; real permission/SSID/BSSID behavior still requires development builds on physical devices.                                                                       |
| Remote laptop companion UI         | PASS     | `/attendance/remote-session` renders the privacy guidance and no fake code; code creation is same-origin web-cookie only, prior codes are invalidated and five failed resolves lock the active code.                           |
| Mobile office flow                 | PREPARED | Device registration, day/shift load, challenge, native Wi-Fi read and server finalize are wired; physical-device/network verification remains external.                                                                        |
| Signed private upload runtime      | PREPARED | Private bucket, signed upload intent and server object-existence checks are implemented; finalize binds the exact intent to the challenge and consumes it transactionally. Real Storage execution awaits Supabase setup.       |
| Direct camera remote flow          | PREPARED | Expo Camera + legacy stable Expo FileSystem flow compiles: laptop-code resolve, front-camera capture/retake, signed PUT upload and committed-event-only success are wired. Physical-device/Storage execution remains deferred. |
| Supabase attendance DB/RLS runtime | DEFERRED | Migration/pgTAP/authenticated runtime execution awaits the later Supabase setup stage; no runtime backend PASS is claimed.                                                                                                     |

## P07 — Timesheet & Monthly Reconciliation

| Check                              | Result   | Evidence |
| ---------------------------------- | -------- | -------- |
| Timesheet arithmetic engine        | PASS     | `packages/domain/tests/timesheet.test.ts` passes 12/12 cases covering TIME-01..10 and TIME-13/14. |
| Raw-second / work-unit precision   | PASS     | Engine unions intervals, keeps raw seconds through aggregation and only then divides by historical `standard_day_minutes`. |
| Missing/conflicting data policy    | PASS     | Missing checkout is provisional/unknown; overlapping sessions and attendance/leave conflicts block verification instead of being silently normalized. |
| Demo UX boundary                   | PASS     | `/timesheet/me` and `/timesheets` explicitly label synthetic preview rows; demo reconciliation/export/close controls are disabled and no salary value is shown. |
| Live-source UI wiring              | PASS     | Real-source self/roster reads call the prepared Supabase RPC layer; reconcile/close/reopen controls call same-origin HTTP routes, use idempotency keys + optimistic `period_version`, and refresh server data after success. This is source-level verification only. |
| Shared contract + TypeScript       | PASS     | Timesheet contract now separates `period_id`, optimistic `period_version` and snapshot `revision`; contracts/domain/api-client/web TypeScript all compile after the live-action wiring. |
| Static P07 DB contract             | PASS     | Static verifier covers day summaries, periods, RLS, immutable snapshots/events, service-only summary writes, blocking close and revisioned reopen through TIME-01..14. |
| Closed empty-member contract       | PASS     | `rpc_get_timesheet` now returns schema-valid zero totals when a closed period has no snapshot for a scoped member; static verifier asserts the fallback fields are present. |
| P07 pgTAP source                   | PREPARED | `supabase/tests/0007_p07_timesheets.sql` checks schema/privilege/immutability/close-reopen invariants; it has not been executed against Supabase yet. |
| Timesheet HTTP boundaries          | PREPARED | Authenticated read/reconcile/close/reopen routes compile and are wired to real-source UI; database authorization remains authoritative and runtime execution awaits Supabase setup. |
| Supabase timesheet DB/RLS runtime  | DEFERRED | Docker, Supabase CLI and real project credentials are still deferred; no runtime backend PASS is claimed. |

## P11 — Full regression, UAT, performance and deployment readiness

### Executed application/browser gates

| Check | Result | Evidence |
| --- | --- | --- |
| Web unit suite | PASS | `pnpm --filter @opsdesk/web test` — 18 files, 74 tests passed |
| Web TypeScript | PASS | `pnpm --filter @opsdesk/web typecheck` |
| Browser regression | PASS | `pnpm --filter @opsdesk/web test:e2e` — 16/16 passed after running Chromium outside the restricted sandbox |
| Full repository lint | PASS | `pnpm lint` |
| Full repository typecheck | PASS | `pnpm typecheck` |
| Domain suite | PASS | `pnpm test` — domain 42/42; web 74/74 |
| Secret scan | PASS | `pnpm secret-scan` |
| Static DB/security verifier | PASS | `pnpm test:db:static` through P10 plus the P11 `rpc_get_context` contract source/manual-patch contract |
| Production web build | PASS | `pnpm build:web` — all application/API routes compiled |
| Mobile config/dependency check | PASS | `pnpm check:mobile` |
| Mobile cross-platform export | PASS | `pnpm build:mobile` — web, Android and iOS bundles exported |
| Format check | PASS | `pnpm format:check` |
| Production env validator logic | PASS | `validate-env.mjs --strict --production --require-invitation-service` with safe synthetic identifiers; no real production credential is claimed |
| Hosted schema/storage probe | PASS | `pnpm test:db:remote:probe` validates representative P01–P10 tables and `attendance-evidence`/`exports` buckets through the configured hosted project; it performs read-only metadata/data probes. |
| Hosted auth/RLS smoke | PASS (NARROW) | `pnpm test:auth:rls:remote` creates and removes an isolated QA user/tenant, then verifies session context, own tenant reads, foreign-context denial, direct membership-write denial and empty-state P03/P05/P06/P07/P08/P09 read RPCs. |
| Repeatable remote gate | AVAILABLE | `pnpm test:runtime:remote` runs the hosted schema/storage probe followed by the isolated authenticated read/RLS smoke. |
| BOMAX demo readiness | PASS | `pnpm check:demo:hosted` confirms all four Auth identities, active owner/member links, three sellers and nine task rows in the hosted BOMAX workspace. |
| Browser cookie → SSR context | PASS | `pnpm test:web:session:remote` signs in a disposable QA admin through `@supabase/ssr` browser cookies and receives the rendered `/overview` workspace through Next.js; the QA user/tenant is deleted afterward. |
| TASK-17 | PASS | Explicit projection regression: task planned today with due date tomorrow remains in Today |
| UI-01 | PASS | Playwright viewports 1440/1280/1024/768/390; task filter overflow found at 1280/1024 and fixed before final pass |
| UI-02 | PASS | Playwright asserts Synapse-like light sidebar/surface/thin border/dark primary CTA hierarchy |
| UI-03 | PASS | Source + rendered-route no-avatar regression |
| UI-04 | PASS | Row selection, checklist required checkbox and Daily toggle tested as independent state |
| UI-05 | PASS | Direct task deep link and refresh retain the same task; access-error branch remains source-covered |
| UI-06 | PASS | Invalid create draft is retained and first invalid field is identified for focus |
| UI-07 | PASS | Route loading skeleton plus task empty/error states verified |
| UI-08 | PASS | Keyboard focus trap, Escape close and focus return pass Playwright |
| UI-09 | PARTIAL_EXTERNAL_DEVICE | Web safe-area rules source-covered; physical mobile keyboard/home-indicator verification still requires devices |
| UI-10 | PASS | Filter query values survive reload and browser back through URL state |
| UI-11 | PARTIAL_EXTERNAL_RUNTIME | No browser data cache layer is present and logout uses full history-replacing navigation; two-real-user authenticated test awaits Supabase |
| UI-12 | PASS | Single-flight mutation guard and malformed-response false-success prevention pass unit tests |

### Production hardening evidence

- Production never falls back to deterministic demo data even when `NEXT_PUBLIC_DEMO_MODE=true`; missing real
  Supabase config instead produces the existing safe workspace configuration state.
- Production/demo links are hidden outside permitted local/dev demo mode.
- `verify:env:production` requires HTTPS app URL, demo disabled, real Supabase identifiers, service-role worker
  access, automation secret, valid 32-byte push-token key and trusted attendance ingress.
- Baseline response headers include content-type protection, referrer policy, frame denial, permissions policy,
  CSP frame/object/base restrictions and HSTS.
- Mobile workspace/drawer CSS reserves safe-area space at the bottom.

### Full required suite status

The source/static/unit suites represent AUTH-01..12, TASK-01..20, DAILY-01..14, ATT, REQ-01..13,
TIME-01..14, REPORT-01..14, NOTIFY-01..11, UI-01..12 and SEC-01..15 across prior phase migrations/tests.
P11 does not promote database/device-dependent cases to runtime PASS merely because their IDs exist in source.

| Runtime group | Result | Blocker |
| --- | --- | --- |
| Authenticated AUTH/RLS/tenant isolation | PARTIAL_REMOTE_PASS | Hosted baseline passes for context, own member/org visibility, foreign-context denial, direct membership mutation denial and browser-cookie → SSR workspace handoff; remaining tables/roles need workflow coverage. |
| Task/recurrence/HR database mutation lifecycle | NOT_EXECUTED | Hosted schema is present, but authenticated task/recurrence/HR commands and pgTAP have not yet been executed. |
| Attendance Wi-Fi/camera/device cases | BLOCKED_EXTERNAL_DEVICE | Physical iOS/Android + trusted office network needed |
| Timesheet/report/notification DB + cron | NOT_EXECUTED | Hosted schema is present; scheduler, provider and authenticated command execution still need a controlled test window. |
| Private Storage signed URL/runtime ACL | PARTIAL_REMOTE_PASS | Both required buckets exist; signed upload/download, object ACL and retention behavior still need runtime coverage. |
| Backup + Storage restore drill | NOT_EXECUTED | Requires an explicitly designated staging-equivalent restore target. |

### UAT-01..07

All seven cross-feature UAT scenarios remain `NOT_EXECUTED`. The hosted backend is available, but the scenarios
need controlled user roles, device/network access and a designated staging-equivalent restore target. Demo E2E is
useful for UX/regression only and is not counted as end-to-end UAT for attendance, approvals, cron, RLS,
notifications or persistence.

### P11 result

`IN_PROGRESS_UNVERIFIED`.

There is currently no application/browser regression blocker in the executed P11 web suite. The project must not
be labeled `READY_FOR_INTERNAL_PRODUCTION` until the authenticated Supabase/RLS suite, real-device attendance/push,
cron/job-health checks, production header/origin verification, backup/restore drill and UAT-01..07 are completed
or explicitly accepted by the production owner with documented risk.
