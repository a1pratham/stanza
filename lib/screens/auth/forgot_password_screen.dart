import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'auth_validators.dart';
import 'auth_widgets.dart';

/// Forgot password. Firebase's default flow finishes on a Firebase-hosted
/// page, so this screen only collects the email and confirms it was sent.
class ForgotPasswordScreen extends StatefulWidget {
  final AuthService authService;
  final String initialEmail;

  const ForgotPasswordScreen({
    super.key,
    required this.authService,
    this.initialEmail = '',
  });

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _email;
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
      _sent = false;
    });
    try {
      await widget.authService.sendPasswordResetEmail(_email.text);
      if (mounted) setState(() => _sent = true);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Reset your password',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text("Enter your email and we'll send you a reset link.",
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 24),
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
              AuthErrorText(_error),
              if (_sent)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'If an account exists for that email, a reset link is on its way. '
                    'Open it, set a new password, then come back and sign in.',
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (!_busy && AuthValidators.isValidEmail(_email.text)) ? _send : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_sent ? 'Send again' : 'Send reset link'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
