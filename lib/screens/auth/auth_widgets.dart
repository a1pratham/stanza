import 'package:flutter/material.dart';
import 'auth_validators.dart';

/// Password field with a visibility toggle.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// The three live password-requirement rows.
class PasswordRequirements extends StatelessWidget {
  final String password;
  const PasswordRequirements({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row('At least 8 characters', AuthValidators.hasMinLength(password)),
        _row('Include a number', AuthValidators.hasNumber(password)),
        _row('Include a letter', AuthValidators.hasLetter(password)),
      ],
    );
  }

  Widget _row(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: met ? Colors.white : Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const GoogleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.account_circle_outlined),
      label: const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Continue with Google'),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
        Expanded(child: Divider()),
      ],
    );
  }
}

class AuthErrorText extends StatelessWidget {
  final String? message;
  const AuthErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(message!, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
