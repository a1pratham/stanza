import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, SupabaseClient;

/// Bookmarks, now stored per account in `user_stanza_interactions`
/// (interaction_type = 'bookmark') instead of device-local
/// shared_preferences.
///
/// DELIBERATELY the same interface as before -- `load()` returns the full
/// set of bookmarked stanza IDs and `save(ids)` receives the full set
/// after each toggle -- so feed_screen, search_screen and saved_screen
/// need no changes at all. `save` works out the difference against what
/// the server last confirmed and sends only that.
///
/// Failure model: screens update their UI first and call `save` without
/// a try/catch, so this class never throws. A failed write is logged and
/// simply not recorded as synced, so the next `save` includes it in its
/// diff and retries. The cost is that a bookmark can look saved on screen
/// while the write is still pending offline.
class BookmarkStore {
  static const String _table = 'user_stanza_interactions';
  static const String _type = 'bookmark';

  final SupabaseClient _client;
  final FirebaseAuth _auth;

  BookmarkStore({SupabaseClient? client, FirebaseAuth? auth})
      : _client = client ?? Supabase.instance.client,
        _auth = auth ?? FirebaseAuth.instance;

  /// What the server is known to hold. Null until a fetch succeeds.
  Set<String>? _synced;

  /// Serializes saves. Rapid toggles would otherwise run overlapping
  /// diffs against the same `_synced` and corrupt it.
  Future<void> _queue = Future<void>.value();

  String? get _uid => _auth.currentUser?.uid;

  Future<Set<String>?> _fetchRemote() async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final rows = await _client
          .from(_table)
          .select('stanza_id')
          .eq('profile_id', uid)
          .eq('interaction_type', _type);
      return rows.map<String>((r) => r['stanza_id'] as String).toSet();
    } catch (err) {
      // ignore: avoid_print
      print('BookmarkStore: failed to load bookmarks: $err');
      return null;
    }
  }

  /// The signed-in user's bookmarked stanza IDs. Empty if signed out or
  /// the request fails (the failure is retried by the next `save`).
  Future<Set<String>> load() async {
    final remote = await _fetchRemote();
    if (remote == null) return {};
    _synced = remote;
    return {...remote};
  }

  /// Reconciles the server with [ids], the complete desired set.
  Future<void> save(Set<String> ids) {
    final desired = {...ids};
    _queue = _queue.then((_) => _reconcile(desired));
    return _queue;
  }

  Future<void> _reconcile(Set<String> desired) async {
    final uid = _uid;
    if (uid == null) return;

    // If the initial load failed, learn the real server state first;
    // diffing against an assumed-empty set would wrongly skip deletes.
    var synced = _synced;
    if (synced == null) {
      synced = await _fetchRemote();
      if (synced == null) return; // still offline; try again next save
      _synced = synced;
    }

    final toAdd = desired.difference(synced);
    final toRemove = synced.difference(desired);

    // One row at a time: if a single story has been cleaned up since it
    // was bookmarked, its foreign key fails, and a batch insert would
    // let that one row block every other bookmark forever.
    for (final stanzaId in toAdd) {
      try {
        await _client.from(_table).upsert(
          {'profile_id': uid, 'stanza_id': stanzaId, 'interaction_type': _type},
          onConflict: 'profile_id,stanza_id,interaction_type',
          ignoreDuplicates: true,
        );
        synced.add(stanzaId);
      } catch (err) {
        // ignore: avoid_print
        print('BookmarkStore: failed to save bookmark $stanzaId: $err');
      }
    }

    if (toRemove.isNotEmpty) {
      try {
        await _client
            .from(_table)
            .delete()
            .eq('profile_id', uid)
            .eq('interaction_type', _type)
            .inFilter('stanza_id', toRemove.toList());
        synced.removeAll(toRemove);
      } catch (err) {
        // ignore: avoid_print
        print('BookmarkStore: failed to remove bookmarks: $err');
      }
    }
  }
}
