import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/constants/safety_constants.dart';
import '../../../core/models/nearby_service_model.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/location_service.dart';

/// Reusable production widget displaying nearby hospitals and police stations
/// sourced from OpenStreetMap (Overpass API).
class NearbyServicesSection extends StatefulWidget {
  /// Destination or stop coordinates from the itinerary
  final double? latitude;
  final double? longitude;
  final String? locationName;

  /// Pre-existing saved services for offline and historical viewing
  final List<NearbyServiceModel>? initialServices;

  /// Callback when services are fetched or refreshed
  final ValueChanged<List<NearbyServiceModel>>? onServicesUpdated;

  /// Whether user has permission to refresh (used in Groups permissions)
  final bool canRefresh;

  /// Whether this is being viewed in a saved itinerary
  final bool isSavedMode;

  const NearbyServicesSection({
    super.key,
    this.latitude,
    this.longitude,
    this.locationName,
    this.initialServices,
    this.onServicesUpdated,
    this.canRefresh = true,
    this.isSavedMode = false,
  });

  @override
  State<NearbyServicesSection> createState() => _NearbyServicesSectionState();
}

class _NearbyServicesSectionState extends State<NearbyServicesSection> {
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();

  List<NearbyServiceModel> _hospitals = [];
  List<NearbyServiceModel> _policeStations = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  String _activeTab = 'hospital'; // 'hospital' or 'police'
  DateTime? _lastUpdated;
  bool _useGpsLocation = false;
  String? _searchOriginDescription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void didUpdateWidget(covariant NearbyServicesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialServices != oldWidget.initialServices &&
        widget.initialServices != null &&
        widget.initialServices!.isNotEmpty) {
      _loadFromInitialServices(widget.initialServices!);
    }
  }

  void _initializeServices() {
    if (widget.initialServices != null && widget.initialServices!.isNotEmpty) {
      _loadFromInitialServices(widget.initialServices!);
    } else {
      // Auto-fetch for new or unsaved itineraries
      _fetchNearbyServices(forceRefresh: false);
    }
  }

  void _loadFromInitialServices(List<NearbyServiceModel> services) {
    setState(() {
      _hospitals = services.where((s) => s.type == 'hospital').toList();
      _policeStations = services.where((s) => s.type == 'police').toList();
      _isLoading = false;
      _error = null;
      if (services.isNotEmpty) {
        _lastUpdated = services.first.fetchedAt;
      }
      _searchOriginDescription = widget.locationName != null
          ? 'Near ${widget.locationName}'
          : 'Saved itinerary location';
    });
  }

  Future<void> _fetchNearbyServices({bool forceRefresh = false}) async {
    if (_isLoading || _isRefreshing) return;

    setState(() {
      if (_hospitals.isEmpty && _policeStations.isEmpty) {
        _isLoading = true;
      } else {
        _isRefreshing = true;
      }
      _error = null;
    });

    try {
      double targetLat;
      double targetLon;
      String originDesc;

      final hasValidItineraryCoords = widget.latitude != null &&
          widget.longitude != null &&
          !(widget.latitude == 0.0 && widget.longitude == 0.0);

      if (!_useGpsLocation && hasValidItineraryCoords) {
        targetLat = widget.latitude!;
        targetLon = widget.longitude!;
        originDesc = widget.locationName != null
            ? 'Near ${widget.locationName}'
            : 'Itinerary destination';
      } else {
        // Attempt GPS location, or fallback to itinerary coordinates if GPS is unavailable
        try {
          final position = await _locationService.getCurrentPosition();
          targetLat = position.latitude;
          targetLon = position.longitude;
          originDesc = 'Current GPS location';
        } on LocationException {
          if (hasValidItineraryCoords) {
            targetLat = widget.latitude!;
            targetLon = widget.longitude!;
            originDesc = widget.locationName != null
                ? 'Near ${widget.locationName} (GPS access fallback)'
                : 'Itinerary location';
            _useGpsLocation = false;
          } else {
            rethrow;
          }
        }
      }

      final results = await _placesService.searchNearbyEmergencyServices(
        latitude: targetLat,
        longitude: targetLon,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      final hospitals = results.where((s) => s.type == 'hospital').toList();
      final police = results.where((s) => s.type == 'police').toList();

      setState(() {
        _hospitals = hospitals;
        _policeStations = police;
        _isLoading = false;
        _isRefreshing = false;
        _lastUpdated = DateTime.now();
        _searchOriginDescription = originDesc;
      });

      // Notify parent to store in itinerary model
      widget.onServicesUpdated?.call(results);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load nearby safety services. Please check your network connection.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _openUrl(Uri url, String failureMessage) async {
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    }
  }

  void _callNumber(String? phone) {
    if (phone == null || phone.isEmpty) return;
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty) return;
    _openUrl(
      Uri.parse('tel:$sanitized'),
      'Could not open dialer for $phone',
    );
  }

  String _formatLastUpdated(DateTime? time) {
    if (time == null) return 'Not available';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Title & Actions ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppTokens.sm),
                      Text(
                        'Nearby Safety',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppColors.text, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hospitals, clinics & police stations near your location',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSoft,
                        ),
                  ),
                ],
              ),
            ),
            if (widget.canRefresh && !_isLoading) ...[
              IconButton(
                onPressed: _isRefreshing
                    ? null
                    : () {
                        setState(() => _useGpsLocation = true);
                        _fetchNearbyServices(forceRefresh: true);
                      },
                tooltip: 'Find near current GPS location',
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              IconButton(
                onPressed: _isRefreshing
                    ? null
                    : () => _fetchNearbyServices(forceRefresh: true),
                tooltip: 'Refresh safety data',
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.textSoft,
                        size: 20,
                      ),
              ),
            ],
          ],
        ),

        // ── Origin & Last Updated Status Banner ──
        if (_searchOriginDescription != null || _lastUpdated != null) ...[
          const SizedBox(height: AppTokens.sm),
          Row(
            children: [
              if (_searchOriginDescription != null) ...[
                const Icon(Icons.place_outlined, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _searchOriginDescription!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (_lastUpdated != null) ...[
                const SizedBox(width: AppTokens.sm),
                Text(
                  'Updated: ${_formatLastUpdated(_lastUpdated)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ],

        const SizedBox(height: AppTokens.md),

        // ── Emergency Quick Dial Pills ──
        _buildEmergencySpeedDial(),

        const SizedBox(height: AppTokens.md),

        // ── Tab Switcher ──
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.glassWhiteLight,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                border: Border.all(color: AppColors.borderGlass),
              ),
              child: Row(
                children: [
                  _buildTab(
                    label: '🏥 Hospitals',
                    isActive: _activeTab == 'hospital',
                    count: _hospitals.length,
                    onTap: () => setState(() => _activeTab = 'hospital'),
                  ),
                  const SizedBox(width: 4),
                  _buildTab(
                    label: '👮 Police Stations',
                    isActive: _activeTab == 'police',
                    count: _policeStations.length,
                    onTap: () => setState(() => _activeTab = 'police'),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppTokens.md),

        // ── Body Content ──
        if (_isLoading)
          _buildLoadingState()
        else if (_error != null && _hospitals.isEmpty && _policeStations.isEmpty)
          _buildErrorState()
        else
          _buildServicesList(),

        const SizedBox(height: AppTokens.md),

        // ── Legal Attribution & Emergency Notice ──
        _buildFooterNotice(),
      ],
    );
  }

  Widget _buildEmergencySpeedDial() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.md, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          const Text(
            'SOS Dial:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft,
            ),
          ),
          _buildQuickDialChip(
            label: '112 (National)',
            number: SafetyConstants.nationalEmergencyNumber,
            color: AppColors.error,
          ),
          _buildQuickDialChip(
            label: '100 (Police)',
            number: SafetyConstants.policeEmergencyNumber,
            color: AppColors.info,
          ),
          _buildQuickDialChip(
            label: '108 (Ambulance)',
            number: SafetyConstants.ambulanceEmergencyNumber,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDialChip({
    required String label,
    required String number,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _callNumber(number),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    required int count,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          child: Center(
            child: Text(
              _isLoading ? label : '$label ($count)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.textSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.xl),
      decoration: BoxDecoration(
        color: AppColors.glassWhiteLight,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: const Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.brand,
              ),
            ),
            SizedBox(height: AppTokens.md),
            Text(
              'Finding nearest hospitals & police stations via OpenStreetMap...',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSoft, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.xl),
      decoration: BoxDecoration(
        color: AppColors.glassWhiteLight,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: AppTokens.sm),
          Text(
            _error ?? 'Unable to retrieve nearby safety places.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
          ),
          const SizedBox(height: AppTokens.md),
          ElevatedButton.icon(
            onPressed: () => _fetchNearbyServices(forceRefresh: true),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    final items = _activeTab == 'hospital' ? _hospitals : _policeStations;
    final emptyLabel = _activeTab == 'hospital'
        ? 'No hospitals or clinics found within 10 km. Try refreshing or use the emergency numbers above.'
        : 'No police stations found within 10 km. Try refreshing or dial 100/112 in an emergency.';

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTokens.xl),
        decoration: BoxDecoration(
          color: AppColors.glassWhiteLight,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: AppColors.borderGlass),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                _activeTab == 'hospital'
                    ? Icons.local_hospital_outlined
                    : Icons.local_police_outlined,
                size: 36,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppTokens.sm),
              Text(
                emptyLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
              ),
              if (widget.initialServices != null && widget.initialServices!.isEmpty) ...[
                const SizedBox(height: AppTokens.md),
                ElevatedButton.icon(
                  onPressed: () => _fetchNearbyServices(forceRefresh: true),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Load nearby hospitals and police stations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: items.map((service) => _buildServiceCard(service)).toList(),
    );
  }

  Widget _buildServiceCard(NearbyServiceModel service) {
    final isHospital = service.type == 'hospital';
    final isClinic = service.subtype == 'clinic';

    Color themeColor;
    IconData typeIcon;
    String badgeText;

    if (isHospital) {
      if (isClinic) {
        themeColor = Colors.teal;
        typeIcon = Icons.medical_services_outlined;
        badgeText = 'Clinic';
      } else {
        themeColor = AppColors.error;
        typeIcon = Icons.local_hospital_rounded;
        badgeText = 'Hospital';
      }
    } else {
      themeColor = AppColors.info;
      typeIcon = Icons.local_police_rounded;
      badgeText = 'Police Station';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.md),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: AppColors.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type Icon, Title, Subtype Badge, Distance
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      child: Icon(typeIcon, color: themeColor, size: 22),
                    ),
                    const SizedBox(width: AppTokens.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: themeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: themeColor,
                                  ),
                                ),
                              ),
                              if (service.distanceKm != null) ...[
                                const Spacer(),
                                const Icon(Icons.near_me, size: 12, color: AppColors.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  '${service.distanceKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSoft,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Address row if available
                if (service.address != null && service.address!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          service.address!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Emergency / 24-Hour tag if verified by OSM tags
                if (service.isEmergency ||
                    (service.openingHours != null &&
                        service.openingHours!.toLowerCase().contains('24/7'))) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline, size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          '24/7 Emergency Services verified on OSM',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppTokens.md),

                // Action Buttons: Open in Google Maps, Directions, Call
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Open in Google Maps
                    OutlinedButton.icon(
                      onPressed: () => _openUrl(
                        service.googleMapsSearchUrl,
                        'Could not open Google Maps for ${service.name}',
                      ),
                      icon: const Icon(Icons.map_outlined, size: 15),
                      label: const Text('Open in Google Maps'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),

                    // Directions
                    ElevatedButton.icon(
                      onPressed: () => _openUrl(
                        service.googleMapsDirectionsUrl,
                        'Could not open Google Maps navigation',
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 15),
                      label: const Text('Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),

                    // Call button (only if phone available)
                    if (service.phone != null && service.phone!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _callNumber(service.phone),
                        icon: const Icon(Icons.phone, size: 15, color: AppColors.success),
                        label: Text('Call (${service.phone})'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterNotice() {
    return Container(
      padding: const EdgeInsets.all(AppTokens.sm),
      decoration: BoxDecoration(
        color: AppColors.glassWhiteLight,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  SafetyConstants.emergencyDisclaimer,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _openUrl(
              Uri.parse(SafetyConstants.osmCopyrightUrl),
              'Could not open OpenStreetMap copyright page',
            ),
            child: const Text(
              SafetyConstants.osmAttribution,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.brand,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
