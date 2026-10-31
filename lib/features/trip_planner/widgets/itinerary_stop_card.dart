import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/itinerary_model.dart';
import '../../../core/services/place_media_service.dart';
import '../../groups/widgets/group_place_detail_sheet.dart';

/// Compact, editorial itinerary stop card matching the reference design.
///
/// Features:
/// - Collapsed default state: left thumbnail, time badge, category pill, title, compact meta, chevron
/// - Timeline connector node with category-themed icon on the left
/// - Smooth animated expansion showing brief description, swipeable photo gallery,
///   practical details, tips, and keyless Google Maps actions
/// - Full accessibility semantics and error-resilient image fallbacks
class ItineraryStopCard extends StatefulWidget {
  final int index;
  final ItineraryStop stop;
  final bool isLast;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final String? cityName;
  final VoidCallback? onPinToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const ItineraryStopCard({
    super.key,
    required this.index,
    required this.stop,
    required this.isLast,
    required this.isExpanded,
    required this.onToggleExpand,
    this.cityName,
    this.onPinToggle,
    this.onEdit,
    this.onDelete,
    this.onShare,
  });

  @override
  State<ItineraryStopCard> createState() => _ItineraryStopCardState();
}

class _ItineraryStopCardState extends State<ItineraryStopCard> {
  final PlaceMediaService _mediaService = PlaceMediaService();
  List<String> _galleryPhotos = [];
  bool _isLoadingGallery = false;
  bool _hasAttemptedFetch = false;

  @override
  void initState() {
    super.initState();
    _loadGalleryPhotos();
  }

  @override
  void didUpdateWidget(covariant ItineraryStopCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stop.name != oldWidget.stop.name) {
      _hasAttemptedFetch = false;
      _loadGalleryPhotos();
    } else if (widget.isExpanded && !oldWidget.isExpanded && !_hasAttemptedFetch) {
      _loadGalleryPhotos();
    }
  }

  void _openPlaceDetailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupPlaceDetailSheet(
        stop: widget.stop.toMap(),
        city: widget.cityName ?? 'Trip',
      ),
    );
  }

  Future<void> _loadGalleryPhotos() async {
    if (widget.stop.galleryPhotos.isNotEmpty) {
      setState(() {
        _galleryPhotos = widget.stop.galleryPhotos;
        _hasAttemptedFetch = true;
      });
      return;
    }

    _hasAttemptedFetch = true;
    setState(() => _isLoadingGallery = true);

    try {
      final media = await _mediaService.fetchMediaForPlace(
        widget.stop.name,
        city: widget.cityName,
      );
      if (mounted) {
        setState(() {
          _galleryPhotos = media.images;
          _isLoadingGallery = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingGallery = false);
      }
    }
  }

  Future<void> _openGoogleMapsSearch() async {
    final lat = widget.stop.latitude;
    final lng = widget.stop.longitude;
    final String urlStr;
    if (lat != null && lng != null) {
      urlStr = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    } else {
      urlStr = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${widget.stop.name} ${widget.cityName ?? ""}")}';
    }
    final uri = Uri.parse(urlStr);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openGoogleMapsDirections() async {
    final lat = widget.stop.latitude;
    final lng = widget.stop.longitude;
    final String urlStr;
    if (lat != null && lng != null) {
      urlStr = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else {
      urlStr = 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent("${widget.stop.name} ${widget.cityName ?? ""}")}';
    }
    final uri = Uri.parse(urlStr);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (c, u) => Container(
                  height: 240,
                  color: AppColors.card,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (c, u, e) => Container(
                  height: 200,
                  color: AppColors.card,
                  child: const Center(child: Icon(Icons.broken_image, size: 40)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Photo via Wikimedia Commons (Attribution CC)',
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpanded = widget.isExpanded;
    final stop = widget.stop;

    return Semantics(
      label: '${stop.name}, ${stop.startTime}, ${stop.durationMinutes} minutes, ${isExpanded ? "expanded" : "collapsed"}. Double-tap to ${isExpanded ? "collapse" : "expand"}.',
      button: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left Timeline Column with Category Icon Node ──
              _buildTimelineNode(),

              const SizedBox(width: AppTokens.sm),

              // ── Stop Card Container ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isExpanded ? AppColors.brand.withOpacity(0.3) : const Color(0xFFE5E7EB),
                        width: isExpanded ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isExpanded
                              ? AppColors.brand.withOpacity(0.08)
                              : Colors.black.withOpacity(0.03),
                          blurRadius: isExpanded ? 12 : 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: widget.onToggleExpand,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Collapsed Core Row (Always Visible) ──
                              _buildCollapsedHeader(context),

                              // ── Expanded Content (Smoothly Cross-Faded) ──
                              AnimatedCrossFade(
                                firstChild: const SizedBox.shrink(),
                                secondChild: _buildExpandedContent(context),
                                crossFadeState: isExpanded
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 240),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Left timeline track with custom category icon node
  Widget _buildTimelineNode() {
    final categoryIcon = _getCategoryIcon(widget.stop);
    final categoryColor = _getCategoryColor(widget.stop);

    return SizedBox(
      width: 36,
      child: Column(
        children: [
          // Circular icon node
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: categoryColor, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Icon(categoryIcon, size: 16, color: categoryColor),
          ),
          if (!widget.isLast)
            Expanded(
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFFE5E7EB),
              ),
            ),
        ],
      ),
    );
  }

  /// Collapsed view matching reference design
  Widget _buildCollapsedHeader(BuildContext context) {
    final stop = widget.stop;
    final categoryLabel = _getCategoryLabel(stop);
    final categoryStyle = _getCategoryBadgeStyle(stop);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Left Rounded Thumbnail ──
        _buildThumbnail(),

        const SizedBox(width: 12),

        // ── Center Content Info ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top line: Time badge & Category pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    flex: 2,
                    child: Text(
                      stop.startTime.isNotEmpty ? stop.startTime : 'Planned',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryStyle.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        categoryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: categoryStyle.textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              // Title (Place Name)
              Text(
                stop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),

              const SizedBox(height: 3),

              // Bottom sub-info line: location / duration / distance
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 3,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 85),
                        child: Text(
                          stop.displayShortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        _formatDuration(stop.durationMinutes),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  if (stop.distanceFromPrevKm != null && stop.distanceFromPrevKm! > 0)
                    Text(
                      '${stop.distanceFromPrevKm!.toStringAsFixed(1)} km',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // ── Right Chevron / Expand Indicator ──
        AnimatedRotation(
          turns: widget.isExpanded ? 0.25 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  /// Thumbnail image with category icon placeholder
  Widget _buildThumbnail() {
    final photo = widget.stop.photoUrl ?? (_galleryPhotos.isNotEmpty ? _galleryPhotos.first : null);
    final categoryIcon = _getCategoryIcon(widget.stop);
    final categoryColor = _getCategoryColor(widget.stop);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: photo != null && photo.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: photo,
                fit: BoxFit.cover,
                placeholder: (c, u) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (c, u, e) => Container(
                  color: categoryColor.withOpacity(0.12),
                  child: Center(child: Icon(categoryIcon, size: 24, color: categoryColor)),
                ),
              )
            : Container(
                color: categoryColor.withOpacity(0.12),
                child: Center(
                  child: Icon(categoryIcon, size: 24, color: categoryColor),
                ),
              ),
      ),
    );
  }

  /// Expanded Card Details
  Widget _buildExpandedContent(BuildContext context) {
    final stop = widget.stop;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // 1. Brief Description (2-3 sentences)
          if (stop.displayBriefDescription.isNotEmpty)
            Text(
              stop.displayBriefDescription,
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF334155),
              ),
            ),

          const SizedBox(height: 12),

          // 2. Swipeable Image Gallery (if loaded or available)
          if (_isLoadingGallery)
            Container(
              height: 70,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_galleryPhotos.isNotEmpty) ...[
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _galleryPhotos.length.clamp(0, 5),
                separatorBuilder: (c, i) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final imgUrl = _galleryPhotos[idx];
                  return GestureDetector(
                    onTap: () => _showImageDialog(context, imgUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 90,
                        height: 76,
                        child: CachedNetworkImage(
                          imageUrl: imgUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) => Container(color: const Color(0xFFF1F5F9)),
                          errorWidget: (c, u, e) => Container(
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.broken_image, size: 16),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photos via Wikimedia Commons (tap to enlarge)',
              style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Practical Details Grid (Only real data shown)
          _buildPracticalDetailsGrid(stop),

          // 4. Short Tips (Max 2 tips)
          if (stop.tips.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...stop.tips.take(2).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tip,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // 5. Tags (Kid-Friendly, Dietary)
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (stop.isKidFriendly)
                _buildChip(
                  icon: Icons.child_care_rounded,
                  label: 'Kid-Friendly',
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFE0F2FE),
                ),
              if (stop.dietaryType != null && stop.dietaryType!.isNotEmpty && stop.dietaryType != 'all')
                _buildChip(
                  icon: Icons.eco_rounded,
                  label: stop.dietaryType!.toUpperCase(),
                  color: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFDCFCE7),
                ),
              if (stop.isAnchored || stop.isPinned)
                _buildChip(
                  icon: Icons.push_pin_rounded,
                  label: 'Fixed Stop',
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFEDE9FE),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // View Place Details Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.brand),
              label: Text(
                'View All Place Details & Photos',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
              ),
              onPressed: _openPlaceDetailSheet,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.brand, width: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 6. Action Buttons: Google Maps, Directions, Pin & Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.map_rounded, size: 14),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Open Maps', style: GoogleFonts.outfit(fontSize: 12)),
                  ),
                  onPressed: _openGoogleMapsSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions_rounded, size: 14),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Directions', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
                  ),
                  onPressed: _openGoogleMapsDirections,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (widget.onPinToggle != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: stop.isPinned ? 'Unpin stop' : 'Pin stop',
                  icon: Icon(
                    stop.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 18,
                    color: stop.isPinned ? AppColors.brand : const Color(0xFF64748B),
                  ),
                  onPressed: widget.onPinToggle,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Practical details section with verified data only
  Widget _buildPracticalDetailsGrid(ItineraryStop stop) {
    final details = <Widget>[];

    final costStr = stop.ticketPrice != null && stop.ticketPrice!.trim().isNotEmpty
        ? stop.ticketPrice!
        : (stop.estimatedCost != null && stop.estimatedCost! > 0
            ? '₹${stop.estimatedCost}'
            : 'Free entry or on-site');
    details.add(_buildDetailRow(Icons.currency_rupee_rounded, 'Cost', costStr));

    final hoursStr = stop.openingHours != null && stop.openingHours!.trim().isNotEmpty
        ? stop.openingHours!
        : 'Not available (check locally)';
    details.add(_buildDetailRow(Icons.access_time_rounded, 'Hours', hoursStr));

    if (stop.bestTimeToVisit != null && stop.bestTimeToVisit!.trim().isNotEmpty) {
      details.add(_buildDetailRow(Icons.wb_sunny_outlined, 'Best Time', stop.bestTimeToVisit!));
    }
    if (stop.childTicketInfo != null && stop.childTicketInfo!.trim().isNotEmpty) {
      details.add(_buildDetailRow(Icons.escalator_warning_rounded, 'Kids', stop.childTicketInfo!));
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: details,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '$title: ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
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

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '45 min';
    if (minutes < 60) return '$minutes min';
    final hrs = minutes / 60;
    return hrs == hrs.roundToDouble()
        ? '${hrs.toInt()} hr${hrs.toInt() > 1 ? "s" : ""}'
        : '${hrs.toStringAsFixed(1)} hrs';
  }

  static IconData _getCategoryIcon(ItineraryStop stop) {
    final type = stop.type.toLowerCase();
    final name = stop.name.toLowerCase();

    if (type == 'food' || name.contains('breakfast') || name.contains('lunch') || name.contains('dinner') || name.contains('cafe')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('beach') || name.contains('coast') || name.contains('cove')) {
      return Icons.beach_access_rounded;
    }
    if (name.contains('sunset') || name.contains('view') || name.contains('lake') || name.contains('garden')) {
      return Icons.wb_twilight_rounded;
    }
    if (name.contains('fort') || name.contains('palace') || name.contains('temple') || name.contains('church') || name.contains('heritage')) {
      return Icons.account_balance_rounded;
    }
    if (type == 'market' || name.contains('bazaar') || name.contains('market')) {
      return Icons.shopping_bag_rounded;
    }
    if (type == 'travel') {
      return Icons.directions_car_rounded;
    }
    return Icons.camera_alt_rounded;
  }

  static Color _getCategoryColor(ItineraryStop stop) {
    final type = stop.type.toLowerCase();
    final name = stop.name.toLowerCase();

    if (type == 'food' || name.contains('breakfast') || name.contains('lunch') || name.contains('dinner')) {
      return const Color(0xFF16A34A); // Green
    }
    if (name.contains('beach')) {
      return const Color(0xFF0284C7); // Cyan/Blue
    }
    if (name.contains('fort') || name.contains('palace') || name.contains('temple')) {
      return const Color(0xFF7C3AED); // Purple
    }
    if (name.contains('sunset') || name.contains('view')) {
      return const Color(0xFFEA580C); // Warm Orange
    }
    return AppColors.brand;
  }

  static String _getCategoryLabel(ItineraryStop stop) {
    final type = stop.type.toLowerCase();
    final name = stop.name.toLowerCase();

    if (type == 'food' || name.contains('breakfast') || name.contains('lunch') || name.contains('dinner')) {
      return 'Food';
    }
    if (name.contains('beach')) {
      return 'Beach';
    }
    if (name.contains('fort') || name.contains('palace') || name.contains('temple') || name.contains('heritage')) {
      return 'Historical Site';
    }
    if (name.contains('sunset') || name.contains('view') || name.contains('point')) {
      return 'Scenic Spot';
    }
    if (type == 'market' || name.contains('bazaar') || name.contains('market')) {
      return 'Market';
    }
    return 'Sightseeing';
  }

  static _BadgeStyle _getCategoryBadgeStyle(ItineraryStop stop) {
    final type = stop.type.toLowerCase();
    final name = stop.name.toLowerCase();

    if (type == 'food' || name.contains('breakfast') || name.contains('lunch') || name.contains('dinner')) {
      return const _BadgeStyle(
        backgroundColor: Color(0xFFDCFCE7),
        textColor: Color(0xFF15803D),
      );
    }
    if (name.contains('beach')) {
      return const _BadgeStyle(
        backgroundColor: Color(0xFFE0F2FE),
        textColor: Color(0xFF0369A1),
      );
    }
    if (name.contains('fort') || name.contains('palace') || name.contains('temple') || name.contains('heritage')) {
      return const _BadgeStyle(
        backgroundColor: Color(0xFFEDE9FE),
        textColor: Color(0xFF6D28D9),
      );
    }
    if (name.contains('sunset') || name.contains('view') || name.contains('point')) {
      return const _BadgeStyle(
        backgroundColor: Color(0xFFFFEDD5),
        textColor: Color(0xFFC2410C),
      );
    }
    return const _BadgeStyle(
      backgroundColor: Color(0xFFEFF6FF),
      textColor: Color(0xFF1D4ED8),
    );
  }
}

class _BadgeStyle {
  final Color backgroundColor;
  final Color textColor;
  const _BadgeStyle({required this.backgroundColor, required this.textColor});
}
