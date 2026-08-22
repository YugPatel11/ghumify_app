import 'package:flutter/material.dart';

/// Ghumify brand color palette derived from the logo.
/// Orange mountain/arrow, ocean blue waves, forest green text.
class AppColors {
  AppColors._();

  // ── Brand Primary: Warm Orange (mountain/arrow) ──
  static const Color primaryOrange = Color(0xFFF5A623);
  static const Color primaryOrangeLight = Color(0xFFFFC857);
  static const Color primaryOrangeDark = Color(0xFFE8930E);

  // ── Brand Secondary: Ocean Blue (waves/palm) ──
  static const Color secondaryBlue = Color(0xFF4ABFED);
  static const Color secondaryBlueLight = Color(0xFF7DD3F2);
  static const Color secondaryBlueDark = Color(0xFF2A9FCC);

  // ── Brand Accent: Forest Green (text) ──
  static const Color accentGreen = Color(0xFF2D6A4F);
  static const Color accentGreenLight = Color(0xFF40916C);
  static const Color accentGreenDark = Color(0xFF1B4332);

  // ── Surfaces ──
  static const Color surfaceWhite = Color(0xFFFFFBF5);
  static const Color surfaceCream = Color(0xFFFFF3E0);
  static const Color surfaceLight = Color(0xFFF8F4F0);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceDarkCard = Color(0xFF222240);
  static const Color surfaceDarkElevated = Color(0xFF2A2A48);

  // ── Neutrals ──
  static const Color neutral900 = Color(0xFF1A1A1A);
  static const Color neutral800 = Color(0xFF2D2D2D);
  static const Color neutral700 = Color(0xFF404040);
  static const Color neutral600 = Color(0xFF525252);
  static const Color neutral500 = Color(0xFF737373);
  static const Color neutral400 = Color(0xFFA3A3A3);
  static const Color neutral300 = Color(0xFFD4D4D4);
  static const Color neutral200 = Color(0xFFE5E5E5);
  static const Color neutral100 = Color(0xFFF5F5F5);

  // ── Semantic ──
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, primaryOrangeLight],
  );

  static const LinearGradient oceanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryBlue, secondaryBlueDark],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryOrange, Color(0xFFFF6B6B)],
  );

  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentGreen, accentGreenLight],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceDark, Color(0xFF16213E)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF5A623),
      Color(0xFFFF8A50),
      Color(0xFF4ABFED),
    ],
  );
}
