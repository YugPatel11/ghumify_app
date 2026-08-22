import 'package:flutter/material.dart';

/// Ghumify global design tokens — spacing, radius, shadows, gradients.
/// Use these everywhere instead of hardcoded values.
class AppTokens {
  AppTokens._();

  // ── Spacing ──
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 36;

  // ── Border Radius ──
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
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
  static const double elevationLow = 2;
  static const double elevationMedium = 4;
  static const double elevationHigh = 8;

  /// Soft shadow — level 1 (subtle), 2 (card), 3 (elevated)
  static List<BoxShadow> shadow({int level = 1}) {
    switch (level) {
      case 1:
        return [
          BoxShadow(
            color: const Color(0xFF1F1D2B).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];
      case 2:
        return [
          BoxShadow(
            color: const Color(0xFF1F1D2B).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF1F1D2B).withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case 3:
        return [
          BoxShadow(
            color: const Color(0xFF1F1D2B).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1F1D2B).withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
      default:
        return shadow(level: 1);
    }
  }

  /// Colored shadow for gradient cards
  static List<BoxShadow> coloredShadow(Color color, {int level = 1}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.18 + level * 0.06),
        blurRadius: 12.0 + level * 6,
        offset: Offset(0, 4.0 + level * 2),
      ),
    ];
  }
}
