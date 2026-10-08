import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'auth/email_verification_screen.dart';
import 'auth/sign_in_screen.dart';
import 'feed_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'welcome_screen.dart';

/// PART 5: the session/navigation state machine. Replaces
/// `home: const FeedScreen()` in main.dart. No routing package -- a
/// StreamBuilder on Firebase's auth state, same level of machinery as the
/// rest of this codebase.
///
///   Firebase state unknown yet        -> splash
///   signed out                        -> SignInScreen
///   signed in, email not verified     -> EmailVerificationScreen
///   signed in + verified              -> _SignedInGate:
///        profile loading              -> splash
///        profile load failed          -> retry screen
///        onboarding not completed     -> OnboardingScreen (resumes)
///        just finished onboarding     -> WelcomeScreen (once)
///        otherwise                    -> FeedScreen
///
/// One AuthService/ProfileService instance lives here and is passed down,
/// so AuthService's in-memory resend-email cooldown isn't reset by each
/// screen constructing its own copy.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // No event yet: Firebase hasn't told us whether a session exists.
        // Showing sign-in here would flash the wrong screen at a
        // signed-in user on every launch.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        final user = snapshot.data;

        if (user == null) {
          return SignInScreen(authService: _authService);
        }

        // Unverified email/password accounts are not considered
        // onboarded. Google accounts arrive already verified.
        if (!user.emailVerified) {
          return EmailVerificationScreen(
            authService: _authService,
            // Verification happens outside the app, and Firebase doesn't
            // push it on authStateChanges. The verification screen
            // reloads the user, then calls this to re-run this builder.
            onVerified: () => setState(() {}),
          );
        }

        return _SignedInGate(
          // Keyed by uid so switching accounts never reuses another
          // user's loaded profile state.
          key: ValueKey(user.uid),
          user: user,
          authService: _authService,
          profileService: _profileService,
        );
      },
    );
  }
}

enum _GateStatus { loading, error, ready }

class _SignedInGate extends StatefulWidget {
  final User user;
  final AuthService authService;
  final ProfileService profileService;

  const _SignedInGate({
    super.key,
    required this.user,
    required this.authService,
    required this.profileService,
  });

  @override
  State<_SignedInGate> createState() => _SignedInGateState();
}

class _SignedInGateState extends State<_SignedInGate> {
  _GateStatus _status = _GateStatus.loading;
  Profile? _profile;
  bool _showWelcome = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Creates the profile row if this is the user's first sign-in, then
  /// loads it.
  ///
  /// The retry loop is not cosmetic. authStateChanges fires the instant
  /// Firebase signs the user in, but AuthService only finishes assigning
  /// the `role: authenticated` claim (set-auth-role + token refresh)
  /// shortly after. A request made in that gap carries a token without
  /// the claim, Supabase treats it as `anon`, and RLS denies it. A few
  /// spaced retries ride out that window; if it still fails after that,
  /// something is genuinely wrong and the retry screen takes over.
  Future<void> _load() async {
    setState(() => _status = _GateStatus.loading);

    const maxAttempts = 4;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await widget.profileService.ensureProfileExists(
          uid: widget.user.uid,
          fullName: widget.user.displayName,
          avatarUrl: widget.user.photoURL,
        );
        final profile = await widget.profileService.fetchProfile(widget.user.uid);
        if (profile == null) throw StateError('Profile row missing after creation.');

        if (!mounted) return;
        setState(() {
          _profile = profile;
          _status = _GateStatus.ready;
        });
        return;
      } catch (_) {
        if (attempt == maxAttempts) break;
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted) return;
      }
    }

    if (!mounted) return;
    setState(() => _status = _GateStatus.error);
  }

  Future<void> _onOnboardingCompleted() async {
    // Re-read rather than flip a local flag, so what's shown always
    // matches what the database actually says.
    try {
      final profile = await widget.profileService.fetchProfile(widget.user.uid);
      if (!mounted) return;
      setState(() {
        _profile = profile ?? _profile;
        _showWelcome = true;
      });
    } catch (_) {
      if (!mounted) return;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.loading:
        return const _SplashScreen();

      case _GateStatus.error:
        return _LoadErrorScreen(
          onRetry: _load,
          onSignOut: () => widget.authService.signOut(),
        );

      case _GateStatus.ready:
        final profile = _profile!;

        if (!profile.onboardingCompleted) {
          return OnboardingScreen(
            uid: widget.user.uid,
            profileService: widget.profileService,
            onCompleted: _onOnboardingCompleted,
          );
        }

        if (_showWelcome) {
          return WelcomeScreen(
            onContinue: () => setState(() => _showWelcome = false),
          );
        }

        return const FeedScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
    );
  }
}

class _LoadErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  const _LoadErrorScreen({required this.onRetry, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, color: Colors.white24, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't load your account",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: Colors.amberAccent),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: onSignOut,
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
