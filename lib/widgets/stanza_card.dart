import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/stanza.dart';
import '../theme/app_theme.dart';

/// The full-screen story card: hero image, category pill, serif headline,
/// frosted summary sheet with "Why it matters", source row and the
/// Like / Save / Share rail on the right.
class StanzaCard extends StatefulWidget {
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
  State<StanzaCard> createState() => _StanzaCardState();
}

class _StanzaCardState extends State<StanzaCard> {
  bool _liked = false;

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final stanza = widget.stanza;
    final screenWidth = MediaQuery.of(context).size.width;
    final likes = stanza.likeCount + (_liked ? 1 : 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Hero image
        _buildImage(stanza.imageUrl),

        // Top scrim (keeps the wordmark/icons legible)
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0x00000000)],
              ),
            ),
          ),
        ),

        // Bottom scrim
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.42, 0.68, 1.0],
                colors: [
                  Color(0x00000000),
                  Color(0x33050A12),
                  Color(0xCC050A12),
                  Color(0xF2050A12),
                ],
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Category pill
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: _CategoryPill(label: stanza.category),
              ),
              const SizedBox(height: 14),

              // Headline
              Padding(
                padding: EdgeInsets.only(left: 24, right: screenWidth * 0.22),
                child: Text(
                  stanza.headline,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(size: 32, weight: FontWeight.w500, height: 1.08),
                ),
              ),
              const SizedBox(height: 22),

              // Frosted sheet
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(36),
                    topRight: Radius.circular(56),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.12),
                            const Color(0xFF0B111B).withOpacity(0.55),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 36, 22, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stanza.summary,
                                  style: AppText.sans(
                                    size: 16,
                                    color: const Color(0xFFE3E7EE),
                                    height: 1.5,
                                  ),
                                ),
                                if (stanza.whyItMatters.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 1,
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      const Text(
                                        '✦',
                                        style: TextStyle(color: AppColors.accent, fontSize: 18),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Why it matters',
                                        style: AppText.serif(
                                          size: 18,
                                          color: AppColors.accent,
                                          weight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    stanza.whyItMatters,
                                    style: AppText.sans(
                                      size: 14.5,
                                      color: const Color(0xFFC9CFDA),
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Drag handle (centred on the screen)
                          Positioned(
                            top: 12,
                            left: screenWidth / 2 - 14,
                            child: Container(
                              width: 28,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Source row
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
                child: GestureDetector(
                  onTap: widget.onOpenArticle,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _initials(stanza.sourceName),
                          style: AppText.serif(
                            size: 14,
                            color: Colors.black,
                            weight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          stanza.sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.sans(size: 14, color: const Color(0xFFD5DAE3)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD5DAE3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Text(
                        stanza.timeAgo,
                        style: AppText.sans(size: 14, color: const Color(0xFFD5DAE3)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Like / Save / Share rail
        Positioned(
          right: 6,
          bottom: 0,
          width: 72,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 84),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RailButton(
                    icon: _liked ? Icons.favorite : Icons.favorite_border,
                    iconColor: _liked ? const Color(0xFFFF6B6B) : Colors.white,
                    label: likes > 0 ? _formatCount(likes) : 'Like',
                    onTap: () => setState(() => _liked = !_liked),
                  ),
                  const SizedBox(height: 18),
                  _RailButton(
                    icon: widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    iconColor: widget.isBookmarked ? AppColors.accent : Colors.white,
                    label: 'Save',
                    onTap: widget.onBookmarkToggle,
                  ),
                  const SizedBox(height: 18),
                  _RailButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: widget.onShare,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String? url) {
    final fallback = Container(
      decoration: const BoxDecoration(gradient: AppColors.background),
    );
    if (url == null) return fallback;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  const _CategoryPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2A1E).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.live.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppColors.live, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.6,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 30),
          const SizedBox(height: 4),
          Text(label, style: AppText.sans(size: 13, color: Colors.white, height: 1.1)),
        ],
      ),
    );
  }
}
