import 'package:flutter/material.dart';
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
import 'search_screen.dart';

/// Saved screen — bookmarked Stanzas as a list of cards.
///
/// A bookmarked ID whose Stanza was removed by the 24-hour cleanup job
/// simply won't appear here; that's surfaced as a small note rather than
/// an error, since it's expected behavior given the retention policy.
class SavedScreen extends StatefulWidget {
  final StanzaRepository repository;
  final Set<String> bookmarkedIds;
  final BookmarkStore bookmarkStore;
  final ValueChanged<Set<String>> onBookmarksChanged;

  const SavedScreen({
    super.key,
    required this.repository,
    required this.bookmarkedIds,
    required this.bookmarkStore,
    required this.onBookmarksChanged,
  });

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Stanza> _saved = const [];
  bool _isLoading = true;
  String? _error;
  late Set<String> _bookmarkedIds;
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();
    _bookmarkedIds = widget.bookmarkedIds;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.fetchByIds(_bookmarkedIds.toList());
      if (!mounted) return;
      setState(() {
        _saved = saved;
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

  Future<void> _removeBookmark(Stanza stanza) async {
    setState(() {
      _bookmarkedIds = {..._bookmarkedIds}..remove(stanza.stanzaId);
      _saved = _saved.where((s) => s.stanzaId != stanza.stanzaId).toList();
    });
    await widget.bookmarkStore.save(_bookmarkedIds);
    widget.onBookmarksChanged(_bookmarkedIds);
    _analytics.logBookmarkToggle(stanza.stanzaId, false);
  }

  Future<void> _toggleBookmark(Stanza stanza) async {
    // Inside the viewer, toggling either removes or re-adds the bookmark.
    if (_bookmarkedIds.contains(stanza.stanzaId)) {
      await _removeBookmark(stanza);
    } else {
      setState(() => _bookmarkedIds = {..._bookmarkedIds, stanza.stanzaId});
      await widget.bookmarkStore.save(_bookmarkedIds);
      widget.onBookmarksChanged(_bookmarkedIds);
      _analytics.logBookmarkToggle(stanza.stanzaId, true);
    }
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

  void _openViewer(int index) {
    StoryViewer.open(
      context,
      StoryViewer(
        stanzas: List<Stanza>.of(_saved),
        initialIndex: index,
        currentBookmarks: () => _bookmarkedIds,
        onBookmarkToggle: _toggleBookmark,
        onShare: _onShare,
        onOpenArticle: _openArticle,
        onSwipeLeft: _openRelatedCoverage,
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          repository: widget.repository,
          bookmarkedIds: _bookmarkedIds,
          bookmarkStore: widget.bookmarkStore,
          onBookmarksChanged: (ids) {
            setState(() => _bookmarkedIds = ids);
            widget.onBookmarksChanged(ids);
          },
        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StanzaTopBar(onSearch: _openSearch, onSaved: () {}, savedActive: true),
              const SizedBox(height: 18),
              _buildHeader(),
              const SizedBox(height: 14),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final count = _bookmarkedIds.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saved', style: AppText.serif(size: 34, weight: FontWeight.w500, height: 1.1)),
                const SizedBox(height: 2),
                Text(
                  'Articles you\u2019ve bookmarked for later.',
                  style: AppText.sans(size: 14, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$count ${count == 1 ? 'article' : 'articles'}',
              style: AppText.sans(size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
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

    if (_bookmarkedIds.isEmpty) {
      return Center(
        child: Text('No saved stories yet', style: AppText.sans(color: AppColors.textMuted)),
      );
    }

    final missing = _bookmarkedIds.length - _saved.length;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _saved.length + (missing > 0 ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (missing > 0 && index == _saved.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$missing saved ${missing == 1 ? 'story is' : 'stories are'} '
              'no longer available (older than 24h).',
              style: AppText.sans(size: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          );
        }
        final stanza = _saved[index];
        return ArticleListCard(
          stanza: stanza,
          onTap: () => _openViewer(index),
          trailing: _CardMenu(
            onRemove: () => _removeBookmark(stanza),
            onShare: () => _onShare(stanza),
          ),
        );
      },
    );
  }
}

class _CardMenu extends StatelessWidget {
  final VoidCallback onRemove;
  final VoidCallback onShare;
  const _CardMenu({required this.onRemove, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        color: AppColors.menuBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.more_vert, color: Color(0xFFCDD3DE), size: 22),
        onSelected: (value) => value == 'remove' ? onRemove() : onShare(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'share',
            child: Text('Share', style: AppText.sans(size: 14, color: Colors.white)),
          ),
          PopupMenuItem(
            value: 'remove',
            child: Text('Remove from saved', style: AppText.sans(size: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
