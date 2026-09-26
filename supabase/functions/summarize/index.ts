// Stanza Phase 3/7/8/9 -- Summarization Edge Function.
//
// PHASE 9 CHANGES:
//   1. Consistency check runs on every AI result before it's stored;
//      failures are flagged (flagged_for_review + flag_reason) but the
//      Stanza is still stored -- this is a sanity net, not a gate.
//   2. Source reliability_tier is now fetched and threaded through to
//      event-linking, so events prefer titles from more reliable sources.
//   3. Every invocation writes a pipeline_runs row (start + finish), so
//      run history is queryable in SQL instead of only in Dashboard Logs.
//
// Atomic claim, batch size, insufficient-content skip, why-it-matters
// generation, and per-article failure handling are all UNCHANGED from
// Phase 8.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { summarizeArticle } from './_shared/ai-provider.ts';
import { findDuplicateMatch, type RecentHeadline } from './_shared/duplicate-detection.ts';
import { linkArticlesToEvent } from './_shared/event-linking.ts';
import { checkConsistency } from './_shared/consistency-check.ts';
import { startRun, finishRun } from '../_shared/pipeline-logger.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const BATCH_SIZE = 5;

async function loadRecentHeadlines(supabase: any): Promise<RecentHeadline[]> {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('stanzas')
    .select(`
      articles!inner (
        article_id, title, category, published_at,
        sources!inner ( reliability_tier )
      )
    `)
    .eq('status', 'published')
    .gte('articles.published_at', cutoff);

  if (error) {
    console.error('Failed to load recent headlines for dedup check:', error.message);
    return [];
  }

  return (data ?? [])
    .map((row: any) => row.articles)
    .filter((a: any) => a?.article_id && a?.title && a?.category)
    .map((a: any) => ({
      articleId: a.article_id,
      title: a.title,
      category: a.category,
      reliabilityTier: a.sources?.reliability_tier ?? 1,
    }));
}

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const run = await startRun(supabase, 'summarize');

  try {
    const { data: articles, error: fetchError } = await supabase
      .from('articles')
      .select('article_id, title, description, category, source_id, sources(name, reliability_tier)')
      .eq('status', 'pending_summary')
      .order('published_at', { ascending: false })
      .limit(BATCH_SIZE);

    if (fetchError) throw fetchError;

    if (!articles || articles.length === 0) {
      await finishRun(supabase, run, { succeeded: 0, failed: 0, skipped: 0 });
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
      flagged: 0,
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

        const articleTier = (article as any).sources?.reliability_tier ?? 1;

        const match = findDuplicateMatch(article.title, article.category, recentHeadlines);

        if (match) {
          try {
            await linkArticlesToEvent(
              supabase,
              { articleId: match.articleId, title: match.title, reliabilityTier: match.reliabilityTier },
              { articleId: article.article_id, title: article.title, reliabilityTier: articleTier },
              article.category,
            );
          } catch (linkErr) {
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

        // PHASE 9: consistency check before storing. A flag never blocks
        // storage -- it's a signal for later spot-checking, not a gate.
        const check = checkConsistency({
          articleTitle: article.title,
          articleDescription: article.description,
          summary: result.summary,
          headline: result.headline,
          wordCount: result.wordCount,
        });

        if (check.flagged) results.flagged += 1;

        const { error: insertError } = await supabase.from('stanzas').insert({
          article_id: article.article_id,
          headline: result.headline,
          summary: result.summary,
          why_it_matters: result.whyItMatters,
          word_count: result.wordCount,
          model_version: result.modelVersion,
          flagged_for_review: check.flagged,
          flag_reason: check.reason,
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
          reliabilityTier: articleTier,
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
        `Duplicates linked: ${results.duplicatesLinked}, Flagged: ${results.flagged}, ` +
        `Failed: ${results.failed}`,
    );

    await finishRun(supabase, run, {
      succeeded: results.succeeded,
      failed: results.failed,
      skipped: results.duplicatesLinked,
      details: { flagged: results.flagged, errors: results.errors },
    });

    return new Response(
      JSON.stringify({ ok: true, processed: articles.length, ...results }, null, 2),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Summarization run failed:', err);
    await finishRun(supabase, run, { error: err.message });
    return new Response(JSON.stringify({ ok: false, error: err.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
