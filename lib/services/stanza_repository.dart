import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stanza.dart';

/// Reads published Stanzas from the live Supabase pipeline and maps them
/// into the existing Stanza model.
///
/// PHASE 5 CHANGE: added `search()` and `fetchByIds()`. `fetchFeed()` and
/// `_select`/`_mapRow` are UNCHANGED from Phase 4.
class StanzaRepository {
  final SupabaseClient _client;

  StanzaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

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
      if (mapped != null) stanzas.add(mapped);
    }
    return stanzas;
  }

  /// PHASE 5 NEW: live text search over headline + summary.
  ///
  /// Two separate ilike queries (rather than a single `.or()` across a
  /// joined table) because PostgREST's `.or()` filter syntax does not
  /// reliably combine columns from the base table with columns from a
  /// nested relationship in one expression. Results are merged and
  /// de-duplicated by stanza_id client-side, which is fine at this data
  /// volume (24-hour retention keeps the table small).
  Future<List<Stanza>> search(String query, {int limit = 30}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final pattern = '%$trimmed%';

    final headlineRows = await _client
        .from('stanzas')
        .select(_select)
        .eq('status', 'published')
        .ilike('headline', pattern)
        .order('articles(published_at)', ascending: false)
        .limit(limit);

    final summaryRows = await _client
        .from('stanzas')
        .select(_select)
        .eq('status', 'published')
        .ilike('summary', pattern)
        .order('articles(published_at)', ascending: false)
        .limit(limit);

    final seen = <String>{};
    final results = <Stanza>[];

    for (final row in [...headlineRows, ...summaryRows]) {
      final mapped = _mapRow(row);
      if (mapped == null || seen.contains(mapped.stanzaId)) continue;
      seen.add(mapped.stanzaId);
      results.add(mapped);
    }

    return results;
  }

  /// PHASE 5 NEW: fetches specific Stanzas by ID, for the Saved screen.
  /// A bookmarked ID whose Stanza has since been removed by the 24-hour
  /// cleanup job is simply absent from the result — the caller (Saved
  /// screen) treats that as "no longer available" rather than an error.
  Future<List<Stanza>> fetchByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final rows = await _client
        .from('stanzas')
        .select(_select)
        .eq('status', 'published')
        .inFilter('stanza_id', ids);

    final stanzas = <Stanza>[];
    for (final row in rows) {
      final mapped = _mapRow(row);
      if (mapped != null) stanzas.add(mapped);
    }
    return stanzas;
  }

  Stanza? _mapRow(Map<String, dynamic> row) {
    final stanzaId = row['stanza_id'];
    final headline = row['headline'];
    final summary = row['summary'];

    if (stanzaId is! String || headline is! String || summary is! String) {
      return null;
    }

    final article = row['articles'];
    if (article is! Map<String, dynamic>) return null;

    final source = article['sources'];
    final sourceName =
    (source is Map<String, dynamic> ? source['name'] : null);

    return Stanza(
      stanzaId: stanzaId,
      category: (article['category'] as String? ?? 'NEWS').toUpperCase(),
      headline: headline,
      summary: summary,
      sourceName: sourceName as String? ?? 'Unknown source',
      sourceUrl: article['source_url'] as String? ?? '',
      timeAgo: _formatTimeAgo(article['published_at'] as String?),
      imageUrl: article['image_url'] as String?,
    );
  }

  static String _formatTimeAgo(String? isoTimestamp) {
    if (isoTimestamp == null) return '';
    final parsed = DateTime.tryParse(isoTimestamp);
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.isNegative) return 'just now';
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}