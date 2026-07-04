import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central palette + text styles, tuned to match the Storm Blitz key art
/// (deep storm navy, gold accents, electric blue lightning).
class AppColors {
  static const Color background = Color(0xFF0A0E1A);
  static const Color backgroundLight = Color(0xFF141B2E);
  static const Color panel = Color(0xFF1B2438);
  static const Color panelBorder = Color(0xFF2C3A57);

  static const Color gold = Color(0xFFE8B23A);
  static const Color goldLight = Color(0xFFFFD87A);
  static const Color lightning = Color(0xFF5BC8FF);
  static const Color lightningDeep = Color(0xFF2B7FE0);

  static const Color hpRed = Color(0xFFE2433B);
  static const Color manaBlue = Color(0xFF3D8BFF);
  static const Color attackOrange = Color(0xFFF5A623);

  static const Color textPrimary = Color(0xFFF2F5FF);
  static const Color textMuted = Color(0xFF9AA7C2);

  static const Color legendary = Color(0xFFFFB23E);
  static const Color rare = Color(0xFF4FA8FF);
  static const Color common = Color(0xFFB9C2D6);
  static const Color epic = Color(0xFFB05CFF);

  static const Color ambrosia = Color(0xFFFF6FD8);
  static const Color success = Color(0xFF4CD964);
}

class AppTheme {
  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.lightning,
        surface: AppColors.panel,
      ),
      textTheme: GoogleFonts.exo2TextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }

  /// Display font used for the logo word-mark, titles and big numbers.
  static TextStyle title(double size, {Color? color}) =>
      GoogleFonts.philosopher(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.goldLight,
        letterSpacing: 1.1,
      );

  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.exo2(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        color: color ?? AppColors.textPrimary,
      );

  static Color rarityColor(int rarityIndex) {
    switch (rarityIndex) {
      case 2:
        return AppColors.legendary;
      case 1:
        return AppColors.rare;
      default:
        return AppColors.common;
    }
  }
}
