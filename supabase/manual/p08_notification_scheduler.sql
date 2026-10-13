-- OpsDesk P08 notification scheduler (manual deployment step).
-- Run only after the web app is deployed and AUTOMATION_SECRET is configured there.
-- Replace both REPLACE_* values before executing this file in Supabase SQL Editor.

create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select vault.create_secret(
  'REPLACE_WITH_HTTPS_WEB_ORIGIN/api/internal/notifications/dispatch',
  'opsdesk_notification_dispatch_url',
  'OpsDesk P08 notification dispatch endpoint'
);

select vault.create_secret(
  'REPLACE_WITH_AUTOMATION_SECRET',
  'opsdesk_notification_automation_secret',
  'OpsDesk P08 worker authentication secret'
);

do $$
begin
  if exists (select 1 from cron.job where jobname = 'opsdesk-notification-dispatch') then
    perform cron.unschedule('opsdesk-notification-dispatch');
  end if;
end;
$$;

select cron.schedule(
  'opsdesk-notification-dispatch',
  '* * * * *',
  $job$
  select net.http_post(
    url := (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'opsdesk_notification_dispatch_url'
      limit 1
    ),
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-opsdesk-automation-secret', (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'opsdesk_notification_automation_secret'
        limit 1
      )
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 50000
  );
  $job$
);

-- Verification after setup:
-- select jobid, jobname, schedule, active from cron.job where jobname = 'opsdesk-notification-dispatch';
-- select * from cron.job_run_details where jobid = (
--   select jobid from cron.job where jobname = 'opsdesk-notification-dispatch'
-- ) order by start_time desc limit 20;
