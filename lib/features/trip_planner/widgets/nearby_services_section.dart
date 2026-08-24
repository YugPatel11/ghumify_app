import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../core/models/nearby_service_model.dart';
import '../../../core/services/places_service.dart';
import '../../../core/services/location_service.dart';

/// Reusable widget showing nearby hospitals/clinics and police stations.
/// Uses the free Overpass API (OpenStreetMap) — no paid API required.
class NearbyServicesSection extends StatefulWidget {
  /// Optional: provide coordinates directly (e.g. from itinerary destination)
  final double? latitude;
  final double? longitude;

  const NearbyServicesSection({
    super.key,
    this.latitude,
    this.longitude,
  });

  @override
  State<NearbyServicesSection> createState() => _NearbyServicesSectionState();
}

class _NearbyServicesSectionState extends State<NearbyServicesSection> {
  final PlacesService _placesService = PlacesService();
  final LocationService _locationService = LocationService();

  List<NearbyServiceModel> _hospitals = [];
  List<NearbyServiceModel> _policeStations = [];
  bool _isLoading = true;
  String? _error;
  String _activeTab = 'hospital'; // 'hospital' or 'police'

  @override
  void initState() {
    super.initState();
    _fetchNearbyServices();
  }

  Future<void> _fetchNearbyServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      double lat;
      double lon;

      if (widget.latitude != null && widget.longitude != null) {
        lat = widget.latitude!;
        lon = widget.longitude!;
      } else {
        // Use user's current location
        final position = await _locationService.getCurrentPosition();
        lat = position.latitude;
        lon = position.longitude;
      }

      final results = await _placesService.searchNearbyEmergencyServices(
        latitude: lat,
        longitude: lon,
        radiusMeters: 5000,
      );

      if (!mounted) return;

      setState(() {
        _hospitals = results.where((s) => s.type == 'hospital').toList();
        _policeStations = results.where((s) => s.type == 'police').toList();
        _isLoading = false;
      });
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load nearby services. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  void _openInMaps(NearbyServiceModel service) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${service.latitude},${service.longitude}&destination_place_id=&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Nearby Emergency Services',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.text),
        ),
        const SizedBox(height: AppTokens.sm),
        Text(
          'Hospitals, clinics & police stations near you',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSoft,
              ),
        ),
        const SizedBox(height: AppTokens.md),

        // Tab Switcher
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
                    label: '👮 Police',
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

        // Content
        if (_isLoading)
          _buildLoadingState()
        else if (_error != null)
          _buildErrorState()
        else
          _buildServicesList(),
      ],
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          ),
          child: Center(
            child: Text(
              _isLoading ? label : '$label ($count)',
              style: TextStyle(
                fontSize: 13,
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
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
            SizedBox(height: AppTokens.md),
            Text(
              'Finding nearby services...',
              style: TextStyle(color: AppColors.textSoft, fontSize: 14),
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
          Icon(Icons.location_off_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: AppTokens.sm),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 14),
          ),
          const SizedBox(height: AppTokens.md),
          TextButton.icon(
            onPressed: _fetchNearbyServices,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesList() {
    final items = _activeTab == 'hospital' ? _hospitals : _policeStations;
    final emptyLabel = _activeTab == 'hospital'
        ? 'No hospitals or clinics found nearby'
        : 'No police stations found nearby';

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
                style: const TextStyle(color: AppColors.textSoft, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Show max 5 results
    final displayItems = items.take(5).toList();

    return Column(
      children: displayItems.map((service) => _buildServiceCard(service)).toList(),
    );
  }

  Widget _buildServiceCard(NearbyServiceModel service) {
    final isHospital = service.type == 'hospital';

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
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isHospital
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(
                    isHospital
                        ? Icons.local_hospital_rounded
                        : Icons.local_police_rounded,
                    color: isHospital ? AppColors.error : AppColors.info,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTokens.sm),

                // Name + Distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (service.distanceKm != null) ...[
                            Icon(Icons.near_me, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${service.distanceKm!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSoft,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (service.address != null) ...[
                            if (service.distanceKm != null)
                              const Text('  •  ',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 12)),
                            Expanded(
                              child: Text(
                                service.address!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Directions button
                GestureDetector(
                  onTap: () => _openInMaps(service),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: const Icon(
                      Icons.directions_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
