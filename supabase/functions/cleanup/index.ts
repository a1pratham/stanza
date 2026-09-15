import { createClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const BATCH_SIZE = 500;

Deno.serve(async (_req) => {
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const cutoff = new Date(
      Date.now() - 24 * 60 * 60 * 1000,
    ).toISOString();

    const { data: articles, error: fetchError } = await supabase
      .from('articles')
      .select('article_id')
      .or(
        `published_at.lt.${cutoff},and(published_at.is.null,created_at.lt.${cutoff})`,
      )
      .limit(BATCH_SIZE);

    if (fetchError) throw fetchError;

    if (!articles || articles.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          deleted: 0,
          message: 'No articles older than 24 hours.',
        }),
        { headers: { 'Content-Type': 'application/json' } },
      );
    }

    const articleIds = articles.map((article) => article.article_id);

    // Delete Stanzas first because stanzas.article_id references articles.
    const { error: stanzaDeleteError } = await supabase
      .from('stanzas')
      .delete()
      .in('article_id', articleIds);

    if (stanzaDeleteError) throw stanzaDeleteError;

    // Now the corresponding articles can safely be deleted.
    const { error: articleDeleteError } = await supabase
      .from('articles')
      .delete()
      .in('article_id', articleIds);

    if (articleDeleteError) throw articleDeleteError;

    console.log(`Cleanup complete. Deleted ${articleIds.length} articles.`);

    return new Response(
      JSON.stringify({
        ok: true,
        deleted: articleIds.length,
      }),
      { headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Cleanup failed:', err);

    return new Response(
      JSON.stringify({
        ok: false,
        error: err.message,
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }
});