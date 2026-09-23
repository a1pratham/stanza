import 'package:flutter/material.dart';
import '../models/stanza.dart';
import '../services/article_actions.dart';
import '../services/bookmark_store.dart';
import '../services/stanza_repository.dart';
import '../widgets/stanza_swipe_feed.dart';

/// PHASE 5 NEW: Saved screen — shows bookmarked Stanzas.
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

  Future<void> _toggleBookmark(Stanza stanza) async {
    setState(() {
      _bookmarkedIds = {..._bookmarkedIds}..remove(stanza.stanzaId);
      _saved = _saved.where((s) => s.stanzaId != stanza.stanzaId).toList();
    });
    await widget.bookmarkStore.save(_bookmarkedIds);
    widget.onBookmarksChanged(_bookmarkedIds);
  }

  void _onShare(Stanza stanza) {
    ArticleActions.share(stanza);
  }

  void _openArticle(Stanza stanza) {
    ArticleActions.openArticle(context, stanza);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Saved', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
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

    if (_bookmarkedIds.isEmpty) {
      return const Center(
        child: Text('No saved stories yet', style: TextStyle(color: Colors.white38)),
      );
    }

    final missing = _bookmarkedIds.length - _saved.length;

    return Column(
      children: [
        if (missing > 0)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '$missing saved ${missing == 1 ? 'story is' : 'stories are'} '
              'no longer available (older than 24h).',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: StanzaSwipeFeed(
            stanzas: _saved,
            bookmarkedIds: _bookmarkedIds,
            onBookmarkToggle: _toggleBookmark,
            onShare: _onShare,
            onOpenArticle: _openArticle,
          ),
        ),
      ],
    );
  }
}
