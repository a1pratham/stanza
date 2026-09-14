-- Stanza Phase 3 — Database schema addition (NEW FILE, does not touch
-- existing 0001_init.sql or 0002_schedule.sql)
--
-- Adds the STANZAS table from spec section 31.
--
-- Note on why_it_matters: the original spec's conceptual STANZAS table
-- (section 31) includes this column. It's kept here, nullable, so no
-- further migration is needed when Phase 6 implements it -- but Phase 3's
-- pipeline never writes to it. Every row Phase 3 creates will have
-- why_it_matters = NULL. This is a schema-only accommodation, not an
-- early implementation of the feature.

create table if not exists stanzas (
  stanza_id uuid primary key default gen_random_uuid(),
  article_id uuid not null references articles(article_id) unique,
  headline text not null,
  summary text not null,
  why_it_matters text, -- intentionally unused until Phase 6
  word_count int not null,
  model_version text not null,
  status text not null default 'published',
  generated_at timestamptz not null default now()
);

create index if not exists idx_stanzas_status on stanzas(status);

alter table stanzas enable row level security;

create policy "Public read access to stanzas"
  on stanzas for select
  using (true);

-- No insert/update policy: only the Edge Function (service_role key,
-- which bypasses RLS) writes to this table.
