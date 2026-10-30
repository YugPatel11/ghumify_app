import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/food_preferences.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/providers/auth_provider.dart';

/// A radio button group for selecting food preferences with 5 options:
/// Veg, Veg + Egg, Jain, Non-Veg, and All.
class FoodPreferenceSelector extends StatelessWidget {
  final String? selectedValue;
  final ValueChanged<String>? onChanged;
  final bool showHeader;
  final bool isCompact;

  const FoodPreferenceSelector({
    super.key,
    this.selectedValue,
    this.onChanged,
    this.showHeader = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AppSettingsProvider>();
    final currentPreference = FoodPreference.normalize(
      selectedValue ?? settingsProvider.foodPreference,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTokens.sm),
              const Text(
                'Food Preference',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'We will suggest food and restaurants based on your choice.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSoft,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTokens.md),
        ],

        // Radio List of 5 Options
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: FoodPreference.values.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final option = FoodPreference.values[index];
            final isSelected = option == currentPreference;
            final label = FoodPreference.getLabel(option);
            final explanation = FoodPreference.getExplanation(option);
            final indicatorColor = FoodPreference.getIndicatorColor(option);

            return _FoodPreferenceOptionTile(
              optionKey: option,
              label: label,
              explanation: explanation,
              indicatorColor: indicatorColor,
              isSelected: isSelected,
              isCompact: isCompact,
              onTap: () => _handleSelection(context, option),
            );
          },
        ),
      ],
    );
  }

  void _handleSelection(BuildContext context, String option) {
    // 1. Invoke custom callback if provided
    onChanged?.call(option);

    // 2. Persist in AppSettingsProvider (local cache + shared prefs)
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    settings.setFoodPreference(option);

    // 3. Persist to Firestore if user is authenticated
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      authProvider.updateFoodPreference(option);
    }
  }
}

class _FoodPreferenceOptionTile extends StatelessWidget {
  final String optionKey;
  final String label;
  final String explanation;
  final Color indicatorColor;
  final bool isSelected;
  final bool isCompact;
  final VoidCallback onTap;

  const _FoodPreferenceOptionTile({
    required this.optionKey,
    required this.label,
    required this.explanation,
    required this.indicatorColor,
    required this.isSelected,
    required this.isCompact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label food preference: $explanation',
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: AppTokens.md,
              vertical: isCompact ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : AppColors.cardAlt,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(
                color: isSelected ? AppColors.brand : AppColors.border,
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Radio Circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.brand : AppColors.textMuted,
                      width: isSelected ? 6.5 : 2.0,
                    ),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppTokens.md),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          // Color indicator dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: indicatorColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: indicatorColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        explanation,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppColors.textSoft : AppColors.textMuted,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
