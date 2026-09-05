import 'package:flutter/material.dart';
import '../data/mock_stanzas.dart';
import '../models/stanza.dart';
import '../widgets/stanza_card.dart';

/// The Home Feed screen — the core Stanza experience.
///
/// Swipe behavior:
/// - Swipe UP   -> next Stanza
/// - Swipe DOWN -> previous Stanza
/// - Swipe RIGHT -> open original article
/// - Swipe LEFT  -> reserved for related coverage in a later phase
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  final List<Stanza> _stanzas = mockStanzas;
  final Set<String> _bookmarkedIds = {};

  double _dragStartX = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
              'In-app browser comes online in Phase 4.',
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
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _stanzas.length,
        itemBuilder: (context, index) {
          final stanza = _stanzas[index];

          return GestureDetector(
            onHorizontalDragStart: (details) {
              _dragStartX = details.globalPosition.dx;
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;

              if (velocity > 250) {
                _openArticle(stanza);
              }
            },
            child: StanzaCard(
              stanza: stanza,
              isBookmarked:
              _bookmarkedIds.contains(stanza.stanzaId),
              onBookmarkToggle: () =>
                  _toggleBookmark(stanza.stanzaId),
              onShare: () => _onShare(stanza),
              onOpenArticle: () => _openArticle(stanza),
            ),
          );
        },
      ),
    );
  }
} 