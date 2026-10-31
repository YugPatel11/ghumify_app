import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/services/place_media_service.dart';

/// Modal bottom sheet displaying detailed view and photos for an itinerary place/stop
/// within the Group section.
class GroupPlaceDetailSheet extends StatefulWidget {
  final Map<String, dynamic> stop;
  final String city;
  final String? itineraryDate;
  final String? groupId;
  final VoidCallback? onShareToChat;

  const GroupPlaceDetailSheet({
    super.key,
    required this.stop,
    required this.city,
    this.itineraryDate,
    this.groupId,
    this.onShareToChat,
  });

  @override
  State<GroupPlaceDetailSheet> createState() => _GroupPlaceDetailSheetState();
}

class _GroupPlaceDetailSheetState extends State<GroupPlaceDetailSheet> {
  final PlaceMediaService _mediaService = PlaceMediaService();
  final PageController _pageController = PageController();

  List<String> _photos = [];
  bool _isLoadingPhotos = false;
  int _currentPhotoIndex = 0;

  String get _name => (widget.stop['name'] as String?)?.trim() ?? 'Place';
  String get _description => (widget.stop['description'] as String?)?.trim() ??
      (widget.stop['briefDescription'] as String?)?.trim() ??
      '';
  String get _startTime => (widget.stop['startTime'] as String?)?.trim() ?? '';
  String get _endTime => (widget.stop['endTime'] as String?)?.trim() ?? '';
  int get _durationMinutes => (widget.stop['durationMinutes'] as num?)?.toInt() ?? 0;
  double? get _lat => (widget.stop['latitude'] as num?)?.toDouble();
  double? get _lng => (widget.stop['longitude'] as num?)?.toDouble();
  String? get _address => widget.stop['address'] as String?;
  dynamic get _cost => widget.stop['ticketPrice'] ?? widget.stop['estimatedCost'];
  String? get _openingHours => widget.stop['openingHours'] as String?;
  String? get _bestTimeToVisit => widget.stop['bestTimeToVisit'] as String?;
  bool get _isKidFriendly =>
      widget.stop['isKidFriendly'] == true || widget.stop['is_kid_friendly'] == true;
  List<dynamic> get _tips => (widget.stop['tips'] as List<dynamic>?) ?? [];
  String get _type => (widget.stop['type'] as String?)?.toUpperCase() ?? 'ATTRACTION';
  double? get _rating {
    final r = widget.stop['rating'];
    if (r is num) return r.toDouble();
    if (r is String) return double.tryParse(r);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _initPhotos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initPhotos() {
    // 1. Gather any existing photos from stop data
    final existingPhotos = <String>[];

    final gallery = widget.stop['galleryPhotos'];
    if (gallery is List) {
      for (final p in gallery) {
        if (p is String && p.trim().isNotEmpty) existingPhotos.add(p.trim());
      }
    }

    final images = widget.stop['images'];
    if (images is List) {
      for (final p in images) {
        if (p is String && p.trim().isNotEmpty && !existingPhotos.contains(p.trim())) {
          existingPhotos.add(p.trim());
        }
      }
    }

    final photoUrl = widget.stop['photoUrl'] as String?;
    if (photoUrl != null && photoUrl.trim().isNotEmpty && !existingPhotos.contains(photoUrl.trim())) {
      existingPhotos.insert(0, photoUrl.trim());
    }

    if (existingPhotos.isNotEmpty) {
      _photos = existingPhotos;
    } else {
      // 2. Fetch dynamically from Wikimedia Commons
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoadingPhotos = true);
    try {
      final media = await _mediaService.fetchMediaForPlace(
        _name,
        city: widget.city,
      );
      if (mounted) {
        setState(() {
          _photos = media.images;
          _isLoadingPhotos = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPhotos = false);
      }
    }
  }

  Future<void> _openDirections() async {
    final String urlStr;
    if (_lat != null && _lng != null && _lat != 0.0 && _lng != 0.0) {
      urlStr = 'https://www.google.com/maps/dir/?api=1&destination=$_lat,$_lng';
    } else {
      urlStr =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("$_name ${widget.city}")}';
    }

    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map directions.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open directions: $e')),
        );
      }
    }
  }

  void _showFullImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (c, u) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (c, u, e) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black87,
                    child: const Icon(Icons.broken_image, color: Colors.white70, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTiming() {
    if (_startTime.isNotEmpty && _endTime.isNotEmpty) {
      return '$_startTime - $_endTime';
    } else if (_startTime.isNotEmpty) {
      return _startTime;
    } else if (_durationMinutes > 0) {
      final hours = _durationMinutes ~/ 60;
      final mins = _durationMinutes % 60;
      if (hours > 0 && mins > 0) return '${hours}h ${mins}m duration';
      if (hours > 0) return '${hours}h duration';
      return '${mins}m duration';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final timing = _formatTiming();
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle & Header Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTokens.lg, 12, AppTokens.md, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Category Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                  child: Text(
                    _type,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                // Center Drag indicator
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Close button (X)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSoft, size: 22),
                  tooltip: 'Close details',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // ── Scrollable Body Content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppTokens.lg, AppTokens.md, AppTokens.lg, AppTokens.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Image Carousel / Gallery
                  _buildPhotoSection(),

                  const SizedBox(height: AppTokens.lg),

                  // 2. Place Name & Header Meta
                  Text(
                    _name,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Meta chips (City, Time, Date, Kid-Friendly)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoPill(Icons.place_rounded, widget.city, AppColors.brand),
                      if (_rating != null)
                        _buildInfoPill(Icons.star_rounded, '★ ${_rating!.toStringAsFixed(1)}', const Color(0xFFD97706)),
                      if (timing.isNotEmpty)
                        _buildInfoPill(Icons.schedule_rounded, timing, const Color(0xFF0284C7)),
                      if (widget.itineraryDate != null && widget.itineraryDate!.isNotEmpty)
                        _buildInfoPill(Icons.calendar_today_rounded, widget.itineraryDate!, const Color(0xFF7C3AED)),
                      if (_isKidFriendly)
                        _buildInfoPill(Icons.child_care_rounded, 'Kid-Friendly', const Color(0xFF16A34A)),
                    ],
                  ),

                  const SizedBox(height: AppTokens.lg),

                  // 3. Location & Directions Card
                  _buildLocationCard(),

                  const SizedBox(height: AppTokens.lg),

                  // 4. Description / About Place
                  if (_description.isNotEmpty) ...[
                    Text(
                      'About this Stop',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTokens.md),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: Text(
                        _description,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.lg),
                  ],

                  // 5. Practical Info Grid (Cost, Hours, Best Time)
                  if (_cost != null || _openingHours != null || _bestTimeToVisit != null)
                    _buildPracticalInfoGrid(),

                  // 6. Helpful Tips Section
                  if (_tips.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.lg),
                    Text(
                      'Tips & Advice',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._tips.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded,
                                  size: 16, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tip.toString(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.textSoft,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: AppTokens.xl),

                  // 7. Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openDirections,
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: Text(
                            'Directions',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      if (widget.onShareToChat != null) ...[
                        const SizedBox(width: AppTokens.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onShareToChat,
                            icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.brand),
                            label: Text(
                              'Share to Chat',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brand,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.brand),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    if (_isLoadingPhotos) {
      return Container(
        height: 190,
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
              ),
              SizedBox(height: 8),
              Text('Loading photos...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_photos.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_outlined, size: 36, color: Colors.white70),
              const SizedBox(height: 6),
              Text(
                _name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              Text(
                widget.city,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          child: SizedBox(
            height: 200,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: _photos.length,
                  onPageChanged: (index) {
                    setState(() => _currentPhotoIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final photoUrl = _photos[index];
                    return GestureDetector(
                      onTap: () => _showFullImageDialog(photoUrl),
                      child: CachedNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(
                          color: AppColors.cardAlt,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                            ),
                          ),
                        ),
                        errorWidget: (c, u, e) => Container(
                          color: AppColors.cardAlt,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 36, color: AppColors.textMuted),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Tap hint badge
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to view',
                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),

                // Counter indicator badge
                if (_photos.length > 1)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPhotoIndex + 1} / ${_photos.length}',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Thumbnail strip / dot indicators
        if (_photos.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (c, i) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final isSelected = idx == _currentPhotoIndex;
                return GestureDetector(
                  onTap: () {
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.brand : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: _photos[idx],
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) => Container(color: AppColors.cardAlt),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final locationText = _address ??
        (widget.stop['shortLabel'] as String?) ??
        '${widget.city}, India';

    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  locationText,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.brand),
            tooltip: 'Open in Maps',
            onPressed: _openDirections,
          ),
        ],
      ),
    );
  }

  Widget _buildPracticalInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practical Info',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          _buildGridRow(
            Icons.payments_outlined,
            'Estimated Cost / Ticket',
            _cost != null && _cost.toString().trim().isNotEmpty
                ? (_cost.toString().startsWith('₹') ? _cost.toString() : '₹$_cost')
                : 'Free entry or on-site',
          ),
          _buildGridRow(
            Icons.access_time_rounded,
            'Opening Hours',
            _openingHours != null && _openingHours!.trim().isNotEmpty
                ? _openingHours!
                : 'Not available (Check local timings)',
          ),
          _buildGridRow(
            Icons.wb_sunny_outlined,
            'Best Time to Visit',
            _bestTimeToVisit != null && _bestTimeToVisit!.trim().isNotEmpty
                ? _bestTimeToVisit!
                : 'Morning or late afternoon',
          ),
        ],
      ),
    );
  }

  Widget _buildGridRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
