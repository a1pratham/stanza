import 'package:flutter/material.dart';
import '../models/stanza.dart';

class StanzaCard extends StatelessWidget {
  final Stanza stanza;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onShare;
  final VoidCallback onOpenArticle;

  const StanzaCard({
    super.key,
    required this.stanza,
    required this.isBookmarked,
    required this.onBookmarkToggle,
    required this.onShare,
    required this.onOpenArticle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category
            Text(
              stanza.category,
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // Image / placeholder
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: stanza.imageUrl != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    stanza.imageUrl!,
                    fit: BoxFit.cover,
                  ),
                )
                    : const Center(
                  child: Icon(
                    Icons.article_outlined,
                    color: Colors.white24,
                    size: 64,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Headline
            Text(
              stanza.headline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 12),

            // Summary
            Text(
              stanza.summary,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 14),

            // Why it matters
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WHY IT MATTERS',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stanza.whyItMatters,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Bottom row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onOpenArticle,
                    child: Text(
                      '${stanza.sourceName} · ${stanza.timeAgo}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  onPressed: onBookmarkToggle,
                  icon: Icon(
                    isBookmarked
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: isBookmarked
                        ? Colors.amberAccent
                        : Colors.white70,
                  ),
                ),

                IconButton(
                  onPressed: onShare,
                  icon: const Icon(
                    Icons.ios_share,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}