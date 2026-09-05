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

  const Stanza({
    required this.stanzaId,
    required this.category,
    required this.headline,
    required this.summary,
    required this.whyItMatters,
    required this.sourceName,
    required this.sourceUrl,
    required this.timeAgo,
    this.imageUrl,
  });
}