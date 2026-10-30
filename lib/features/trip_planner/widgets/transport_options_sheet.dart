import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/transport_config.dart';
import '../../../core/models/transport_option_model.dart';
import '../../../core/models/travel_leg_model.dart';
import '../../../core/models/travelers_model.dart';

/// Modal bottom sheet displaying all available transit options for an inter-city leg
class TransportOptionsSheet extends StatefulWidget {
  final TravelLegModel leg;
  final TravelersModel travelers;
  final ValueChanged<TransportOptionModel> onOptionSelected;

  const TransportOptionsSheet({
    super.key,
    required this.leg,
    required this.travelers,
    required this.onOptionSelected,
  });

  @override
  State<TransportOptionsSheet> createState() => _TransportOptionsSheetState();
}

class _TransportOptionsSheetState extends State<TransportOptionsSheet> {
  late TransportOptionModel _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.leg.selectedOption;
  }

  void _editPrice(TransportOptionModel option) async {
    final controller = TextEditingController(
      text: option.estimatedTotalCost.toString(),
    );

    final newPrice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Edit Cost for ', maxLines: 2, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Group Cost (₹ INR)',
            hintText: 'Enter your custom total fare',
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
              Navigator.of(ctx).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newPrice != null && newPrice > 0) {
      final perPerson = widget.travelers.totalCount > 0
          ? (newPrice / widget.travelers.totalCount).round()
          : newPrice;
      final updated = option.copyWith(
        estimatedTotalCost: newPrice,
        estimatedCostPerPerson: perPerson,
        isCustomEdited: true,
      );
      setState(() {
        _selected = updated;
      });
      widget.onOptionSelected(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppTokens.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.leg.fromCity} to ${widget.leg.toCity}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    'Distance: ${widget.leg.distanceKm.toInt()} km · ${widget.travelers.compactSummary}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSoft),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.md),

          // Options List
          Expanded(
            child: ListView.separated(
              itemCount: widget.leg.availableOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final opt = widget.leg.availableOptions[i];
                final isSelected = opt.id == _selected.id;

                return InkWell(
                  onTap: () {
                    setState(() => _selected = opt);
                  },
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.brandSoft : Colors.white,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : AppColors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(opt.iconData,
                                color: isSelected ? AppColors.brand : AppColors.textSoft),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        opt.modeName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? AppColors.brandDeep
                                              : AppColors.text,
                                        ),
                                      ),
                                      if (opt.isRecommended) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F5E9),
                                            borderRadius:
                                                BorderRadius.circular(AppTokens.radiusPill),
                                          ),
                                          child: const Text(
                                            'Recommended',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    opt.comfortClass,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${opt.estimatedTotalCost}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.brandDeep,
                                  ),
                                ),
                                Text(
                                  '₹${opt.estimatedCostPerPerson}/person',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected ? AppColors.brand : AppColors.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              opt.formattedDuration,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSoft),
                            ),
                            if (opt.recommendationReason != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                '• ${opt.recommendationReason!}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF2E7D32)),
                              ),
                            ],
                            const Spacer(),
                            // Edit price button
                            TextButton(
                              onPressed: () => _editPrice(opt),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Edit fare',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Disclaimer & Source Footnote
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardAlt,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.textSoft),
                    const SizedBox(width: 4),
                    const Text(
                      'ESTIMATED FARES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  TransportConfig.disclaimerText,
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.md),

          // Apply Selection Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onOptionSelected(_selected);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
              child: Text(
                'Select ${_selected.modeName} (₹${_selected.estimatedTotalCost})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
