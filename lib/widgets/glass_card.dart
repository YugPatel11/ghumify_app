import 'dart:ui';
import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_tokens.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool darkGlass;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = AppTokens.radiusLg,
    this.padding = const EdgeInsets.all(AppTokens.lg),
    this.onTap,
    this.darkGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: darkGlass ? AppColors.glassDark : AppColors.glassWhite,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AppColors.borderGlass,
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
