-- Stanza Phase 10 -- Research instrumentation (NEW FILE).
--
-- A single events table, matching spec section 41's metrics (reading
-- time, consumption volume, engagement) as closely as a live single-arm
-- app can. This does NOT implement the full 3-group (traditional /
-- summary-list / Stanza) controlled experiment from spec section 40 --
-- that's a separate research-study build (distinct participant groups,
-- comprehension quizzes, a consent flow), not something to bolt onto the
-- production app. This captures the behavioral signal side: how people
-- actually use Stanza, which is the "consumption volume" and
-- "engagement" half of the metrics list, and reading time as a proxy
-- input to the "efficiency" side of the research question.

create table if not exists analytics_events (
  event_id uuid primary key default gen_random_uuid(),
  session_id text not null,
  event_type text not null,
  stanza_id uuid,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_analytics_events_type_created
  on analytics_events(event_type, created_at desc);
create index if not exists idx_analytics_events_session
  on analytics_events(session_id);

alter table analytics_events enable row level security;

-- The Flutter app writes with the anon key and never reads this table
-- back (no analytics dashboard is being built into the app itself), so:
--   - INSERT is open to anon: this is telemetry, not user data --
--     no PII, no auth, nothing sensitive.
--   - No SELECT policy for anon: reading/aggregating is done by you,
--     directly in the SQL Editor or a future admin-only view, not
--     exposed to the public anon key.
create policy "Anon can log analytics events"
  on analytics_events for insert
  to anon
  with check (true);
