import 'package:flutter/material.dart';

/// Ghumify Premium Travel UI Palette
/// Clean whites, soft neutrals, and vibrant accents for light glassmorphism.
class AppColors {
  AppColors._();

  // ── Brand Primary: Sky/Oceanic Blue ──
  static const Color brand = Color(0xFF0EA5E9); // Tailwind Sky 500
  static const Color brandDeep = Color(0xFF0369A1); // Sky 700
  static const Color brandLight = Color(0xFF7DD3FC); // Sky 300
  static const Color brandSoft = Color(0xFFE0F2FE); // Sky 100

  // ── Accent: Soft Coral / Sunset ──
  static const Color accent = Color(0xFFF43F5E); // Rose 500
  static const Color accentDeep = Color(0xFFBE123C); // Rose 700
  static const Color accentLight = Color(0xFFFDA4AF); // Rose 300
  static const Color accentSoft = Color(0xFFFFE4E6); // Rose 100

  // ── Teal / Sage (Secondary) ──
  static const Color teal = Color(0xFF14B8A6); // Teal 500
  static const Color tealDeep = Color(0xFF0F766E);
  static const Color tealSoft = Color(0xFFCCFBF1);

  // ── Indigo / Slate (Secondary) ──
  static const Color indigo = Color(0xFF6366F1); // Indigo 500
  static const Color indigoSoft = Color(0xFFE0E7FF);

  // ── Surfaces (Clean, bright, for glassmorphism) ──
  static const Color bg = Color(0xFFFAFAFA); // Very light grey/white
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF1F5F9); // Slate 100

  // ── Glass Surfaces ──
  static const Color glassWhite = Color(0xCCFFFFFF); // 80% White
  static const Color glassWhiteLight = Color(0x80FFFFFF); // 50% White
  static const Color glassDark = Color(0x1A000000);  // 10% Black (for subtle shadows/overlays)

  // ── Text ──
  static const Color text = Color(0xFF0F172A); // Slate 900
  static const Color textSoft = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textLight = Color(0xFFFFFFFF); // White for overlays

  // ── Border ──
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderLight = Color(0xFFF1F5F9); // Slate 100
  static const Color borderGlass = Color(0x4DFFFFFF); // 30% White border

  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Gradients ──
  static const LinearGradient cherryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
  );

  static const LinearGradient saffronGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFD97706)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
  );

  static const LinearGradient indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
  );

  static const LinearGradient forestGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCCFFFFFF)], // Fades to 80% white
  );

  // ── Gradient by name (for dynamic usage) ──
  static LinearGradient gradientByName(String name) {
    switch (name) {
      case 'cherry': return cherryGradient;
      case 'saffron': return saffronGradient;
      case 'teal': return tealGradient;
      case 'indigo': return indigoGradient;
      case 'sunset': return sunsetGradient;
      case 'forest': return forestGradient;
      default: return cherryGradient;
    }
  }
}
