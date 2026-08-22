import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';

/// A highly polished, structural card that mimics high-end print design.
/// It drops generic pill-shapes and heavy shadows in favor of crisp borders,
/// subtle scaling, and stark contrast.
class PremiumCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool hasImage;
  final bool isTransparent;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTokens.lg),
    this.hasImage = false,
    this.isTransparent = false,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: widget.hasImage ? EdgeInsets.zero : widget.padding,
      decoration: BoxDecoration(
        color: widget.isTransparent ? Colors.transparent : AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: widget.isTransparent ? Colors.transparent : AppColors.border,
          width: AppTokens.borderThin,
        ),
        boxShadow: widget.isTransparent ? null : AppTokens.shadow(level: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap!();
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
