import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PHASE 10 NEW: lightweight research/behavioral instrumentation.
///
/// Logs the metrics spec section 41 asks for, to the extent a live
/// single-arm app can capture them without a formal controlled study:
///   - reading time (per-story view duration)
///   - consumption volume (stories viewed per session)
///   - engagement (bookmarks, shares, article opens, related-coverage
///     opens, searches)
///
/// This does NOT implement the 3-group comparison experiment (spec
/// section 40) or comprehension/retention quizzes (section 42) -- those
/// require distinct participant groups and a consent flow, which is a
/// separate research-study build, not something to fold into the
/// production app's data model.
///
/// Fire-and-forget by design: a failed analytics write should never
/// interrupt the person's reading experience, so every call swallows its
/// own errors after a single console log.
class AnalyticsService {
  final SupabaseClient _client;

  AnalyticsService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  /// One session per app launch, shared across every AnalyticsService
  /// instance in this process (Feed/Search/Saved each construct their
  /// own instance, but they should all attribute events to the same
  /// session). Computed lazily, once, on first access.
  static String? _sessionId;
  static String get _session {
    _sessionId ??= _generateSessionId();
    return _sessionId!;
  }

  static String _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = random.nextInt(1 << 32).toRadixString(16);
    return '$timestamp-$suffix';
  }

  Future<void> _log(String eventType, {String? stanzaId, Map<String, dynamic>? metadata}) async {
    try {
      await _client.from('analytics_events').insert({
        'session_id': _session,
        'event_type': eventType,
        'stanza_id': stanzaId,
        'metadata': metadata,
      });
    } catch (err) {
      // Deliberately swallowed -- see class doc. A missing analytics row
      // is not worth interrupting anything the person is doing.
      // ignore: avoid_print
      print('AnalyticsService: failed to log "$eventType": $err');
    }
  }

  /// Reading time: how long a given Stanza was the visible card before
  /// the person swiped away from it.
  void logStoryView(String stanzaId, Duration viewDuration) {
    _log('story_view', stanzaId: stanzaId, metadata: {
      'duration_ms': viewDuration.inMilliseconds,
    });
  }

  void logBookmarkToggle(String stanzaId, bool nowBookmarked) {
    _log('bookmark_toggle', stanzaId: stanzaId, metadata: {'bookmarked': nowBookmarked});
  }

  void logShare(String stanzaId) {
    _log('share', stanzaId: stanzaId);
  }

  void logArticleOpen(String stanzaId) {
    _log('article_open', stanzaId: stanzaId);
  }

  void logRelatedCoverageOpen(String stanzaId) {
    _log('related_coverage_open', stanzaId: stanzaId);
  }

  void logSearch(String query, int resultCount) {
    _log('search', metadata: {'query': query, 'result_count': resultCount});
  }

  void logCategoryFilter(String category) {
    _log('category_filter', metadata: {'category': category});
  }
}
