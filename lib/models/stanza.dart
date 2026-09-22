/// Immutable domain model for a feed Stanza.
///
/// PHASE 4 CHANGE — deliberately minimal and backward compatible:
///   * All existing field names, types and order are UNCHANGED.
///   * The constructor is still `const`, so `mock_stanzas.dart`'s
///     `const List<Stanza>` still compiles.
///   * `whyItMatters` changed from `required` to defaulted (`= ''`).
///     Existing callers that pass it (all of mock_stanzas.dart) are
///     unaffected; the repository can now omit it, because Phase 3 does
///     not generate why-it-matters and the database column is always NULL.
///     Supplying an empty string rather than fabricating text keeps the
///     app honest about what the pipeline actually produced.
///
/// No new required fields were added, and nothing was removed or renamed.
/// Database-to-model conversion (published_at -> timeAgo, snake_case ->
/// camelCase, joined source name) happens in StanzaRepository, not here.
class Stanza {
  final String stanzaId;
  final String category;
  final String headline;
  final String summary;
  final String whyItMatters;
  final String sourceName;
  final String sourceUrl;
  final String timeAgo;
  final String? imageUrl;

  const Stanza({
    required this.stanzaId,
    required this.category,
    required this.headline,
    required this.summary,
    this.whyItMatters = '',
    required this.sourceName,
    required this.sourceUrl,
    required this.timeAgo,
    this.imageUrl,
  });
}
