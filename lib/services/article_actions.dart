import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stanza.dart';

/// PHASE 6 NEW: centralizes "open article" and "share" so FeedScreen,
/// SearchScreen and SavedScreen all get the same real behavior instead of
/// three separate placeholder implementations.
///
/// This replaces the Phase 1-4 bottom-sheet placeholder and the SnackBar
/// placeholder. Nothing about StanzaCard, StanzaSwipeFeed, or the gesture
/// thresholds that call these functions has changed.
class ArticleActions {
  /// Opens the article's source URL using an in-app browser tab —
  /// Chrome Custom Tabs on Android, SFSafariViewController on iOS — per
  /// spec section 27 ("Android Custom Tabs ... browser-based experience.
  /// The user should not have to manually leave Stanza.").
  ///
  /// Falls back to the external browser only if the in-app tab genuinely
  /// can't be launched (e.g. no browser installed at all), matching spec
  /// section 27's "appropriate external-browser fallback if a website
  /// cannot be displayed inside the application."
  static Future<void> openArticle(BuildContext context, Stanza stanza) async {
    final url = stanza.sourceUrl.trim();

    if (url.isEmpty) {
      _showMessage(context, "This story doesn't have a source link.");
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      _showMessage(context, "This story's source link looks invalid.");
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (opened) return;
    } catch (_) {
      // fall through to the external-browser fallback below
    }

    try {
      final openedExternally =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!openedExternally && context.mounted) {
        _showMessage(context, "Couldn't open the article.");
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, "Couldn't open the article.");
      }
    }
  }

  /// Opens the real platform share sheet (spec section 23), sharing the
  /// headline and source link.
  static Future<void> share(Stanza stanza, {Rect? sharePositionOrigin}) async {
    final text = stanza.sourceUrl.isNotEmpty
        ? '${stanza.headline}\n\n${stanza.sourceUrl}'
        : stanza.headline;

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: stanza.headline,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
