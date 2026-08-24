import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_tokens.dart';

class ActionGridItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isNew;
  final LinearGradient? customGradient;

  ActionGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isNew = false,
    this.customGradient,
  });
}

class ActionGrid extends StatelessWidget {
  final List<ActionGridItem> items;

  const ActionGrid({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 24,
        alignment: WrapAlignment.spaceBetween,
        children: items.map((item) => _buildActionItem(context, item)).toList(),
      ),
    );
  }

  Widget _buildActionItem(BuildContext context, ActionGridItem item) {
    // 4 items per row logic, but let the wrap handle it
    // calculating width for 4 items:
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - (AppTokens.lg * 4) - (16 * 3)) / 4;

    return GestureDetector(
      onTap: item.onTap,
      child: SizedBox(
        width: itemWidth > 70 ? itemWidth : 70, // min width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: item.customGradient ?? AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (item.customGradient?.colors.first ?? AppColors.brand).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                if (item.isNew)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
