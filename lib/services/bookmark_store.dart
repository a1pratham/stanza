import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists bookmarked stanza IDs locally, per device.
///
/// Spec section 22 explicitly allows local-only storage for the MVP
/// ("can initially use local storage if authentication is not included").
/// Cloud sync is a later-phase concern once auth exists.
class BookmarkStore {
  static const _key = 'bookmarked_stanza_ids';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(ids.toList()));
  }
}
