import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  static final List<_CategoryItem> _categories = [
    _CategoryItem('Heritage', Icons.account_balance, AppColors.primaryOrange, 'heritage'),
    _CategoryItem('Temples', Icons.temple_hindu, AppColors.accentGreen, 'temples'),
    _CategoryItem('Food', Icons.restaurant, AppColors.error, 'food'),
    _CategoryItem('Markets', Icons.storefront, AppColors.secondaryBlue, 'markets'),
    _CategoryItem('Nature', Icons.park, Color(0xFF66BB6A), 'nature'),
    _CategoryItem('Culture', Icons.theater_comedy, Color(0xFFAB47BC), 'culture'),
    _CategoryItem('Adventure', Icons.hiking, Color(0xFFFF7043), 'adventure'),
    _CategoryItem('Hidden Gems', Icons.auto_awesome, Color(0xFFFFCA28), 'hidden_gems'),
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
          mainAxisSpacing: 16,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
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
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    cat.icon,
                    color: cat.color,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cat.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
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

  _CategoryItem(this.label, this.icon, this.color, this.id);
}
