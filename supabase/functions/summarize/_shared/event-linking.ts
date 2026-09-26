// Stanza Phase 8/9 -- event linking.
//
// PHASE 9 CHANGE: now source-quality aware. When a duplicate comes from
// a more reliable source (lower reliability_tier number) than whichever
// source's title the event currently uses, the event's title is
// upgraded. This directly implements spec section 25's "prefer reliable
// and established sources" using Phase 8's clustering as the mechanism.
// Linking logic itself (find-or-create event, link both articles) is
// unchanged from Phase 8.

export interface ArticleForLinking {
  articleId: string;
  title: string;
  reliabilityTier: number;
}

export async function linkArticlesToEvent(
  supabase: any,
  canonical: ArticleForLinking,
  duplicate: ArticleForLinking,
  category: string,
): Promise<void> {
  const { data: existingLink, error: lookupError } = await supabase
    .from('event_sources')
    .select('event_id')
    .eq('article_id', canonical.articleId)
    .maybeSingle();

  if (lookupError) throw lookupError;

  let eventId: string;

  if (existingLink) {
    eventId = existingLink.event_id;

    // PHASE 9: check whether the duplicate's source outranks whichever
    // source currently supplies the event's title.
    const { data: event, error: eventFetchError } = await supabase
      .from('events')
      .select('title_source_tier')
      .eq('event_id', eventId)
      .single();

    if (eventFetchError) throw eventFetchError;

    const currentTier = event?.title_source_tier ?? 999;
    if (duplicate.reliabilityTier < currentTier) {
      const { error: titleUpdateError } = await supabase
        .from('events')
        .update({
          title: duplicate.title,
          title_source_tier: duplicate.reliabilityTier,
          updated_at: new Date().toISOString(),
        })
        .eq('event_id', eventId);

      if (titleUpdateError) throw titleUpdateError;
    }
  } else {
    // First duplicate found for this story -- create the event now.
    // Title starts from whichever of the two (canonical or duplicate) is
    // from the more reliable source, not automatically the canonical one.
    const useDuplicateTitle = duplicate.reliabilityTier < canonical.reliabilityTier;
    const initialTitle = useDuplicateTitle ? duplicate.title : canonical.title;
    const initialTier = useDuplicateTitle ? duplicate.reliabilityTier : canonical.reliabilityTier;

    const { data: newEvent, error: createError } = await supabase
      .from('events')
      .insert({ title: initialTitle, category, title_source_tier: initialTier })
      .select('event_id')
      .single();

    if (createError) throw createError;
    eventId = newEvent.event_id;

    const { error: linkCanonicalError } = await supabase
      .from('event_sources')
      .insert({ event_id: eventId, article_id: canonical.articleId });

    if (linkCanonicalError) throw linkCanonicalError;
  }

  const { error: linkDuplicateError } = await supabase
    .from('event_sources')
    .insert({ event_id: eventId, article_id: duplicate.articleId });

  if (linkDuplicateError) throw linkDuplicateError;
}
