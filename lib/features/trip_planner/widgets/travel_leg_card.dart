import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/transport_config.dart';
import '../../../core/models/transport_option_model.dart';
import '../../../core/models/travel_leg_model.dart';
import '../../../core/models/travelers_model.dart';
import 'transport_options_sheet.dart';

/// Distinct Journey Card rendered in the timeline between cities
class TravelLegCard extends StatelessWidget {
  final TravelLegModel leg;
  final TravelersModel travelers;
  final ValueChanged<TransportOptionModel> onOptionSelected;

  const TravelLegCard({
    super.key,
    required this.leg,
    required this.travelers,
    required this.onOptionSelected,
  });

  Future<void> _launchBooking(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open booking portal.')),
        );
      }
    }
  }

  void _openOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TransportOptionsSheet(
        leg: leg,
        travelers: travelers,
        onOptionSelected: (opt) {
          onOptionSelected(opt);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opt = leg.selectedOption;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTokens.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.brand.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transit Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(opt.iconData, size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${leg.fromCity} → ${leg.toCity}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandDeep,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    border: Border.all(color: AppColors.brand.withOpacity(0.2)),
                  ),
                  child: Text(
                    '${leg.distanceKm.toInt()} km',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(AppTokens.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                opt.modeName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              if (opt.isRecommended) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                                  ),
                                  child: const Text(
                                    'Recommended',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${opt.formattedDuration} · Departs ${leg.departureTime} → Arrives ~${leg.arrivalTime}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            opt.comfortClass,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Price Pill
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${opt.estimatedTotalCost}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandDeep,
                          ),
                        ),
                        Text(
                          '₹${opt.estimatedCostPerPerson}/person',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (opt.isCustomEdited)
                          const Text(
                            'Edited by you',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                if (opt.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cardAlt,
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSoft),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            opt.notes,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),

                // Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Switch Mode Action
                    TextButton.icon(
                      onPressed: () => _openOptionsSheet(context),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: Text(
                        'Change Mode (${leg.availableOptions.length} available)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),

                    // Official Booking Link
                    if (opt.bookingUrl != null)
                      ElevatedButton.icon(
                        onPressed: () => _launchBooking(context, opt.bookingUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: Text(
                          _getBookingPortalName(opt.mode),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getBookingPortalName(String mode) {
    switch (mode) {
      case 'train':
        return 'Search IRCTC';
      case 'bus':
        return 'Search RedBus';
      case 'flight':
        return 'Search Flights';
      case 'car':
        return 'Search Cab';
      default:
        return 'Search Booking';
    }
  }
}
