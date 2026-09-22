import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../models/stanza.dart';
import '../services/stanza_repository.dart';
import '../widgets/stanza_card.dart';

/// The Home Feed screen — the core Stanza experience.
///
/// PHASE 4 CHANGE: `_stanzas` is now loaded from Supabase instead of being
/// assigned from `mockStanzas`, and loading / empty / error states were
/// added around the existing PageView.
///
/// UNCHANGED: the PageView itself, scrollDirection, the horizontal-drag
/// gesture handling and its velocity > 250 threshold, the bookmark set,
/// the share SnackBar, the article bottom sheet, and every StanzaCard
/// argument. The card is not modified at all.
///
/// Swipe behavior:
///   - Swipe UP    -> next Stanza
///   - Swipe DOWN  -> previous Stanza
///   - Swipe RIGHT -> open original article
///   - Swipe LEFT  -> reserved for related coverage in a later phase
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  final StanzaRepository _repository = StanzaRepository();
  final Set<String> _bookmarkedIds = {};

  List<Stanza> _stanzas = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() {
        _isLoading = false;
        _error =
        'SUPABASE_ANON_KEY was not provided at build time.\n'
            'Run the app with --dart-define=SUPABASE_ANON_KEY=your-key '
            '(see PHASE4_NOTES.md).';
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
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleBookmark(String stanzaId) {
    setState(() {
      if (_bookmarkedIds.contains(stanzaId)) {
        _bookmarkedIds.remove(stanzaId);
      } else {
        _bookmarkedIds.add(stanzaId);
      }
    });
  }

  void _onShare(Stanza stanza) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share: ${stanza.headline}')),
    );
  }

  void _openArticle(Stanza stanza) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Original Article',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Would open: ${stanza.sourceUrl}',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            Text(
              'In-app browser comes in a later phase.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
      return _FeedMessage(
        icon: Icons.cloud_off,
        title: "Couldn't load news",
        message: _error!,
        onRetry: _loadFeed,
      );
    }

    if (_stanzas.isEmpty) {
      return _FeedMessage(
        icon: Icons.article_outlined,
        title: 'No stories yet',
        message: 'No published Stanzas were found. '
            'The pipeline may still be generating them.',
        onRetry: _loadFeed,
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _stanzas.length,
      itemBuilder: (context, index) {
        final stanza = _stanzas[index];

        return GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;

            if (velocity > 250) {
              _openArticle(stanza);
            }
          },
          child: StanzaCard(
            stanza: stanza,
            isBookmarked: _bookmarkedIds.contains(stanza.stanzaId),
            onBookmarkToggle: () => _toggleBookmark(stanza.stanzaId),
            onShare: () => _onShare(stanza),
            onOpenArticle: () => _openArticle(stanza),
          ),
        );
      },
    );
  }
}

/// Simple shared empty/error state, styled to match the dark feed.
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
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}