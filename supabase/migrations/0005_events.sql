-- Stanza Phase 8 -- Event clustering schema addition (NEW FILE, does not
-- touch any existing migration).
--
-- Mirrors the EVENTS + EVENT_SOURCES tables from spec section 31/13.
-- An event is created lazily by the summarizer the first time it detects
-- a near-duplicate article (Phase 7's duplicate-detection logic) -- most
-- articles never join an event at all, since most stories are only
-- covered by one of your five sources.

create table if not exists events (
  event_id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists event_sources (
  event_id uuid not null references events(event_id) on delete cascade,
  article_id uuid not null references articles(article_id) on delete cascade unique,
  -- unique on article_id: one article belongs to at most one event.
  created_at timestamptz not null default now(),
  primary key (event_id, article_id)
);

create index if not exists idx_event_sources_event_id on event_sources(event_id);

alter table events enable row level security;
alter table event_sources enable row level security;

create policy "Public read access to events"
  on events for select
  using (true);

create policy "Public read access to event_sources"
  on event_sources for select
  using (true);

-- No insert/update policy on either table: only the Edge Function
-- (service_role key, bypasses RLS) writes to them.

-- Note on cleanup: the existing hourly cleanup job deletes articles older
-- than 24h and their stanzas. Because event_sources.article_id has
-- ON DELETE CASCADE, a deleted article's event_sources row is
-- automatically removed too -- no change to cleanup/index.ts is needed
-- for this to stay consistent. An event with zero remaining
-- event_sources rows becomes an orphan (harmless, just an unreferenced
-- row); a periodic cleanup of orphaned events is a reasonable Phase 9
-- reliability improvement, not required for this feature to work.
