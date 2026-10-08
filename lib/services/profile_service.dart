import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/topic.dart';

/// Reads/writes a Firebase-identified user's profile data in Supabase.
///
/// This is now a REQUIRED service, not optional scaffolding: with the
/// Firebase pivot, there is no database trigger auto-creating a profile
/// row anymore (0010_firebase_schema.sql dropped it, since nothing
/// inserts into auth.users for a trigger to fire on). Profile creation
/// is application logic now, and this is where it lives.
///
/// Same "UI -> service -> Supabase" shape as StanzaRepository/
/// AnalyticsService/AuthService -- plain class, no DI framework,
/// constructed with an optional client for testability.
///
/// NOTE on when this gets called: ensureProfileExists() is NOT called
/// from AuthService. It's called from the navigation state machine
/// (Part 5), right after a signed-in Firebase user is detected -- that's
/// the natural point to say "does this person have a profile yet," and
/// keeps AuthService scoped purely to Firebase auth, this service scoped
/// purely to Supabase profile data.
class ProfileService {
  final SupabaseClient _client;

  ProfileService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------
  // Profile creation / loading
  // ---------------------------------------------------------------------

  /// Creates a profile row (and a default preferences row) for this
  /// Firebase user if one doesn't already exist. Safe to call on every
  /// sign-in -- `ignoreDuplicates: true` means an existing row (and
  /// whatever onboarding progress it holds) is left untouched, not
  /// overwritten.
  ///
  /// [fullName]/[avatarUrl] should come from the Firebase user object
  /// (`currentUser.displayName`/`currentUser.photoURL`) -- Firebase is
  /// the source of truth for these, Supabase just stores a copy
  /// alongside app-specific fields like onboarding state.
  Future<void> ensureProfileExists({
    required String uid,
    String? fullName,
    String? avatarUrl,
  }) async {
    await _client.from('profiles').upsert(
      {
        'id': uid,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      },
      onConflict: 'id',
      ignoreDuplicates: true,
    );

    await _client.from('profile_preferences').upsert(
      {'profile_id': uid},
      onConflict: 'profile_id',
      ignoreDuplicates: true,
    );
  }

  /// Fetches the current user's profile. Returns null if, somehow, none
  /// exists yet (shouldn't happen if ensureProfileExists was called
  /// first, but callers -- especially the navigation state machine --
  /// should handle null rather than assume).
  Future<Profile?> fetchProfile(String uid) async {
    final row = await _client.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return null;
    return Profile.fromRow(row);
  }

  Future<void> updateProfile(
    String uid, {
    String? fullName,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isEmpty) return;

    await _client.from('profiles').update(updates).eq('id', uid);
  }

  /// Marks onboarding complete. Called once, at the end of the
  /// onboarding flow (Part 6), after preferences and interests have
  /// already been saved.
  Future<void> markOnboardingComplete(String uid) async {
    await _client.from('profiles').update({'onboarding_completed': true}).eq('id', uid);
  }

  // ---------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------

  Future<ProfilePreferences> fetchPreferences(String uid) async {
    final row = await _client
        .from('profile_preferences')
        .select()
        .eq('profile_id', uid)
        .maybeSingle();

    // Falls back to in-code defaults rather than throwing if, for any
    // reason, the row isn't there yet -- ensureProfileExists should have
    // created it, but a UI screen reading preferences shouldn't crash
    // over a timing edge case it can't control.
    if (row == null) return const ProfilePreferences.defaults();
    return ProfilePreferences.fromRow(row);
  }

  Future<void> updatePreferences(
    String uid, {
    String? language,
    bool? morningBriefEnabled,
    String? morningBriefTime, // "HH:MM"
    bool? breakingNewsEnabled,
    bool? recommendedStoriesEnabled,
  }) async {
    final updates = <String, dynamic>{};
    if (language != null) updates['language'] = language;
    if (morningBriefEnabled != null) updates['morning_brief_enabled'] = morningBriefEnabled;
    if (morningBriefTime != null) updates['morning_brief_time'] = morningBriefTime;
    if (breakingNewsEnabled != null) updates['breaking_news_enabled'] = breakingNewsEnabled;
    if (recommendedStoriesEnabled != null) {
      updates['recommended_stories_enabled'] = recommendedStoriesEnabled;
    }
    if (updates.isEmpty) return;

    await _client.from('profile_preferences').update(updates).eq('profile_id', uid);
  }

  // ---------------------------------------------------------------------
  // Interest taxonomy (public reference data) + selected interests
  // ---------------------------------------------------------------------

  /// Fetches every topic group and its topics, for the "Choose your
  /// interests" onboarding screen (Part 6) to render. Public data --
  /// works even before a profile exists, since `topic_groups`/`topics`
  /// have no identity coupling at all.
  Future<List<TopicGroup>> fetchTopicTaxonomy() async {
    final groupRows = await _client
        .from('topic_groups')
        .select()
        .order('sort_order');

    final topicRows = await _client
        .from('topics')
        .select()
        .order('sort_order');

    final topicsByGroup = <String, List<Topic>>{};
    for (final row in topicRows) {
      final topic = Topic(
        topicId: row['topic_id'] as String,
        groupId: row['group_id'] as String,
        name: row['name'] as String,
      );
      topicsByGroup.putIfAbsent(topic.groupId, () => []).add(topic);
    }

    return groupRows.map<TopicGroup>((row) {
      final groupId = row['group_id'] as String;
      return TopicGroup(
        groupId: groupId,
        name: row['name'] as String,
        description: row['description'] as String?,
        topics: topicsByGroup[groupId] ?? const [],
      );
    }).toList();
  }

  /// The set of topic IDs this user has already selected, for
  /// pre-checking boxes if onboarding is resumed after being closed
  /// partway through.
  Future<Set<String>> fetchSelectedInterestIds(String uid) async {
    final rows = await _client
        .from('profile_interests')
        .select('topic_id')
        .eq('profile_id', uid);

    return rows.map<String>((row) => row['topic_id'] as String).toSet();
  }

  /// Replaces the user's full interest selection with [topicIds].
  ///
  /// Implemented as delete-then-insert rather than a diff, since the
  /// onboarding screen collects a full selection and submits it once --
  /// there's no incremental "add one, remove one" interaction to
  /// optimize for. Two requests, not a single atomic transaction (REST
  /// doesn't give us one here), which is an acceptable simplicity
  /// trade-off at this scale -- a failure between the delete and the
  /// insert would leave someone with zero interests temporarily, not
  /// corrupted data, and they can simply resubmit.
  Future<void> setInterests(String uid, List<String> topicIds) async {
    await _client.from('profile_interests').delete().eq('profile_id', uid);

    if (topicIds.isEmpty) return;

    await _client.from('profile_interests').insert(
      topicIds.map((topicId) => {'profile_id': uid, 'topic_id': topicId}).toList(),
    );
  }
}
