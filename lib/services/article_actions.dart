import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stanza.dart';

/// Centralizes "open article" and "share" so every screen gets identical
/// real behavior instead of separate implementations.
///
/// PHASE 8 CHANGE: the URL-opening logic is now `openUrl()`, a standalone
/// method taking a plain string rather than a Stanza. `openArticle()` is
/// kept as a thin wrapper for existing callers (Feed/Search/Saved, which
/// all call it with a Stanza) so none of them need to change. The new
/// Related Coverage sheet calls `openUrl()` directly, since a
/// RelatedArticle isn't a Stanza and doesn't need to become one just for
/// this.
class ArticleActions {
  /// Opens the article's source URL using an in-app browser tab —
  /// Chrome Custom Tabs on Android, SFSafariViewController on iOS — per
  /// spec section 27. Falls back to the external browser, then a
  /// SnackBar, if that fails.
  static Future<void> openArticle(BuildContext context, Stanza stanza) {
    return openUrl(context, stanza.sourceUrl);
  }

  /// Same behavior as [openArticle], but takes a plain URL string. Used
  /// by anything that has a source link but isn't a full Stanza (e.g.
  /// Related Coverage entries).
  static Future<void> openUrl(BuildContext context, String url) async {
    final trimmed = url.trim();

    if (trimmed.isEmpty) {
      _showMessage(context, "This story doesn't have a source link.");
      return;
    }

    final uri = Uri.tryParse(trimmed);
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

  /// Opens the real platform share sheet (spec section 23).
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
