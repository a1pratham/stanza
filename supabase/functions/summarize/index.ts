// Stanza Phase 3 -- Summarization Edge Function. (NEW FILE)
//
// Queries articles with status = 'pending_summary', calls the AI provider
// once per article, stores the result as a Stanza, and flips the article's
// status to 'summarized'.
//
// This implements spec section 15: "AI should not run on every user
// request." It runs on a schedule, and the resulting Stanza is then read
// by every user for free with no further AI calls (spec section 30).
//
// Scope note: this phase does NOT generate "why it matters" -- that's
// Phase 6. See _shared/ai-provider.ts.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { summarizeArticle } from './_shared/ai-provider.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

// Caps how many articles one invocation processes, so a backlog doesn't
// hit the function's execution time limit or the AI provider's per-minute
// rate limit in one burst.
const BATCH_SIZE = 5;

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const { data: articles, error: fetchError } = await supabase
      .from('articles')
      .select('article_id, title, description, source_id, sources(name)')
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

    const results = { succeeded: 0, failed: 0, errors: [] as string[] };

    for (const article of articles) {
      try {
        // Claim the article atomically before calling the AI provider. A
        // concurrent invocation may have selected the same pending article,
        // but only one invocation can change it from pending_summary to
        // summarizing. This prevents duplicate AI generation.
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

        const sourceName = (article as any).sources?.name ?? 'Unknown source';

        const result = await summarizeArticle({
          title: article.title,
          description: article.description,
          sourceName,
        });

        // why_it_matters is intentionally omitted -- Phase 6 scope, and the
        // column defaults to NULL, which is exactly what we want here.
        const { error: insertError } = await supabase.from('stanzas').insert({
          article_id: article.article_id,
          headline: result.headline,
          summary: result.summary,
          word_count: result.wordCount,
          model_version: result.modelVersion,
        });

        if (insertError) throw insertError;

        await supabase
          .from('articles')
          .update({ status: 'summarized', updated_at: new Date().toISOString() })
          .eq('article_id', article.article_id);

        results.succeeded += 1;
      } catch (err) {
        console.error(`Failed to summarize article ${article.article_id}:`, err.message);
        results.failed += 1;
        results.errors.push(`${article.article_id}: ${err.message}`);

        // Mark as failed rather than leaving it stuck in 'pending_summary'
        // forever -- otherwise it gets retried (and re-burns quota) every run.
        await supabase
          .from('articles')
          .update({ status: 'summary_failed', updated_at: new Date().toISOString() })
          .eq('article_id', article.article_id)
          .eq('status', 'summarizing');
      }
    }

    console.log(`Summarization complete. Succeeded: ${results.succeeded}, Failed: ${results.failed}`);

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
