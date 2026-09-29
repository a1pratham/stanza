import 'package:flutter/material.dart';
import '../models/stanza.dart';
import '../widgets/stanza_swipe_feed.dart';

/// Full-screen swipeable card viewer opened when a list card is tapped on
/// Search or Saved. Reuses StanzaSwipeFeed, so the main-screen card design
/// is identical everywhere.
class StoryViewer extends StatefulWidget {
  final List<Stanza> stanzas;
  final int initialIndex;
  final Set<String> Function() currentBookmarks;
  final Future<void> Function(Stanza) onBookmarkToggle;
  final ValueChanged<Stanza> onShare;
  final ValueChanged<Stanza> onOpenArticle;
  final ValueChanged<Stanza>? onSwipeLeft;

  const StoryViewer({
    super.key,
    required this.stanzas,
    required this.initialIndex,
    required this.currentBookmarks,
    required this.onBookmarkToggle,
    required this.onShare,
    required this.onOpenArticle,
    this.onSwipeLeft,
  });

  static Future<void> open(BuildContext context, StoryViewer viewer) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => viewer));
  }

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StanzaSwipeFeed(
            stanzas: widget.stanzas,
            bookmarkedIds: widget.currentBookmarks(),
            onBookmarkToggle: (s) async {
              await widget.onBookmarkToggle(s);
              if (mounted) setState(() {});
            },
            onShare: widget.onShare,
            onOpenArticle: widget.onOpenArticle,
            onSwipeLeft: widget.onSwipeLeft,
            controller: _controller,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
