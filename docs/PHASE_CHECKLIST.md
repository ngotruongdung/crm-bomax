# Phase Checklist

## P00

### Scope

- [x] Repository audit completed.
- [x] pnpm workspace structure created.
- [x] Web/mobile bootstrap created.
- [x] Shared packages created.
- [x] Supabase config/migration/seed skeleton created.
- [x] No business feature mock added.

### Tooling

- [x] TypeScript strict configuration.
- [x] ESLint entry points.
- [x] Prettier configuration.
- [x] Vitest runner and smoke tests.
- [x] Playwright configuration and bootstrap E2E.
- [x] GitHub Actions CI workflow for baseline, mobile, static DB and browser checks.
- [x] Environment validation script.
- [x] Basic secret scan.

### Verification to run before PASS

- [x] Clean dependency install.
- [x] `pnpm lint`.
- [x] `pnpm typecheck`.
- [x] `pnpm test`.
- [x] `pnpm build`.
- [x] `pnpm check:mobile`.
- [x] `pnpm build:mobile` — Expo/Metro bundles for web, iOS and Android passed.
- [x] `pnpm test:e2e` with Chromium runtime.
- [ ] `pnpm test:db` after Docker and Supabase CLI setup.

### Gate

`FINAL_PHASE_RESULT: BLOCKED_EXTERNAL_SETUP` until Supabase local start/reset is verified.

## P01A

### Scope

- [x] Organization, membership, roles and capability contracts.
- [x] Core tables, constraints, indexes and immutable audit/policy foundations.
- [x] Private idempotency storage.
- [x] RLS enablement and minimum client grants.
- [x] Membership helpers and context RPC.
- [x] Auth server helper for Next.js cookie sessions.
- [x] Session refresh middleware and PKCE callback with open-redirect protection.
- [x] Mobile Supabase client with SecureStore-backed session persistence.
- [x] Deterministic two-organization seed without plaintext credentials.
- [x] Local-only Auth demo provisioning script with environment-only password.
- [x] Static migration checks and pgTAP test suite.

### Verification

- [x] `pnpm test:db:static`.
- [x] `pnpm lint`.
- [x] `pnpm typecheck`.
- [x] `pnpm test`.
- [x] `pnpm build`.
- [ ] `pnpm test:db` — blocked by missing Docker/Supabase CLI.
- [ ] `pnpm types:db` — blocked by missing Supabase CLI/local database.
- [ ] `pnpm test:db:pgtap` — blocked by missing Docker/Supabase CLI.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_UNVERIFIED`; P01A runtime reset, generated types and RLS suite must
pass before this foundation can be marked complete.

## P01B — Invite, role/capability and seller scope

### Scope

- [x] Seller master, seller membership history and invitation seller-scope migration.
- [x] Capability normalization and seller/current-scope helpers.
- [x] Invitation create, validate, accept and service-only internal finalization commands.
- [x] Scoped member list, member access/deactivation and seller access commands.
- [x] Web invitation validation/activation UI and server-only invitation delivery route.
- [x] Compile-safe P01B database type snapshot and contracts.
- [x] P01B static verifier and pgTAP suite for AUTH-05..10/12 plus RLS/grants.

### Verification

- [x] `pnpm test:db:static`.
- [x] `pnpm lint`.
- [x] `pnpm typecheck`.
- [x] `pnpm test`.
- [x] `pnpm build`.
- [x] `pnpm test:e2e` — 5 specs passed, including the URL-untrusted invitation state.
- [ ] `pnpm test:db` — blocked by missing Docker/Supabase CLI.
- [ ] `pnpm types:db` — blocked by missing Supabase CLI/local database.
- [ ] `pnpm test:db:pgtap` — blocked by missing Docker/Supabase CLI.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_UNVERIFIED`; runtime migration/RLS behaviour, invitation retry and
cross-scope cases must pass locally before P01B can be marked complete.

## P02 — Design System, Auth UX, App Shell (web slice)

### Scope

- [x] Auth UX routes for login, forgot password and reset password.
- [x] Real workspace sign-out action with pending/error states.
- [x] Safe invite entry/fallback UI at `/auth/accept-invite` without client-side membership grant.
- [x] Mobile auth form uses real Supabase password/context flow and sign-out.
- [x] Mobile session restore and Expo Router destinations `/today` and `/overview` use the validated
      `OrganizationContext`; employee access to overview redirects to today.
- [x] Mobile login/workspace use safe-area insets; bottom navigation clears the home-indicator area.
- [x] Shared workspace shell with desktop sidebar and mobile navigation.
- [x] Breadcrumb, page heading, organization/member context strip and empty state.
- [x] Explicit configuration, authentication, membership and generic load-error states.
- [x] Minimum shared primitive set: shell, navigation, fields, overlays, table, badges and feedback states.
- [x] Shared design-token map covers color, spacing, typography, controls, row density, sidebar and responsive spacing;
      mobile imports it directly.
- [x] No fake dashboard metrics or business data.
- [x] System-font fallback with no CDN font dependency.

### Verification

- [x] `pnpm lint`.
- [x] `pnpm typecheck`.
- [x] `pnpm test`.
- [x] `pnpm build`.
- [x] `pnpm test:e2e` — 5 specs passed.
- [x] `pnpm check`.
- [x] Visual QA: web login desktop/mobile, workspace 1024px, app shell 1440px/390px and Expo mobile
      login at 390px.
- [x] Primitive preview and overlay interaction QA at `/design-system`.
- [x] Full P02 primitive/component coverage in the shared preview, including Select/Combobox and
      feedback/overlay variants.
- [x] Keyboard overlay behavior: focus trap, Escape close, focus return and mobile full-screen drawer.
- [ ] Supabase-backed context rendering after local DB setup.
- [ ] Real invite token validation, account provisioning and membership activation (P01B backend).

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_UNVERIFIED`; do not claim P02 complete until the Supabase
context flow is verified against the local runtime and target responsive/device checks are complete.

## P03A — Seller and Team Management UI

### Scope

- [x] Seller and Team workspace routes wired to authenticated server data loaders.
- [x] Admin seller create/edit/archive and seller member-scope editor use P01B RPC commands.
- [x] Admin invitation, member role/capability/seller-scope editor and deactivation use server/RPC commands.
- [x] Employee navigation omits administrative destinations; server/RLS remains the final deep-link check.
- [x] Setup-state browser coverage includes `/sellers` and `/team`.
- [x] Missing Supabase public config now falls back to deterministic Seller/Team demo data.
- [x] Demo Seller/Team mutation controls are disabled and mutation handlers have hard read-only guards.

### Verification

- [x] `pnpm lint`.
- [x] `pnpm typecheck`.
- [x] `pnpm test`.
- [x] `pnpm build`.
- [x] `pnpm test:e2e` — 5 specs passed.
- [ ] Real seller/team command E2E — blocked by missing Docker/Supabase CLI and public project credentials.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_UNVERIFIED`; owner/admin/manager/employee paths must run with real
database data and prove the P03A permission cases before this phase can be marked complete.

## P03B — Task Core

### Scope

- [x] Task core schema, immutable history foundations, checklist/result/evidence gates and blocker model.
- [x] Task lifecycle RPCs for acknowledge, start, submit, approve/request changes, cancel/waive/reopen,
      reassignment and deadline changes.
- [x] Reviewer policy: active in-scope admin/manager only, reviewer != assignee, employee reviewer denied.
- [x] Optimistic version conflict contract with explicit UI reload path; no silent overwrite.
- [x] Task create/list/detail routes use authenticated server data and RPC mutation boundaries.
- [x] Create/edit/submit UI preserves draft input on validation/server failure and focuses first invalid field.
- [x] Duplicate-submit protection uses deterministic idempotency plus a synchronous single-flight guard.
- [x] In-review checklist/result/details freeze and blocker semantics are represented by a centralized UI policy.
- [x] No avatars or initial-circle substitutes on task surfaces.
- [x] Static migration verifier covers the P03B core, hardening and reviewer-policy migrations plus TASK-21.
- [x] pgTAP suite represents required P03B task/reviewer/permission cases.
- [x] Setup-state browser coverage includes `/tasks`, `/tasks/new` and `/tasks/[id]` deep link.

### Verification

- [x] `pnpm test:db:static`.
- [x] `pnpm lint`.
- [x] `pnpm typecheck`.
- [x] `pnpm test` — task UI policy/deep-link tests included.
- [x] `pnpm build` — task list/create/detail routes compile in production build.
- [x] `pnpm format:check`.
- [x] Setup-state `pnpm test:e2e` coverage for task routes without configured Supabase.
- [ ] `pnpm verify:env` with real web/mobile public credentials — currently missing.
- [ ] `pnpm db:reset` — blocked by missing Docker and Supabase CLI.
- [ ] `pnpm types:db` — blocked by missing Supabase CLI/local database.
- [ ] `pnpm test:db:pgtap` — blocked by missing Docker and Supabase CLI.
- [ ] Authenticated task lifecycle E2E — requires real Supabase runtime and credentials.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_UNVERIFIED`; real reset/types/pgTAP and authenticated task lifecycle E2E
remain required for a final backend PASS, but by product direction they no longer block P03C frontend work.

## P03C — Operational workspace in DEMO_DATA mode

### Scope

- [x] Deterministic source adapter falls back to demo data when public Supabase config is absent.
- [x] Today grouping: waiting, overdue, new, today and completed.
- [x] My Tasks projections: assigned, collaborating, review and created.
- [x] All Tasks search/filter/selection UI; selection is not completion and selection is capped at 50.
- [x] Overview operational KPIs, attention queue and seller workload summary derived only from task data.
- [x] Demo-safe Create Task and Task Detail mutations are disabled with hard guards.
- [x] Seller and Team routes use the same `demo | supabase` source model; demo management is read-only.
- [x] No fabricated revenue or attendance/check-in state.
- [x] Manual-paste SQL fixture prepared at `supabase/demo/seed_p03c_demo.sql`; frontend does not depend on it.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_DEMO_DATA`; continue product/UI modules now. Supabase runtime verification is
deferred to the final database/setup stage and must not be reported as passed until actually executed.

## P04 — Daily / Recurring Tasks

### Scope

- [x] Recurring template model uses immutable versions, target snapshots and one occurrence per
      organization/template/target/work-date.
- [x] Daily Task UX is available from task creation, recurring management and Calendar projections.
- [x] Calendar future recurrence remains virtual/dashed and has no complete action before materialization.
- [x] Materializer is idempotent for the same work-date and bounded for delayed catch-up.
- [x] Fixed assignee unavailability creates `needs_assignment`; it never silently drops or force-assigns work.
- [x] Manager/admin can resolve an assignment issue through an idempotent RPC with required reason and
      seller-scope/availability validation.
- [x] Pause/resume prevents backfill across the paused window; definition edits append future-facing versions.
- [x] Manual-paste demo fixture prepared at `supabase/demo/seed_p04_recurring_demo.sql` and mirrors the
      deterministic frontend recurring demo.
- [x] pgTAP contract file prepared at `supabase/tests/0004_p04_recurring_tasks.sql` with DAILY-01..DAILY-14.
- [x] Static DB verifier covers P04 schema, RLS, grants, unique occurrence identity, assignment resolution,
      pause/resume, version-forward and catch-up contracts.
- [x] P05 schema now prepares approved full-day leave coverage/handoff for Daily Tasks; runtime verification
      remains deferred until Supabase local setup exists.
- [ ] Execute migration/pgTAP/RLS/Auth runtime checks after Docker, Supabase CLI and real public credentials
      are configured.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_DEMO_DATA`; P04 frontend/product and static SQL contracts are prepared.
Runtime Supabase execution remains deferred and is not reported as passed.

## P05 — Shifts, Leave Requests and Approvals

### Scope

- [x] P21 Requests, P22 Approvals and a compact Schedule surface are available in deterministic demo mode.
- [x] Shift instances preserve ordered working segments and scheduled seconds; break-only leave has zero
      affected work time.
- [x] Leave treatment distinguishes paid, unpaid and HR-determined states; paid use is modeled through an
      immutable balance ledger instead of a client-side balance mutation.
- [x] Employee requests include leave, early leave, late arrival, remote work, attendance-correction claims
      and cancellation of a prior approved request.
- [x] Approvals require the existing `can_approve_requests` capability, forbid self-approval, use optimistic
      request versions and keep immutable before/after decision history.
- [x] Approved overlap is blocked; pending withdrawal retains history; cancellation is a separate approved
      request and writes a ledger reversal where applicable.
- [x] Managers receive availability-only rows; private reasons and handover notes remain request/HR data.
- [x] Approval creates a handover queue for affected tasks and marks unmaterialized full-day Daily work as
      coverage-required rather than deleting tasks or forcing an assignee.
- [x] Manual-paste fixture is prepared at `supabase/demo/seed_p05_hr_demo.sql` without Auth users or secrets.
- [x] pgTAP contract at `supabase/tests/0005_p05_hr_requests.sql` covers REQ-01..REQ-13 and DAILY-07.
- [x] Static verifier covers P05 tables, RLS, RPC/privileged boundaries, leave coverage and contract IDs.
- [ ] Execute migrations/pgTAP/RLS/Auth runtime checks after Docker, Supabase CLI and real public credentials
      are configured.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_DEMO_DATA`; product/UI and static SQL are ready. No Supabase runtime,
RLS or authenticated workflow result is reported as passed before the final setup phase.

## P06 — Attendance Native

### Scope

- [x] Web `/attendance` and mobile Attendance surfaces fail closed: they show no check-in/check-out success
      until a server-recorded event exists.
- [x] Office browser flow is explicitly blocked because it cannot strict-verify SSID/BSSID; diagnostics are
      specific rather than a generic failure.
- [x] Online flow states the direct-camera/private-evidence requirement and deliberately omits a gallery path.
- [x] Attendance monitor has no fabricated demo events, working time or employee surveillance signal.
- [x] Pure policy tests cover browser Wi-Fi denial, expired challenge, remote approval requirement, upload
      failure and the server-event-only success boundary.
- [x] Shared attendance contracts cover office/remote challenge, upload intent, finalize and commit payloads.
- [x] Android/iOS local Expo Wi-Fi module exists with permission/location/unavailable states and no fake SSID.
- [x] P06 Supabase migration prepares office network/IP allowlists, devices, private file metadata,
      one-time challenges, immutable attendance events/evidence and one-open-session enforcement.
- [x] Internal challenge/finalize RPC boundaries are service-role only; authenticated direct event mutation is
      denied and official timestamps are created by the database.
- [x] `/attendance/remote-session` laptop companion surface exists and shows no fabricated session code.
- [x] `0006_p06_attendance.sql` represents ATT-01..ATT-29 and static migration verification includes P06.
- [x] Attendance API routes support web cookie sessions and mobile Supabase Bearer tokens without trusting a
      client-supplied member id.
- [x] Trusted ingress adapters are explicit (`vercel`/`cloudflare`) and default to fail-closed `none`; office
      finalization also rejects Wi-Fi claims older than five seconds.
- [x] Signed private attendance upload intent and server-side object existence/finalize checks are prepared.
- [x] Remote evidence is challenge-bound in both the HTTP boundary and DB transaction; a used/expired or unrelated
      upload intent cannot be committed and the accepted intent is consumed with the event.
- [x] Laptop-code creation is same-origin web-cookie only, older active codes are invalidated and five failed
      resolve attempts lock the current session; direct internal laptop RPCs remain service-role only.
- [x] Mobile office check-in/out is wired through device registration -> day/shift -> challenge -> native Wi-Fi
      -> server finalize and refresh, with no offline or optimistic success.
- [x] Direct-camera remote selfie capture/preview/upload is wired in source through laptop-code resolve -> front
      camera -> retake/confirm -> signed private upload -> server finalize, with no gallery picker or optimistic success.
- [ ] Device-required ATT cases remain `BLOCKED_EXTERNAL_SETUP`; no device verification is reported as PASS.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_DEMO_DATA`; office and remote attendance flows are prepared end-to-end in source.
Supabase DB/Storage runtime, trusted production ingress and physical-device camera/Wi-Fi verification remain
explicitly unclaimed until final environment setup.

## P07 — Timesheet & Monthly Reconciliation

### Scope

- [x] Pure interval engine sums raw seconds, unions overlapping sessions and separates office/remote/paid/unpaid.
- [x] Missing checkout stays provisional/unknown; attendance/leave overlap and session overlap remain review
      exceptions rather than being silently clamped or double-counted.
- [x] Work units divide by historical `standard_day_minutes`; actual scheduled rows are used instead of a fixed
      26-day month and sub-minute seconds are summed before conversion.
- [x] Domain tests cover TIME-01..10 and TIME-13/14 with 12/12 passing locally.
- [x] `/timesheet/me` and `/timesheets` are implemented with explicit demo-preview labeling and no payroll claim.
- [x] P07 contracts cover day rows, totals, period status and close/reopen command payloads.
- [x] `00000000000009_p07_timesheets.sql` prepares `attendance_day_summaries`, `timesheet_periods`, immutable
      snapshots/events, RLS and optimistic/idempotent reconciliation commands.
- [x] Closing requires admin, rejects missing/unverified scheduled days, snapshots the current revision and source
      hash; reopening requires a reason, increments revision and preserves the old immutable snapshot.
- [x] Closed periods reject summary recalculation and the internal summary upsert is service-role only.
- [x] Live `/timesheet/me` and manager roster reads use `rpc_get_timesheet`; manager roster scopes active members
      through `rpc_list_members_by_scope` before loading their monthly views.
- [x] Read/reconcile/close/reopen HTTP boundaries and local Supabase function typings are prepared and compile.
- [x] Real-source period actions are wired with idempotency keys and optimistic `period_version`; demo mode remains
      read-only. Close is admin-only in UI and reopen requires an audit reason.
- [x] Timesheet response exposes `period_id`/`period_version`; closed members without a snapshot return zero totals
      instead of an invalid empty totals object.
- [x] `0007_p07_timesheets.sql` represents TIME-01..14 and static migration verification includes P07.
- [ ] Run P07 migration + pgTAP + authenticated RLS/close/reopen runtime checks after final Supabase setup.

### Gate

`FINAL_PHASE_RESULT: IN_PROGRESS_DEMO_DATA`; P07 calculation logic, demo/live-source UI wiring, contracts, SQL and
HTTP boundaries are prepared and statically verified. No Supabase runtime close/reopen result or payroll result is
claimed.
