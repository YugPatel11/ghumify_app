/// Model representing a nearby emergency service (hospital/police station)
class NearbyServiceModel {
  final String name;
  final String type; // 'hospital' or 'police'
  final double latitude;
  final double longitude;
  final String? address;
  final double? distanceKm;

  NearbyServiceModel({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.distanceKm,
  });

  factory NearbyServiceModel.fromOverpassElement(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final amenity = tags['amenity'] as String? ?? '';

    return NearbyServiceModel(
      name: tags['name'] as String? ??
          tags['name:en'] as String? ??
          (amenity == 'hospital' ? 'Hospital' : 'Police Station'),
      type: amenity == 'police' ? 'police' : 'hospital',
      latitude: (element['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (element['lon'] as num?)?.toDouble() ?? 0.0,
      address: tags['addr:full'] as String? ??
          tags['addr:street'] as String? ??
          null,
    );
  }

  NearbyServiceModel copyWith({double? distanceKm}) {
    return NearbyServiceModel(
      name: name,
      type: type,
      latitude: latitude,
      longitude: longitude,
      address: address,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }
}
