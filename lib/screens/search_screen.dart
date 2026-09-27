import 'package:flutter/material.dart';
import '../models/stanza.dart';
import '../services/analytics_service.dart';
import '../services/article_actions.dart';
import '../services/bookmark_store.dart';
import '../services/stanza_repository.dart';
import '../widgets/related_coverage_sheet.dart';
import '../widgets/stanza_swipe_feed.dart';

/// PHASE 5 NEW: search screen.
///
/// Shows a text field and a simple result list (headline + source/time).
/// Tapping a result opens the same swipeable full-screen card experience
/// used on Home, scoped to the search results, via StanzaSwipeFeed.
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
  List<Stanza> _results = const [];
  bool _isLoading = false;
  String? _error;
  bool _searched = false;
  late Set<String> _bookmarkedIds;

  @override
  void initState() {
    super.initState();
    _bookmarkedIds = widget.bookmarkedIds;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                StanzaSwipeFeed(
                  stanzas: _results,
                  bookmarkedIds: _bookmarkedIds,
                  onBookmarkToggle: _toggleBookmark,
                  onShare: _onShare,
                  onOpenArticle: _openArticle,
                  onSwipeLeft: _openRelatedCoverage,
                  controller: PageController(initialPage: index),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search stories...',
            hintStyle: TextStyle(color: Colors.white38),
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _runSearch(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _runSearch,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amberAccent),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.white54)),
      );
    }

    if (!_searched) {
      return const Center(
        child: Text(
          'Search headlines and summaries',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('No matching stories', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final stanza = _results[index];
        return ListTile(
          onTap: () => _openResult(index),
          title: Text(
            stanza.headline,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${stanza.sourceName} · ${stanza.timeAgo}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: _bookmarkedIds.contains(stanza.stanzaId)
              ? const Icon(Icons.bookmark, color: Colors.amberAccent, size: 18)
              : null,
        );
      },
    );
  }
}
