# Implementation Status

## Current phase

- Phase: `P11` (full regression, UAT, basic performance and deployment readiness)
- Status: `IN_PROGRESS_UNVERIFIED`
- Scope: regression, production-mode hardening, browser/device/runtime verification and deployment readiness
- Started: 2026-10-05

Local pgTAP/reset gates remain blocked by missing Docker/Supabase CLI. Hosted Supabase is now configured,
and narrowly scoped remote checks have verified the deployed P01–P10 schema/buckets plus authenticated
context and tenant-isolation baselines. This is not yet a substitute for the full mutation lifecycle or UAT.

## Frontend redesign track

The ClickUp-inspired redesign is tracked independently from the backend P-phases. It keeps the existing
task, permission and mutation boundaries intact; no visual phase is a backend-runtime verification claim.

| Redesign phase | Status | Delivered scope |
| --- | --- | --- |
| FE-R0 | `COMPLETE` | Existing routes, states, permissions and responsive constraints audited before visual changes. |
| FE-R1 | `COMPLETE` | Shared light-surface tokens and reusable compact UI primitives. |
| FE-R2 | `COMPLETE` | Responsive workspace shell, information hierarchy and permission-aware navigation. |
| FE-R3 | `COMPLETE` | Task list command bar, saved filters, fields, grouping and sorting controls. |
| FE-R4 | `COMPLETE` | Deep-linkable task detail drawer and create-task drawer workflows. |
| FE-R5 | `COMPLETE_LOCAL_VERIFIED` | URL-persistent List/Board/Calendar views, 280px status board cards, and an accessible month grid with direct task links, three visible task chips per date and overflow counts. Status drag/drop is intentionally omitted because the approved task lifecycle has server-side transition rules. |
| FE-R6 | `COMPLETE_LOCAL_VERIFIED` | Today now presents the current local day, a compact four-metric focus strip, action-priority group ordering and attendance/My Work shortcuts. Notifications are projected as an action inbox: digest/system rows are excluded, tabs persist in the URL and task/HR/report actions retain their existing links and read-state boundary. Browser visual execution is blocked in this sandbox before Chromium can launch. |
| FE-R7–FE-R11 | `NOT_STARTED` | Sellers/Team, HR views, Reports/Settings, mobile/accessibility pass and cross-route regression remain next. |

## Repository audit

- Repository was empty apart from the three specification documents and `UI_REFERENCE.png`.
- No existing frontend framework or database migration was present to preserve.
- Selected baseline: pnpm workspaces, Next.js App Router + TypeScript strict, Expo Router,
  Supabase CLI layout, Vitest, Playwright and Prettier.
- GitHub Actions CI is configured to run baseline, mobile, static database-contract and browser checks;
  its first remote execution remains pending until the repository is connected to GitHub.
- Root scripts expose the required operational aliases for web/mobile development, DB reset/type generation,
  demo seed and the full deployment verification gate; database aliases remain blocked until local Supabase
  tooling is installed.
- `pnpm verify:env` and `pnpm verify:env:server` pass against the local non-secret/public configuration and
  server-only worker configuration respectively, without printing any credential values.
- `pnpm verify:env:production` is now the production deployment preflight. It validates the public app URL,
  forbids demo mode in production, validates Supabase web/mobile identifiers, requires the service-role key,
  automation secret, 32-byte push-token encryption key and a trusted attendance ingress, without printing
  secret values.

## Phase summary

| Phase | Status                   | Notes                                                                                                                                                                                                                                          |
| ----- | ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| P00   | `BLOCKED_EXTERNAL_SETUP` | Bootstrap files and baseline checks pass; local Supabase verification awaits Docker/Supabase CLI.                                                                                                                                              |
| P01A  | `IN_PROGRESS_UNVERIFIED` | Core schema, RLS helpers, seed, contracts and auth server helper are implemented; hosted schema and a narrow authenticated tenant-isolation smoke pass, while full DB lifecycle/pgTAP remains outstanding.                                  |
| P01B  | `IN_PROGRESS_UNVERIFIED` | Seller scope, invitation commands and web invitation activation are implemented; pgTAP and real invitation lifecycle execution remain outstanding.                                                                                               |
| P02   | `IN_PROGRESS_UNVERIFIED` | Web auth UX and a context-backed shell for `/overview` and `/today` are implemented; a hosted browser-cookie-to-SSR session smoke now reaches `/overview`, while role-by-role manual UAT remains outstanding.                                |
| P03A  | `IN_PROGRESS_UNVERIFIED` | `/sellers` and `/team` use the P01B command/query boundary when configured and deterministic read-only demo data otherwise; real-data E2E awaits Supabase runtime.                                                                             |
| P03B  | `IN_PROGRESS_UNVERIFIED` | Task schema/RPCs, reviewer policy, task create/list/detail UI and deterministic UI policy tests are implemented; an authenticated empty-state task-read RPC smoke now passes, while task mutations/authenticated E2E remain outstanding.         |
| P03C  | `IN_PROGRESS_DEMO_DATA`  | Today, My Tasks, All Tasks, Overview, Sellers and Team run from deterministic demo data when Supabase public config is absent. Manual-paste SQL fixture is prepared at `supabase/demo/seed_p03c_demo.sql`.                                     |
| P04   | `IN_PROGRESS_UNVERIFIED` | Recurring/daily task generation and policy logic are implemented; DB runtime verification remains deferred.                                                                                                                                    |
| P05   | `IN_PROGRESS_UNVERIFIED` | HR request workflows, approval policy and demo-first UI are implemented; authenticated availability read smoke passes, while request/approval lifecycle verification remains outstanding.                                                        |
| P06   | `IN_PROGRESS_UNVERIFIED` | Attendance contracts, native verification boundary, web/mobile flows and DB source are implemented; authenticated attendance-day read smoke passes, while real device and finalize runtime verification remains outstanding.                     |
| P07   | `IN_PROGRESS_UNVERIFIED` | Timesheet engine, reconciliation/close/reopen flows and snapshot model are implemented; authenticated self-timesheet read smoke passes, while reconciliation/close/reopen runtime verification remains outstanding.                              |
| P08   | `IN_PROGRESS_UNVERIFIED` | Notification inbox, outbox/reminder worker, Expo registration and deployment scheduler template are implemented; authenticated empty-inbox read smoke passes, while worker/provider runtime verification remains outstanding.                    |
| P09   | `IN_PROGRESS_UNVERIFIED` | 18:00 report contracts/domain rules, immutable recipient snapshots, server tick, scoped list/detail pages and revision flow are implemented; authenticated empty-report read smoke passes, while cron/revision runtime verification remains outstanding. |
| P10   | `IN_PROGRESS_UNVERIFIED` | Private Storage/file gateway, content validation, scoped export jobs/worker, legal-hold retention, admin audit UI, SEC-01..15 static/pgTAP source and backup/restore runbook are prepared; runtime Storage/RLS/restore proof remains deferred. |
| P11   | `IN_PROGRESS_UNVERIFIED` | Production can no longer silently fall back to demo mode; security headers, production env preflight, mobile safe-area fixes, route loading state and P11 browser regression coverage are implemented. Hosted schema/storage, demo readiness and browser-cookie-to-SSR auth smoke now pass; lifecycle, cron, device, restore and UAT gates remain pending. |

## Feature status

- No business feature is claimed complete in P00.
- Deterministic task/seller/member demo data is now intentionally allowed while Supabase setup is deferred. Demo mode remains read-only for mutations, does not fabricate revenue or attendance state, and never claims backend success.
- P01A/P01B implementation is not claimed runtime-verified or phase-complete.

## P11 implementation snapshot

- Workspace data-source resolution is fail-closed in production: configured Supabase always wins, local/dev
  may use deterministic demo data, while production never renders demo workspace links or falls back to mock data.
- `NEXT_PUBLIC_APP_URL` and `NEXT_PUBLIC_DEMO_MODE` are documented in `.env.example`; the production preflight
  requires HTTPS, `NEXT_PUBLIC_DEMO_MODE=false`, server worker secrets and trusted attendance ingress.
- Next.js responses now include baseline `nosniff`, referrer, frame, permissions, CSP frame/object/base and HSTS
  headers. The CSP intentionally remains narrow at this stage so it does not break Next.js/Supabase runtime.
- Web route loading now has a real skeleton state. Mobile workspace/drawer fixed UI reserves safe-area inset at
  the bottom, and the task filter grid was corrected to avoid document-level overflow at 1280px and 1024px.
- TASK-17 now has an explicit regression asserting a task planned today remains in Today when its due date is
  tomorrow. UI-01..12 are mapped to behavior tests/source guards/E2E rather than label-only placeholders.
- Playwright now starts a dedicated demo server on port 3101, independent of `.env.local`. The P11 browser suite
  passes 16/16, including viewports 1440/1280/1024/768/390, visual hierarchy, no-avatar audit, checkbox
  independence, deep-link refresh, empty/error states, keyboard focus and URL filter persistence.
- Web unit tests currently pass 74/74 and the web TypeScript check passes after P11 hardening.
- Full lint/typecheck pass, domain tests pass 42/42, secret scan and static DB/security verification pass,
  production web build succeeds, formatting passes, mobile runtime config check passes and Expo exports succeed for
  web/iOS/Android.
- `pnpm test:db:remote:probe` passes against the hosted project: representative P01–P10 tables and the
  `attendance-evidence`/`exports` private buckets are present. It is read-only and intentionally does not test
  application mutations or object ACLs.
- `pnpm test:auth:rls:remote` passes with a temporary, automatically removed QA user/tenant. It proves the
  session context, own membership/organization visibility, cross-tenant context denial, direct membership
  mutation denial and empty-state read access for P03/P05/P06/P07/P08/P09. It does not cover every business
  table or mutation workflow.
- `pnpm check:demo:hosted` confirms the hosted BOMAX demo has four linked Auth identities, an active owner,
  three sellers and nine seeded task rows. `pnpm test:web:session:remote` proves a browser-compatible Supabase
  session reaches the `/overview` SSR workspace with a disposable QA admin, which is removed at completion.
- P11 adds migration `00000000000013_p11_context_contract.sql`: `rpc_get_context` now returns `false` rather
  than `null` for `is_owner` while a new organization has no owner yet. Existing hosted projects can apply the
  prepared, data-safe SQL patch in `supabase/manual/OPSDesk_P11_Context_Contract_Fix.sql`.
- P12 extends the pending attendance surface with administrator-managed office Wi‑Fi/BSSID, trusted web
  public-IP/CIDR policy, configurable work shifts and 90-day shift materialization. Remote attendance now uses a
  direct camera-photo private upload rather than a laptop hand-off code. The migration and UI are implemented but
  hosted P12 migration, trusted-ingress deployment and real-device/browser finalization are not yet runtime-verified.
- P11 must remain `IN_PROGRESS_UNVERIFIED` until business lifecycle execution, cron/worker health,
  real-device Wi-Fi/camera/push checks, backup/restore drill and UAT-01..07 are actually completed.

## P01A implementation snapshot

- Core migration covers organizations, memberships, HR settings, specialties, invitations,
  immutable policy/audit foundations and private idempotency storage.
- Owner eligibility is enforced across tables: an organization owner must remain an active admin;
  HR policy references are organization-scoped composite foreign keys.
- RLS is enabled on all P01A tables, direct client writes are revoked, and security-sensitive
  helpers use a fixed empty `search_path`.
- Membership directory reads are restricted to the current member or an admin; employees do not
  receive a full organization roster through direct table SELECT.
- `rpc_get_context` is exposed only to authenticated users and derives role/capabilities from
  the membership row, not user metadata.
- Next.js session refresh middleware and the Auth PKCE callback are wired; callback redirects are
  constrained to internal paths.
- Mobile Supabase client uses the shared database contract and Expo SecureStore persistence;
  only the public anon key is accepted in the mobile bundle.
- Auth UX slice is available at `/login`, `/forgot-password` and `/reset-password`; sign-in uses
  the real Supabase password flow and routes by the validated membership role, without fake success data.
- Authenticated workspace shell includes a real Supabase `signOut()` action with pending and generic
  error states; it redirects to `/login` only after sign-out succeeds.
- Invite entry UI is available at `/auth/accept-invite`; it handles missing/invalid tokens and routes
  token-bearing links through login without trusting `organization_id` or granting membership client-side.
- Mobile auth entry now uses the shared `OrganizationContext` contract and real Supabase password flow;
  it restores sessions, routes employees to `/today` and admin/manager members to `/overview`, and
  exposes a real sign-out action.
- P02 web shell slice is available at `/overview` and `/today`; it renders organization/member context
  when available and explicit configuration, authentication, membership or load-error states otherwise.
  It does not fabricate dashboard metrics or task data.
- Minimum shared UI primitives are available in `apps/web/components/ui.tsx`: shell building blocks,
  form controls including native accessible `Select`/`Combobox`, dialog/drawer/sheet, table, badges,
  empty/error/skeleton/toast/confirm states and text-only person labels.
- An internal `/design-system` preview route exercises these primitives and overlay interactions without
  entering product navigation or using business records.
- Dialog and drawer primitives trap keyboard focus, close on Escape when safe, return focus to their
  trigger and use a full-screen sheet layout at the mobile breakpoint; related browser checks pass.
- Seed creates two deterministic organizations and only attaches Auth users that already exist;
  it never embeds plaintext passwords.
- `pnpm seed:auth-demo` can provision local Auth users and memberships idempotently using environment-only
  credentials; it refuses non-local Supabase URLs.
- `packages/api-client/src/database.types.ts` is a compile-safe P01A snapshot. Run
  `pnpm types:db` after local Supabase is available to replace it with CLI-generated types; the
  generator uses a temporary file and preserves this snapshot when the CLI/runtime is unavailable.

## P01B implementation snapshot

- `sellers`, interval-based `seller_members` and invitation seller-scope tables are added in a new
  migration; no P01A migration history was rewritten. Seller scope follows the organization timezone
  and prevents overlapping assignments for the same person/seller.
- P01B commands validate and activate invitations, list a scoped directory, update member access,
  deactivate members, and create/update sellers or seller membership. All direct authenticated writes
  to the new tables remain revoked.
- HR capabilities remain independent from role/seller scope; manager scope never grants attendance
  access by default. Scope reads verify current active membership, so revocation applies on the next read.
- Internal invitation finalization/reference RPCs are executable only by `service_role`; the broad
  seller-member helper is not exposed to authenticated clients.
- `POST /api/admin/invitations` creates the database invitation as the authenticated admin, then uses
  a server-only service key solely to deliver the Supabase Auth invitation and record its Auth reference.
  The custom token is hashed in the database, travels through the PKCE callback, and is verified with
  the signed-in email before a membership is activated. A delivery failure leaves no application access;
  retry reuses the open invitation instead of creating a duplicate membership.
- `/auth/accept-invite` now uses the validation/acceptance RPCs and renders explicit loading, wrong-email,
  expired and retry-safe states. It never trusts organization, role or seller data from URL parameters.

## P03A implementation snapshot

- `/sellers` reads only seller rows allowed by RLS and shows the people currently derived from the
  scoped member query. Admin actions call `rpc_create_or_update_seller` and
  `rpc_update_seller_members`; seller history is archived rather than deleted.
- `/team` reads the privacy-filtered directory RPC. Admin actions use the invitation route,
  `rpc_update_member_access` and `rpc_deactivate_member`; the browser does not write membership,
  capability or seller tables directly.
- The admin editor keeps HR capabilities separate from role and seller scope. Changing an existing
  admin to a non-admin clears the auto-granted HR defaults in the UI; the database remains the authority.
- Employee navigation intentionally omits Team and Seller administration. Direct deep links still depend
  on current database/RLS scope, not on the navigation visibility.

## P03B implementation snapshot

- Task core migrations implement assignment, acknowledgement, start, submit/review, request-changes,
  cancel/waive/reopen, reassignment, due-date changes, blockers, checklist/result/evidence gates and
  optimistic version checks without allowing privileged direct client writes.
- Reviewer assignment is restricted to active in-scope admin/manager members, cannot equal the assignee,
  and internal reviewer assignment remains admin-only in V1. Employee reviewer assignment is rejected with
  the explicit `TASK_REVIEWER_ROLE_DENIED` contract.
- `/tasks`, `/tasks/new` and `/tasks/[id]` use authenticated server loaders and RPC command boundaries;
  task mutations use deterministic idempotency keys and synchronous single-flight guards to prevent rapid
  duplicate submissions before React state re-renders.
- Create/edit/submit validation preserves user input, focuses the first invalid field and never treats a
  malformed mutation response as success. Version conflicts expose an explicit reload path instead of
  silently overwriting newer data.
- Task UI policy is centralized in pure helpers with regression tests for action visibility, in-review
  freezes, blocker semantics, submit gates, duplicate-submit protection, deep-link loading/error behavior
  and the no-avatar requirement.
- Setup-state Playwright coverage includes the task list, task creation and a task-detail deep link when
  Supabase is not configured; authenticated task lifecycle E2E still requires the real local runtime.

## P04 implementation snapshot

- Recurring work is modeled as template -> immutable version -> target snapshot -> occurrence, with a unique
  occurrence identity on organization/template/target-key/work-date to make repeated generation idempotent.
- The service-only materializer creates fresh task rows per valid work-date, marks delayed catch-up as
  `system_delay`, bounds catch-up, and surfaces manager attention rather than silently skipping unavailable
  assignees.
- `rpc_assign_recurring_occurrence` lets an authorized admin/manager resolve `needs_assignment` with an
  eligible in-scope member, required reason, audit trail and idempotent single-task materialization.
- Pause/resume advances the generation floor so paused dates are not backfilled. Template edits append a new
  version and do not rewrite already-materialized occurrences.
- Recurring management and Calendar projection UI run on deterministic demo data while Supabase is absent;
  projected future occurrences remain virtual/dashed and non-completable.
- `supabase/demo/seed_p04_recurring_demo.sql` is ready for later manual execution in Supabase SQL Editor and
  contains no Auth users, passwords, tokens or service credentials.
- `supabase/tests/0004_p04_recurring_tasks.sql` represents DAILY-01..DAILY-14. DAILY-07 is explicitly TODO
  until approved leave/attendance data exists, so P04 does not fabricate leave suppression behavior.
- Runtime migration/RLS/Auth verification remains deferred; only static SQL and application gates may be
  reported as passing at this stage.

## P05 implementation snapshot

- The demo-first workspace now includes `/requests`, `/approvals` and `/schedule`, following the same compact
  light-surface visual language as the supplied reference. All P05 mutations are explicitly disabled in demo
  mode; no fake persisted approval or attendance success is claimed.
- `00000000000007_p05_hr_requests.sql` introduces offices, shift templates/assignments/instances, leave
  types, private employee requests, immutable request decisions, leave-balance ledger entries and a task
  handover queue. Shift segment validation keeps scheduled time and break handling server-owned.
- Request commands use capability-based HR approval, self-approval denial, optimistic versions, idempotency,
  overlap protection, pending withdrawal and approved-cancellation history. An attendance correction remains
  a claim that emits a future P06 adjustment workflow, not a mutable attendance event.
- Availability is exposed by a narrow RPC without `reason_private`, handover notes or evidence. Direct request
  rows are restricted to their owner or users with `can_approve_requests`.
- Approved full-day leave becomes a coverage concern: existing work stays intact, a handover action is created,
  unmaterialized recurring work is marked `APPROVED_LEAVE_COVERAGE_REQUIRED`, and reminder suppression is
  requested through the outbox.
- `supabase/demo/seed_p05_hr_demo.sql` and `supabase/tests/0005_p05_hr_requests.sql` are ready for manual
  setup later; they contain no credentials or fabricated Auth users.

## P06 implementation snapshot

- Attendance now has web and native-mobile entry surfaces and remains fail closed: no event/time is shown as
  successful until a server-recorded attendance event exists.
- The browser explicitly cannot strict-verify office SSID/BSSID. The UI guides the user to the native app
  rather than treating browser network hints as proof. Remote flow requires approved remote eligibility,
  direct camera capture and private evidence storage; it never offers a gallery-based success path.
- HR monitor intentionally contains no demo attendance rows or inferred “working” status. The P06 policy/server
  tests now include 10 passing cases, including the same-origin web boundary for laptop-code creation, while
  device/network-specific ATT checks remain external verification.
- `00000000000008_p06_attendance.sql` now prepares office BSSID/IP allowlists, registered devices, private
  file/upload metadata, one-time attendance challenges, immutable events/evidence and one-open-session
  enforcement. Internal challenge/finalize RPCs are service-role only and use the database clock for official
  timestamps; authenticated users cannot insert/update raw events directly.
- Shared attendance contracts now define challenge/finalize payloads plus the native Wi-Fi result boundary.
  A local Expo module implements Android SSID/BSSID reads and iOS `NEHotspotNetwork.fetchCurrent`; when the
  module/permission/network is unavailable it returns an explicit fail-closed diagnostic rather than fake data.
- `/attendance/remote-session` is available as the laptop companion surface. Creating a code is restricted to a
  same-origin cookie-authenticated web request; mobile Bearer requests cannot self-issue the laptop code. New
  codes invalidate older active codes, and the resolver locks a session after five failed attempts.
- `supabase/tests/0006_p06_attendance.sql` represents ATT-01..ATT-29, separating server/static assertions from
  the device-required cases. The static migration verifier now includes P06 and passes locally.
- Attendance HTTP boundaries now cover device registration, day/shift projection, challenge creation,
  remote evidence upload intent, laptop sessions and finalization. General attendance routes accept either the
  web cookie session or a verified Supabase Bearer token from mobile while resolving organization/member identity
  server-side; laptop-code creation is intentionally web-cookie/same-origin only.
- Office finalization reads source IP only from an explicitly configured trusted ingress adapter and rejects
  native Wi-Fi claims older than five seconds. Local/demo ingress defaults to disabled and therefore fails closed.
- Mobile Attendance now registers its installation, loads the server day/shift projection and runs the office
  check-in/out challenge flow. The remote screen also resolves the laptop code, requests front-camera permission,
  captures/retakes the selfie directly, uploads it through the signed private intent, then finalizes attendance.
  Success is rendered only from a committed event returned by the server.
- The private `attendance-evidence` Storage bucket and signed upload-intent/object-existence checks are prepared.
  Remote finalize additionally requires the upload intent to match the exact organization/member/file/challenge,
  be unexpired and unused, and consumes it transactionally with the attendance event. Real Storage execution and
  physical-camera behavior remain deferred until Supabase/device setup.

## P07 implementation snapshot

- A pure timesheet interval engine now calculates raw seconds before work-unit conversion. It unions overlapping
  sessions, keeps office/remote/paid/unpaid categories separate, treats missing checkout as provisional/unknown,
  surfaces attendance/leave conflicts for reconciliation and never turns outside-schedule time into payroll/OT.
- Domain tests cover TIME-01..10 plus TIME-13/14 and currently pass 12/12 locally. The monthly aggregate uses the
  actual schedule rows rather than a fixed 26-day assumption.
- `/timesheet/me` and `/timesheets` follow the light Synapse-style workspace UI. Demo rows are explicitly labeled
  as formula/UI preview data and all write controls stay read-only in demo mode. In real-source mode the manager
  roster now loads live RPC-backed timesheets and the reconciliation/close/reopen controls call the prepared HTTP
  boundaries, refresh server data after success and retain idempotency/optimistic-version semantics.
- `00000000000009_p07_timesheets.sql` prepares day summaries, monthly periods, immutable snapshots and immutable
  period audit events. Closing is admin-only, blocks unresolved/missing scheduled days, hashes and snapshots the
  current revision, while reopening requires a reason and increments revision without rewriting old snapshots.
- Closed periods reject recalculation writes. The internal summary-upsert boundary is service-role only; users can
  read their own timesheet while attendance managers may read scoped employees through the authenticated RPC.
- The timesheet view contract now carries `period_id` and `period_version` separately from business `revision`, so
  close/reopen mutations use the actual optimistic-lock version instead of conflating it with snapshot revision.
  Closed periods also return deterministic zero totals for an active member with no snapshot, avoiding a contract
  failure on an otherwise valid empty month.
- HTTP boundaries and UI wiring are prepared for timesheet read, begin reconciliation, close and reopen commands.
  Contracts, domain, API-client and web TypeScript compile, but these paths remain runtime-unverified until
  Supabase is configured.
- `supabase/tests/0007_p07_timesheets.sql` documents TIME-01..14 invariants. Static migration verification now runs
  through P07 successfully; pgTAP/RLS/Auth runtime execution remains deferred.

## P08 implementation snapshot

- Notification inbox contracts, domain policies, migration/RPCs, deterministic demo data and the Synapse-style
  `/notifications` UI are implemented. Reading a notification remains separate from task acknowledgement.
- Durable outbox processing uses leases for outbox events; reminder routing, approved-leave suppression, snooze
  semantics, daily push limits/digest behavior and stale-worker acknowledgement protection are represented in
  source tests and pgTAP fixtures.
- The web worker endpoint materializes inbox rows first, then dispatches push independently. Expo delivery uses
  encrypted server-side tokens, provider tickets/receipts, bounded retry and endpoint deactivation for permanent
  token errors. Push send rows now use a ten-minute compare-and-set send lease to avoid overlapping workers
  sending the same delivery concurrently.
- Native mobile now registers/reuses the existing OpsDesk device after authenticated workspace context loads,
  requests notification permission, obtains an Expo token using `EXPO_PUBLIC_EAS_PROJECT_ID`, and registers it
  with the server. Logout revokes the current device before Supabase sign-out so its push endpoints are disabled.
- `supabase/manual/p08_notification_scheduler.sql` is prepared for the final deployment stage. After replacing
  the HTTPS worker URL and automation secret, it stores both values in Supabase Vault and schedules the worker
  once per minute through `pg_cron` + `pg_net`, so reminders do not depend on an open browser/mobile client.
- Real device push, Expo provider receipts, cron execution, DB/RLS and pgTAP runtime verification remain deferred
  until Supabase/EAS/deployment credentials are configured. Static/source-level gates must not be treated as
  runtime PASS.

## P09 implementation snapshot

- `00000000000011_p09_reports.sql` adds logical report runs, immutable recipient snapshots and immutable run
  events. A run is unique by organization/date/cutoff/revision, so retrying the 18:00 tick reuses revision 1
  instead of creating duplicate logical reports.
- Cutoff is computed from organization timezone and optional `report` policy `cutoff_local`; task facts are
  reconstructed from the latest `task_events.report_state_after` at or before cutoff, tie-broken by task version.
  Future task events now also include the display-safe task title in report state; historical missing state is
  surfaced as `TASK_HISTORY_INCOMPLETE` rather than silently substituting current values.
- The deterministic report fact builder keeps the main cohort formula `due = done + review + open`, counts blocked
  only as a subset of open, and separates previous-day overdue, due-after-cutoff and canceled/waived task IDs.
  Attendance at cutoff is projected as a general `working/unknown` state and never auto-checks a session out.
- Recipient scope is snapshotted per active member: admin receives organization scope, a manager with active
  manager seller assignments receives seller scope, and other users receive personal scope. Opening a stored
  manager snapshot rechecks that its seller scope is still permitted; stale broader snapshots are denied.
- `rpc_internal_generate_due_reports` is service-role only and is invoked by the existing one-minute notification
  dispatch worker before outbox processing. Report facts are saved before report-ready outbox events, so push
  failure/retry remains independent of report availability. The existing Supabase scheduler template therefore
  also wakes P09 while all clients are closed.
- `/reports` and `/reports/[id]` are implemented with deterministic demo fallback, Synapse-style light UI and no
  avatars. Notification report links now deep-link to the report run. Admin can request an explicit revision with
  reason, optimistic version and idempotency key; old recipient snapshots stay immutable.
- At the P09 checkpoint, REPORT domain tests passed 8/8, total domain tests were 37/37 and web tests were 53/53;
  static migration checks passed through P09 and production web build included `/reports`, `/reports/[id]` and
  `/api/reports/revision`.
- P09 is not runtime PASS yet: Supabase migration execution, pgTAP, real cron catch-up, authenticated RLS scope,
  report-ready push delivery and late-commit/revision behavior still require the final Supabase runtime setup.

## P10 implementation snapshot

- `00000000000012_p10_security_ops.sql` normalizes all four business buckets as private, binds file metadata to
  purpose-specific buckets/size limits/server-generated paths, adds export jobs and legal-hold-aware retention.
- File downloads go through `/api/files/[id]/download`: the database rechecks the current parent ACL, sensitive
  evidence access is audited, and the server issues only short signed URLs with `Cache-Control: no-store`.
- Remote attendance evidence is limited to JPEG/WebP and 5 MB. Finalize downloads the stored object server-side,
  verifies magic bytes, declared byte count and maximum 1920px edge, and quarantines invalid content.
- Export requests snapshot the caller's current organization/seller/personal scope. A secret-protected maintenance
  worker claims jobs, writes formula-safe UTF-8 CSV, uploads to the private `exports` bucket and marks jobs ready.
  A new download link is denied when the requester no longer owns the original scope.
- Retention cleanup is service-only and skips legal hold. Real Supabase use now requires an explicit retention
  policy; `supabase/manual/p10_retention_policy_template.sql` contains demo/test values that must be reviewed and
  replaced before production.
- `/system/audit` is admin-only and has deterministic demo data while Supabase is absent. It shows safe audit
  metadata without avatars and without persisting signed file URLs.
- `supabase/manual/p10_security_maintenance_scheduler.sql` prepares a two-minute `pg_cron`/`pg_net` wake-up for
  export and retention work after the deployed worker URL and automation secret are configured in Vault.
- SEC-01..SEC-15 are represented in the P10 pgTAP/static suite, with content/CSV/retention rules additionally
  covered by domain/web tests. Backup/restore requirements are recorded in `docs/BACKUP_RESTORE_RUNBOOK.md`.
- Current P10 source-level gate: domain tests 42/42, web tests 58/58, full lint/typecheck, secret scan,
  static DB/security checks and production web build all pass.
- P10 is not runtime PASS yet: clean migration execution, authenticated Storage/RLS tests, real signed URL TTL,
  scheduler execution, Storage-byte backup and staging-equivalent restore drill remain for final Supabase setup.

## External blockers

- `docker` is not installed or available on PATH, so Supabase local start/reset cannot be verified.
- `supabase` CLI is not installed or available on PATH.
- No Supabase project URL/keys were supplied; `.env.example` documents the required names only.

## P02 implementation snapshot

- Light-gray canvas, white surfaces, thin borders, dark CTA and system-font stack follow the supplied
  reference direction without a CDN font dependency.
- Desktop sidebar and mobile bottom navigation expose only the implemented workspace destinations:
  `Tổng quan` and `Hôm nay`.
- Workspace header, breadcrumb, role/organization context strip and empty states are driven by the
  validated `OrganizationContext` contract.
- Route-level access states avoid leaking Supabase errors and preserve the intended login return path.
- The primitive set keeps the reference language: light surfaces, thin borders, dark CTA, compact rows,
  line icons and no avatar-based people display.
- `@opsdesk/design-tokens` now contains the shared color, spacing, typography, control and layout map;
  web maps the values to CSS variables while mobile imports the package directly.
- Invite route visual/security state is covered, but token validation, account creation and membership
  activation remain P01B backend work.
- Mobile auth now includes Expo Router screens for `/today` and `/overview`, a shared context guard,
  employee access redirect and a safe empty workspace state; native device/emulator verification remains
  outside this checkpoint.
- The mobile root provides safe-area context; login/workspace content and bottom navigation apply the
  current device insets so controls clear display cutouts and the home indicator.
- The mobile workspace now declares direct `react-dom`, `react-native-web`, SDK 53-compatible
  `react-native-screens`/`react-native-safe-area-context`, and Expo Router's CommonJS-compatible
  `query-string@7.1.3` resolver; `pnpm build:mobile` successfully exports Expo/Metro bundles for
  web, iOS and Android.
- Expo Router mobile login has a 390px visual capture under `apps/mobile/visual-check/`; it renders
  the real configuration error state until public Supabase environment values are supplied.
- Visual QA captures for login desktop/mobile, the 1024px workspace setup state, and the app shell at
  1440px/390px are stored under `apps/web/visual-check/`; the visual gate is complete for the
  implemented/auth setup states.
- Design-system desktop/mobile captures are also stored there; the missing `--danger`/`--warning` CSS
  tokens found during review were added to the shared root token set.

## Current implementation policy

Proceed in `DEMO_DATA_FIRST` mode: continue P03C+ frontend/product work without treating missing Docker,
Supabase CLI or public credentials as a blocker. Keep the data boundary source-swappable to Supabase and do
not claim database/RLS/authenticated runtime PASS until those checks are actually executed.

At the final database/setup stage, apply migrations, create the real Auth/member/seller prerequisites, paste
`supabase/demo/seed_p03c_demo.sql`, `supabase/demo/seed_p04_recurring_demo.sql` and
`supabase/demo/seed_p05_hr_demo.sql` if representative data is useful, then run `pnpm verify:env`, DB
reset/types, pgTAP and authenticated E2E before marking backend phases complete.
