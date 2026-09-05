import 'package:flutter/material.dart';
import 'screens/feed_screen.dart';

void main() {
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
      // Phase 1: straight to the feed. Splash/onboarding screens (spec
      // section 32) get added once there's real personalization to onboard
      // into (Phase 5).
      home: const FeedScreen(),
    );
  }
}