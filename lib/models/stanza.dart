
class Stanza {
  final String stanzaId;
  final String category;
  final String headline;
  final String summary;
  final String whyItMatters;
  final String sourceName;
  final String sourceUrl;
  final String timeAgo;
  final String? imageUrl;

  /// Optional like count shown next to the heart on the main card.
  final int likeCount;

  const Stanza({
    required this.stanzaId,
    required this.category,
    required this.headline,
    required this.summary,
    this.whyItMatters = '',
    required this.sourceName,
    required this.sourceUrl,
    required this.timeAgo,
    this.imageUrl,
    this.likeCount = 0,
  });
}
