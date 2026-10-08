import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/feed_screen.dart';

/// AUTH PIVOT: this file now initializes Firebase FIRST, then initializes
/// Supabase with an `accessToken` callback instead of letting it manage
/// its own session.
///
/// IMPORTANT consequence of setting `accessToken`: per supabase_flutter's
/// own documented behavior, once this option is set, `supabase.auth.*`
/// (the GoTrue client namespace) becomes unusable -- calling it throws.
/// This isn't a workaround we have to remember to respect; the package
/// itself enforces "no Supabase Auth" at the API level once this is
/// configured, which matches the architecture exactly: Firebase is the
/// only thing that can authenticate a user here, full stop.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      accessToken: () async {
        return FirebaseAuth.instance.currentUser?.getIdToken(false);
      },
    );
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // Every Supabase request (REST queries, Realtime, Storage) now
    // carries the current Firebase user's ID token instead of a
    // Supabase-issued session token. `forceRefresh: false` here is
    // correct for routine calls -- Firebase caches and auto-refreshes
    // tokens under an hour old. The one place a FORCED refresh is
    // required is immediately after set-auth-role assigns the
    // `role: authenticated` custom claim post-sign-up -- that happens in
    // auth_service.dart (a later part), not here.
    //
    // Returns null when signed out, which Supabase treats as
    // "unauthenticated" -- RLS policies then correctly deny access to
    // anything scoped `to authenticated`.
    accessToken: () async {
      return FirebaseAuth.instance.currentUser?.getIdToken(false);
    },
  );

  runApp(const StanzaApp());
}

class StanzaApp extends StatelessWidget {
  const StanzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stanza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amberAccent,
          brightness: Brightness.dark,
        ),
      ),
      // AUTH PIVOT NOTE: still routes straight to FeedScreen for now.
      // The splash -> auth-check -> onboarding -> feed state machine
      // (AppRoot) is a later part, once auth_service.dart and
      // profile_service.dart actually exist for it to branch on.
      home: const FeedScreen(),
    );
  }
}
