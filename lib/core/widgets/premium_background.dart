import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// A premium, editorial-style background wrapper that displays a large 
/// image header which gracefully fades into the app's solid background color.
class PremiumBackground extends StatelessWidget {
  final Widget child;
  final String imageUrl;
  final double imageHeight;
  final double overlayOpacity;

  const PremiumBackground({
    super.key,
    required this.child,
    this.imageUrl = 'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?q=80&w=2000&auto=format&fit=crop', // Default: Beautiful Indian architecture
    this.imageHeight = 450,
    this.overlayOpacity = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 1. The Photographic Background ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: imageHeight,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(overlayOpacity),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.brandDeep,
            ),
          ),
        ),
        
        // ── 2. The Editorial Gradient Fade ──
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: imageHeight,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.4, 1.0],
                colors: [
                  AppColors.bg.withOpacity(0.0), // Let the photo shine at the top
                  AppColors.bg.withOpacity(0.3), // Mid-fade
                  AppColors.bg, // Solid background color to match the rest of the app
                ],
              ),
            ),
          ),
        ),

        // ── 3. The Content ──
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}
