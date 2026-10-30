import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// Immersive editorial header with dynamic destination photography and glass accents.
class CraftHeader extends StatelessWidget {
  final String heroImageUrl;
  final String destinationName;
  final VoidCallback onBack;

  const CraftHeader({
    super.key,
    required this.heroImageUrl,
    required this.destinationName,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final hasDestination = destinationName.trim().isNotEmpty;
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 220 + topPadding,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image with AnimatedSwitcher & CachedNetworkImage
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: CachedNetworkImage(
              key: ValueKey<String>(heroImageUrl),
              imageUrl: heroImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: AppColors.brandDeep,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: AppColors.brandDeep,
                child: const Center(
                  child: Icon(Icons.landscape, size: 48, color: Colors.white24),
                ),
              ),
            ),
          ),

          // Multi-layer Gradient: Darkened top for status bar + Smooth fade at bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.25),
                  AppColors.bg.withValues(alpha: 0.85),
                  AppColors.bg,
                ],
                stops: const [0.0, 0.4, 0.82, 1.0],
              ),
            ),
          ),

          // Header Content (Back Button, Destination Pill, Title)
          Positioned(
            top: topPadding + 8,
            left: AppTokens.md,
            right: AppTokens.md,
            bottom: AppTokens.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Bar: Back Button & Step Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onBack,
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasDestination)
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusPill),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius:
                                  BorderRadius.circular(AppTokens.radiusPill),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    destinationName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Headline & Sub-headline
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusXs),
                        ),
                        child: const Text(
                          'AI TRIP ARCHITECT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Craft Your Itinerary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
