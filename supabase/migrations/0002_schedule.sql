-- Stanza Phase 2 — Scheduling (Supabase / Postgres)
--
-- Runs the ingest Edge Function automatically every 30 minutes using
-- pg_cron (job scheduler) + pg_net (lets Postgres make HTTP calls).
-- Both extensions are available on Supabase's free tier at no extra cost.
--
-- IMPORTANT: Before running this file, replace the two placeholders below:
--   YOUR_PROJECT_REF   -> found in Supabase dashboard > Project Settings > General
--   YOUR_SERVICE_ROLE_KEY -> found in Project Settings > API > service_role key
--
-- Run this in the Supabase SQL Editor (dashboard), not via the CLI migration
-- flow, since it contains a secret key that shouldn't sit in version control
-- as plain text. If you do want it in migrations, use Supabase Vault instead
-- of pasting the key directly (see SETUP.md).

create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'stanza-ingest-every-30-min',
  '*/30 * * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/ingest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- To check scheduled jobs:
--   select * from cron.job;
-- To check run history / see if it's actually firing:
--   select * from cron.job_run_details order by start_time desc limit 10;
-- To remove the schedule if needed:
--   select cron.unschedule('stanza-ingest-every-30-min');
