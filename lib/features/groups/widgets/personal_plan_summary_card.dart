import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/personal_itinerary_model.dart';

/// Banner and cards shown in "Whole Group" mode summarizing members following personal plans
class PersonalPlanSummarySection extends StatelessWidget {
  final List<PersonalItineraryModel> personalPlans;

  const PersonalPlanSummarySection({
    super.key,
    required this.personalPlans,
  });

  @override
  Widget build(BuildContext context) {
    if (personalPlans.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.lg),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.brand.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.brand.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Members on Personal Plans (${personalPlans.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Text(
                  'Coordination',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These members are following customized personal stops and will rejoin the group at their designated meeting points:',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppTokens.sm),
          ...personalPlans.map((plan) => _PersonalMemberCard(plan: plan)),
        ],
      ),
    );
  }
}

class _PersonalMemberCard extends StatelessWidget {
  final PersonalItineraryModel plan;

  const _PersonalMemberCard({required this.plan});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryMp = plan.meetingPoints.isNotEmpty ? plan.meetingPoints.first : null;
    final meetPlace = primaryMp?.placeName ?? 'Designated meeting point';
    final meetTime = primaryMp?.meetTime ?? '';
    final rejoinStop = primaryMp?.rejoinStopName;
    final notes = primaryMp?.notes;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppTokens.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.brand.withOpacity(0.15),
                child: Text(
                  plan.userName.isNotEmpty ? plan.userName[0].toUpperCase() : 'M',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.userName,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (plan.needsReview)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: Text(
                    'Needs Review',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.text),
                    children: [
                      const TextSpan(text: 'Rejoins at '),
                      TextSpan(
                        text: meetPlace,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (meetTime.isNotEmpty) ...[
                        const TextSpan(text: ' at '),
                        TextSpan(
                          text: meetTime,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand),
                        ),
                      ],
                      if (rejoinStop != null && rejoinStop.isNotEmpty) ...[
                        TextSpan(
                          text: ' (Group stop: $rejoinStop)',
                          style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                'Note: "$notes"',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSoft,
                ),
              ),
            ),
          ],
          if (primaryMp != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                InkWell(
                  onTap: () => _launchUrl(primaryMp.googleMapsUrl),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_rounded, size: 14, color: AppColors.brand),
                        const SizedBox(width: 4),
                        Text(
                          'Open in Google Maps',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _launchUrl(primaryMp.directionsUrl),
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_rounded, size: 14, color: AppColors.brand),
                        const SizedBox(width: 4),
                        Text(
                          'Directions',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
