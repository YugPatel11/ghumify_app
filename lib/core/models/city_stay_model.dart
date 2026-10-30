/// Represents a city destination within a multi-city journey
class CityStayModel {
  final String id;
  final String name;
  final String stateOrRegion;
  final String country;
  final double latitude;
  final double longitude;
  final int stayDays;
  final DateTime? arrivalDate;
  final DateTime? departureDate;
  final String? heroImage;

  const CityStayModel({
    required this.id,
    required this.name,
    this.stateOrRegion = 'India',
    this.country = 'India',
    required this.latitude,
    required this.longitude,
    this.stayDays = 2,
    this.arrivalDate,
    this.departureDate,
    this.heroImage,
  });

  CityStayModel copyWith({
    String? id,
    String? name,
    String? stateOrRegion,
    String? country,
    double? latitude,
    double? longitude,
    int? stayDays,
    DateTime? arrivalDate,
    DateTime? departureDate,
    String? heroImage,
  }) {
    return CityStayModel(
      id: id ?? this.id,
      name: name ?? this.name,
      stateOrRegion: stateOrRegion ?? this.stateOrRegion,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      stayDays: stayDays ?? this.stayDays,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      heroImage: heroImage ?? this.heroImage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'stateOrRegion': stateOrRegion,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'stayDays': stayDays,
      if (arrivalDate != null) 'arrivalDate': arrivalDate!.toIso8601String(),
      if (departureDate != null) 'departureDate': departureDate!.toIso8601String(),
      if (heroImage != null) 'heroImage': heroImage,
    };
  }

  factory CityStayModel.fromMap(Map<String, dynamic> data) {
    return CityStayModel(
      id: data['id']?.toString() ?? 'city_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name'] ?? '',
      stateOrRegion: data['stateOrRegion'] ?? 'India',
      country: data['country'] ?? 'India',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 28.6139,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 77.2090,
      stayDays: (data['stayDays'] as num?)?.toInt() ?? 2,
      arrivalDate: data['arrivalDate'] != null
          ? DateTime.tryParse(data['arrivalDate'].toString())
          : null,
      departureDate: data['departureDate'] != null
          ? DateTime.tryParse(data['departureDate'].toString())
          : null,
      heroImage: data['heroImage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CityStayModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name.toLowerCase() == other.name.toLowerCase();

  @override
  int get hashCode => id.hashCode ^ name.toLowerCase().hashCode;
}
