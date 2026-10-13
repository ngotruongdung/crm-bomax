# Production Monitoring Runbook

## Purpose

This runbook defines the minimum P11 production signals for OpsDesk. Monitoring must use safe metadata only:
never log raw selfie bytes, private request reasons, access tokens, service-role keys, encryption keys or signed
Storage URLs.

## Required health signals

| Signal | Healthy target | Alert condition | First response |
| --- | --- | --- | --- |
| Notification/report worker heartbeat | tick at least every 1–2 minutes | no successful tick for >5 minutes | inspect scheduler, worker auth and last lease/error |
| Notification outbox | pending queue drains continuously | oldest actionable pending row >10 minutes | inspect provider/API failure, lease expiry and retry state |
| Daily 18:00 report | revision 1 available shortly after cutoff | expected report not ready by 18:05 org local time | inspect report generation tick, task-history completeness and outbox |
| Export worker | queued/processing jobs make progress | oldest non-terminal export exceeds operational SLA | inspect job lease, Storage upload and scope snapshot errors |
| Retention worker | scheduled cleanup completes | cleanup stale beyond two expected scheduler intervals | inspect legal hold, policy configuration and Storage delete failures |
| Attendance verification | normal fail-closed error rate | sudden spike in Wi-Fi/challenge/upload/finalize failures | inspect trusted ingress, office allowlist and device/app version |
| Timesheet reconciliation | blocking exceptions trend toward resolution | unresolved exception volume grows unexpectedly | inspect attendance/leave conflicts and missing checkout sources |
| Auth/RLS access | expected 2xx/4xx mix | unusual 5xx or access-denied spike after deploy | compare migration, session, membership and seller-scope changes |

## Logging rules

- Log request/job IDs, organization IDs, member IDs, safe error codes, durations and state transitions only when
  required for operations.
- Redact authorization headers, cookies, raw invitation tokens, automation secrets and provider credentials.
- Never persist signed download/upload URLs; store the stable file metadata ID instead.
- Attendance evidence diagnostics may log MIME type, byte count, pixel dimensions and validation error code, but
  never image bytes or a publicly reusable object URL.
- Private HR request reasons and handover notes must not be copied into generic monitoring logs.

## Alert routing and severity

- `Critical`: cross-tenant access, service-role/public-secret leak, unrecoverable data-loss signal, production demo
  mode exposure. Disable affected boundary or deployment immediately and preserve evidence.
- `High`: authentication/RLS regression, worker outage >5 minutes, report deadline breach, private file ACL issue,
  backup failure. Assign an owner immediately and stop risky releases.
- `Medium`: delayed export/retention work, elevated attendance verification failures, repeated provider retry.
- `Low`: individual recoverable user/job failures with bounded retry and no security/data-integrity impact.

## Deployment verification

After each production deployment:

1. Confirm `NEXT_PUBLIC_DEMO_MODE=false` and production environment preflight success.
2. Confirm login, organization context and one authorized read path.
3. Confirm one unauthorized/cross-scope read is denied.
4. Confirm worker heartbeat and scheduler timestamps advance.
5. Confirm report/notification/export/retention queues have no unexpectedly stale rows.
6. Confirm security headers over HTTPS from the real deployment edge.
7. Confirm no secrets or signed URLs appear in application logs.

## Incident evidence

For every P11 production incident, retain: UTC/local timestamps, deployment version, safe request/job IDs,
organization scope, affected feature, error code, remediation and verification result. Do not attach private file
contents unless the incident owner explicitly requires them in an access-controlled evidence system.
