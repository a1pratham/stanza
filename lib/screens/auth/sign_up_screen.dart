import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/legal_config.dart';
import '../../services/auth_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';

/// Sign Up. Pushed on top of SignInScreen, so on success it pops itself:
/// AppRoot will already have swapped the screen underneath, and a route
/// left on top would hide the verification/onboarding screen.
class SignUpScreen extends StatefulWidget {
  final AuthService authService;
  const SignUpScreen({super.key, required this.authService});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _busy = false;
  String? _error;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refresh);
    _email.addListener(_refresh);
    _password.addListener(_refresh);
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(LegalConfig.termsUrl, 'Terms of Service');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(LegalConfig.privacyUrl, 'Privacy Policy');
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy &&
      _agreed &&
      AuthValidators.isValidName(_name.text) &&
      AuthValidators.isValidEmail(_email.text) &&
      AuthValidators.isValidPassword(_password.text);

  Future<void> _openLegal(String url, String label) async {
    // No legal documents exist yet -- say so rather than pretend.
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('The $label is not published yet.')));
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Couldn't open the $label.")));
      }
    }
  }

  Future<void> _run(Future<void> Function() action, {bool popIfSignedIn = true}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      // Covers both success and (for Google) a silent cancel: only pop
      // if someone is actually signed in now.
      if (mounted && popIfSignedIn && widget.authService.isSignedIn) {
        Navigator.of(context).pop();
      }
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create your account',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Join Stanza to personalise your news experience.',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  GoogleSignInButton(
                    onPressed: _busy ? null : () => _run(widget.authService.signInWithGoogle),
                  ),
                  const SizedBox(height: 16),
                  const OrDivider(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PasswordField(controller: _password, enabled: !_busy),
                  const SizedBox(height: 12),
                  PasswordRequirements(password: _password.text),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreed,
                        onChanged: _busy ? null : (v) => setState(() => _agreed = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      decoration: TextDecoration.underline),
                                  recognizer: _termsTap,
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                      color: Colors.lightBlueAccent,
                                      decoration: TextDecoration.underline),
                                  recognizer: _privacyTap,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AuthErrorText(_error),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _canSubmit
                        ? () => _run(() => widget.authService.signUpWithEmail(
                              fullName: _name.text,
                              email: _email.text,
                              password: _password.text,
                            ))
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
