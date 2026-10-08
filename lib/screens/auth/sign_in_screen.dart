import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

/// Sign In. AppRoot shows this whenever nobody is signed in. No
/// navigation happens on success: Firebase's auth state changes and
/// AppRoot swaps this screen out by itself.
class SignInScreen extends StatefulWidget {
  final AuthService authService;
  const SignInScreen({super.key, required this.authService});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(_refresh);
    _password.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_busy && AuthValidators.isValidEmail(_email.text) && _password.text.isNotEmpty;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Stanza',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('News, one stanza at a time.',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 32),
                  const Text('Welcome back',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Sign in to continue to Stanza',
                      style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 24),
                  GoogleSignInButton(
                    onPressed: _busy ? null : () => _run(widget.authService.signInWithGoogle),
                  ),
                  const SizedBox(height: 16),
                  const OrDivider(),
                  const SizedBox(height: 16),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ForgotPasswordScreen(
                                  authService: widget.authService,
                                  initialEmail: _email.text,
                                ),
                              )),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  AuthErrorText(_error),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _canSubmit
                        ? () => _run(() => widget.authService
                            .signInWithEmail(email: _email.text, password: _password.text))
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _busy
                          ? const SizedBox(
                              height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Sign in'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => SignUpScreen(authService: widget.authService),
                                )),
                        child: const Text('Sign up'),
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
