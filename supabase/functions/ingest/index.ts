// Stanza Phase 2 — Ingestion Edge Function (Supabase, Deno runtime)
//
// Fetches each configured RSS feed, normalizes items into the ARTICLES
// shape, skips anything already stored (source_url is UNIQUE in Postgres,
// so we rely on that constraint rather than a separate existence check),
// and inserts new rows with status = 'pending_summary'.
//
// This function is triggered two ways:
//   1. Manually, by calling its URL directly (for testing).
//   2. On a schedule, via pg_cron + pg_net (see migrations/0002_schedule.sql).

import { createClient } from 'npm:@supabase/supabase-js@2';
import Parser from 'npm:rss-parser@3';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const parser = new Parser({ timeout: 10000 });

/** Strips HTML tags from RSS descriptions so downstream AI summarization
 * (Phase 3) gets clean text, not markup. */
function stripHtml(html: string | undefined): string {
  if (!html) return '';
  return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

/** Pulls an image URL out of common RSS enclosure/media field shapes. */
function extractImageUrl(item: any): string | null {
  if (item.enclosure?.url) return item.enclosure.url;
  if (item['media:content']?.$?.url) return item['media:content'].$.url;
  return null;
}

interface SourceRow {
  source_id: string;
  name: string;
  feed_url: string;
  category: string;
}

async function ingestSource(supabase: any, source: SourceRow) {
  let feed;
  try {
    feed = await parser.parseURL(source.feed_url);
  } catch (err) {
    console.error(`Failed to fetch feed for ${source.name} (${source.feed_url}):`, err.message);
    return { source: source.name, fetched: 0, added: 0, error: err.message };
  }

  const items = feed.items ?? [];
  let added = 0;

  for (const item of items) {
    const sourceUrl = item.link;
    if (!sourceUrl || !item.title) continue; // skip malformed entries

    const row = {
      source_id: source.source_id,
      title: item.title.trim(),
      source_url: sourceUrl,
      description: stripHtml(item.contentSnippet || item.content || item.summary),
      image_url: extractImageUrl(item),
      published_at: item.isoDate ?? new Date().toISOString(),
      category: source.category,
      status: 'pending_summary',
    };

    // The unique constraint on source_url is the dedup mechanism (spec
    // section 12, URL-level check). ignoreDuplicates makes repeat runs
    // a safe no-op instead of throwing an error.
    const { error, count } = await supabase
      .from('articles')
      .upsert(row, { onConflict: 'source_url', ignoreDuplicates: true, count: 'exact' });

    if (error) {
      console.error(`Insert failed for "${row.title}":`, error.message);
      continue;
    }
    if (count && count > 0) added += 1;
  }

  return { source: source.name, fetched: items.length, added };
}

Deno.serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: sources, error } = await supabase
      .from('sources')
      .select('source_id, name, feed_url, category')
      .eq('status', 'active');

    if (error) throw error;

    const results = [];
    for (const source of sources as SourceRow[]) {
      const result = await ingestSource(supabase, source);
      results.push(result);
    }

    const totalAdded = results.reduce((sum, r) => sum + r.added, 0);
    console.log(`Ingestion complete. New articles added: ${totalAdded}`);

    return new Response(JSON.stringify({ ok: true, totalAdded, results }, null, 2), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('Ingestion run failed:', err);
    return new Response(JSON.stringify({ ok: false, error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
