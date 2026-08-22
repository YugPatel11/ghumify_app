import 'package:flutter/material.dart';

/// Ghumify Earthy Luxury Brand Palette — Editorial, Human-Designed, Premium.
/// Deep Forest Green + Warm Sand/Beige + Dark Charcoal.
class AppColors {
  AppColors._();

  // ── Brand Primary: Deep Forest Green ──
  static const Color brand = Color(0xFF064E3B);
  static const Color brandDeep = Color(0xFF022C22);
  static const Color brandLight = Color(0xFF10B981);
  static const Color brandSoft = Color(0xFFECFDF5);

  // ── Accent: Premium Gold / Sand ──
  static const Color accent = Color(0xFFD97706);
  static const Color accentDeep = Color(0xFF92400E);
  static const Color accentLight = Color(0xFFFBBF24);
  static const Color accentSoft = Color(0xFFFEF3C7);

  // ── Teal / Sage (Secondary) ──
  static const Color teal = Color(0xFF0D9488);
  static const Color tealDeep = Color(0xFF115E59);
  static const Color tealSoft = Color(0xFFF0FDFA);

  // ── Rose / Terracotta (Secondary) ──
  static const Color rose = Color(0xFFBE123C);
  static const Color roseSoft = Color(0xFFFFF1F2);

  // ── Indigo / Slate (Secondary) ──
  static const Color indigo = Color(0xFF4338CA);
  static const Color indigoSoft = Color(0xFFEEF2FF);

  // ── Surfaces (Warm, Editorial Light Theme) ──
  static const Color bg = Color(0xFFFDFBF7); // Warm paper/sand
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF9F9F9); // Crisp grey-white

  // ── Text ──
  static const Color text = Color(0xFF1F2937); // Dark Charcoal
  static const Color textSoft = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF9CA3AF);

  // ── Border ──
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // ── Semantic ──
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // ── Legacy Named Gradients (Re-mapped to earthy tones so nothing breaks) ──
  static const LinearGradient cherryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)], // Remapped to Forest
  );

  static const LinearGradient saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)], // Remapped to Gold
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF5EEAD4)], // Remapped to Slate Teal
  );

  static const LinearGradient indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF374151), Color(0xFF4B5563), Color(0xFF6B7280)], // Remapped to Charcoal
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF991B1B), Color(0xFFB91C1C), Color(0xFFEF4444)], // Remapped to Terracotta
  );

  static const LinearGradient roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9F1239), Color(0xFFBE123C), Color(0xFFE11D48)], // Remapped to Rose
  );

  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF4B5563)], // Remapped to Charcoal
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
