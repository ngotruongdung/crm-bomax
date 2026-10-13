-- OpsDesk P10 security maintenance scheduler (manual deployment step).
-- Run only after the web app is deployed and AUTOMATION_SECRET is configured there.
-- Replace both REPLACE_* values before executing this file in Supabase SQL Editor.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  'REPLACE_WITH_HTTPS_WEB_ORIGIN/api/internal/security/maintenance',
  'opsdesk_security_maintenance_url',
  'OpsDesk P10 export and retention maintenance endpoint'
);

select vault.create_secret(
  'REPLACE_WITH_AUTOMATION_SECRET',
  'opsdesk_security_automation_secret',
  'OpsDesk P10 worker authentication secret'
);

do $$
begin
  if exists (select 1 from cron.job where jobname = 'opsdesk-security-maintenance') then
    perform cron.unschedule('opsdesk-security-maintenance');
  end if;
end;
$$;

select cron.schedule(
  'opsdesk-security-maintenance',
  '*/2 * * * *',
  $job$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'opsdesk_security_maintenance_url'
      limit 1
    ),
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-opsdesk-automation-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'opsdesk_security_automation_secret'
        limit 1
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 50000
  );
  $job$
);

-- Verification after setup:
-- select jobid, jobname, schedule, active from cron.job where jobname = 'opsdesk-security-maintenance';
-- select * from cron.job_run_details where jobid = (
--   select jobid from cron.job where jobname = 'opsdesk-security-maintenance'
-- ) order by start_time desc limit 20;
