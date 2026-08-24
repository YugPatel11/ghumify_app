import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_tokens.dart';
import 'glass_card.dart';

class DestinationHero extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onExploreTap;
  final String? badgeText;

  const DestinationHero({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.onExploreTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Image
          Positioned.fill(
            bottom: 30, // Leave room for overlapping card
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                  ),
                  // Subtle gradient overlay for better text contrast if we had text on top
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.imageOverlay,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Optional Badge (Overlapping top left)
          if (badgeText != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

          // Overlapping Glass Card
          Positioned(
            left: 20,
            right: 20,
            bottom: 0,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSoft,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (onExploreTap != null)
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        onPressed: onExploreTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
