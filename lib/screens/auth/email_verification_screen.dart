import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'auth_widgets.dart';

/// Shown while a signed-in email/password account is unverified. Polls
/// Firebase quietly every few seconds, so the person doesn't have to
/// tap anything after clicking the emailed link.
class EmailVerificationScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onVerified;

  const EmailVerificationScreen({
    super.key,
    required this.authService,
    required this.onVerified,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;
  Timer? _tickTimer;
  String? _message;
  String? _error;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
    // Re-renders once a second so the resend countdown visibly ticks.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final verified = await widget.authService.checkEmailVerified();
      if (!mounted) return;
      if (verified) {
        widget.onVerified();
      } else if (!silent) {
        setState(() {
          _error = null;
          _message = "Not verified yet. Open the link in the email, then try again.";
        });
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = null;
      _message = null;
    });
    try {
      await widget.authService.resendVerificationEmail();
      if (mounted) setState(() => _message = 'Verification email sent.');
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cooldown = widget.authService.resendCooldownRemaining;
    final email = widget.authService.currentUser?.email ?? 'your email';

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
                  const Icon(Icons.mark_email_unread_outlined, size: 56),
                  const SizedBox(height: 16),
                  const Text('Verify your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to\n$email',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _check(),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text("I've verified my email"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: cooldown == null ? _resend : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(cooldown == null
                          ? 'Resend email'
                          : 'Resend email (${cooldown.inSeconds}s)'),
                    ),
                  ),
                  AuthErrorText(_error),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.authService.signOut,
                    child: const Text('Use a different account'),
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
