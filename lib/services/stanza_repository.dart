import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stanza.dart';

/// Reads published Stanzas from the live Supabase pipeline and maps them
/// into the EXISTING Stanza model.
///
/// This is the only file in lib/ that knows the database schema. All
/// snake_case -> camelCase conversion, the published_at -> timeAgo
/// formatting, and the joined source name are handled here, so the model,
/// the card and the mock data stay exactly as they were.
///
/// Reads use the public anon key against the read-only RLS policies
/// created in Phase 2/3. No authentication is performed or required.
class StanzaRepository {
  final SupabaseClient _client;

  StanzaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Selects the Stanza plus the article and source columns the card needs.
  ///
  /// `!inner` on both joins means a Stanza whose article (or that article's
  /// source) is missing is excluded rather than rendered with null
  /// metadata. This matters because the cleanup function deletes articles,
  /// so an orphaned Stanza could otherwise briefly appear.
  static const String _select = '''
stanza_id,
headline,
summary,
articles!inner (
  source_url,
  image_url,
  published_at,
  category,
  sources!inner (
    name
  )
)
''';

  /// Fetches the newest published Stanzas for the feed.
  ///
  /// Ordered by the article's published_at DESC so the freshest news is
  /// first, matching the summarizer's newest-first processing order.
  Future<List<Stanza>> fetchFeed({int limit = 50}) async {
    final rows = await _client
        .from('stanzas')
        .select(_select)
        .eq('status', 'published')
        .order('articles(published_at)', ascending: false)
        .limit(limit);

    final stanzas = <Stanza>[];

    for (final row in rows) {
      final mapped = _mapRow(row);
      // Defensive: skip any row that can't be mapped rather than letting
      // one malformed record take down the whole feed.
      if (mapped != null) stanzas.add(mapped);
    }

    return stanzas;
  }

  /// Maps one joined database row onto the existing Stanza model.
  /// Returns null if the row is missing data the card requires.
  Stanza? _mapRow(Map<String, dynamic> row) {
    final stanzaId = row['stanza_id'];
    final headline = row['headline'];
    final summary = row['summary'];

    if (stanzaId is! String || headline is! String || summary is! String) {
      return null;
    }

    // PostgREST returns a nested object (not a list) for a to-one
    // relationship, but guard the type anyway so an unexpected shape
    // degrades gracefully instead of throwing.
    final article = row['articles'];
    if (article is! Map<String, dynamic>) return null;

    final source = article['sources'];
    final sourceName = (source is Map<String, dynamic> ? source['name'] : null);

    return Stanza(
      stanzaId: stanzaId,
      // The existing card renders category with wide letter spacing and the
      // mock data is uppercase, so uppercase the database value to match.
      category: (article['category'] as String? ?? 'NEWS').toUpperCase(),
      headline: headline,
      summary: summary,
      // whyItMatters intentionally omitted: Phase 3 never populates it and
      // Phase 6 owns that feature. The model defaults it to ''.
      sourceName: sourceName as String? ?? 'Unknown source',
      sourceUrl: article['source_url'] as String? ?? '',
      timeAgo: _formatTimeAgo(article['published_at'] as String?),
      imageUrl: article['image_url'] as String?,
    );
  }

  /// Converts an ISO timestamp into the short relative string the existing
  /// model and card expect (e.g. "2h ago").
  static String _formatTimeAgo(String? isoTimestamp) {
    if (isoTimestamp == null) return '';

    final parsed = DateTime.tryParse(isoTimestamp);
    if (parsed == null) return '';

    final diff = DateTime.now().difference(parsed.toLocal());

    // Clock skew or a feed dated slightly in the future shouldn't render
    // as a negative duration.
    if (diff.isNegative) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
