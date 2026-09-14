-- Stanza Phase 3 -- Scheduling the summarizer. (NEW FILE)
--
-- Runs every 15 minutes, offset from your existing 30-minute ingestion
-- schedule, so there's reliably a backlog of pending_summary articles to
-- work through on each run.
--
-- Uses Supabase Vault for the service-role key, consistent with your
-- existing Phase 2 setup (stanza_service_role_key). This assumes that
-- secret already exists in Vault -- it does, since your ingest cron job
-- already reads it. No plaintext key appears anywhere in this file.

select cron.schedule(
  'stanza-summarize-every-15-min',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://ieppmtartaayeeaejivs.supabase.co/functions/v1/summarize',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'stanza_service_role_key'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Check scheduled jobs:  select * from cron.job;
-- Check run history:     select * from cron.job_run_details order by start_time desc limit 10;
-- Remove if needed:      select cron.unschedule('stanza-summarize-every-15-min');
