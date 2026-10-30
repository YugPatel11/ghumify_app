import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/travelers_model.dart';

/// A polished, accessible Travelers selector widget
/// Inspired by modern travel UX: Adults & Children steppers, direct typing,
/// skippable age bands, live summary, and DPDP-safe privacy.
class TravelersSelector extends StatefulWidget {
  final TravelersModel initialValue;
  final ValueChanged<TravelersModel> onChanged;

  const TravelersSelector({
    super.key,
    this.initialValue = const TravelersModel(adults: 1, minors: 0),
    required this.onChanged,
  });

  @override
  State<TravelersSelector> createState() => _TravelersSelectorState();
}

class _TravelersSelectorState extends State<TravelersSelector> {
  late int _adults;
  late int _minors;
  late Set<String> _selectedAgeBands;
  String? _limitMessage;

  @override
  void initState() {
    super.initState();
    _adults = widget.initialValue.adults;
    _minors = widget.initialValue.minors;
    _selectedAgeBands = Set.from(widget.initialValue.minorAgeBands);
  }

  void _notifyChange() {
    final updated = TravelersModel(
      adults: _adults,
      minors: _minors,
      minorAgeBands: _minors > 0 ? _selectedAgeBands.toList() : const [],
    );
    widget.onChanged(updated);
  }

  void _setAdults(int val) {
    if (val < TravelersModel.minAdults) {
      val = TravelersModel.minAdults;
    }
    if (val > TravelersModel.maxAdults) {
      val = TravelersModel.maxAdults;
      _showLimitMessage('Maximum 20 adults allowed per trip.');
    } else {
      _limitMessage = null;
    }
    setState(() => _adults = val);
    _notifyChange();
  }

  void _setMinors(int val) {
    if (val < TravelersModel.minMinors) {
      val = TravelersModel.minMinors;
    }
    if (val > TravelersModel.maxMinors) {
      val = TravelersModel.maxMinors;
      _showLimitMessage('Maximum 20 children allowed per trip.');
    } else {
      _limitMessage = null;
    }
    setState(() {
      _minors = val;
      if (_minors == 0) {
        _selectedAgeBands.clear();
      }
    });
    _notifyChange();
  }

  void _showLimitMessage(String msg) {
    setState(() => _limitMessage = msg);
  }

  void _toggleAgeBand(String band) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAgeBands.contains(band)) {
        _selectedAgeBands.remove(band);
      } else {
        _selectedAgeBands.add(band);
      }
    });
    _notifyChange();
  }

  Future<void> _showDirectInputDialog({
    required BuildContext context,
    required String title,
    required int currentValue,
    required int min,
    required int max,
    required ValueChanged<int> onConfirm,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          ),
          title: Text(
            'Enter $title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Between $min and $max',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed >= min && parsed <= max) {
                  onConfirm(parsed);
                  Navigator.of(ctx).pop();
                } else if (parsed != null && parsed > max) {
                  onConfirm(max);
                  Navigator.of(ctx).pop();
                } else {
                  onConfirm(min);
                  Navigator.of(ctx).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final travelersModel = TravelersModel(
      adults: _adults,
      minors: _minors,
      minorAgeBands: _selectedAgeBands.toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Header Card
        Container(
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brand.withValues(alpha: 0.08),
                AppColors.accentLight.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppTokens.shadow(level: 1),
                ),
                child: Icon(
                  _minors > 0
                      ? Icons.family_restroom_rounded
                      : (_adults == 1
                          ? Icons.person_rounded
                          : Icons.groups_rounded),
                  color: AppColors.brand,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppTokens.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _minors > 0
                          ? 'Family Trip'
                          : (_adults == 1 ? 'Solo Trip' : 'Adults Group'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDeep,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      travelersModel.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTokens.md),

        // Quick Category Switchers
        Row(
          children: [
            Expanded(
              child: _buildCategoryChip(
                label: 'Adults Only',
                icon: Icons.people_outline_rounded,
                isSelected: _minors == 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _setMinors(0);
                },
              ),
            ),
            const SizedBox(width: AppTokens.sm),
            Expanded(
              child: _buildCategoryChip(
                label: 'With Children',
                icon: Icons.child_friendly_rounded,
                isSelected: _minors > 0,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (_minors == 0) _setMinors(1);
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: AppTokens.lg),

        // Adults Stepper Card
        _buildStepperRow(
          title: 'Adults',
          subtitle: 'Ages 18 and above',
          icon: Icons.person_rounded,
          value: _adults,
          min: TravelersModel.minAdults,
          max: TravelersModel.maxAdults,
          onDecrement: () {
            if (_adults > TravelersModel.minAdults) {
              HapticFeedback.selectionClick();
              _setAdults(_adults - 1);
            }
          },
          onIncrement: () {
            if (_adults < TravelersModel.maxAdults) {
              HapticFeedback.selectionClick();
              _setAdults(_adults + 1);
            } else {
              _showLimitMessage('Maximum 20 adults allowed.');
            }
          },
          onTapValue: () {
            _showDirectInputDialog(
              context: context,
              title: 'Adults (18+)',
              currentValue: _adults,
              min: TravelersModel.minAdults,
              max: TravelersModel.maxAdults,
              onConfirm: _setAdults,
            );
          },
        ),

        const SizedBox(height: AppTokens.md),

        // Children Stepper Card
        _buildStepperRow(
          title: 'Children',
          subtitle: 'Under 18 years',
          icon: Icons.child_care_rounded,
          value: _minors,
          min: TravelersModel.minMinors,
          max: TravelersModel.maxMinors,
          onDecrement: () {
            if (_minors > TravelersModel.minMinors) {
              HapticFeedback.selectionClick();
              _setMinors(_minors - 1);
            }
          },
          onIncrement: () {
            if (_minors < TravelersModel.maxMinors) {
              HapticFeedback.selectionClick();
              _setMinors(_minors + 1);
            } else {
              _showLimitMessage('Maximum 20 children allowed.');
            }
          },
          onTapValue: () {
            _showDirectInputDialog(
              context: context,
              title: 'Children (under 18)',
              currentValue: _minors,
              min: TravelersModel.minMinors,
              max: TravelersModel.maxMinors,
              onConfirm: _setMinors,
            );
          },
        ),

        // Friendly Limit Notification
        if (_limitMessage != null) ...[
          const SizedBox(height: AppTokens.xs),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.brand),
              const SizedBox(width: 4),
              Text(
                _limitMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ],

        // Age of Minors Selector (Animated appearance when minors > 0)
        if (_minors > 0) ...[
          const SizedBox(height: AppTokens.lg),
          Container(
            padding: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppColors.border),
              boxShadow: AppTokens.shadow(level: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AGE OF CHILDREN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.textSoft,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardAlt,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                      child: const Text(
                        'Skippable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select age bands for custom pace, rides, and activities:',
                  style: TextStyle(fontSize: 12, color: AppColors.textSoft),
                ),
                const SizedBox(height: AppTokens.sm),

                // Age Band Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MinorAgeBand.all.map((band) {
                    final isSelected = _selectedAgeBands.contains(band);
                    return InkWell(
                      onTap: () => _toggleAgeBand(band),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brand.withValues(alpha: 0.1)
                              : AppColors.cardAlt,
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusMd),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brand
                                : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 16,
                              color: isSelected
                                  ? AppColors.brand
                                  : AppColors.textSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              MinorAgeBand.getLabel(band),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.brandDeep
                                    : AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppTokens.sm),

                // Default Explanation if Skipped
                if (_selectedAgeBands.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.cardAlt,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.textSoft,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'If skipped, we safely plan for a general mix of children (ages 6–12) with family-friendly attractions.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSoft,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppTokens.md),

        // Helper explanation card
        Container(
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _minors > 0 ? 'Why this helps?' : 'Trip Customization',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _minors > 0
                    ? 'We prioritize science centers, gardens, theme parks, nap breaks, and stroller-friendly places with zero bars or nightlife.'
                    : 'We calculate realistic travel logistics, ticket requirements, and comfortable pacing for your group size.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSoft,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 14, color: AppColors.textSoft),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'DPDP Privacy Safe: We store counts and age bands only. No children\'s personal data or photos are ever collected.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: AppTokens.shadow(level: isSelected ? 1 : 0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.brand : AppColors.textSoft,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.brandDeep : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required int value,
    required int min,
    required int max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required VoidCallback onTapValue,
  }) {
    final canDecrement = value > min;
    final canIncrement = value < max;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.md,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTokens.shadow(level: 1),
      ),
      child: Row(
        children: [
          // Icon Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: AppTokens.md),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),

          // Stepper Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrement Button
              Semantics(
                label: '$title, decrease button',
                button: true,
                child: InkWell(
                  onTap: canDecrement ? onDecrement : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: canDecrement
                            ? AppColors.border
                            : AppColors.border.withValues(alpha: 0.4),
                      ),
                      color: canDecrement
                          ? AppColors.cardAlt
                          : AppColors.bg,
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 20,
                      color: canDecrement
                          ? AppColors.text
                          : AppColors.textSoft.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),

              // Value (tappable for direct typing)
              Semantics(
                label: '$title, $value',
                child: InkWell(
                  onTap: onTapValue,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brandDeep,
                      ),
                    ),
                  ),
                ),
              ),

              // Increment Button
              Semantics(
                label: '$title, increase button',
                button: true,
                child: InkWell(
                  onTap: canIncrement ? onIncrement : null,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: canIncrement
                            ? AppColors.brand
                            : AppColors.border.withValues(alpha: 0.4),
                      ),
                      color: canIncrement
                          ? AppColors.brand.withValues(alpha: 0.08)
                          : AppColors.bg,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: canIncrement
                          ? AppColors.brand
                          : AppColors.textSoft.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
