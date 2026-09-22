import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/feed_screen.dart';

/// PHASE 4 CHANGE: main() is now async and initializes Supabase before
/// runApp, so the client is ready when FeedScreen makes its first query.
/// The MaterialApp, theme and home screen are otherwise UNCHANGED.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // If the key wasn't supplied, skip initialization rather than throwing.
  // FeedScreen then shows its normal error state with a clear message,
  // which is friendlier than a red screen at launch.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

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
      home: const FeedScreen(),
    );
  }
}
