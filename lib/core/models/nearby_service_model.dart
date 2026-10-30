import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a nearby emergency service (hospital, clinic, or police station)
/// Sourced strictly from OpenStreetMap Overpass API without paid APIs.
class NearbyServiceModel {
  final String name;
  final String type; // 'hospital' or 'police'
  final String subtype; // 'hospital', 'clinic', or 'police'
  final double latitude;
  final double longitude;
  final String? address;
  final double? distanceKm;
  final String? phone;
  final String? openingHours;
  final bool isEmergency; // true if emergency=yes
  final DateTime fetchedAt;

  NearbyServiceModel({
    required this.name,
    required this.type,
    String? subtype,
    required this.latitude,
    required this.longitude,
    this.address,
    this.distanceKm,
    this.phone,
    this.openingHours,
    this.isEmergency = false,
    DateTime? fetchedAt,
  })  : subtype = subtype ?? type,
        fetchedAt = fetchedAt ?? DateTime.now();

  /// Parse an element (node, way, or relation) from the Overpass API response.
  factory NearbyServiceModel.fromOverpassElement(
    Map<String, dynamic> element, {
    double? originLat,
    double? originLon,
    double? distanceKm,
  }) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final amenity = (tags['amenity'] as String? ?? '').toLowerCase();
    final healthcare = (tags['healthcare'] as String? ?? '').toLowerCase();

    // Determine type and subtype
    final bool isPolice = amenity == 'police';
    final bool isClinic = amenity == 'clinic' || healthcare == 'clinic';
    final String type = isPolice ? 'police' : 'hospital';
    final String subtype = isPolice
        ? 'police'
        : (isClinic ? 'clinic' : 'hospital');

    // Extract name with clean fallbacks
    String? rawName = tags['name'] as String? ??
        tags['name:en'] as String? ??
        tags['operator'] as String?;
    rawName = rawName?.trim();

    final String fallbackName = isPolice
        ? 'Police Station (name not available)'
        : (isClinic
            ? 'Clinic (name not available)'
            : 'Hospital (name not available)');

    final String name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : fallbackName;

    // Extract coordinates (node lat/lon or way/relation center)
    double lat = 0.0;
    double lon = 0.0;

    if (element['type'] == 'way' || element['type'] == 'relation') {
      final center = element['center'] as Map<String, dynamic>?;
      if (center != null) {
        lat = (center['lat'] as num?)?.toDouble() ?? 0.0;
        lon = (center['lon'] as num?)?.toDouble() ?? 0.0;
      }
    }

    if (lat == 0.0 && lon == 0.0) {
      lat = (element['lat'] as num?)?.toDouble() ?? 0.0;
      lon = (element['lon'] as num?)?.toDouble() ?? 0.0;
    }

    // Extract structured address if available
    String? address = tags['addr:full'] as String?;
    if (address == null || address.trim().isEmpty) {
      final houseNumber = tags['addr:housenumber'] as String?;
      final street = tags['addr:street'] as String?;
      final city = tags['addr:city'] as String?;
      final parts = <String>[];
      if (houseNumber != null && houseNumber.isNotEmpty) parts.add(houseNumber);
      if (street != null && street.isNotEmpty) parts.add(street);
      if (city != null && city.isNotEmpty) parts.add(city);
      if (parts.isNotEmpty) {
        address = parts.join(', ');
      }
    }

    // Extract phone
    String? phone = tags['phone'] as String? ??
        tags['contact:phone'] as String? ??
        tags['contact:mobile'] as String?;
    if (phone != null && phone.trim().isEmpty) {
      phone = null;
    }

    // Extract opening hours and emergency flag
    final openingHours = tags['opening_hours'] as String?;
    final isEmergencyTag = (tags['emergency'] as String? ?? '').toLowerCase() == 'yes';

    return NearbyServiceModel(
      name: name,
      type: type,
      subtype: subtype,
      latitude: lat,
      longitude: lon,
      address: address,
      distanceKm: distanceKm,
      phone: phone?.trim(),
      openingHours: openingHours?.trim(),
      isEmergency: isEmergencyTag,
      fetchedAt: DateTime.now(),
    );
  }

  /// Convert to a clean Map for Firestore and local persistence
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'subtype': subtype,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'distanceKm': distanceKm,
      'phone': phone,
      'openingHours': openingHours,
      'isEmergency': isEmergency,
      'fetchedAt': Timestamp.fromDate(fetchedAt),
    };
  }

  /// Create from a Firestore or local persistence Map
  factory NearbyServiceModel.fromMap(Map<String, dynamic> map) {
    DateTime fetched = DateTime.now();
    if (map['fetchedAt'] is Timestamp) {
      fetched = (map['fetchedAt'] as Timestamp).toDate();
    } else if (map['fetchedAt'] is String) {
      fetched = DateTime.tryParse(map['fetchedAt'] as String) ?? DateTime.now();
    }

    return NearbyServiceModel(
      name: map['name'] as String? ?? 'Safety Service',
      type: map['type'] as String? ?? 'hospital',
      subtype: map['subtype'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      phone: map['phone'] as String?,
      openingHours: map['openingHours'] as String?,
      isEmergency: map['isEmergency'] as bool? ?? false,
      fetchedAt: fetched,
    );
  }

  NearbyServiceModel copyWith({
    String? name,
    String? type,
    String? subtype,
    double? latitude,
    double? longitude,
    String? address,
    double? distanceKm,
    String? phone,
    String? openingHours,
    bool? isEmergency,
    DateTime? fetchedAt,
  }) {
    return NearbyServiceModel(
      name: name ?? this.name,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      phone: phone ?? this.phone,
      openingHours: openingHours ?? this.openingHours,
      isEmergency: isEmergency ?? this.isEmergency,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  /// Official Google Maps place query link (no API key required)
  Uri get googleMapsSearchUrl {
    final query = '$latitude,$longitude';
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  }

  /// Official Google Maps turn-by-turn directions link
  Uri get googleMapsDirectionsUrl {
    final destination = '$latitude,$longitude';
    return Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destination');
  }

  /// Sanitized phone dialer URI
  Uri? get phoneDialerUri {
    if (phone == null || phone!.isEmpty) return null;
    final sanitized = phone!.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty) return null;
    return Uri.parse('tel:$sanitized');
  }
}
