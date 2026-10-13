# Deployment Checklist

## P11 production readiness

Status on 2026-10-05: `IN_PROGRESS_UNVERIFIED`. Checked items below are verified in the current source/runtime;
unchecked items require the real production/staging environment, Supabase project, provider credentials or devices.

### Application and environment

- [x] Production never silently falls back to deterministic demo data.
- [x] Demo workspace links are hidden when `NODE_ENV=production`.
- [x] `NEXT_PUBLIC_DEMO_MODE=false` is required by `pnpm verify:env:production`.
- [x] Production app URL must be HTTPS and must not be localhost.
- [x] Public web/mobile Supabase URLs must match the same project.
- [x] Public anon variables reject service-role/secret key patterns.
- [x] `AUTOMATION_SECRET` and `PUSH_TOKEN_ENCRYPTION_KEY` are validated without printing values.
- [x] Production attendance requires trusted ingress `vercel` or `cloudflare`; `none` is rejected.
- [ ] Configure real `NEXT_PUBLIC_APP_URL`.
- [ ] Configure real web/mobile Supabase URL + anon key.
- [ ] Store service-role/automation/push/provider secrets only in server secret storage.
- [ ] Configure Auth redirect URLs for production and staging.
- [ ] Confirm CORS/origin policy against actual deployed hostnames.

### Database, RLS and Storage

- [x] Static migration/security verification exists through P10/P11 source.
- [x] Business Storage buckets are designed private and file downloads recheck fresh ACL.
- [x] Demo seed SQL is separate from production migration history.
- [ ] Create/configure production Supabase project.
- [ ] Apply migrations from zero successfully in staging-equivalent environment.
- [ ] Generate DB types from the real schema and confirm no drift.
- [ ] Run all pgTAP suites with authenticated/service-role contexts.
- [ ] Verify organization/seller/member isolation with real RLS sessions.
- [ ] Confirm all business buckets are private in the deployed project.
- [ ] Verify signed URL TTL and revoked-scope download denial at runtime.
- [ ] Confirm no demo seed/demo Auth users exist in production.
- [ ] Bootstrap the initial production owner/admin through the approved procedure.

### Workers, cron and integrations

- [ ] Deploy notification/report worker and security-maintenance worker.
- [ ] Configure Supabase Vault worker URL + automation secret.
- [ ] Install/enable `pg_cron`/`pg_net` jobs from the reviewed scheduler templates.
- [ ] Confirm notification/report tick freshness is under 5 minutes.
- [ ] Configure Expo push credentials and test provider ticket/receipt lifecycle.
- [ ] Configure retention policy with reviewed production durations; do not use demo template values blindly.
- [ ] Confirm export jobs, retention cleanup and legal hold behavior against private Storage.

### Attendance and devices

- [ ] Configure trusted office network allowlists/BSSID/IP data.
- [ ] Test office check-in/out on a physical iOS device.
- [ ] Test office check-in/out on a physical Android device.
- [ ] Verify wrong Wi-Fi, stale scan, revoked device and replay challenges fail closed.
- [ ] Test remote selfie flow with direct camera capture and private evidence upload.
- [ ] Test mobile keyboard/safe-area behavior on representative physical devices.
- [ ] Test real push notification registration, receipt and logout endpoint revocation.

### Web regression and security

- [x] P11 Playwright demo suite passes 16/16.
- [x] UI-01 viewports 1440/1280/1024/768/390 no longer cause document-level task-page overflow.
- [x] UI-02 light Synapse-like surface hierarchy is regression-tested.
- [x] UI-03 no-avatar regression is covered in source and rendered workspace routes.
- [x] UI-04 row selection/checklist/Daily checkboxes are tested independently.
- [x] UI-05 deep-link + refresh task path is covered.
- [x] UI-06 validation preservation/focus policy is unit-tested.
- [x] UI-07 loading/empty/error states have concrete coverage.
- [x] UI-08 keyboard/focus dialog behavior passes E2E.
- [x] UI-09 safe-area source guard exists; physical-device keyboard verification remains pending.
- [x] UI-10 URL filter state reload/back behavior passes E2E.
- [x] UI-11 browser cache use is absent and logout uses full history-replacing navigation.
- [x] UI-12 duplicate/false-success mutation guards are unit-tested.
- [x] Baseline response security headers are configured in Next.js.
- [ ] Verify HTTPS/header behavior on the deployed edge/runtime, including final CSP/CORS policy.
- [ ] Run authenticated logout/login-as-different-user cache isolation test.

### Backup, restore, monitoring and UAT

- [x] Backup/restore procedure is documented in `docs/BACKUP_RESTORE_RUNBOOK.md`.
- [x] Monitoring/alert expectations are documented in `docs/PRODUCTION_MONITORING_RUNBOOK.md`.
- [ ] Confirm production database backups are enabled and retained per policy.
- [ ] Run a staging-equivalent database + Storage restore drill and record evidence.
- [ ] UAT-01 normal workday passes end-to-end.
- [ ] UAT-02 half-day leave passes end-to-end.
- [ ] UAT-03 remote work passes end-to-end.
- [ ] UAT-04 missed task/reminder/report passes end-to-end.
- [ ] UAT-05 manager scope passes end-to-end.
- [ ] UAT-06 multi-organization isolation passes end-to-end.
- [ ] UAT-07 retry/network instability passes end-to-end.

`READY_FOR_INTERNAL_PRODUCTION` must not be set until the remaining unchecked runtime/device/UAT/restore items
are either passed or explicitly accepted as documented blockers by the production owner.

