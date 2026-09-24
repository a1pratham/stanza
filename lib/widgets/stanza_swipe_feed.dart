import 'package:flutter/material.dart';
import '../models/stanza.dart';
import 'stanza_card.dart';

/// The vertical swipeable PageView of StanzaCards, shared by Home, Search
/// results, and Saved.
///
/// PHASE 8 CHANGE: added an optional `onSwipeLeft` callback, fired on a
/// fast leftward drag (the gesture spec section 6 originally reserved for
/// this). It's nullable and simply not invoked if omitted, so any
/// existing call site that doesn't pass it keeps behaving exactly as
/// before — nothing about the rightward-swipe/open-article path changed.
class StanzaSwipeFeed extends StatelessWidget {
  final List<Stanza> stanzas;
  final Set<String> bookmarkedIds;
  final ValueChanged<Stanza> onBookmarkToggle;
  final ValueChanged<Stanza> onShare;
  final ValueChanged<Stanza> onOpenArticle;
  final ValueChanged<Stanza>? onSwipeLeft;
  final PageController? controller;

  const StanzaSwipeFeed({
    super.key,
    required this.stanzas,
    required this.bookmarkedIds,
    required this.onBookmarkToggle,
    required this.onShare,
    required this.onOpenArticle,
    this.onSwipeLeft,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: stanzas.length,
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
