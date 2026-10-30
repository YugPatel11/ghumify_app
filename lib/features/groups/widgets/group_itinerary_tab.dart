import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/group_activity_model.dart';
import '../../../core/models/nearby_service_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../trip_planner/widgets/nearby_services_section.dart';

/// Shared group itinerary tab with real-time sync, permission gating, and activity history
class GroupItineraryTab extends StatelessWidget {
  final String groupId;

  const GroupItineraryTab({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<GroupProvider, AuthProvider>(
      builder: (context, groupProvider, authProvider, _) {
        final group = groupProvider.currentGroup;
        final itinerary = groupProvider.currentItinerary;
        final userId = authProvider.user?.uid ?? '';

        if (group == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        final canEdit = group.canEditItinerary(userId);
        final isAdmin = group.isAdmin(userId);

        if (itinerary == null) {
          return _buildEmptyState(context, groupProvider, authProvider, canEdit);
        }

        final city = itinerary['city'] ?? 'Trip';
        final stops = List<Map<String, dynamic>>.from(
          (itinerary['stops'] as List<dynamic>? ?? []).map(
            (s) => Map<String, dynamic>.from(s as Map),
          ),
        );

        final lastEditName = group.lastItineraryEditByName ?? 'A member';
        final lastEditAt = group.lastItineraryEditAt;

        return ListView(
          padding: const EdgeInsets.all(AppTokens.md),
          children: [
            // Status and Header Card
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
                          color: canEdit
                              ? AppColors.brand.withOpacity(0.15)
                              : AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        ),
                        child: Text(
                          canEdit ? 'Editable' : 'View Only',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: canEdit ? AppColors.brand : AppColors.warning,
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
                  const SizedBox(height: AppTokens.md),
                  Row(
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
                      const SizedBox(width: AppTokens.sm),
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

            // Stops Title
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
                if (canEdit)
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
                    onPressed: () => _showAddStopDialog(context, groupProvider, itinerary, stops),
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
                  'No stops added yet.',
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
                  canEdit: canEdit,
                  city: city,
                  onShareToChat: () {
                    groupProvider.shareStopToChat(
                      groupId: groupId,
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
                  onMoveUp: index > 0 && canEdit
                      ? () => _reorderStop(groupProvider, itinerary, stops, index, index - 1)
                      : null,
                  onMoveDown: index < stops.length - 1 && canEdit
                      ? () => _reorderStop(groupProvider, itinerary, stops, index, index + 1)
                      : null,
                  onDelete: canEdit
                      ? () => _deleteStop(groupProvider, itinerary, stops, index)
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
              canRefresh: canEdit,
              isSavedMode: true,
              onServicesUpdated: canEdit
                  ? (services) {
                      FirebaseFirestore.instance
                          .collection('groups')
                          .doc(groupId)
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
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    GroupProvider groupProvider,
    AuthProvider authProvider,
    bool canEdit,
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
              canEdit
                  ? 'Import one of your saved itineraries to plan together with the group.'
                  : 'Group admins have not shared an itinerary yet.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (canEdit) ...[
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
              .collection(AppConstants.itinerariesCollection)
              .where('userId', isEqualTo: user.uid)
              .where('isSaved', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.brand),
                ),
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
                      'No Saved Itineraries',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have any saved itineraries to import. Craft one first from the Plan Trip tab!',
                      style: GoogleFonts.outfit(color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTokens.lg),
                  ],
                ),
              );
            }

            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppTokens.lg),
              children: [
                Text(
                  'Select an Itinerary to Share',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: AppTokens.md),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final city = data['city'] ?? 'Trip';
                  final date = data['date'] ?? '';
                  final stops = (data['stops'] as List<dynamic>? ?? []).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppTokens.sm),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_city_rounded, color: AppColors.brand),
                      ),
                      title: Text(
                        city,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      subtitle: Text(
                        '$stops stops • $date',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await groupProvider.importItinerary(
                          groupId: groupId,
                          itineraryData: data,
                          city: city,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Shared "$city" itinerary with the group!',
                                style: GoogleFonts.outfit(),
                              ),
                              backgroundColor: AppColors.brand,
                            ),
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddStopDialog(
    BuildContext context,
    GroupProvider groupProvider,
    Map<String, dynamic> itinerary,
    List<Map<String, dynamic>> currentStops,
  ) {
    final nameCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '12:00 PM');
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          ),
          title: Text(
            'Add Stop',
            style: GoogleFonts.outfit(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
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
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Time (e.g. 10:00 AM)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: GoogleFonts.outfit(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Description / Notes',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
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
                  groupId: groupId,
                  itineraryData: updatedItinerary,
                  actionDescription: 'added stop "$name"',
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

  void _reorderStop(
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
      groupId: groupId,
      itineraryData: updatedItinerary,
      actionDescription: 'reordered stop "${moved['name']}"',
    );
  }

  void _deleteStop(
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
      groupId: groupId,
      itineraryData: updatedItinerary,
      actionDescription: 'removed stop "${removed['name']}"',
    );
  }

  void _confirmClearItinerary(BuildContext context, GroupProvider groupProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgElevated,
          title: Text(
            'Clear Itinerary?',
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
                groupProvider.clearItinerary(groupId);
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
                'Itinerary Edit History',
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
                    separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit_note_rounded, size: 16, color: AppColors.brand),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    log.details,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatRelative(log.timestamp),
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StopCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> stop;
  final int totalStops;
  final bool canEdit;
  final String city;
  final VoidCallback onShareToChat;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onDelete;

  const _StopCard({
    required this.index,
    required this.stop,
    required this.totalStops,
    required this.canEdit,
    required this.city,
    required this.onShareToChat,
    this.onMoveUp,
    this.onMoveDown,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = stop['name'] ?? 'Stop';
    final startTime = stop['startTime'] ?? '';
    final description = stop['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.md),
      padding: const EdgeInsets.all(AppTokens.md),
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
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (startTime.isNotEmpty)
                      Text(
                        startTime,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.brand),
                tooltip: 'Share stop to chat',
                onPressed: onShareToChat,
              ),
              if (canEdit) ...[
                if (onMoveUp != null)
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: onMoveUp,
                  ),
                if (onMoveDown != null)
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: onMoveDown,
                  ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                    onPressed: onDelete,
                  ),
              ],
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
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
