import 'package:flutter/material.dart';
import '../models/stanza.dart';
import 'stanza_card.dart';

/// The vertical swipeable PageView of StanzaCards, factored out of
/// FeedScreen so Search and (filtered) Home can share the exact same
/// swipe/bookmark/share/open-article behavior instead of duplicating it.
///
/// This is a pure presentation + gesture widget — it owns no data loading
/// and no bookmark persistence. The parent screen supplies the list and
/// the current bookmark set, and is notified via callbacks. StanzaCard
/// itself is untouched, imported and used exactly as in Phase 1/4.
class StanzaSwipeFeed extends StatelessWidget {
  final List<Stanza> stanzas;
  final Set<String> bookmarkedIds;
  final ValueChanged<Stanza> onBookmarkToggle;
  final ValueChanged<Stanza> onShare;
  final ValueChanged<Stanza> onOpenArticle;
  final PageController? controller;

  const StanzaSwipeFeed({
    super.key,
    required this.stanzas,
    required this.bookmarkedIds,
    required this.onBookmarkToggle,
    required this.onShare,
    required this.onOpenArticle,
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
            if (velocity > 250) onOpenArticle(stanza);
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
