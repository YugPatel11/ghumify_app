import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/app_settings_provider.dart';
import '../../../core/models/group_activity_model.dart';
import '../../../core/models/nearby_service_model.dart';
import '../../../core/models/personal_itinerary_model.dart';
import '../../../core/constants/food_preferences.dart';
import '../../trip_planner/widgets/nearby_services_section.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'group_place_detail_sheet.dart';
import 'meeting_point_dialog.dart';
import 'personal_plan_summary_card.dart';
import '../../../core/utils/route_proximity_optimizer.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/services/location_service.dart';


/// Group itinerary tab supporting two distinct editing modes:
/// 1. "Whole Group": edits the shared group itinerary followed by everyone
/// 2. "Only Me": edits a personal customized plan with mandatory meeting points
class GroupItineraryTab extends StatefulWidget {
  final String groupId;

  const GroupItineraryTab({super.key, required this.groupId});

  @override
  State<GroupItineraryTab> createState() => _GroupItineraryTabState();
}

class _GroupItineraryTabState extends State<GroupItineraryTab> {
  // Local draft state for "Only Me" personal editing
  List<Map<String, dynamic>> _personalDraftStops = [];
  List<MeetingPointModel> _personalDraftMeetingPoints = [];
  bool _personalDraftInitialized = false;
  bool _hasUnsavedPersonalChanges = false;
  bool _isSavingPersonal = false;

  void _initPersonalDraftIfNeeded({
    required PersonalItineraryModel? savedPersonal,
    required List<Map<String, dynamic>> groupStops,
  }) {
    if (_personalDraftInitialized) return;

    if (savedPersonal != null && savedPersonal.customStops.isNotEmpty) {
      _personalDraftStops = savedPersonal.customStops
          .map((s) => Map<String, dynamic>.from(s))
          .toList();
      _personalDraftMeetingPoints = List.from(savedPersonal.meetingPoints);
    } else {
      _personalDraftStops = groupStops.map((s) {
        final cloned = Map<String, dynamic>.from(s);
        cloned['statusTag'] = 'unchanged';
        return cloned;
      }).toList();
      _personalDraftMeetingPoints = savedPersonal != null
          ? List.from(savedPersonal.meetingPoints)
          : [];
    }
    _personalDraftInitialized = true;
  }

  bool _checkHasDiverged(List<Map<String, dynamic>> groupStops) {
    if (_personalDraftStops.any((s) => s['statusTag'] != null && s['statusTag'] != 'unchanged')) {
      return true;
    }
    if (_personalDraftStops.length != groupStops.length) return true;
    for (int i = 0; i < groupStops.length; i++) {
      if (_personalDraftStops[i]['name'] != groupStops[i]['name']) return true;
    }
    return false;
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmDiscardPersonalDraft(VoidCallback onConfirmed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text(
          'Unsaved Personal Changes',
          style: GoogleFonts.outfit(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You have unsaved changes in your personal plan. Discard them and switch to Whole Group mode?',
          style: GoogleFonts.outfit(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Discard', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _hasUnsavedPersonalChanges = false;
        _personalDraftInitialized = false;
      });
      onConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<GroupProvider, AuthProvider, AppSettingsProvider>(
      builder: (context, groupProvider, authProvider, settingsProvider, _) {
        final group = groupProvider.currentGroup;
        final itinerary = groupProvider.currentItinerary;
        final personalItinerary = groupProvider.personalItinerary;
        final userId = authProvider.user?.uid ?? '';
        final userName = authProvider.user?.name ?? 'A member';
        final userFoodPref = settingsProvider.foodPreference;

        if (group == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        final canEditGroup = group.canEditItinerary(userId);
        final isAdmin = group.isAdmin(userId);

        if (itinerary == null) {
          return _buildEmptyState(context, groupProvider, authProvider, canEditGroup);
        }

        final city = itinerary['city'] ?? 'Trip';
        final groupStops = List<Map<String, dynamic>>.from(
          (itinerary['stops'] as List<dynamic>? ?? []).map(
            (s) => Map<String, dynamic>.from(s as Map),
          ),
        );

        // Auto-initialize personal draft if in personal mode
        if (groupProvider.isPersonalMode) {
          _initPersonalDraftIfNeeded(
            savedPersonal: personalItinerary,
            groupStops: groupStops,
          );
        }

        return ListView(
          padding: const EdgeInsets.all(AppTokens.md),
          children: [
            // ── Mode Switcher Segmented Control ──
            _buildModeSwitcher(context, groupProvider, canEditGroup),

            // ── Mode Explanation Banner ──
            _buildModeBanner(groupProvider.isPersonalMode, canEditGroup),

            // ── Mode Specific Content ──
            if (groupProvider.isPersonalMode)
              _buildPersonalModeContent(
                context,
                groupProvider,
                groupStops,
                city,
                userId,
                userName,
                userFoodPref,
                personalItinerary,
                itinerary['date'] as String?,
              )
            else
              _buildGroupModeContent(
                context,
                groupProvider,
                itinerary,
                groupStops,
                city,
                canEditGroup,
                isAdmin,
              ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MODE SWITCHER & BANNER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildModeSwitcher(
    BuildContext context,
    GroupProvider groupProvider,
    bool canEditGroup,
  ) {
    final isPersonal = groupProvider.isPersonalMode;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.md),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeSegmentButton(
              label: 'Whole Group',
              icon: Icons.groups_rounded,
              isSelected: !isPersonal,
              badgeText: null,
              onTap: () {
                if (_hasUnsavedPersonalChanges) {
                  _confirmDiscardPersonalDraft(() {
                    groupProvider.setItineraryMode('group');
                  });
                } else {
                  groupProvider.setItineraryMode('group');
                }
              },
            ),
          ),
          Expanded(
            child: _ModeSegmentButton(
              label: 'Only Me',
              icon: Icons.person_rounded,
              isSelected: isPersonal,
              badgeText: groupProvider.personalItinerary?.hasDiverged == true ? 'Active' : null,
              onTap: () {
                groupProvider.setItineraryMode('personal');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeBanner(bool isPersonal, bool canEditGroup) {
    if (isPersonal) {
      return Container(
        margin: const EdgeInsets.only(bottom: AppTokens.md),
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.brand.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(color: AppColors.brand.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_pin_circle_outlined, size: 20, color: AppColors.brand),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are editing only your own plan',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                  Text(
                    'Customize stops to your liking. Every personal change requires a meeting point where you rejoin the group.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.md),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 10),
      decoration: BoxDecoration(
        color: canEditGroup
            ? AppColors.brand.withOpacity(0.08)
            : AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(
          color: canEditGroup
              ? AppColors.brand.withOpacity(0.25)
              : AppColors.warning.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canEditGroup ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
            size: 20,
            color: canEditGroup ? AppColors.brand : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canEditGroup
                      ? 'You are editing the plan for the whole group'
                      : 'Viewing shared group itinerary',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: canEditGroup ? AppColors.brand : AppColors.warning,
                  ),
                ),
                Text(
                  canEditGroup
                      ? 'Changes you save here will be seen by and followed by all group members.'
                      : 'Only admins and authorized editors can modify the group plan. Switch to "Only Me" to customize your personal plan.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // WHOLE GROUP MODE VIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGroupModeContent(
    BuildContext context,
    GroupProvider groupProvider,
    Map<String, dynamic> itinerary,
    List<Map<String, dynamic>> stops,
    String city,
    bool canEditGroup,
    bool isAdmin,
  ) {
    final group = groupProvider.currentGroup!;
    final lastEditName = group.lastItineraryEditByName ?? 'A member';
    final lastEditAt = group.lastItineraryEditAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary of members on personal plans (Safety & Coordination)
        PersonalPlanSummarySection(
          personalPlans: groupProvider.allPersonalItineraries,
        ),

        // Shared Group Header Card
        Container(
          padding: const EdgeInsets.all(AppTokens.lg),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: AppTokens.shadow(level: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$city Itinerary',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: canEditGroup
                          ? AppColors.brand.withOpacity(0.15)
                          : AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      canEditGroup ? 'Group Editable' : 'View Only',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: canEditGroup ? AppColors.brand : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Last updated by $lastEditName${lastEditAt != null ? ' • ${_formatRelative(lastEditAt)}' : ''}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final adultsCount = itinerary['adultsCount'] as int?;
                  final minorsCount = itinerary['minorsCount'] as int? ?? 0;
                  final rawSummary = itinerary['travelersSummary'] as String?;
                  final summary = rawSummary ??
                      (adultsCount != null
                          ? '$adultsCount ${adultsCount == 1 ? "Adult" : "Adults"}${minorsCount > 0 ? ", $minorsCount ${minorsCount == 1 ? "Child" : "Children"}" : ""}'
                          : '${group.memberIds.length} Group Members');
                  final isFamily = minorsCount > 0 || (itinerary['isFamilyFriendly'] as bool? ?? false);

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isFamily ? const Color(0xFFE8F5E9) : AppColors.brand.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      border: Border.all(
                        color: isFamily ? const Color(0xFFA5D6A7) : AppColors.brand.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFamily ? Icons.family_restroom : Icons.people_outline,
                          size: 14,
                          color: isFamily ? const Color(0xFF2E7D32) : AppColors.brand,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          summary,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isFamily ? const Color(0xFF2E7D32) : AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTokens.md),
              Wrap(
                spacing: AppTokens.sm,
                runSpacing: AppTokens.sm,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: Text(
                      'Activity History',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                    ),
                    onPressed: () => _showActivityLogs(context, groupProvider.activityLogs),
                  ),
                  if (isAdmin)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                      label: Text(
                        'Clear',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        ),
                      ),
                      onPressed: () => _confirmClearItinerary(context, groupProvider),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTokens.lg),

        // Stops Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Planned Stops (${stops.length})',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
            if (canEditGroup)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stops.length > 1)
                    TextButton.icon(
                      icon: const Icon(Icons.near_me_outlined, size: 16, color: AppColors.brand),
                      label: Text(
                        'Re-order',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brand,
                        ),
                      ),
                      onPressed: () => _reorderByNearestGroupStops(groupProvider, itinerary, stops),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.brand),
                    label: Text(
                      'Add Stop',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                    onPressed: () => _showAddGroupStopDialog(context, groupProvider, itinerary, stops),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppTokens.sm),

        // Stops list
        if (stops.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTokens.xl),
            alignment: Alignment.center,
            child: Text(
              'No group stops added yet.',
              style: GoogleFonts.outfit(color: AppColors.textMuted),
            ),
          )
        else
          ...stops.asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;
            return _StopCard(
              index: index,
              stop: stop,
              totalStops: stops.length,
              canEdit: canEditGroup,
              city: city,
              onTap: () => _openPlaceDetailSheet(
                stop: stop,
                city: city,
                itineraryDate: itinerary['date'] as String?,
              ),
              onShareToChat: () {
                groupProvider.shareStopToChat(
                  groupId: widget.groupId,
                  stopData: stop,
                  city: city,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Shared "${stop['name']}" to group chat!',
                      style: GoogleFonts.outfit(),
                    ),
                    backgroundColor: AppColors.brand,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              onMoveUp: index > 0 && canEditGroup
                  ? () => _reorderGroupStop(groupProvider, itinerary, stops, index, index - 1)
                  : null,
              onMoveDown: index < stops.length - 1 && canEditGroup
                  ? () => _reorderGroupStop(groupProvider, itinerary, stops, index, index + 1)
                  : null,
              onDelete: canEditGroup
                  ? () => _deleteGroupStop(groupProvider, itinerary, stops, index)
                  : null,
            );
          }),

        const SizedBox(height: AppTokens.xl),

        // Shared Group Safety Services
        NearbyServicesSection(
          latitude: stops.isNotEmpty
              ? (stops.first['latitude'] as num?)?.toDouble()
              : null,
          longitude: stops.isNotEmpty
              ? (stops.first['longitude'] as num?)?.toDouble()
              : null,
          locationName: city,
          initialServices: (itinerary['nearbySafetyServices'] as List? ?? [])
              .map((s) => NearbyServiceModel.fromMap(
                  Map<String, dynamic>.from(s as Map)))
              .toList(),
          canRefresh: canEditGroup,
          isSavedMode: true,
          onServicesUpdated: canEditGroup
              ? (services) {
                  FirebaseFirestore.instance
                      .collection('groups')
                      .doc(widget.groupId)
                      .collection('group_itineraries')
                      .doc('active')
                      .set({
                    'nearbySafetyServices':
                        services.map((s) => s.toMap()).toList(),
                  }, SetOptions(merge: true));
                }
              : null,
        ),

        const SizedBox(height: AppTokens.xxl),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ONLY ME (PERSONAL) MODE VIEW
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPersonalModeContent(
    BuildContext context,
    GroupProvider groupProvider,
    List<Map<String, dynamic>> groupStops,
    String city,
    String userId,
    String userName,
    String userFoodPref,
    PersonalItineraryModel? personalItinerary, [
    String? itineraryDate,
  ]) {
    final hasDiverged = _checkHasDiverged(groupStops);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "Needs Review" Banner if Group Itinerary was Changed ──
        if (personalItinerary?.needsReview == true)
          Container(
            margin: const EdgeInsets.only(bottom: AppTokens.md),
            padding: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppColors.warning.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Needs Review: Shared Plan Updated',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  personalItinerary!.reviewReason ??
                      'A stop in the shared group plan was modified or removed. Please verify your custom stops and meeting point.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.text,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: AppTokens.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                    ),
                    onPressed: () {
                      final updated = personalItinerary.copyWith(
                        status: 'active',
                        reviewReason: null,
                      );
                      groupProvider.savePersonalItinerary(
                        groupId: widget.groupId,
                        personalItinerary: updated,
                        actionDescription: 'acknowledged the shared plan updates',
                      );
                    },
                    child: Text('Acknowledge & Keep Plan', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

        // ── MANDATORY MEETING POINTS SECTION ──
        Container(
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: hasDiverged && _personalDraftMeetingPoints.isEmpty
                  ? AppColors.error
                  : AppColors.brand.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: AppTokens.shadow(level: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.meeting_room_rounded, color: AppColors.brand, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Meeting Point (Required)',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16, color: AppColors.brand),
                    label: Text(
                      _personalDraftMeetingPoints.isEmpty ? 'Set Point' : 'Add Point',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
                    ),
                    onPressed: () => _openMeetingPointDialog(groupStops),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Where and when you will meet back up with the group. Mandatory whenever your plan differs from the group.',
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppTokens.sm),

              if (_personalDraftMeetingPoints.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(AppTokens.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasDiverged
                              ? 'Action needed: You made personal changes. Add a meeting point before saving.'
                              : 'No meeting point set yet. You are currently following the group plan.',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.warning),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._personalDraftMeetingPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mp = entry.value;
                  return _buildMeetingPointCard(mp, index, groupStops);
                }),
            ],
          ),
        ),

        const SizedBox(height: AppTokens.lg),

        // ── Personal Stops Header & Controls ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Personal Stops (${_personalDraftStops.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                if (userFoodPref != FoodPreference.all)
                  Text(
                    'Honoring food preference: ${FoodPreference.getLabel(userFoodPref)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: FoodPreference.getIndicatorColor(userFoodPref),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.brand),
              label: Text(
                'Add Stop',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
              onPressed: () => _showAddPersonalStopDialog(context, userFoodPref),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.sm),

        // ── Personal Stops List ──
        if (_personalDraftStops.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTokens.xl),
            alignment: Alignment.center,
            child: Text(
              'No personal stops. Tap "Add Stop" to customize your itinerary.',
              style: GoogleFonts.outfit(color: AppColors.textMuted),
            ),
          )
        else
          ..._personalDraftStops.asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;
            final statusTag = stop['statusTag'] as String? ?? 'unchanged';

            return _StopCard(
              index: index,
              stop: stop,
              totalStops: _personalDraftStops.length,
              canEdit: true,
              city: city,
              statusTag: statusTag,
              onTap: () => _openPlaceDetailSheet(
                stop: stop,
                city: city,
                itineraryDate: itineraryDate,
              ),
              onShareToChat: () {
                groupProvider.shareStopToChat(
                  groupId: widget.groupId,
                  stopData: stop,
                  city: city,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Shared personal stop "${stop['name']}" to chat!',
                      style: GoogleFonts.outfit(),
                    ),
                    backgroundColor: AppColors.brand,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              onEdit: () => _showEditPersonalStopDialog(context, stop, index),
              onMoveUp: index > 0
                  ? () => _reorderPersonalStop(index, index - 1)
                  : null,
              onMoveDown: index < _personalDraftStops.length - 1
                  ? () => _reorderPersonalStop(index, index + 1)
                  : null,
              onDelete: () => _deletePersonalStop(index),
              onRestore: statusTag == 'removed'
                  ? () => _restorePersonalStop(index)
                  : null,
            );
          }),

        const SizedBox(height: AppTokens.lg),

        // ── Action Buttons (Save Personal Plan & Reset to Group Plan) ──
        _buildPersonalActionButtons(
          context,
          groupProvider,
          userId,
          userName,
          groupStops,
        ),

        const SizedBox(height: AppTokens.xxl),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MEETING POINT CARD & ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMeetingPointCard(
    MeetingPointModel mp,
    int index,
    List<Map<String, dynamic>> groupStops,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppTokens.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mp.placeName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                onPressed: () => _openMeetingPointDialog(groupStops, existing: mp, index: index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                onPressed: () {
                  setState(() {
                    _personalDraftMeetingPoints.removeAt(index);
                    _hasUnsavedPersonalChanges = true;
                  });
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.brand),
                    const SizedBox(width: 4),
                    Text(
                      'Rejoin time: ${mp.meetTime}${mp.meetDate != null ? ' (${mp.meetDate})' : ''}',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
                    ),
                  ],
                ),
                if (mp.rejoinStopName != null && mp.rejoinStopName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Rejoining at group stop: ${mp.rejoinStopName}',
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSoft),
                  ),
                ],
                if (mp.notes != null && mp.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: "${mp.notes}"',
                    style: GoogleFonts.outfit(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () => _launchUrl(mp.googleMapsUrl),
                      child: Row(
                        children: [
                          const Icon(Icons.map_rounded, size: 14, color: AppColors.brand),
                          const SizedBox(width: 4),
                          Text(
                            'Open in Google Maps',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brand),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTokens.md),
                    InkWell(
                      onTap: () => _launchUrl(mp.directionsUrl),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_rounded, size: 14, color: AppColors.brand),
                          const SizedBox(width: 4),
                          Text(
                            'Directions',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brand),
                          ),
                        ],
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

  void _openPlaceDetailSheet({
    required Map<String, dynamic> stop,
    required String city,
    String? itineraryDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupPlaceDetailSheet(
        stop: stop,
        city: city,
        itineraryDate: itineraryDate,
        groupId: widget.groupId,
        onShareToChat: () {
          final groupProvider = context.read<GroupProvider>();
          groupProvider.shareStopToChat(
            groupId: widget.groupId,
            stopData: stop,
            city: city,
          );
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shared "${stop['name']}" to group chat!',
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: AppColors.brand,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _openMeetingPointDialog(
    List<Map<String, dynamic>> groupStops, {
    MeetingPointModel? existing,
    int? index,
  }) async {
    final lastStop = _personalDraftStops.isNotEmpty ? _personalDraftStops.last : null;

    final result = await showDialog<MeetingPointModel>(
      context: context,
      builder: (ctx) => MeetingPointDialog(
        initialMeetingPoint: existing,
        groupStops: groupStops,
        lastPersonalStop: lastStop,
      ),
    );

    if (result != null) {
      setState(() {
        if (index != null && index < _personalDraftMeetingPoints.length) {
          _personalDraftMeetingPoints[index] = result;
        } else {
          _personalDraftMeetingPoints.add(result);
        }
        _hasUnsavedPersonalChanges = true;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PERSONAL ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPersonalActionButtons(
    BuildContext context,
    GroupProvider groupProvider,
    String userId,
    String userName,
    List<Map<String, dynamic>> groupStops,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(
                  'Reset to Group Plan',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: AppColors.error.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                onPressed: () => _confirmResetPersonalPlan(context, groupProvider, userId, groupStops),
              ),
            ),
            const SizedBox(width: AppTokens.md),
            Expanded(
              child: ElevatedButton.icon(
                icon: _isSavingPersonal
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  'Save Personal Plan',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                onPressed: _isSavingPersonal
                    ? null
                    : () => _savePersonalPlan(context, groupProvider, userId, userName, groupStops),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _savePersonalPlan(
    BuildContext context,
    GroupProvider groupProvider,
    String userId,
    String userName,
    List<Map<String, dynamic>> groupStops,
  ) async {
    final hasDiverged = _checkHasDiverged(groupStops);

    // MANDATORY MEETING POINT ENFORCEMENT
    if (hasDiverged && _personalDraftMeetingPoints.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meeting Point Required',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Text(
            'Your personal itinerary has customized stops. You must specify a meeting point so the group knows where and when you will rejoin them.',
            style: GoogleFonts.outfit(color: AppColors.textMuted),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () {
                Navigator.of(ctx).pop();
                _openMeetingPointDialog(groupStops);
              },
              child: Text('Add Meeting Point', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSavingPersonal = true);

    try {
      final addedNames = _personalDraftStops
          .where((s) => s['statusTag'] == 'added')
          .map((s) => s['name'] as String)
          .toList();
      final modifiedNames = _personalDraftStops
          .where((s) => s['statusTag'] == 'modified')
          .map((s) => s['name'] as String)
          .toList();
      final removedNames = _personalDraftStops
          .where((s) => s['statusTag'] == 'removed')
          .map((s) => s['name'] as String)
          .toList();

      final model = PersonalItineraryModel(
        id: userId,
        userId: userId,
        userName: userName,
        groupId: widget.groupId,
        status: 'active',
        meetingPoints: _personalDraftMeetingPoints,
        customStops: _personalDraftStops,
        addedStopNames: addedNames,
        modifiedStopNames: modifiedNames,
        removedStopNames: removedNames,
        updatedAt: DateTime.now(),
      );

      await groupProvider.savePersonalItinerary(
        groupId: widget.groupId,
        personalItinerary: model,
      );

      setState(() {
        _hasUnsavedPersonalChanges = false;
        _isSavingPersonal = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Personal plan saved! Group members can see your rejoin point.',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSavingPersonal = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmResetPersonalPlan(
    BuildContext context,
    GroupProvider groupProvider,
    String userId,
    List<Map<String, dynamic>> groupStops,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Reset to Group Plan?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.text)),
        content: Text(
          'This will remove all your personal stops and meeting points. Your schedule will sync back to the shared group itinerary.',
          style: GoogleFonts.outfit(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Reset', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await groupProvider.resetPersonalItinerary(
          groupId: widget.groupId,
          userId: userId,
        );

        setState(() {
          _personalDraftStops = groupStops.map((s) {
            final cloned = Map<String, dynamic>.from(s);
            cloned['statusTag'] = 'unchanged';
            return cloned;
          }).toList();
          _personalDraftMeetingPoints = [];
          _hasUnsavedPersonalChanges = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset to group plan successfully.', style: GoogleFonts.outfit()),
              backgroundColor: AppColors.brand,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString(), style: GoogleFonts.outfit()),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PERSONAL STOP EDITING & REORDERING
  // ═══════════════════════════════════════════════════════════════════

  void _showAddPersonalStopDialog(BuildContext context, String foodPref) {
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String stopType = 'place';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text('Add Personal Stop', style: GoogleFonts.outfit(color: AppColors.text, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Place / Stop Name',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Time (e.g. 2:00 PM)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: stopType,
                dropdownColor: AppColors.card,
                items: const [
                  DropdownMenuItem(value: 'place', child: Text('Sightseeing Place')),
                  DropdownMenuItem(value: 'food', child: Text('Food / Restaurant')),
                  DropdownMenuItem(value: 'market', child: Text('Market / Shopping')),
                  DropdownMenuItem(value: 'break', child: Text('Rest / Break')),
                ],
                onChanged: (val) {
                  setDlgState(() => stopType = val ?? 'place');
                },
                decoration: InputDecoration(
                  labelText: 'Category',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
              if (stopType == 'food' && foodPref != FoodPreference.all) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '💡 Filtered for your dietary choice: ${FoodPreference.getLabel(foodPref)}',
                    style: GoogleFonts.outfit(fontSize: 11, color: FoodPreference.getIndicatorColor(foodPref)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Notes / Description',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                setState(() {
                  _personalDraftStops.add({
                    'name': name,
                    'type': stopType,
                    'startTime': timeCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'statusTag': 'added',
                    'dietaryType': stopType == 'food' ? foodPref : null,
                  });
                  _hasUnsavedPersonalChanges = true;
                });
                Navigator.of(ctx).pop();
              },
              child: Text('Add', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPersonalStopDialog(BuildContext context, Map<String, dynamic> stop, int index) {
    final nameCtrl = TextEditingController(text: stop['name']);
    final timeCtrl = TextEditingController(text: stop['startTime']);
    final descCtrl = TextEditingController(text: stop['description']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('Edit Personal Stop', style: GoogleFonts.outfit(color: AppColors.text, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: GoogleFonts.outfit(color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Place / Stop Name',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: timeCtrl,
              style: GoogleFonts.outfit(color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Time (e.g. 2:00 PM)',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: GoogleFonts.outfit(color: AppColors.text),
              decoration: InputDecoration(
                labelText: 'Notes / Description',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              setState(() {
                final currentTag = stop['statusTag'];
                _personalDraftStops[index]['name'] = name;
                _personalDraftStops[index]['startTime'] = timeCtrl.text.trim();
                _personalDraftStops[index]['description'] = descCtrl.text.trim();
                _personalDraftStops[index]['statusTag'] =
                    currentTag == 'added' ? 'added' : 'modified';
                _hasUnsavedPersonalChanges = true;
              });
              Navigator.of(ctx).pop();
            },
            child: Text('Save', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _reorderPersonalStop(int oldIndex, int newIndex) {
    setState(() {
      final moved = _personalDraftStops.removeAt(oldIndex);
      _personalDraftStops.insert(newIndex, moved);
      _hasUnsavedPersonalChanges = true;
    });
  }

  void _deletePersonalStop(int index) {
    setState(() {
      final stop = _personalDraftStops[index];
      if (stop['statusTag'] == 'added') {
        _personalDraftStops.removeAt(index);
      } else {
        _personalDraftStops[index]['statusTag'] = 'removed';
      }
      _hasUnsavedPersonalChanges = true;
    });
  }

  void _restorePersonalStop(int index) {
    setState(() {
      _personalDraftStops[index]['statusTag'] = 'unchanged';
      _hasUnsavedPersonalChanges = true;
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED GROUP STOP DIALOG & HELPERS
  // ═══════════════════════════════════════════════════════════════════

  void _showAddGroupStopDialog(
    BuildContext context,
    GroupProvider groupProvider,
    Map<String, dynamic> itinerary,
    List<Map<String, dynamic>> currentStops,
  ) {
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text(
            'Add Stop to Group Plan',
            style: GoogleFonts.outfit(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Place / Stop Name',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Time (e.g. 10:00 AM)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Description / Notes',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final newStop = {
                  'name': name,
                  'type': 'place',
                  'startTime': timeCtrl.text.trim(),
                  'endTime': '',
                  'durationMinutes': 60,
                  'description': descCtrl.text.trim(),
                  'tips': <String>[],
                };

                final updatedStops = List<Map<String, dynamic>>.from(currentStops)..add(newStop);
                final updatedItinerary = Map<String, dynamic>.from(itinerary);
                updatedItinerary['stops'] = updatedStops;

                groupProvider.updateItinerary(
                  groupId: widget.groupId,
                  itineraryData: updatedItinerary,
                  actionDescription: 'added stop "$name" to the group plan',
                );

                Navigator.of(context).pop();
              },
              child: Text('Add', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reorderByNearestGroupStops(
    GroupProvider groupProvider,
    Map<String, dynamic> itinerary,
    List<Map<String, dynamic>> stops,
  ) async {
    if (stops.length < 2) return;

    // Start point: group meeting point, hotel stay, or first stop
    double? startLat;
    double? startLng;
    String startLabel = 'Group start point';

    for (final s in stops) {
      if (s['type'] == 'meeting_point' || s['type'] == 'hotel' || s['isAnchored'] == true) {
        final lat = (s['latitude'] as num?)?.toDouble();
        final lng = (s['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          startLat = lat;
          startLng = lng;
          startLabel = 'Group stay/meeting point: ${s['name']}';
          break;
        }
      }
    }

    if (startLat == null || startLng == null) {
      final city = itinerary['city'] ?? 'Trip';
      final resolved = await LocationService().resolveStartPoint(city: city);
      startLat = resolved.latitude;
      startLng = resolved.longitude;
      startLabel = 'City center ($city)';
    }

    final parsedStops = stops.map((s) {
      final isFood = s['type'] == 'food' || s['type'] == 'meal' || s['type'] == 'restaurant';
      final isMeeting = s['type'] == 'meeting_point';
      return ItineraryStop.fromMap({
        ...s,
        'isAnchored': s['isAnchored'] == true || isFood || isMeeting,
      });
    }).toList();

    final prevStops = List<Map<String, dynamic>>.from(stops);

    final optResult = RouteProximityOptimizer.optimizeStopsProximity(
      stops: parsedStops,
      startLat: startLat,
      startLng: startLng,
      startPointLabel: startLabel,
      pace: itinerary['pace'] ?? 'moderate',
    );

    final reorderedMaps = optResult.orderedStops.map((s) => s.toMap()).toList();
    final updatedItinerary = Map<String, dynamic>.from(itinerary);
    updatedItinerary['stops'] = reorderedMaps;
    updatedItinerary['isManuallyOrdered'] = false;
    updatedItinerary['routeStartPointInfo'] = startLabel;

    await groupProvider.updateItinerary(
      groupId: widget.groupId,
      itineraryData: updatedItinerary,
      actionDescription: 're-ordered stops nearest-first from $startLabel',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Re-ordered by proximity starting from $startLabel',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              final restoredItinerary = Map<String, dynamic>.from(itinerary);
              restoredItinerary['stops'] = prevStops;
              groupProvider.updateItinerary(
                groupId: widget.groupId,
                itineraryData: restoredItinerary,
                actionDescription: 'restored previous stop order',
              );
            },
          ),
        ),
      );
    }
  }

  void _reorderGroupStop(
    GroupProvider groupProvider,
    Map<String, dynamic> itinerary,
    List<Map<String, dynamic>> stops,
    int oldIndex,
    int newIndex,
  ) {
    final updatedStops = List<Map<String, dynamic>>.from(stops);
    final moved = updatedStops.removeAt(oldIndex);
    updatedStops.insert(newIndex, moved);

    final updatedItinerary = Map<String, dynamic>.from(itinerary);
    updatedItinerary['stops'] = updatedStops;

    groupProvider.updateItinerary(
      groupId: widget.groupId,
      itineraryData: updatedItinerary,
      actionDescription: 'reordered stop "${moved['name']}"',
    );
  }

  void _deleteGroupStop(
    GroupProvider groupProvider,
    Map<String, dynamic> itinerary,
    List<Map<String, dynamic>> stops,
    int index,
  ) {
    final updatedStops = List<Map<String, dynamic>>.from(stops);
    final removed = updatedStops.removeAt(index);

    final updatedItinerary = Map<String, dynamic>.from(itinerary);
    updatedItinerary['stops'] = updatedStops;

    groupProvider.updateItinerary(
      groupId: widget.groupId,
      itineraryData: updatedItinerary,
      actionDescription: 'removed stop "${removed['name']}" from the group plan',
    );
  }

  void _confirmClearItinerary(BuildContext context, GroupProvider groupProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text(
            'Clear Group Itinerary?',
            style: GoogleFonts.outfit(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
          content: Text(
            'This will remove the shared itinerary from the group. Individual members’ personal saved itineraries will remain untouched.',
            style: GoogleFonts.outfit(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                groupProvider.clearItinerary(widget.groupId);
              },
              child: Text('Clear', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showActivityLogs(BuildContext context, List<GroupActivityModel> logs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppTokens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Itinerary Activity History',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: AppTokens.md),
              if (logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No edits logged yet.',
                      style: GoogleFonts.outfit(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.brand.withOpacity(0.1),
                          child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.brand),
                        ),
                        title: Text(
                          log.details,
                          style: GoogleFonts.outfit(fontSize: 13, color: AppColors.text),
                        ),
                        subtitle: Text(
                          _formatRelative(log.timestamp),
                          style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    GroupProvider groupProvider,
    AuthProvider authProvider,
    bool canEditGroup,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.route_rounded,
                size: 48,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: AppTokens.lg),
            Text(
              'No Shared Itinerary Yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              canEditGroup
                  ? 'Import one of your saved itineraries to plan together with the group.'
                  : 'Group admins have not shared an itinerary yet.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (canEditGroup) ...[
              const SizedBox(height: AppTokens.xl),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_download_outlined, size: 20),
                label: Text(
                  'Import Saved Itinerary',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                ),
                onPressed: () => _showImportItineraryDialog(context, groupProvider, authProvider),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImportItineraryDialog(
    BuildContext context,
    GroupProvider groupProvider,
    AuthProvider authProvider,
  ) {
    final user = authProvider.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('itineraries')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppTokens.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No saved itineraries found.',
                      style: GoogleFonts.outfit(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppTokens.md),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(AppTokens.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select an Itinerary to Share',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: AppTokens.md),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final city = data['city'] ?? 'Trip';
                        final days = (data['days'] as List?)?.length ?? 1;

                        return ListTile(
                          title: Text(city, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppColors.text)),
                          subtitle: Text('$days Day(s)', style: GoogleFonts.outfit(color: AppColors.textMuted)),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.brand),
                          onTap: () {
                            Navigator.of(context).pop();
                            groupProvider.importItinerary(
                              groupId: widget.groupId,
                              itineraryData: data,
                              city: city,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEGMENT BUTTON WIDGET
// ═══════════════════════════════════════════════════════════════════

class _ModeSegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final String? badgeText;
  final VoidCallback onTap;

  const _ModeSegmentButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          boxShadow: isSelected ? AppTokens.shadow(level: 1) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.brand : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.text : AppColors.textMuted,
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                ),
                child: Text(
                  badgeText!,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STOP CARD WIDGET WITH ACCESSIBLE STATUS TAGS
// ═══════════════════════════════════════════════════════════════════

class _StopCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> stop;
  final int totalStops;
  final bool canEdit;
  final String city;
  final String? statusTag; // 'added' | 'modified' | 'removed' | 'unchanged'
  final VoidCallback onShareToChat;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onTap;

  const _StopCard({
    required this.index,
    required this.stop,
    required this.totalStops,
    required this.canEdit,
    required this.city,
    this.statusTag,
    required this.onShareToChat,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
    this.onRestore,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = stop['name'] ?? 'Stop';
    final startTime = stop['startTime'] ?? '';
    final description = stop['description'] ?? '';
    final isRemoved = statusTag == 'removed';
    final isAdded = statusTag == 'added';
    final isModified = statusTag == 'modified';

    final photoUrl = stop['photoUrl'] as String? ??
        (stop['galleryPhotos'] is List && (stop['galleryPhotos'] as List).isNotEmpty
            ? (stop['galleryPhotos'] as List).first as String?
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRemoved ? null : onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTokens.md),
          padding: const EdgeInsets.all(AppTokens.md),
          decoration: BoxDecoration(
            color: isRemoved ? AppColors.cardAlt : AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: isAdded
                  ? AppColors.success.withOpacity(0.4)
                  : isModified
                      ? AppColors.warning.withOpacity(0.4)
                      : isRemoved
                          ? AppColors.error.withOpacity(0.3)
                          : AppColors.border,
              width: isAdded || isModified || isRemoved ? 1.0 : 0.5,
            ),
            boxShadow: isRemoved ? null : AppTokens.shadow(level: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: isRemoved ? null : AppColors.brandGradient,
                      color: isRemoved ? AppColors.textMuted : null,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.sm),
                  if (photoUrl != null && photoUrl.isNotEmpty && !isRemoved) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: AppColors.cardAlt),
                          errorWidget: (c, u, e) => Container(
                            color: AppColors.cardAlt,
                            child: const Icon(Icons.place_rounded, size: 16, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isRemoved ? AppColors.textMuted : AppColors.text,
                                  decoration: isRemoved ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            if (isAdded) ...[
                              const SizedBox(width: 8),
                              _buildTagChip('Added', AppColors.success, Icons.add_circle_outline),
                            ],
                            if (isModified) ...[
                              const SizedBox(width: 8),
                              _buildTagChip('Changed', AppColors.warning, Icons.edit_note_outlined),
                            ],
                            if (isRemoved) ...[
                              const SizedBox(width: 8),
                              _buildTagChip('Removed', AppColors.error, Icons.remove_circle_outline),
                            ],
                            if (stop['isKidFriendly'] == true || stop['is_kid_friendly'] == true) ...[
                              const SizedBox(width: 8),
                              _buildTagChip('Kid-Friendly', const Color(0xFF2E7D32), Icons.child_care_rounded),
                            ],
                          ],
                        ),
                        if (startTime.isNotEmpty)
                          Text(
                            startTime,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: isRemoved ? AppColors.textMuted : AppColors.brand,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isRemoved)
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.brand),
                      tooltip: 'Share stop to chat',
                      onPressed: onShareToChat,
                    ),
                  if (canEdit) ...[
                    if (onEdit != null && !isRemoved)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSoft),
                        tooltip: 'Edit stop',
                        onPressed: onEdit,
                      ),
                    if (onMoveUp != null && !isRemoved)
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: AppColors.textMuted),
                        onPressed: onMoveUp,
                      ),
                    if (onMoveDown != null && !isRemoved)
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textMuted),
                        onPressed: onMoveDown,
                      ),
                    if (isRemoved && onRestore != null)
                      TextButton.icon(
                        icon: const Icon(Icons.undo_rounded, size: 16, color: AppColors.brand),
                        label: Text('Restore', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand)),
                        onPressed: onRestore,
                      )
                    else if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                        tooltip: 'Remove stop',
                        onPressed: onDelete,
                      ),
                  ],
                  if (!isRemoved)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.textMuted,
                      height: 1.3,
                      decoration: isRemoved ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
