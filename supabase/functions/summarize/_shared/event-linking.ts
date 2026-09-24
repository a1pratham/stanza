// Stanza Phase 8 -- event linking.
//
// When a near-duplicate article is found, this ensures both the original
// (canonical) article and the new duplicate are linked to the same event
// row, creating one lazily if the canonical article isn't in an event yet.

export async function linkArticlesToEvent(
  supabase: any,
  canonicalArticleId: string,
  duplicateArticleId: string,
  title: string,
  category: string,
): Promise<void> {
  // Does the canonical article already belong to an event? (True if this
  // is the third+ publisher covering the same story.)
  const { data: existingLink, error: lookupError } = await supabase
    .from('event_sources')
    .select('event_id')
    .eq('article_id', canonicalArticleId)
    .maybeSingle();

  if (lookupError) throw lookupError;

  let eventId: string;

  if (existingLink) {
    eventId = existingLink.event_id;
  } else {
    // First duplicate found for this story -- create the event now,
    // titled after the canonical (first-seen) article.
    const { data: newEvent, error: createError } = await supabase
      .from('events')
      .insert({ title, category })
      .select('event_id')
      .single();

    if (createError) throw createError;
    eventId = newEvent.event_id;

    const { error: linkCanonicalError } = await supabase
      .from('event_sources')
      .insert({ event_id: eventId, article_id: canonicalArticleId });

    if (linkCanonicalError) throw linkCanonicalError;
  }

  const { error: linkDuplicateError } = await supabase
    .from('event_sources')
    .insert({ event_id: eventId, article_id: duplicateArticleId });

  if (linkDuplicateError) throw linkDuplicateError;
}
