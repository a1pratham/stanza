import 'package:flutter/material.dart';
import '../models/stanza.dart';
import '../theme/app_theme.dart';

/// The rounded list card used by both the Saved and Search screens:
/// square thumbnail, coloured category label, serif headline, two-line
/// summary and "Source • time" footer. [trailing] is the optional
/// three-dot menu shown on Saved.
class ArticleListCard extends StatelessWidget {
  final Stanza stanza;
  final VoidCallback onTap;
  final Widget? trailing;

  const ArticleListCard({
    super.key,
    required this.stanza,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(url: stanza.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: trailing != null ? 26 : 0),
                      child: Text(
                        stanza.category.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.sans(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: AppColors.category(stanza.category),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stanza.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.serif(size: 17, weight: FontWeight.w500, height: 1.18),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stanza.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.sans(size: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            stanza.sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(size: 12, color: AppColors.textMuted),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Text(
                          stanza.timeAgo,
                          style: AppText.sans(size: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null) Padding(padding: const EdgeInsets.only(top: 0), child: trailing),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: const Color(0xFF1C2433),
      child: const Center(
        child: Icon(Icons.article_outlined, color: Colors.white24, size: 30),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 104,
        height: 106,
        child: url == null
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}
