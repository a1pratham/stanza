import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens taken from the Stanza UI designs (dark navy + warm peach).
class AppColors {
  static const Color bgTop = Color(0xFF111826);
  static const Color bgBottom = Color(0xFF0A0F18);
  static const Color card = Color(0xFF151C29);
  static const Color cardBorder = Color(0x14FFFFFF); // white @ 8%
  static const Color accent = Color(0xFFF6CFA3); // peach (bookmark, "Why it matters")
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA7AFBE);
  static const Color textMuted = Color(0xFF8790A0);
  static const Color live = Color(0xFF22C55E);
  static const Color menuBg = Color(0xFF1A2231);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgTop, bgBottom],
  );

  /// Category label colours used on the list cards (Saved / Search).
  static Color category(String category) {
    switch (category.trim().toLowerCase()) {
      case 'infrastructure':
        return const Color(0xFFA9B6CC);
      case 'environment':
      case 'india':
        return const Color(0xFF8FD48A);
      case 'science':
      case 'technology':
        return const Color(0xFF7FA6F0);
      case 'business':
        return const Color(0xFFF2C46B);
      case 'politics':
        return const Color(0xFFF0605D);
      case 'sports':
        return const Color(0xFFF59E6B);
      default:
        return const Color(0xFFA9B6CC);
    }
  }
}

class AppText {
  static TextStyle serif({
    double size = 16,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double height = 1.15,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.sourceSerif4(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textSecondary,
    double height = 1.4,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.figtree(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}
