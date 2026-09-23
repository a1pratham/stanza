import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/stanza.dart';

/// Reads published Stanzas from the live Supabase pipeline and maps them
/// into the existing Stanza model.
///
/// PHASE 7 CHANGE: `_select` and `_mapRow` now also fetch and map
/// `why_it_matters`, since Phase 7's summarizer finally populates it.
/// This is the ONLY change in this file — fetchFeed(), search(), and
/// fetchByIds() are otherwise identical to Phase 5, including the
/// corrected `.order('articles(published_at)', ascending: false)` syntax
/// that must be preserved per the current project state.
class StanzaRepository {
  final SupabaseClient _client;

  StanzaRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String _select = '''
stanza_id,
headline,
summary,
why_it_matters,
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
    final sourceName = (source is Map<String, dynamic> ? source['name'] : null);

    // PHASE 7: why_it_matters may now be a real string, or still null for
    // older articles summarized before this phase deployed, or for
    // stories the AI judged to have no broader significance. The model's
    // default ('') keeps the card's existing unconditional rendering
    // working either way — an empty string just renders an empty line,
    // same as it always has for every card until now.
    final whyItMatters = row['why_it_matters'] as String?;

    return Stanza(
      stanzaId: stanzaId,
      category: (article['category'] as String? ?? 'NEWS').toUpperCase(),
      headline: headline,
      summary: summary,
      whyItMatters: whyItMatters ?? '',
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
