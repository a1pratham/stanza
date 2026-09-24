import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/related_article.dart';
import '../models/stanza.dart';

/// Reads published Stanzas from the live Supabase pipeline and maps them
/// into the existing Stanza model.
///
/// PHASE 8 CHANGE: added `fetchRelatedCoverage()`. fetchFeed(), search(),
/// fetchByIds(), and _mapRow() are UNCHANGED from Phase 7, including the
/// `.order('articles(published_at)', ascending: false)` syntax that must
/// be preserved.
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

  /// PHASE 8 NEW: fetches other publishers' coverage of the same event as
  /// this Stanza's article, for the swipe-left "Related Coverage" sheet.
  ///
  /// Two queries rather than one large join: first resolve this stanza's
  /// article_id and, via event_sources, its event_id; then, only if an
  /// event exists, fetch every OTHER article linked to that event. Most
  /// stanzas belong to no event at all (most stories are only covered by
  /// one source), so this returns an empty list quickly and cheaply in
  /// the common case.
  Future<List<RelatedArticle>> fetchRelatedCoverage(String stanzaId) async {
    final stanzaRow = await _client
        .from('stanzas')
        .select('article_id')
        .eq('stanza_id', stanzaId)
        .maybeSingle();

    final articleId = stanzaRow?['article_id'] as String?;
    if (articleId == null) return [];

    final eventLink = await _client
        .from('event_sources')
        .select('event_id')
        .eq('article_id', articleId)
        .maybeSingle();

    final eventId = eventLink?['event_id'] as String?;
    if (eventId == null) return [];

    final rows = await _client
        .from('event_sources')
        .select('''
articles!inner (
  title,
  source_url,
  published_at,
  sources!inner ( name )
)
''')
        .eq('event_id', eventId)
        .neq('article_id', articleId);

    final related = <RelatedArticle>[];
    for (final row in rows) {
      final article = row['articles'];
      if (article is! Map<String, dynamic>) continue;

      final source = article['sources'];
      final sourceName = (source is Map<String, dynamic> ? source['name'] : null) as String?;
      final title = article['title'] as String?;
      if (title == null) continue;

      related.add(RelatedArticle(
        title: title,
        sourceName: sourceName ?? 'Unknown source',
        sourceUrl: article['source_url'] as String? ?? '',
        timeAgo: _formatTimeAgo(article['published_at'] as String?),
      ));
    }

    return related;
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
