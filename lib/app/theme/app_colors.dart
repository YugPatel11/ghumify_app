import 'package:flutter/material.dart';

/// Ghumify brand color palette — warm, Indian-inspired, designer-crafted.
/// Terracotta coral + golden saffron + deep teal on warm cream.
class AppColors {
  AppColors._();

  // ── Brand Primary: Warm Coral-Terracotta ──
  static const Color brand = Color(0xFFE8573A);
  static const Color brandDeep = Color(0xFFCC3D22);
  static const Color brandLight = Color(0xFFF4796A);
  static const Color brandSoft = Color(0xFFFEECE8);

  // ── Accent: Golden Saffron ──
  static const Color accent = Color(0xFFD4860B);
  static const Color accentDeep = Color(0xFFB06E00);
  static const Color accentLight = Color(0xFFFFB938);
  static const Color accentSoft = Color(0xFFFFF3E0);

  // ── Teal ──
  static const Color teal = Color(0xFF0DA98E);
  static const Color tealDeep = Color(0xFF0B7A66);
  static const Color tealSoft = Color(0xFFDDF6F1);

  // ── Rose ──
  static const Color rose = Color(0xFFD4508A);
  static const Color roseSoft = Color(0xFFFCE7F2);

  // ── Indigo ──
  static const Color indigo = Color(0xFF4338CA);
  static const Color indigoSoft = Color(0xFFEEEBFF);

  // ── Surfaces ──
  static const Color bg = Color(0xFFF9F7F4);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFFBF8F3);

  // ── Text ──
  static const Color text = Color(0xFF1F1D2B);
  static const Color textSoft = Color(0xFF5B5675);
  static const Color textMuted = Color(0xFF9992AD);

  // ── Border ──
  static const Color border = Color(0xFFE8E4DF);
  static const Color borderLight = Color(0xFFF2EFEB);

  // ── Semantic ──
  static const Color success = Color(0xFF12B886);
  static const Color warning = Color(0xFFD4860B);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF3B82F6);

  // ── Named Gradients ──
  static const LinearGradient cherryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8573A), Color(0xFFFF7A5A), Color(0xFFFFA07A)],
  );

  static const LinearGradient saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4860B), Color(0xFFFF9D1B), Color(0xFFFFB938)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0DA98E), Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const LinearGradient indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4338CA), Color(0xFF6C5CE7), Color(0xFF9B8CFF)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8573A), Color(0xFFD4860B), Color(0xFFFFB938)],
  );

  static const LinearGradient roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD4508A), Color(0xFFF472B6), Color(0xFFFB7FC4)],
  );

  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF6EE7B7)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8573A), Color(0xFFD4860B), Color(0xFFFFB938)],
  );

  // ── Gradient by name (for dynamic usage) ──
  static LinearGradient gradientByName(String name) {
    switch (name) {
      case 'cherry':
        return cherryGradient;
      case 'saffron':
        return saffronGradient;
      case 'teal':
        return tealGradient;
      case 'indigo':
        return indigoGradient;
      case 'sunset':
        return sunsetGradient;
      case 'rose':
        return roseGradient;
      case 'forest':
        return forestGradient;
      default:
        return cherryGradient;
    }
  }
}
