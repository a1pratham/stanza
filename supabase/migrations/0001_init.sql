-- Stanza Phase 2 — Database schema (Supabase / Postgres)
-- Mirrors the SOURCES and ARTICLES tables from the project spec (section 31).

-- SOURCES: the list of RSS feeds Stanza pulls from.
create table if not exists sources (
  source_id text primary key,
  name text not null,
  feed_url text not null,
  category text not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

-- ARTICLES: raw ingested articles, one row per article.
-- status starts as 'pending_summary' and Phase 3's AI job flips it to
-- 'summarized' once a Stanza has been generated for it.
create table if not exists articles (
  article_id uuid primary key default gen_random_uuid(),
  source_id text not null references sources(source_id),
  title text not null,
  source_url text not null unique, -- unique constraint IS the dedup mechanism
  description text,
  image_url text,
  published_at timestamptz,
  category text not null,
  status text not null default 'pending_summary',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Speeds up Phase 3's query for "give me all articles still needing a summary".
create index if not exists idx_articles_status on articles(status);

-- Seed the initial source list (spec section 8: small, reliable set for MVP).
insert into sources (source_id, name, feed_url, category) values
  ('the-hindu-national', 'The Hindu', 'https://www.thehindu.com/news/national/feeder/default.rss', 'India'),
  ('reuters-world', 'Reuters', 'https://feeds.reuters.com/Reuters/worldNews', 'World'),
  ('bbc-world', 'BBC News', 'http://feeds.bbci.co.uk/news/world/rss.xml', 'World'),
  ('ndtv-india', 'NDTV', 'https://feeds.feedburner.com/ndtvnews-india-news', 'India'),
  ('bbc-business', 'BBC News', 'http://feeds.bbci.co.uk/news/business/rss.xml', 'Business')
on conflict (source_id) do nothing;

-- Row Level Security: public read-only access, no public writes.
-- The Edge Function uses the service_role key, which bypasses RLS entirely,
-- so it can still insert articles.
alter table articles enable row level security;
alter table sources enable row level security;

create policy "Public read access to articles"
  on articles for select
  using (true);

create policy "Public read access to sources"
  on sources for select
  using (true);
