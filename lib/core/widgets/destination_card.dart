import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// Figma-matching destination card — supports featured (full-width) and compact (grid) modes
class DestinationCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? badge;
  final Color? badgeColor;
  final double? rating;
  final int? reviewCount;
  final String? price;
  final bool isFavorited;
  final bool isAsset;
  final bool isFeatured;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  const DestinationCard({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.rating,
    this.reviewCount,
    this.price,
    this.isFavorited = false,
    this.isAsset = false,
    this.isFeatured = false,
    this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          boxShadow: AppTokens.shadow(level: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Image ──
            Stack(
              children: [
                SizedBox(
                  height: isFeatured ? 200 : 140,
                  width: double.infinity,
                  child: isAsset
                      ? Image.asset(imageUrl, fit: BoxFit.cover)
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.cardAlt,
                            child: const Center(
                              child: Icon(Icons.image_outlined, color: AppColors.textMuted, size: 32),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.cardAlt,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted, size: 32),
                            ),
                          ),
                        ),
                ),
                // Gradient overlay for featured cards
                if (isFeatured)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),
                // Badge
                if (badge != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppColors.brand,
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                // Heart / Save
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: onFavoriteTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited ? AppColors.error : AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                // Price badge
                if (price != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        boxShadow: AppTokens.shadow(level: 1),
                      ),
                      child: Text(
                        price!,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                // Featured overlay text
                if (isFeatured)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: price != null ? 100 : 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null)
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                subtitle!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (rating != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < rating!.round() ? Icons.star : Icons.star_border,
                                  size: 14,
                                  color: AppColors.star,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$rating',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              if (reviewCount != null) ...[
                                const Text(' · ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                Text(
                                  '${_formatCount(reviewCount!)} reviews',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            // ── Info (non-featured cards) ──
            if (!isFeatured)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (rating != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: AppColors.star),
                          const SizedBox(width: 4),
                          Text(
                            rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}
