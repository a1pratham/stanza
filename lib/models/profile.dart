/// A user's Supabase `profiles` row, keyed by Firebase UID.
///
/// Deliberately a plain data class, no Supabase/Firebase imports here --
/// ProfileService owns all database access; this is just the shape it
/// hands back, matching how Stanza/RelatedArticle are kept free of
/// network concerns.
class Profile {
  final String id; // Firebase UID
  final String? fullName;
  final String? avatarUrl;
  final bool onboardingCompleted;
  final int onboardingVersion;

  const Profile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    required this.onboardingCompleted,
    required this.onboardingVersion,
  });

  factory Profile.fromRow(Map<String, dynamic> row) {
    return Profile(
      id: row['id'] as String,
      fullName: row['full_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      onboardingCompleted: row['onboarding_completed'] as bool? ?? false,
      onboardingVersion: row['onboarding_version'] as int? ?? 1,
    );
  }
}

/// A user's `profile_preferences` row. One-to-one with [Profile].
class ProfilePreferences {
  final String language;
  final bool morningBriefEnabled;
  final String morningBriefTime; // "HH:MM" (Postgres `time`, read as text)
  final bool breakingNewsEnabled;
  final bool recommendedStoriesEnabled;

  const ProfilePreferences({
    required this.language,
    required this.morningBriefEnabled,
    required this.morningBriefTime,
    required this.breakingNewsEnabled,
    required this.recommendedStoriesEnabled,
  });

  /// Matches the column defaults in 0010_firebase_schema.sql exactly, so
  /// the app has a sane in-memory default even before the first
  /// preferences row is confirmed to exist.
  const ProfilePreferences.defaults()
      : language = 'en',
        morningBriefEnabled = true,
        morningBriefTime = '08:00',
        breakingNewsEnabled = true,
        recommendedStoriesEnabled = true;

  factory ProfilePreferences.fromRow(Map<String, dynamic> row) {
    // Postgres `time` comes back as "HH:MM:SS" over PostgREST; trimmed to
    // "HH:MM" since that's what the onboarding UI (Part 6) will want to
    // show and edit.
    final rawTime = row['morning_brief_time'] as String? ?? '08:00:00';
    final trimmedTime = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;

    return ProfilePreferences(
      language: row['language'] as String? ?? 'en',
      morningBriefEnabled: row['morning_brief_enabled'] as bool? ?? true,
      morningBriefTime: trimmedTime,
      breakingNewsEnabled: row['breaking_news_enabled'] as bool? ?? true,
      recommendedStoriesEnabled: row['recommended_stories_enabled'] as bool? ?? true,
    );
  }
}
