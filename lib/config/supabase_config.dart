/// Supabase connection settings.
///
/// Only the PUBLIC anon/publishable key is ever used here. The service-role
/// key must never appear in Flutter code, in the repository, or in the APK.
///
/// The key is supplied at build time via --dart-define so it is not
/// committed to source control. See PHASE4_NOTES.md for the run command.
class SupabaseConfig {
  /// The project URL is not a secret, so it has a default. Override it with
  /// --dart-define=SUPABASE_URL=... if the project ever changes.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ieppmtartaayeeaejivs.supabase.co',
  );

  /// Public anon/publishable key. Intentionally has no default so that a
  /// missing value fails loudly at startup instead of producing a confusing
  /// 401 on the first query.
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => anonKey.isNotEmpty;
}
