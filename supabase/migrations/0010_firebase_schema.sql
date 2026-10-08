-- Stanza -- Firebase-native profile/preferences/interests/interactions
-- schema (NEW FILE, replaces the content of the previous 0010 draft).
--
-- Built clean, not converted: drops the tables 0008/0009 created and
-- recreates them from scratch with Firebase UID (text) as the identity
-- from the start. No auth.users reference anywhere, no auth.uid()
-- anywhere, no leftover shape from the old design.
--
-- Safe as a destructive DROP because profiles, profile_preferences,
-- profile_interests, and user_stanza_interactions are confirmed at 0 rows.
-- topic_groups/topics are also dropped and recreated purely so the whole
-- feature is defined in one self-contained file -- their content
-- (the 6-group interest taxonomy) is identical to what 0008 seeded, nothing
-- about the taxonomy itself changes, only which migration file owns it.
--
-- Does NOT touch: sources, articles, stanzas, events, event_sources,
-- pipeline_runs, analytics_events. Zero identity coupling, zero changes.

-- =========================================================================
-- 1. DROP EVERYTHING 0008/0009 CREATED
-- =========================================================================
-- IF EXISTS on every statement: safe to run whether 0008/0009 were ever
-- applied as originally written, or already partially altered by an
-- earlier migration attempt. CASCADE on the tables removes their
-- policies, indexes and FKs along with them -- nothing to drop by hand
-- first.

drop trigger if exists on_auth_user_created on auth.users;
drop function if exists handle_new_user();

drop table if exists user_stanza_interactions cascade;
drop table if exists profile_interests cascade;
drop table if exists profile_preferences cascade;
drop table if exists topics cascade;
drop table if exists topic_groups cascade;
drop table if exists profiles cascade;

-- =========================================================================
-- 2. PROFILES -- Firebase UID is the identity, full stop
-- =========================================================================
-- id is the Firebase UID directly (text). No reference to auth.users.
-- No Supabase Auth involvement of any kind.

create table profiles (
  id text primary key,
  full_name text,
  avatar_url text,
  onboarding_completed boolean not null default false,
  onboarding_version int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table profiles enable row level security;

-- auth.jwt() is a Postgres helper that reads claims from the request's
-- Authorization header -- it works with Firebase ID tokens once Firebase
-- is registered as a Third-Party Auth provider (Dashboard step). This is
-- NOT Supabase Auth/GoTrue; no session, no auth.users row, no Supabase
-- user is created or required for this to function.
create policy "Firebase users can view their own profile"
  on profiles for select
  to authenticated
  using ((select auth.jwt()->>'sub') = id);

create policy "Firebase users can create their own profile"
  on profiles for insert
  to authenticated
  with check ((select auth.jwt()->>'sub') = id);

create policy "Firebase users can update their own profile"
  on profiles for update
  to authenticated
  using ((select auth.jwt()->>'sub') = id);

-- =========================================================================
-- 3. TOPIC TAXONOMY -- unchanged content from the original 0008, just
--    re-homed into this file so the whole feature lives in one place.
-- =========================================================================

create table topic_groups (
  group_id text primary key,
  name text not null,
  description text,
  sort_order int not null
);

create table topics (
  topic_id uuid primary key default gen_random_uuid(),
  group_id text not null references topic_groups(group_id) on delete cascade,
  name text not null,
  sort_order int not null,
  unique (group_id, name)
);

create index idx_topics_group on topics(group_id);

alter table topic_groups enable row level security;
alter table topics enable row level security;

-- Public read: the interest taxonomy itself isn't user data -- no
-- identity check needed to see the list of topics that exist.
create policy "Public read access to topic_groups"
  on topic_groups for select
  using (true);

create policy "Public read access to topics"
  on topics for select
  using (true);

insert into topic_groups (group_id, name, description, sort_order) values
  ('technology', 'Technology', 'AI, gadgets, startups and more', 1),
  ('world_politics', 'World & Politics', 'Global events, geopolitics and more', 2),
  ('science', 'Science', 'Space, environment, research and more', 3),
  ('business_finance', 'Business & Finance', 'Markets, companies, economy and more', 4),
  ('lifestyle', 'Lifestyle', 'Health, travel, food, culture and more', 5),
  ('entertainment_gaming', 'Entertainment & Gaming', 'Movies, shows, anime, games and more', 6);

insert into topics (group_id, name, sort_order) values
  ('technology', 'AI', 1),
  ('technology', 'Startups', 2),
  ('technology', 'Gadgets', 3),
  ('technology', 'Internet', 4),

  ('world_politics', 'World', 1),
  ('world_politics', 'Politics', 2),
  ('world_politics', 'Economy', 3),
  ('world_politics', 'Society', 4),

  ('science', 'Space', 1),
  ('science', 'Environment', 2),
  ('science', 'Research', 3),
  ('science', 'Health', 4),

  ('business_finance', 'Business', 1),
  ('business_finance', 'Finance', 2),
  ('business_finance', 'Markets', 3),
  ('business_finance', 'Startups', 4),

  ('lifestyle', 'Health', 1),
  ('lifestyle', 'Travel', 2),
  ('lifestyle', 'Food', 3),
  ('lifestyle', 'Culture', 4),

  ('entertainment_gaming', 'Gaming', 1),
  ('entertainment_gaming', 'Movies & Shows', 2),
  ('entertainment_gaming', 'Anime & Manga', 3),
  ('entertainment_gaming', 'Music', 4);

-- =========================================================================
-- 4. PROFILE INTERESTS (join table)
-- =========================================================================

create table profile_interests (
  profile_id text not null references profiles(id) on delete cascade,
  topic_id uuid not null references topics(topic_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, topic_id)
);

create index idx_profile_interests_profile on profile_interests(profile_id);

alter table profile_interests enable row level security;

create policy "Firebase users can view their own interests"
  on profile_interests for select
  to authenticated
  using ((select auth.jwt()->>'sub') = profile_id);

create policy "Firebase users can set their own interests"
  on profile_interests for insert
  to authenticated
  with check ((select auth.jwt()->>'sub') = profile_id);

create policy "Firebase users can remove their own interests"
  on profile_interests for delete
  to authenticated
  using ((select auth.jwt()->>'sub') = profile_id);

-- =========================================================================
-- 5. PROFILE PREFERENCES
-- =========================================================================

create table profile_preferences (
  profile_id text primary key references profiles(id) on delete cascade,
  language text not null default 'en',
  morning_brief_enabled boolean not null default true,
  morning_brief_time time not null default '08:00',
  breaking_news_enabled boolean not null default true,
  recommended_stories_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table profile_preferences enable row level security;

create policy "Firebase users can view their own preferences"
  on profile_preferences for select
  to authenticated
  using ((select auth.jwt()->>'sub') = profile_id);

create policy "Firebase users can insert their own preferences"
  on profile_preferences for insert
  to authenticated
  with check ((select auth.jwt()->>'sub') = profile_id);

create policy "Firebase users can update their own preferences"
  on profile_preferences for update
  to authenticated
  using ((select auth.jwt()->>'sub') = profile_id);

-- =========================================================================
-- 6. USER STANZA INTERACTIONS (bookmarks, likes, etc.)
-- =========================================================================

create table user_stanza_interactions (
  profile_id text not null references profiles(id) on delete cascade,
  stanza_id uuid not null references stanzas(stanza_id) on delete cascade,
  interaction_type text not null check (interaction_type in ('bookmark', 'like')),
  created_at timestamptz not null default now(),
  primary key (profile_id, stanza_id, interaction_type)
);

alter table user_stanza_interactions enable row level security;

create policy "Firebase users can view their own interactions"
  on user_stanza_interactions for select
  to authenticated
  using ((select auth.jwt()->>'sub') = profile_id);

create policy "Firebase users can create their own interactions"
  on user_stanza_interactions for insert
  to authenticated
  with check ((select auth.jwt()->>'sub') = profile_id);

create policy "Firebase users can remove their own interactions"
  on user_stanza_interactions for delete
  to authenticated
  using ((select auth.jwt()->>'sub') = profile_id);

-- =========================================================================
-- updated_at maintenance
-- =========================================================================

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
  before update on profiles
  for each row
  execute function set_updated_at();

create trigger set_profile_preferences_updated_at
  before update on profile_preferences
  for each row
  execute function set_updated_at();

-- =========================================================================
-- NOT part of this migration:
--   - Registering Firebase as a Third-Party Auth provider (Supabase
--     Dashboard step -- required before auth.jwt() has anything to read).
--   - Any Flutter code.
-- =========================================================================
