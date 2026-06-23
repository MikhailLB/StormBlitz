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
      textTheme: GoogleFonts.rajdhaniTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }

  /// Heavy display font used for the logo word-mark and big titles.
  static TextStyle title(double size, {Color? color}) => GoogleFonts.cinzel(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.goldLight,
        letterSpacing: 1.5,
      );

  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.rajdhani(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w600,
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
