-- Stanza Phase 9 -- Reliability schema additions (NEW FILE).
--
-- Three additions, matching spec section 25 ("News Reliability"):
--   1. stanzas gets flag columns for the automated consistency check.
--   2. sources gets a reliability_tier, used to prefer more established
--      publishers when an event has multiple sources (Phase 8's event
--      clustering).
--   3. A new pipeline_runs table gives every ingest/summarize invocation
--      a permanent, queryable record -- this is the direct fix for the
--      earlier problem where Dashboard log search wasn't surfacing
--      diagnostic output. Logs are ephemeral and hard to search; a table
--      is neither.

alter table stanzas add column if not exists flagged_for_review boolean not null default false;
alter table stanzas add column if not exists flag_reason text;

-- Lower number = more established/reliable. Defaults every existing
-- source to 1 (no downgrade of anything you're currently using) --
-- adjust individual sources yourself via the dashboard if you want to
-- rank any of them lower; this migration doesn't presume to judge them.
alter table sources add column if not exists reliability_tier int not null default 1;

-- Tracks which source's title an event is currently using, so a later,
-- more-reliable duplicate can upgrade it (see event-linking.ts). Not
-- meaningful on its own without the title logic that reads/writes it.
alter table events add column if not exists title_source_tier int;

create table if not exists pipeline_runs (
  run_id uuid primary key default gen_random_uuid(),
  function_name text not null,
  started_at timestamptz not null,
  finished_at timestamptz,
  succeeded int not null default 0,
  failed int not null default 0,
  skipped int not null default 0,
  details jsonb,
  error text
);

create index if not exists idx_pipeline_runs_function_started
  on pipeline_runs(function_name, started_at desc);

-- RLS enabled with NO policies: this is an internal ops table, not
-- something the Flutter app should ever read. service_role (used by the
-- Edge Functions) bypasses RLS entirely, so writes/reads from the
-- functions are unaffected; the anon key gets nothing.
alter table pipeline_runs enable row level security;

create index if not exists idx_stanzas_flagged on stanzas(flagged_for_review)
  where flagged_for_review = true;
