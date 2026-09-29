import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/stanza.dart';
import '../services/analytics_service.dart';
import '../services/article_actions.dart';
import '../services/bookmark_store.dart';
import '../services/stanza_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/article_list_card.dart';
import '../widgets/related_coverage_sheet.dart';
import '../widgets/stanza_top_bar.dart';
import '../widgets/story_viewer.dart';

/// Search screen: wordmark, rounded search field and a list of story cards.
///
/// Before a search is run the list shows the latest stories; submitting a
/// query shows matching stories. Tapping a card opens the same swipeable
/// full-screen card experience used on Home, scoped to the list shown.
class SearchScreen extends StatefulWidget {
  final StanzaRepository repository;
  final Set<String> bookmarkedIds;
  final BookmarkStore bookmarkStore;
  final ValueChanged<Set<String>> onBookmarksChanged;

  const SearchScreen({
    super.key,
    required this.repository,
    required this.bookmarkedIds,
    required this.bookmarkStore,
    required this.onBookmarksChanged,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final AnalyticsService _analytics = AnalyticsService();
  List<Stanza> _latest = const [];
  List<Stanza> _results = const [];
  bool _isLoading = false;
  String? _error;
  bool _searched = false;
  late Set<String> _bookmarkedIds;

  @override
  void initState() {
    super.initState();
    _bookmarkedIds = widget.bookmarkedIds;
    _loadLatest();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Stanza> get _shown => _searched ? _results : _latest;

  Future<void> _loadLatest() async {
    if (!SupabaseConfig.isConfigured) return;
    setState(() => _isLoading = true);
    try {
      final latest = await widget.repository.fetchFeed();
      if (!mounted) return;
      setState(() {
        _latest = latest;
        _isLoading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      _clear();
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _searched = true;
    });

    try {
      final results = await widget.repository.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
      _analytics.logSearch(query, results.length);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _searched = false;
      _results = const [];
      _error = null;
    });
  }

  Future<void> _toggleBookmark(Stanza stanza) async {
    setState(() {
      if (_bookmarkedIds.contains(stanza.stanzaId)) {
        _bookmarkedIds = {..._bookmarkedIds}..remove(stanza.stanzaId);
      } else {
        _bookmarkedIds = {..._bookmarkedIds, stanza.stanzaId};
      }
    });
    await widget.bookmarkStore.save(_bookmarkedIds);
    widget.onBookmarksChanged(_bookmarkedIds);
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
    RelatedCoverageSheet.show(context, widget.repository, stanza.stanzaId);
    _analytics.logRelatedCoverageOpen(stanza.stanzaId);
  }

  void _openResult(int index) {
    StoryViewer.open(
      context,
      StoryViewer(
        stanzas: List<Stanza>.of(_shown),
        initialIndex: index,
        currentBookmarks: () => _bookmarkedIds,
        onBookmarkToggle: _toggleBookmark,
        onShare: _onShare,
        onOpenArticle: _openArticle,
        onSwipeLeft: _openRelatedCoverage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBottom,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.background),
        child: SafeArea(
          child: Column(
            children: [
              const StanzaTopBar(),
              const SizedBox(height: 14),
              _buildSearchField(),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Color(0xFFB5BCCB), size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                cursorColor: AppColors.accent,
                style: AppText.sans(size: 15.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search news, topics, places or people\u2026',
                  hintStyle: AppText.sans(size: 15.5, color: const Color(0xFF8E97A8)),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _clear,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, color: Color(0xFFB5BCCB), size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: AppText.sans(color: AppColors.textMuted)),
        ),
      );
    }

    final items = _shown;

    if (items.isEmpty) {
      return Center(
        child: Text(
          _searched ? 'No matching stories' : 'Search headlines and summaries',
          style: AppText.sans(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => ArticleListCard(
        stanza: items[index],
        onTap: () => _openResult(index),
      ),
    );
  }
}
