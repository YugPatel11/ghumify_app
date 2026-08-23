import 'package:flutter/material.dart';

/// Ghumify global design tokens — modern, glassmorphism-ready, premium.
class AppTokens {
  AppTokens._();

  // ── Generous Spacing ──
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 32;
  static const double xl = 48;
  static const double xxl = 64;

  // ── Soft Border Radius ──
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;
  static const double radiusPill = 999;

  // ── Border Width ──
  static const double borderThin = 1.0;
  static const double borderMedium = 2.0;
  static const double borderThick = 3.0;

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

  /// Diffuse, barely-there shadows for high-end floating feel
  static List<BoxShadow> shadow({int level = 1}) {
    switch (level) {
      case 1:
        return [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
      case 2:
        return [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case 3:
        return [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
        color: color.withOpacity(0.15 + level * 0.05),
        blurRadius: 20.0 + level * 10,
        offset: Offset(0, 8.0 + level * 4),
      ),
    ];
  }
}
