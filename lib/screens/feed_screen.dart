import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/stanza.dart';
import '../services/analytics_service.dart';
import '../services/article_actions.dart';
import '../services/bookmark_store.dart';
import '../services/stanza_repository.dart';
import '../widgets/related_coverage_sheet.dart';
import '../widgets/stanza_swipe_feed.dart';
import 'saved_screen.dart';
import 'search_screen.dart';

/// The Home Feed screen.
///
/// PHASE 5 CHANGE: adds a category filter chip row and Search/Saved entry
/// points (a slim top bar over the feed), and bookmarks now persist via
/// BookmarkStore instead of living only in memory.
///
/// PHASE 6 CHANGE: swipe-right now opens a real in-app browser tab and
/// share now opens the real platform share sheet, both via
/// ArticleActions, replacing the Phase 1-4 bottom-sheet/SnackBar
/// placeholders.
///
/// UNCHANGED: data loading via StanzaRepository.fetchFeed() (Phase 4),
/// swipe gesture thresholds, and StanzaCard itself — all still live
/// inside StanzaSwipeFeed, reused as-is.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final StanzaRepository _repository = StanzaRepository();
  final BookmarkStore _bookmarkStore = BookmarkStore();
  final AnalyticsService _analytics = AnalyticsService();

  List<Stanza> _stanzas = const [];
  Set<String> _bookmarkedIds = {};
  String _selectedCategory = 'All';

  bool _isLoading = true;
  String? _error;

  // PHASE 10: tracks reading time for the currently-visible card.
  DateTime? _currentCardShownAt;
  String? _currentStanzaId;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _flushCurrentCardDuration();
    super.dispose();
  }

  /// PHASE 10: logs how long the previously-visible card was on screen,
  /// then starts timing the new one. Called on every page change and once
  /// more on dispose, so the last card viewed in a session is still
  /// counted.
  void _flushCurrentCardDuration() {
    final shownAt = _currentCardShownAt;
    final stanzaId = _currentStanzaId;
    if (shownAt != null && stanzaId != null) {
      _analytics.logStoryView(stanzaId, DateTime.now().difference(shownAt));
    }
  }

  void _onPageChanged(int index) {
    _flushCurrentCardDuration();
    final visible = _visibleStanzas;
    if (index >= 0 && index < visible.length) {
      _currentStanzaId = visible[index].stanzaId;
      _currentCardShownAt = DateTime.now();
    } else {
      _currentStanzaId = null;
      _currentCardShownAt = null;
    }
  }

  Future<void> _loadBookmarks() async {
    final ids = await _bookmarkStore.load();
    if (!mounted) return;
    setState(() => _bookmarkedIds = ids);
  }

  Future<void> _loadFeed() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() {
        _isLoading = false;
        _error =
            'SUPABASE_ANON_KEY was not provided at build time.\n'
            'Run with --dart-define=SUPABASE_ANON_KEY=your-key.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stanzas = await _repository.fetchFeed();
      if (!mounted) return;
      setState(() {
        _stanzas = stanzas;
        _isLoading = false;
      });
      // PHASE 10: start timing the first card, same as _onPageChanged does
      // for subsequent ones.
      _flushCurrentCardDuration();
      if (stanzas.isNotEmpty) {
        _currentStanzaId = stanzas.first.stanzaId;
        _currentCardShownAt = DateTime.now();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  /// Categories are derived from whatever is actually in the loaded feed,
  /// so the chip row never shows a category with zero live stories.
  List<String> get _availableCategories {
    final set = <String>{'All'};
    for (final s in _stanzas) {
      set.add(s.category);
    }
    return set.toList();
  }

  List<Stanza> get _visibleStanzas {
    if (_selectedCategory == 'All') return _stanzas;
    return _stanzas.where((s) => s.category == _selectedCategory).toList();
  }

  Future<void> _toggleBookmark(Stanza stanza) async {
    final nowBookmarked = !_bookmarkedIds.contains(stanza.stanzaId);
    setState(() {
      if (_bookmarkedIds.contains(stanza.stanzaId)) {
        _bookmarkedIds = {..._bookmarkedIds}..remove(stanza.stanzaId);
      } else {
        _bookmarkedIds = {..._bookmarkedIds, stanza.stanzaId};
      }
    });
    await _bookmarkStore.save(_bookmarkedIds);
    _analytics.logBookmarkToggle(stanza.stanzaId, nowBookmarked);
  }

  void _onShare(Stanza stanza) {
    ArticleActions.share(stanza);
    _analytics.logShare(stanza.stanzaId);
  }

  void _openArticle(Stanza stanza) {
    ArticleActions.openArticle(context, stanza);
    _analytics.logArticleOpen(stanza.stanzaId);
  }

  void _openRelatedCoverage(Stanza stanza) {
    RelatedCoverageSheet.show(context, _repository, stanza.stanzaId);
    _analytics.logRelatedCoverageOpen(stanza.stanzaId);
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          repository: _repository,
          bookmarkedIds: _bookmarkedIds,
          bookmarkStore: _bookmarkStore,
          onBookmarksChanged: (ids) => setState(() => _bookmarkedIds = ids),
        ),
      ),
    );
  }

  Future<void> _openSaved() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedScreen(
          repository: _repository,
          bookmarkedIds: _bookmarkedIds,
          bookmarkStore: _bookmarkStore,
          onBookmarksChanged: (ids) => setState(() => _bookmarkedIds = ids),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBody(),
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              IconButton(
                onPressed: _openSearch,
                icon: const Icon(Icons.search, color: Colors.white),
              ),
              IconButton(
                onPressed: _openSaved,
                icon: const Icon(Icons.bookmark, color: Colors.white),
              ),
            ],
          ),
          if (!_isLoading && _error == null && _stanzas.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _availableCategories.map((category) {
                  final selected = category == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                        // PHASE 10: category change swaps to a fresh
                        // PageView starting at index 0 (see the ValueKey
                        // on StanzaSwipeFeed below), so reading-time
                        // tracking needs to restart the same way it does
                        // on initial load.
                        _flushCurrentCardDuration();
                        final visible = _visibleStanzas;
                        if (visible.isNotEmpty) {
                          _currentStanzaId = visible.first.stanzaId;
                          _currentCardShownAt = DateTime.now();
                        } else {
                          _currentStanzaId = null;
                          _currentCardShownAt = null;
                        }
                        _analytics.logCategoryFilter(category);
                      },
                      backgroundColor: const Color(0xFF181818),
                      selectedColor: Colors.amberAccent,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amberAccent),
      );
    }

    if (_error != null) {
      return _FeedMessage(
        icon: Icons.cloud_off,
        title: "Couldn't load news",
        message: _error!,
        onRetry: _loadFeed,
      );
    }

    final visible = _visibleStanzas;

    if (visible.isEmpty) {
      return _FeedMessage(
        icon: Icons.article_outlined,
        title: _stanzas.isEmpty ? 'No stories yet' : 'No stories in this category',
        message: _stanzas.isEmpty
            ? 'No published Stanzas were found. The pipeline may still be generating them.'
            : 'Try a different category.',
        onRetry: _loadFeed,
      );
    }

    return StanzaSwipeFeed(
      key: ValueKey(_selectedCategory), // fresh PageController per filter
      stanzas: visible,
      bookmarkedIds: _bookmarkedIds,
      onBookmarkToggle: _toggleBookmark,
      onShare: _onShare,
      onOpenArticle: _openArticle,
      onSwipeLeft: _openRelatedCoverage,
      onPageChanged: _onPageChanged,
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white24, size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
