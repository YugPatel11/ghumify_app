import 'package:flutter/material.dart';

/// Ghumify design tokens — clean, modern, mobile-first.
class AppTokens {
  AppTokens._();

  // ── Spacing ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // ── Border Radius ──
  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  // ── Border Width ──
  static const double borderThin = 1.0;
  static const double borderMedium = 1.5;
  static const double borderThick = 2.0;

  // ── Icon Sizes ──
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  // ── Card Elevation ──
  static const double elevationNone = 0;
  static const double elevationLow = 1;
  static const double elevationMedium = 2;
  static const double elevationHigh = 4;

  /// Clean, subtle card shadow
  static List<BoxShadow> shadow({int level = 1}) {
    switch (level) {
      case 1:
        return [
          BoxShadow(
            color: const Color(0xFF1A1D26).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ];
      case 2:
        return [
          BoxShadow(
            color: const Color(0xFF1A1D26).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF1A1D26).withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ];
      case 3:
        return [
          BoxShadow(
            color: const Color(0xFF1A1D26).withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1A1D26).withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ];
      default:
        return shadow(level: 1);
    }
  }

  /// Colored shadow for brand elements
  static List<BoxShadow> coloredShadow(Color color, {int level = 1}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.2 + level * 0.05),
        blurRadius: 16.0 + level * 8,
        offset: Offset(0, 6.0 + level * 2),
      ),
    ];
  }
}
