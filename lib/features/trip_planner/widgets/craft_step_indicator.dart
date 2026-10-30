import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';

/// An animated, accessible step indicator for the Craft Itinerary flow.
class CraftStepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> stepLabels;
  final ValueChanged<int>? onStepTapped;

  const CraftStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepLabels,
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: AppTokens.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step Counter & Current Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: Text(
                        'STEP ${currentStep + 1} OF $totalSteps',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.brandDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.sm),
                    Expanded(
                      child: Text(
                        stepLabels[currentStep],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${((currentStep + 1) / totalSteps * 100).round()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.sm),
          // Segmented Progress Bar
          Row(
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (onStepTapped != null && index < currentStep) {
                      onStepTapped!(index);
                    }
                  },
                  child: Container(
                    height: 5,
                    margin: EdgeInsets.only(
                      right: index == totalSteps - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.brand
                          : isCurrent
                              ? AppColors.accent
                              : AppColors.border,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
