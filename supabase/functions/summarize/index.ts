// Stanza Phase 3/7/8 -- Summarization Edge Function.
//
// PHASE 8 CHANGE: a near-duplicate article is no longer just discarded.
// It's linked, along with its canonical (first-seen) article, into an
// `events` row via event_sources -- this is what powers the Flutter
// app's "Related Coverage" (swipe left). The article is still marked
// 'duplicate_skipped' and still never gets its own Stanza/AI call --
// only the linking behavior around that is new.
//
// Everything else (atomic claim, batch size, insufficient-content skip,
// why-it-matters generation, failure handling, ordering) is UNCHANGED
// from the deployed Phase 7 version.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { summarizeArticle } from './_shared/ai-provider.ts';
import { findDuplicateMatch, type RecentHeadline } from './_shared/duplicate-detection.ts';
import { linkArticlesToEvent } from './_shared/event-linking.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const BATCH_SIZE = 5;

/**
 * Loads recently published Stanzas' article_id + title + category once
 * per invocation. UNCHANGED in purpose from Phase 7; now also returns
 * article_id so a match can be linked via event_sources.
 */
async function loadRecentHeadlines(supabase: any): Promise<RecentHeadline[]> {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('stanzas')
    .select('articles!inner(article_id, title, category, published_at)')
    .eq('status', 'published')
    .gte('articles.published_at', cutoff);

  if (error) {
    console.error('Failed to load recent headlines for dedup check:', error.message);
    return [];
  }

  return (data ?? [])
    .map((row: any) => row.articles)
    .filter((a: any) => a?.article_id && a?.title && a?.category)
    .map((a: any) => ({ articleId: a.article_id, title: a.title, category: a.category }));
}

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const { data: articles, error: fetchError } = await supabase
      .from('articles')
      .select('article_id, title, description, category, source_id, sources(name)')
      .eq('status', 'pending_summary')
      .order('published_at', { ascending: false })
      .limit(BATCH_SIZE);

    if (fetchError) throw fetchError;

    if (!articles || articles.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, processed: 0, message: 'No articles pending summary.' }),
        { headers: { 'Content-Type': 'application/json' } },
      );
    }

    const recentHeadlines = await loadRecentHeadlines(supabase);

    const results = {
      succeeded: 0,
      failed: 0,
      duplicatesLinked: 0,
      errors: [] as string[],
    };

    for (const article of articles) {
      try {
        const { data: claimed, error: claimError } = await supabase
          .from('articles')
          .update({ status: 'summarizing', updated_at: new Date().toISOString() })
          .eq('article_id', article.article_id)
          .eq('status', 'pending_summary')
          .select('article_id');

        if (claimError) throw claimError;
        if (!claimed || claimed.length === 0) continue;

        if (!article.description || article.description.trim().length < 40) {
          await supabase
            .from('articles')
            .update({ status: 'skipped_insufficient_content', updated_at: new Date().toISOString() })
            .eq('article_id', article.article_id)
            .eq('status', 'summarizing');
          continue;
        }

        // PHASE 8: find a near-duplicate; if found, link both articles to
        // an event instead of just discarding this one.
        const matchedArticleId = findDuplicateMatch(article.title, article.category, recentHeadlines);

        if (matchedArticleId) {
          try {
            await linkArticlesToEvent(
              supabase,
              matchedArticleId,
              article.article_id,
              article.title,
              article.category,
            );
          } catch (linkErr) {
            // Event linking failing shouldn't block marking the article as
            // a duplicate -- worst case, this one story is a standalone
            // duplicate_skipped article with no Related Coverage entry,
            // which is no worse than Phase 7's behavior.
            console.error(
              `Event linking failed for article ${article.article_id}:`,
              linkErr.message,
            );
          }

          await supabase
            .from('articles')
            .update({ status: 'duplicate_skipped', updated_at: new Date().toISOString() })
            .eq('article_id', article.article_id)
            .eq('status', 'summarizing');
          results.duplicatesLinked += 1;
          continue;
        }

        const sourceName = (article as any).sources?.name ?? 'Unknown source';

        const result = await summarizeArticle({
          title: article.title,
          description: article.description,
          sourceName,
        });

        const { error: insertError } = await supabase.from('stanzas').insert({
          article_id: article.article_id,
          headline: result.headline,
          summary: result.summary,
          why_it_matters: result.whyItMatters,
          word_count: result.wordCount,
          model_version: result.modelVersion,
        });

        if (insertError) throw insertError;

        await supabase
          .from('articles')
          .update({ status: 'summarized', updated_at: new Date().toISOString() })
          .eq('article_id', article.article_id);

        recentHeadlines.push({
          articleId: article.article_id,
          title: result.headline,
          category: article.category,
        });

        results.succeeded += 1;
      } catch (err) {
        console.error(`Failed to summarize article ${article.article_id}:`, err.message);
        results.failed += 1;
        results.errors.push(`${article.article_id}: ${err.message}`);

        await supabase
          .from('articles')
          .update({ status: 'summary_failed', updated_at: new Date().toISOString() })
          .eq('article_id', article.article_id)
          .eq('status', 'summarizing');
      }
    }

    console.log(
      `Summarization complete. Succeeded: ${results.succeeded}, ` +
        `Duplicates linked: ${results.duplicatesLinked}, Failed: ${results.failed}`,
    );

    return new Response(
      JSON.stringify({ ok: true, processed: articles.length, ...results }, null, 2),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Summarization run failed:', err);
    return new Response(JSON.stringify({ ok: false, error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
