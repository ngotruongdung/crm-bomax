# Setup

## Versions used for P00

- Node.js: `>=22.0.0` (verified locally with `v22.19.0`)
- pnpm: `11.19.0` (verified locally)
- Next.js: `15.5.4`
- React: `19.0.0` for web and mobile (kept aligned for Expo SDK 53 compatibility)
- Expo: `53.0.20`
- TypeScript: `5.8.3`
- Vitest: `3.2.4`
- Playwright: `1.52.0`
- Supabase SSR: `0.7.0`
- Supabase JS: `2.57.4`
- Supabase CLI: required for local DB verification; not available in the current environment
- Docker Desktop: required by Supabase local development; not available in the current environment

## Install

```bash
corepack enable
pnpm install --frozen-lockfile
```

The first install generates `pnpm-lock.yaml` if this is a fresh checkout. Commit the generated lockfile
before using `--frozen-lockfile` in CI.

## Environment

```bash
Copy-Item .env.example .env.local
```

`NEXT_PUBLIC_*` and `EXPO_PUBLIC_*` values are browser/mobile safe identifiers. `SUPABASE_SERVICE_ROLE_KEY`,
`SUPABASE_ACCESS_TOKEN`, provider keys and any future server credentials are server-only and must never be
imported by client components or bundled into mobile.

For P06 mobile attendance, `EXPO_PUBLIC_OPSDESK_WEB_URL` must point to the reachable OpsDesk web/API origin
(for example the LAN/dev URL while testing on a physical phone, or the production HTTPS origin later).
`ATTENDANCE_TRUSTED_INGRESS` stays `none` in local/demo mode; office attendance then fails closed instead of
trusting arbitrary forwarded headers. Set it to `vercel` or `cloudflare` only when the deployment really runs
behind that provider and the corresponding source-IP header is controlled by that ingress.

For a first hosted Supabase project without local Docker/CLI, use the two prepared Dashboard SQL files and the
step-by-step guide in `docs/SUPABASE_DASHBOARD_SETUP.md`. Run `pnpm build:supabase:dashboard-sql` whenever the
source migrations change to regenerate those files.

## Baseline commands

```bash
pnpm dev:web
pnpm dev:mobile
pnpm check:env
pnpm verify:env # strict web/mobile deployment preflight
pnpm verify:env:server # strict preflight including the server-only invitation delivery key
pnpm secret-scan
pnpm lint
pnpm typecheck
pnpm test
pnpm build:web
pnpm check:mobile
pnpm build:mobile # Expo/Metro bundle web, iOS và Android
pnpm test:db:static
pnpm test:runtime:remote # hosted schema/storage + isolated auth/RLS/read-RPC smoke
pnpm db:reset
pnpm test:db:pgtap
pnpm db:types
pnpm seed:demo
pnpm build:supabase:dashboard-sql # regenerate the Dashboard schema/demo SQL files
pnpm verify:deployment # cần Docker, Supabase CLI và local database đang chạy
```

## Supabase local verification

Install Docker Desktop and the Supabase CLI on the development machine, then run:

```bash
supabase start
pnpm verify:env
pnpm db:reset
pnpm db:types
pnpm test:db:pgtap
$env:DEMO_SEED_PASSWORD = 'local-password-at-least-12-chars'
pnpm seed:demo
pnpm verify:deployment
```

The P00 migration is intentionally empty of business tables. P01A owns organization, membership and auth
schema. `pnpm test:db:static` can run without Docker and checks the migration/seed contract; the runtime
reset, pgTAP suite and generated database types still require Docker plus the Supabase CLI. Do not add
business tables to P00 merely to make the database command non-empty. `pnpm seed:demo` is restricted
to localhost and requires a password plus service-role key supplied through the environment; never commit
either value.

`pnpm db:types` generates into a temporary file and replaces the compile-safe snapshot only after the CLI
returns a non-empty `Database` type. If Docker or Supabase CLI is missing, it exits without changing
`packages/api-client/src/database.types.ts`.

`pnpm verify:env` reads `.env.local` without printing values. It requires all web/mobile public variables,
rejects placeholders and public service-role/secret keys, validates URLs and requires web/mobile to target
the same Supabase project. `pnpm verify:env:server` additionally requires a non-placeholder
`SUPABASE_SERVICE_ROLE_KEY` that differs from either public anon key; use it for deployment because the
admin invitation route sends Supabase Auth invitations server-side. `pnpm check:env` retains a non-blocking
bootstrap mode while P00 is blocked.

## Hosted Supabase smoke gate

When the hosted project has been provisioned, set the public URL/key plus the server-only
`SUPABASE_SERVICE_ROLE_KEY` in the root `.env.local`, then run:

```bash
pnpm verify:env:server
pnpm test:runtime:remote
pnpm check:demo:hosted
pnpm test:web:session:remote # requires pnpm dev:web running at NEXT_PUBLIC_APP_URL
```

The remote gate is safe to run repeatedly: it performs read-only schema/bucket probes, then creates an isolated
temporary Auth user and organization to verify RLS and P03/P05/P06/P07/P08/P09 empty-state read RPCs. It deletes
that temporary user and organization before it exits. It does not seed business data, test business mutations,
or replace the local `db:reset` + pgTAP + device/UAT gates.

`pnpm check:demo:hosted` is read-only and checks whether the four documented BOMAX demo Auth identities are
actually linked to the `bomax-digital` organization with the expected roles, sellers and task fixture. Run it when
an Auth login succeeds but the app says that the workspace context is unavailable.

`pnpm test:web:session:remote` uses a separate, self-deleting QA admin to sign in through the same browser-cookie
adapter as the web app, then requests `/overview` through Next.js SSR. It proves the complete browser-session to
server-context handoff without needing any password for a BOMAX account. Start `pnpm dev:web` first at the configured
`NEXT_PUBLIC_APP_URL`.
