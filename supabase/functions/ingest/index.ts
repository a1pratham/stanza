// Stanza Phase 2 -- Ingestion Edge Function (Supabase, Deno runtime)
//
// PHASE 9 CHANGE: wraps the run with startRun()/finishRun() so every
// invocation is logged to pipeline_runs, queryable in SQL. This is the
// ONLY change in this file -- feed fetching, normalization, image
// extraction, and the dedup upsert are all byte-identical to the
// currently deployed version.

import { createClient } from 'npm:@supabase/supabase-js@2';
import Parser from 'npm:rss-parser@3';
import { startRun, finishRun } from '../_shared/pipeline-logger.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const parser = new Parser({
  timeout: 10000,
  customFields: {
    item: [
      ['media:content', 'mediaContent', { keepArray: true }],
      ['media:thumbnail', 'mediaThumbnail', { keepArray: true }],
    ],
  },
});

function stripHtml(html: string | undefined): string {
  if (!html) return '';
  return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
}

function extractImageUrl(item: any): string | null {
  if (item.enclosure?.url) return item.enclosure.url;

  const mediaContent = item.mediaContent?.[0]?.$?.url;
  if (mediaContent) return mediaContent;

  const mediaThumbnail = item.mediaThumbnail?.[0]?.$?.url;
  if (mediaThumbnail) return mediaThumbnail;

  const htmlSource = item['content:encoded'] || item.content || item.contentSnippet;
  if (htmlSource) {
    const match = /<img[^>]+src="([^">]+)"/i.exec(htmlSource);
    if (match) return match[1];
  }

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
    if (!sourceUrl || !item.title) continue;

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
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const run = await startRun(supabase, 'ingest');

  try {
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

    await finishRun(supabase, run, { succeeded: totalAdded, details: { results } });

    return new Response(JSON.stringify({ ok: true, totalAdded, results }, null, 2), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('Ingestion run failed:', err);
    await finishRun(supabase, run, { error: err.message });
    return new Response(JSON.stringify({ ok: false, error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
