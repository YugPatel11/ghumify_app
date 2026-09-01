import 'package:flutter/material.dart';

/// Ghumify Design System — Figma "Tourism App Template" Palette
/// Navy + Amber, clean modern surfaces
class AppColors {
  AppColors._();

  // ── Brand Primary: Navy ──
  static const Color brand = Color(0xFF1A3685);
  static const Color brandDeep = Color(0xFF0F2361);
  static const Color brandLight = Color(0xFF3B5BB5);
  static const Color brandSoft = Color(0xFFE8EDF7);

  // ── Accent: Amber / Gold ──
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentDeep = Color(0xFFD97706);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentSoft = Color(0xFFFFF8E1);

  // ── Surfaces ──
  static const Color bg = Color(0xFFF0F4F9);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF5F7FA);

  // ── Glass / Overlay ──
  static const Color glassWhite = Color(0xD9FFFFFF);
  static const Color glassWhiteLight = Color(0x99FFFFFF);
  static const Color glassDark = Color(0x33000000);

  // ── Text ──
  static const Color text = Color(0xFF1A1D26);
  static const Color textSoft = Color(0xFF5A6175);
  static const Color textMuted = Color(0xFF9DA3B3);
  static const Color textLight = Color(0xFFFFFFFF);

  // ── Border ──
  static const Color border = Color(0xFFE2E6EE);
  static const Color borderLight = Color(0xFFF0F2F7);
  static const Color borderGlass = Color(0x33FFFFFF);

  // ── Status ──
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Star / Rating ──
  static const Color star = Color(0xFFF59E0B);

  // ── Badge Colors ──
  static const Color badgeAdventure = Color(0xFF10B981);
  static const Color badgeRomantic = Color(0xFFEC4899);
  static const Color badgeBeach = Color(0xFF06B6D4);
  static const Color badgeCulture = Color(0xFF8B5CF6);
  static const Color badgeHeritage = Color(0xFFD97706);
  static const Color badgeNature = Color(0xFF059669);

  // ── Gradients ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A3685), Color(0xFF0F2361)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  );

  static const LinearGradient navyLightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B5BB5), Color(0xFF1A3685)],
  );

  static const LinearGradient premiumDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1D26), Color(0xFF2D3142)],
  );

  // Kept for backward compatibility with existing code
  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3B5BB5), Color(0xFF1A3685)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xFFF0F4F9)],
  );

  static const LinearGradient imageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB3000000)],
  );

  // ── Gradient by name ──
  static LinearGradient gradientByName(String name) {
    switch (name) {
      case 'brand':
        return brandGradient;
      case 'sunset':
        return sunsetGradient;
      case 'teal':
        return tealGradient;
      case 'premium':
        return premiumDarkGradient;
      default:
        return brandGradient;
    }
  }
}
