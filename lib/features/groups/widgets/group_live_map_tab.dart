import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/providers/group_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/group_location_model.dart';
import '../../../core/services/location_service.dart';

/// Live group location sharing and map overview tab
class GroupLiveMapTab extends StatefulWidget {
  final String groupId;

  const GroupLiveMapTab({super.key, required this.groupId});

  @override
  State<GroupLiveMapTab> createState() => _GroupLiveMapTabState();
}

class _GroupLiveMapTabState extends State<GroupLiveMapTab> {
  final LocationService _locationService = LocationService();
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _fetchMyPosition();
  }

  Future<void> _fetchMyPosition() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (mounted) {
        setState(() => _myPosition = pos);
      }
    } catch (_) {
      // Handled gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<GroupProvider, AuthProvider>(
      builder: (context, groupProvider, authProvider, _) {
        final currentUid = authProvider.user?.uid ?? '';
        final liveLocations = groupProvider.liveLocations;
        final isSharing = groupProvider.isSharingLiveLocation;
        final itinerary = groupProvider.currentItinerary;
        final stops = List<Map<String, dynamic>>.from(
          (itinerary?['stops'] as List<dynamic>? ?? []).map(
            (s) => Map<String, dynamic>.from(s as Map),
          ),
        );

        return ListView(
          padding: const EdgeInsets.all(AppTokens.md),
          children: [
            // Live Sharing Control Card
            _buildSharingControlCard(context, groupProvider, isSharing),

            const SizedBox(height: AppTokens.lg),

            // Active Members Section
            _buildSectionHeader(
              'Active Members (${liveLocations.length})',
              Icons.people_alt_rounded,
            ),
            const SizedBox(height: AppTokens.sm),

            if (liveLocations.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppTokens.xl),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_rounded,
                      size: 36,
                      color: AppColors.textMuted.withOpacity(0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No members currently sharing live location.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...liveLocations.map((loc) {
                final isMe = loc.userId == currentUid;
                final distKm = _myPosition != null
                    ? _locationService.calculateDistance(
                        _myPosition!.latitude,
                        _myPosition!.longitude,
                        loc.latitude,
                        loc.longitude,
                      )
                    : null;

                return _MemberLocationCard(
                  location: loc,
                  isMe: isMe,
                  distanceKm: distKm,
                  onOpenMaps: () => _openInMaps(loc.latitude, loc.longitude, loc.userName),
                );
              }),

            const SizedBox(height: AppTokens.lg),

            // Itinerary Stops Proximity (if available)
            if (stops.isNotEmpty) ...[
              _buildSectionHeader('Itinerary Destinations (${stops.length})', Icons.place_rounded),
              const SizedBox(height: AppTokens.sm),
              ...stops.map((stop) {
                final stopLat = (stop['latitude'] as num?)?.toDouble();
                final stopLng = (stop['longitude'] as num?)?.toDouble();
                final distKm = (_myPosition != null && stopLat != null && stopLng != null)
                    ? _locationService.calculateDistance(
                        _myPosition!.latitude,
                        _myPosition!.longitude,
                        stopLat,
                        stopLng,
                      )
                    : null;

                return _ItineraryStopProximityCard(
                  name: stop['name'] ?? 'Stop',
                  startTime: stop['startTime'] ?? '',
                  distanceKm: distKm,
                  hasCoords: stopLat != null && stopLng != null,
                  onNavigate: (stopLat != null && stopLng != null)
                      ? () => _openInMaps(stopLat, stopLng, stop['name'] ?? 'Stop')
                      : null,
                );
              }),
              const SizedBox(height: AppTokens.lg),
            ],

            // Privacy Notice
            Container(
              padding: const EdgeInsets.all(AppTokens.md),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 20, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Live locations are strictly shared only with this group and auto-expire to protect battery & privacy.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTokens.xxl),
          ],
        );
      },
    );
  }

  Widget _buildSharingControlCard(
    BuildContext context,
    GroupProvider groupProvider,
    bool isSharing,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(
          color: isSharing ? AppColors.success.withOpacity(0.4) : AppColors.border,
          width: isSharing ? 1.5 : 0.5,
        ),
        boxShadow: AppTokens.shadow(level: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isSharing ? AppColors.success : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isSharing ? 'Sharing Live Location' : 'Location Sharing Inactive',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isSharing ? AppColors.success : AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isSharing
                ? 'Your location is updating in real time every 30 seconds for other group members.'
                : 'Share your real-time position with group members during your trip.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppTokens.md),
          Row(
            children: [
              if (isSharing)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: Text(
                      'Stop Sharing',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                    ),
                    onPressed: () => groupProvider.stopLiveLocationSharing(widget.groupId),
                  ),
                )
              else ...[
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      'Share Live',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                    ),
                    onPressed: () => _showDurationPicker(context, groupProvider),
                  ),
                ),
                const SizedBox(width: AppTokens.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.pin_drop_rounded, size: 18),
                  label: Text(
                    'Send Pin',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                  ),
                  onPressed: () async {
                    await groupProvider.shareCurrentLocationPin(widget.groupId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Location pin posted to group chat!',
                            style: GoogleFonts.outfit(),
                          ),
                          backgroundColor: AppColors.brand,
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDurationPicker(BuildContext context, GroupProvider groupProvider) {
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share Live Location',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how long you want to share your live location:',
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: AppTokens.lg),
              _buildDurationTile(
                title: '15 Minutes',
                subtitle: 'Quick meetup or heading to a nearby attraction',
                onTap: () {
                  Navigator.of(context).pop();
                  groupProvider.startLiveLocationSharing(
                    widget.groupId,
                    duration: const Duration(minutes: 15),
                  );
                },
              ),
              _buildDurationTile(
                title: '1 Hour',
                subtitle: 'Exploring a neighborhood or market together',
                onTap: () {
                  Navigator.of(context).pop();
                  groupProvider.startLiveLocationSharing(
                    widget.groupId,
                    duration: const Duration(hours: 1),
                  );
                },
              ),
              _buildDurationTile(
                title: '8 Hours',
                subtitle: 'Full day sightseeing tour with the group',
                onTap: () {
                  Navigator.of(context).pop();
                  groupProvider.startLiveLocationSharing(
                    widget.groupId,
                    duration: const Duration(hours: 8),
                  );
                },
              ),
              const SizedBox(height: AppTokens.md),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDurationTile({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        leading: const Icon(Icons.timer_outlined, color: AppColors.brand),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brand),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Future<void> _openInMaps(double lat, double lng, String label) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _MemberLocationCard extends StatelessWidget {
  final GroupLocationModel location;
  final bool isMe;
  final double? distanceKm;
  final VoidCallback onOpenMaps;

  const _MemberLocationCard({
    required this.location,
    required this.isMe,
    this.distanceKm,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final remainingMinutes = location.expiresAt.difference(DateTime.now()).inMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.brand.withOpacity(0.15),
            radius: 20,
            child: Text(
              location.userName.isNotEmpty ? location.userName[0].toUpperCase() : 'U',
              style: GoogleFonts.outfit(
                color: AppColors.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      location.userName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'You',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Expires in ${remainingMinutes > 0 ? remainingMinutes : 0}m${distanceKm != null ? ' • ${distanceKm!.toStringAsFixed(1)} km away' : ''}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.directions_rounded, size: 16),
            label: Text('Map', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
            ),
            onPressed: onOpenMaps,
          ),
        ],
      ),
    );
  }
}

class _ItineraryStopProximityCard extends StatelessWidget {
  final String name;
  final String startTime;
  final double? distanceKm;
  final bool hasCoords;
  final VoidCallback? onNavigate;

  const _ItineraryStopProximityCard({
    required this.name,
    required this.startTime,
    this.distanceKm,
    required this.hasCoords,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.sm),
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pin_drop_outlined, size: 18, color: AppColors.brand),
          ),
          const SizedBox(width: AppTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  '${startTime.isNotEmpty ? '$startTime • ' : ''}${distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km from you' : 'Destination stop'}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onNavigate != null)
            IconButton(
              icon: const Icon(Icons.navigation_rounded, size: 20, color: AppColors.brand),
              tooltip: 'Navigate',
              onPressed: onNavigate,
            ),
        ],
      ),
    );
  }
}
