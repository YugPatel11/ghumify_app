import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../app/theme/app_colors.dart';

class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: AppColors.cardAlt,
        highlightColor: Colors.white,
        child: Container(
          width: width ?? double.infinity,
          height: height ?? double.infinity,
          color: AppColors.cardAlt,
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        color: AppColors.cardAlt,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textMuted.withOpacity(0.5),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
