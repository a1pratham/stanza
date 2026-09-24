/// PHASE 8 NEW: one entry in a story's "Related Coverage" list.
///
/// Deliberately a separate, minimal class rather than adding fields to
/// Stanza — related articles don't have their own AI-generated summary
/// (they were skipped specifically because they're a duplicate of one
/// that does), so reusing the Stanza model would mean fields that don't
/// apply. Keeping this separate means zero changes to the Stanza model
/// or anything that already depends on its exact shape.
class RelatedArticle {
  final String title;
  final String sourceName;
  final String sourceUrl;
  final String timeAgo;

  const RelatedArticle({
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    required this.timeAgo,
  });
}
