import 'package:flutter/material.dart';

/// Ghumify Premium Travel UI Palette: "Midnight & Marigold"
/// Inspired by deep forests, vibrant spices, and modern Indian luxury.
class AppColors {
  AppColors._();

  // ── Brand Primary: Deep Jade ──
  static const Color brand = Color(0xFF0F4C3A); // Deep, sophisticated Jade Green
  static const Color brandDeep = Color(0xFF07261D); // Almost black green
  static const Color brandLight = Color(0xFF268A6B); 
  static const Color brandSoft = Color(0xFFE6F3EF); // Extremely light jade background

  // ── Accent: Marigold / Mango ──
  static const Color accent = Color(0xFFFF9F1C); // Warm, optimistic orange/gold
  static const Color accentDeep = Color(0xFFCC7F16);
  static const Color accentLight = Color(0xFFFFB64D);
  static const Color accentSoft = Color(0xFFFFF6EB);

  // ── Surfaces (Clean, bright, high contrast) ──
  static const Color bg = Color(0xFFFAFAFA); // Alabaster/Off-white for clean backdrop
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFF3F4F6); // Very subtle cool gray

  // ── Glass Surfaces (Used sparingly) ──
  static const Color glassWhite = Color(0xD9FFFFFF); // 85% White
  static const Color glassWhiteLight = Color(0x99FFFFFF); // 60% White
  static const Color glassDark = Color(0x33000000);  // 20% Black

  // ── Text ──
  static const Color text = Color(0xFF111827); // Gray 900 (Near Black)
  static const Color textSoft = Color(0xFF4B5563); // Gray 600
  static const Color textMuted = Color(0xFF9CA3AF); // Gray 400
  static const Color textLight = Color(0xFFFFFFFF); // White for overlays

  // ── Border ──
  static const Color border = Color(0xFFE5E7EB); // Gray 200
  static const Color borderLight = Color(0xFFF3F4F6); // Gray 100
  static const Color borderGlass = Color(0x33FFFFFF); // 20% White border

  // ── Status ──
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // ── Gradients ──
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F4C3A), Color(0xFF07261D)],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9F1C), Color(0xFFFF7A00)],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF268A6B), Color(0xFF0F4C3A)],
  );

  static const LinearGradient premiumDarkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF111827), Color(0xFF1F2937)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xFFFAFAFA)], // Fades to Alabaster bg
  );

  static const LinearGradient imageOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xCC000000)], // Transparent to 80% black for crisp text
  );

  // ── Gradient by name (for dynamic usage) ──
  static LinearGradient gradientByName(String name) {
    switch (name) {
      case 'brand': return brandGradient;
      case 'sunset': return sunsetGradient;
      case 'teal': return tealGradient;
      case 'premium': return premiumDarkGradient;
      default: return brandGradient;
    }
  }
}
