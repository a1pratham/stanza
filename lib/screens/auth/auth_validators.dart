/// Client-side checks shared by the auth screens. These only drive UI
/// state (enabling buttons, ticking requirement rows); Firebase remains
/// the authority on what it accepts.
class AuthValidators {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidName(String v) => v.trim().length >= 2;
  static bool isValidEmail(String v) => _email.hasMatch(v.trim());

  static bool hasMinLength(String p) => p.length >= 8;
  static bool hasNumber(String p) => RegExp(r'\d').hasMatch(p);
  static bool hasLetter(String p) => RegExp(r'[A-Za-z]').hasMatch(p);

  static bool isValidPassword(String p) =>
      hasMinLength(p) && hasNumber(p) && hasLetter(p);
}
