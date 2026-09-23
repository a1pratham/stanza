// Stanza Phase 3/7 -- Summarization Edge Function.
//
// Queries articles with status = 'pending_summary', calls the AI provider
// once per article, stores the result as a Stanza, and flips the article's
// status to 'summarized'.
//
// PHASE 7 CHANGES:
//   1. Why-it-matters is now generated (ai-provider.ts) and stored.
//   2. Before calling the AI, each article's title is compared against
//      recently published Stanzas in the same category. A near-duplicate
//      is marked 'duplicate_skipped' and never sent to the AI at all --
//      this also saves Groq quota, not just feed clutter.
//
// Everything else (atomic claim, batch size, insufficient-content skip,
// failure handling, ordering) is UNCHANGED from the deployed Phase 3
// version.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { summarizeArticle } from './_shared/ai-provider.ts';
import { isDuplicate, type RecentHeadline } from './_shared/duplicate-detection.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const BATCH_SIZE = 5;

/**
 * Loads recently published Stanzas' titles + categories once per
 * invocation, so duplicate-checking each article in the batch doesn't
 * require a separate query per article. 24h is generous here on purpose
 * -- the hourly cleanup job means this table realistically never holds
 * more than a day of news anyway, so this is effectively "everything
 * currently live."
 */
async function loadRecentHeadlines(supabase: any): Promise<RecentHeadline[]> {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const { data, error } = await supabase
    .from('stanzas')
    .select('articles!inner(title, category, published_at)')
    .eq('status', 'published')
    .gte('articles.published_at', cutoff);

  if (error) {
    console.error('Failed to load recent headlines for dedup check:', error.message);
    return []; // fail open: dedup is a nice-to-have, not worth blocking summarization
  }

  return (data ?? [])
    .map((row: any) => row.articles)
    .filter((a: any) => a?.title && a?.category)
    .map((a: any) => ({ title: a.title, category: a.category }));
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

    const results = { succeeded: 0, failed: 0, duplicatesSkipped: 0, errors: [] as string[] };

    for (const article of articles) {
      try {
        // Claim the article atomically before doing anything else. A
        // concurrent invocation may have selected the same pending
        // article, but only one invocation can change it from
        // pending_summary to summarizing. This prevents duplicate AI
        // generation for the SAME article (distinct from Phase 7's
        // cross-article duplicate detection below).
        const { data: claimed, error: claimError } = await supabase
          .from('articles')
          .update({ status: 'summarizing', updated_at: new Date().toISOString() })
          .eq('article_id', article.article_id)
          .eq('status', 'pending_summary')
          .select('article_id');

        if (claimError) throw claimError;
        if (!claimed || claimed.length === 0) {
          // Another summarizer invocation claimed this article first.
          continue;
        }

        // Skip anything too thin to summarize meaningfully rather than
        // risking a fabricated summary (spec section 26).
        if (!article.description || article.description.trim().length < 40) {
          await supabase
            .from('articles')
            .update({ status: 'skipped_insufficient_content', updated_at: new Date().toISOString() })
            .eq('article_id', article.article_id)
            .eq('status', 'summarizing');
          continue;
        }

        // PHASE 7: duplicate/near-identical story check, before spending
        // any AI quota. Compares this article's title against already
        // published stories in the same category.
        if (isDuplicate(article.title, article.category, recentHeadlines)) {
          await supabase
            .from('articles')
            .update({ status: 'duplicate_skipped', updated_at: new Date().toISOString() })
            .eq('article_id', article.article_id)
            .eq('status', 'summarizing');
          results.duplicatesSkipped += 1;
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

        // Own headline joins the in-memory recent list too, so later
        // articles in THIS SAME batch can be deduped against it without
        // waiting for the next invocation.
        recentHeadlines.push({ title: result.headline, category: article.category });

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
        `Duplicates skipped: ${results.duplicatesSkipped}, Failed: ${results.failed}`,
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
