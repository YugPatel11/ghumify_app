import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  static const List<_CategoryItem> _categories = [
    _CategoryItem('Heritage', Icons.account_balance, AppColors.brand, 'heritage'),
    _CategoryItem('Temples', Icons.temple_hindu, AppColors.accent, 'temples'),
    _CategoryItem('Food', Icons.restaurant, AppColors.warning, 'food'),
    _CategoryItem('Markets', Icons.storefront, AppColors.indigo, 'markets'),
    _CategoryItem('Nature', Icons.park, AppColors.teal, 'nature'),
    _CategoryItem('Culture', Icons.theater_comedy, Color(0xFFD946EF), 'culture'),
    _CategoryItem('Adventure', Icons.hiking, Color(0xFFF97316), 'adventure'),
    _CategoryItem('Hidden Gems', Icons.auto_awesome, Color(0xFFEAB308), 'hidden_gems'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppTokens.lg,
          crossAxisSpacing: AppTokens.md,
          childAspectRatio: 0.75,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          return GestureDetector(
            onTap: () {
              context.push('/discover', extra: {'category': cat.id});
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                        border: Border.all(color: cat.color.withOpacity(0.3), width: 1),
                      ),
                      child: Icon(
                        cat.icon,
                        color: cat.color,
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.sm),
                Text(
                  cat.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSoft,
                        letterSpacing: 0.2,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  final String label;
  final IconData icon;
  final Color color;
  final String id;

  const _CategoryItem(this.label, this.icon, this.color, this.id);
}

