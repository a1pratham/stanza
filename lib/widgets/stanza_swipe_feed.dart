import 'package:flutter/material.dart';
import '../models/stanza.dart';
import 'stanza_card.dart';

/// The vertical swipeable PageView of StanzaCards, shared by Home, Search
/// results, and Saved.
///
/// PHASE 10 CHANGE: added an optional `onPageChanged` callback, fired
/// whenever the visible card changes (swipe up/down). Nullable, so any
/// caller that doesn't pass it behaves exactly as before -- same pattern
/// as Phase 8's `onSwipeLeft` addition.
class StanzaSwipeFeed extends StatelessWidget {
  final List<Stanza> stanzas;
  final Set<String> bookmarkedIds;
  final ValueChanged<Stanza> onBookmarkToggle;
  final ValueChanged<Stanza> onShare;
  final ValueChanged<Stanza> onOpenArticle;
  final ValueChanged<Stanza>? onSwipeLeft;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;

  const StanzaSwipeFeed({
    super.key,
    required this.stanzas,
    required this.bookmarkedIds,
    required this.onBookmarkToggle,
    required this.onShare,
    required this.onOpenArticle,
    this.onSwipeLeft,
    this.onPageChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: stanzas.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final stanza = stanzas[index];
        return GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity > 250) {
              onOpenArticle(stanza);
            } else if (velocity < -250 && onSwipeLeft != null) {
              onSwipeLeft!(stanza);
            }
          },
          child: StanzaCard(
            stanza: stanza,
            isBookmarked: bookmarkedIds.contains(stanza.stanzaId),
            onBookmarkToggle: () => onBookmarkToggle(stanza),
            onShare: () => onShare(stanza),
            onOpenArticle: () => onOpenArticle(stanza),
          ),
        );
      },
    );
  }
}
