import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "Stanza" wordmark with optional search / bookmark actions.
/// Used on the main feed (over the hero image), Saved and Search screens.
class StanzaTopBar extends StatelessWidget {
  final VoidCallback? onSearch;
  final VoidCallback? onSaved;

  /// When true the bookmark icon is filled + peach with an underline
  /// (the Saved screen's active state).
  final bool savedActive;

  const StanzaTopBar({
    super.key,
    this.onSearch,
    this.onSaved,
    this.savedActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Text('Stanza', style: AppText.serif(size: 26, weight: FontWeight.w500)),
            const Spacer(),
            if (onSearch != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSearch,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Icon(Icons.search, color: Colors.white, size: 26),
                ),
              ),
            if (onSaved != null)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSaved,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 10, bottom: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        savedActive ? Icons.bookmark : Icons.bookmark_border,
                        color: savedActive ? AppColors.accent : Colors.white,
                        size: 26,
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 24,
                        height: 2,
                        decoration: BoxDecoration(
                          color: savedActive ? AppColors.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
