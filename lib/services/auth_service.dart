import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// `hide User`: supabase_flutter re-exports GoTrue's own `User` class,
// which collides with firebase_auth's `User`. This file only needs
// SupabaseClient and HttpMethod from supabase_flutter, never its User
// type, so hiding it is the smallest possible fix -- no need to prefix
// every firebase_auth reference.
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

/// A clean, human-readable auth error, safe to show directly in the UI.
/// Every method below maps Firebase's error codes to specific text and
/// falls back to a generic safe message for anything unrecognized --
/// never surfaces a raw exception to the person using the app.
class AuthServiceException implements Exception {
  final String message;
  const AuthServiceException(this.message);

  @override
  String toString() => message;
}

/// AUTH PIVOT: Firebase Authentication is now the entire identity layer.
///
/// IMPORTANT -- the role-claim step: every method that results in a
/// signed-in user (sign-up, sign-in, Google) calls [_ensureAuthenticatedRole]
/// afterward. This calls the `set-auth-role` Edge Function (Part 1) and
/// then force-refreshes the Firebase ID token, so the
/// `role: authenticated` custom claim is actually present on the token
/// before any Supabase query runs.
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final SupabaseClient _supabase;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        // google_sign_in 7.x: no public constructor anymore -- the
        // plugin is a singleton, accessed via `.instance`.
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _supabase = supabase ?? Supabase.instance.client;

  /// google_sign_in 7.x requires `initialize()` to be awaited exactly
  /// once before `authenticate()` is used. main.dart is deliberately
  /// untouched in this fix, so initialization happens lazily here
  /// instead: the first Google sign-in attempt initializes the plugin,
  /// every later one skips straight past this guard.
  static bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  /// The single source of truth for "is anyone signed in."
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  /// Cached verification status; can be stale. Use [checkEmailVerified]
  /// for a fresh check against Firebase.
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Email + password
  // ---------------------------------------------------------------------

  Future<void> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(fullName.trim());
      await credential.user?.sendEmailVerification();

      await _ensureAuthenticatedRole();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapSignUpError(e));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong creating your account. Check your connection and try again.',
      );
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      await _ensureAuthenticatedRole();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapSignInError(e));
    } catch (_) {
      throw const AuthServiceException(
        'Something went wrong signing in. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Google Sign-In (native -- google_sign_in 7.x API)
  // ---------------------------------------------------------------------

  Future<void> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      // 7.x: authenticate() replaces signIn(). It does NOT return null
      // on cancellation -- it throws GoogleSignInException instead,
      // handled below.
      final googleUser = await _googleSignIn.authenticate();

      // 7.x: `authentication` is a synchronous getter (no await) and
      // exposes only idToken -- accessToken moved to a separate
      // authorization API that Firebase sign-in doesn't need.
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw const AuthServiceException(
          'Google sign-in could not be completed. Please try again.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      await _auth.signInWithCredential(credential);
      await _ensureAuthenticatedRole();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User closed the account picker -- not an error, just a
        // cancellation. Callers should treat a clean return as
        // "nothing happened."
        return;
      }
      throw const AuthServiceException(
        'Google sign-in could not be completed. Please try again.',
      );
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapGoogleError(e));
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'Could not sign in with Google. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Password reset
  // ---------------------------------------------------------------------

  /// Sends a reset email using Firebase's default hosted reset page --
  /// no deep link back into the app and no in-app reset screen needed.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapRateLimitAwareError(e));
    } catch (_) {
      throw const AuthServiceException(
        'Could not send the reset email. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Email verification
  // ---------------------------------------------------------------------

  DateTime? _lastResendAt;
  static const Duration _resendCooldown = Duration(seconds: 60);

  Duration? get resendCooldownRemaining {
    final lastResend = _lastResendAt;
    if (lastResend == null) return null;
    final elapsed = DateTime.now().difference(lastResend);
    if (elapsed >= _resendCooldown) return null;
    return _resendCooldown - elapsed;
  }

  Future<void> resendVerificationEmail() async {
    final remaining = resendCooldownRemaining;
    if (remaining != null) {
      throw AuthServiceException(
        'Please wait ${remaining.inSeconds}s before requesting another email.',
      );
    }
    try {
      await _auth.currentUser?.sendEmailVerification();
      _lastResendAt = DateTime.now();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapRateLimitAwareError(e));
    } catch (_) {
      throw const AuthServiceException(
        'Could not resend the verification email. Check your connection.',
      );
    }
  }

  // ---------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------

  Future<void> signOut() async {
    try {
      // Google sign-out only if the plugin was ever initialized this
      // session -- calling it before initialize() throws in 7.x, and
      // there's nothing to sign out of if Google was never used.
      await Future.wait([
        _auth.signOut(),
        if (_googleSignInInitialized) _googleSignIn.signOut(),
      ]);
    } catch (_) {
      throw const AuthServiceException('Could not sign out. Please try again.');
    }
  }

  // ---------------------------------------------------------------------
  // Role-claim assignment (makes Supabase RLS work at all)
  // ---------------------------------------------------------------------

  /// Calls `set-auth-role` via the Supabase client's functions invoker --
  /// main.dart's `accessToken` wiring attaches the Firebase ID token
  /// automatically. Then force-refreshes the token so the new claim is
  /// actually present on it. Deliberately non-fatal: a failure here
  /// doesn't block sign-in, and retries on the next sign-in.
  Future<void> _ensureAuthenticatedRole() async {
    try {
      await _supabase.functions.invoke('set-auth-role', method: HttpMethod.post);
      await _auth.currentUser?.getIdToken(true);
    } catch (err) {
      // ignore: avoid_print
      print('AuthService: failed to assign authenticated role: $err');
    }
  }

  // ---------------------------------------------------------------------
  // Error message mapping -- keyed on Firebase's stable error codes.
  // ---------------------------------------------------------------------

  String _mapSignUpError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 8 characters and include a letter and a number.';
      case 'operation-not-allowed':
        return 'Email sign-up is not available right now. Please try again later.';
      default:
        return 'Could not create your account. Please check your details and try again.';
    }
  }

  String _mapSignInError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return "You're doing that a bit too fast. Please wait a moment and try again.";
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'Could not sign in. Please check your details and try again.';
    }
  }

  String _mapGoogleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'This email is already linked to a different sign-in method.';
      default:
        return 'Google sign-in could not be completed. Please try again.';
    }
  }

  String _mapRateLimitAwareError(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return "You're doing that a bit too fast. Please wait a moment and try again.";
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with that email.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
