import 'dart:math';
import '../constants/transport_config.dart';
import '../models/city_stay_model.dart';
import '../models/place_suggestion_model.dart';
import '../models/transport_option_model.dart';
import '../models/travel_leg_model.dart';
import '../models/travelers_model.dart';
import 'location_service.dart';
import 'places_service.dart';

/// Core transit planning, cost estimation, and route optimization service for multi-city travel.
class TransportService {
  final LocationService _locationService = LocationService();
  final Map<String, List<TransportOptionModel>> _transitCache = {};

  /// Highway & rail corridor distance multiplier over straight-line Haversine distance
  static const double roadRailWindingFactor = 1.25;

  /// Generate all transit options between two cities tailored to the group composition
  Future<List<TransportOptionModel>> getTransportOptions({
    required String fromCity,
    required String toCity,
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required TravelersModel travelers,
    DateTime? travelDate,
  }) async {
    final cacheKey =
        '${fromCity.toLowerCase()}_${toCity.toLowerCase()}_${travelers.adults}_${travelers.minors}';
    if (_transitCache.containsKey(cacheKey)) {
      return _transitCache[cacheKey]!;
    }

    final straightLineKm = _locationService.calculateDistance(
      fromLat,
      fromLng,
      toLat,
      toLng,
    );
    // Real ground distance approximation
    final groundKm = (straightLineKm * roadRailWindingFactor).roundToDouble();

    final options = <TransportOptionModel>[];
    final now = DateTime.now();

    // 1. Train Option
    final trainDuration =
        (groundKm / TransportConfig.trainAvgSpeedKmH * 60).round();
    final trainAdultCost =
        (TransportConfig.trainBaseFare + groundKm * TransportConfig.trainPerKmRate)
            .round();
    // Minor concession: child 0-2 & 3-5 free; child 6-12 50% fare; teen 13-17 full fare
    int trainMinorsCost = 0;
    if (travelers.hasMinors) {
      for (final band in travelers.minorAgeBands) {
        if (band == MinorAgeBand.child) {
          trainMinorsCost += (trainAdultCost * 0.5).round();
        } else if (band == MinorAgeBand.teen) {
          trainMinorsCost += trainAdultCost;
        }
      }
      if (travelers.minorAgeBands.isEmpty) {
        trainMinorsCost = (travelers.minors * (trainAdultCost * 0.5)).round();
      }
    }
    final trainTotalGroup =
        (trainAdultCost * travelers.adults) + trainMinorsCost;
    final trainOvernight = groundKm >= 500 || trainDuration >= 450;

    options.add(
      TransportOptionModel(
        id: 'train_${fromCity}_$toCity',
        mode: 'train',
        modeName: groundKm >= 300 ? 'Superfast / AC Express' : 'Intercity Express',
        durationMinutes: trainDuration,
        estimatedCostPerPerson: trainAdultCost,
        estimatedTotalCost: trainTotalGroup,
        distanceKm: groundKm,
        isOvernight: trainOvernight,
        notes: trainOvernight
            ? 'Overnight train with sleeper berths. Recommended to book 60 days ahead.'
            : 'Scenic rail journey with punctual departures.',
        comfortClass: '3rd AC (3A) • 2nd AC (2A) • Sleeper',
        dataSource: TransportConfig.engineName,
        isEstimate: true,
        lastUpdated: now,
        bookingUrl: TransportConfig.trainBookingUrl,
      ),
    );

    // 2. Bus Option
    final busDuration = (groundKm / TransportConfig.busAvgSpeedKmH * 60).round();
    final busAdultCost =
        (TransportConfig.busBaseFare + groundKm * TransportConfig.busPerKmRate)
            .round();
    final busTotalGroup = (busAdultCost * travelers.adults) +
        (busAdultCost * (travelers.minors > 0 ? (travelers.minors * 0.8).round() : 0));
    final busOvernight = groundKm >= 400 || busDuration >= 420;

    options.add(
      TransportOptionModel(
        id: 'bus_${fromCity}_$toCity',
        mode: 'bus',
        modeName: 'AC Volvo Semi-Sleeper',
        durationMinutes: busDuration,
        estimatedCostPerPerson: busAdultCost,
        estimatedTotalCost: busTotalGroup,
        distanceKm: groundKm,
        isOvernight: busOvernight,
        notes: 'Frequent departures from state and private inter-state bus terminals.',
        comfortClass: 'Multi-Axle Volvo • AC Sleeper',
        dataSource: TransportConfig.engineName,
        isEstimate: true,
        lastUpdated: now,
        bookingUrl: TransportConfig.busBookingUrl,
      ),
    );

    // 3. Car / Private Taxi Option
    final carDuration = (groundKm / TransportConfig.carAvgSpeedKmH * 60).round();
    final isSuvNeeded = travelers.totalCount > TransportConfig.carSedanCapacity;
    final carRatePerKm = isSuvNeeded
        ? TransportConfig.carSuvPerKmRate
        : TransportConfig.carSedanPerKmRate;
    final tollEstimate = (groundKm * 0.9).round();
    final carGroupCost = (groundKm * carRatePerKm + tollEstimate).round();
    final carPerPersonCost =
        travelers.totalCount > 0 ? (carGroupCost / travelers.totalCount).round() : carGroupCost;

    options.add(
      TransportOptionModel(
        id: 'car_${fromCity}_$toCity',
        mode: 'car',
        modeName: isSuvNeeded ? 'Private Outstation SUV' : 'Private Outstation Sedan',
        durationMinutes: carDuration,
        estimatedCostPerPerson: carPerPersonCost,
        estimatedTotalCost: carGroupCost,
        distanceKm: groundKm,
        isOvernight: false,
        notes:
            'Doorstep pickup with flexible halts, luggage room, and scenic highway dining stops.',
        comfortClass: isSuvNeeded ? 'SUV (Innova / Ertiga)' : 'Sedan (Dzire / Etios)',
        dataSource: TransportConfig.engineName,
        isEstimate: true,
        lastUpdated: now,
        bookingUrl: TransportConfig.cabBookingUrl,
      ),
    );

    // 4. Flight Option (Only when distance >= 320 km & airports exist)
    final hasAirports = TransportConfig.hasCommercialAirport(fromCity) &&
        TransportConfig.hasCommercialAirport(toCity);
    if (straightLineKm >= TransportConfig.flightMinDistanceKm && hasAirports) {
      final flightAirMinutes =
          (straightLineKm / TransportConfig.flightAvgSpeedKmH * 60).round();
      final totalFlightDuration =
          flightAirMinutes + TransportConfig.flightAirportBufferMinutes;
      final flightAdultCost = (TransportConfig.flightBaseFare +
              (straightLineKm - TransportConfig.flightMinDistanceKm) *
                  TransportConfig.flightPerKmRate)
          .round();

      // Infants under 2 pay nominal infant fare (₹1500)
      int flightMinorsCost = 0;
      if (travelers.hasMinors) {
        for (final band in travelers.minorAgeBands) {
          if (band == MinorAgeBand.toddler) {
            flightMinorsCost += 1500;
          } else {
            flightMinorsCost += flightAdultCost;
          }
        }
        if (travelers.minorAgeBands.isEmpty) {
          flightMinorsCost = travelers.minors * flightAdultCost;
        }
      }
      final flightTotalGroup =
          (flightAdultCost * travelers.adults) + flightMinorsCost;

      options.add(
        TransportOptionModel(
          id: 'flight_${fromCity}_$toCity',
          mode: 'flight',
          modeName: 'Domestic Flight',
          durationMinutes: totalFlightDuration,
          estimatedCostPerPerson: flightAdultCost,
          estimatedTotalCost: flightTotalGroup,
          distanceKm: straightLineKm,
          isOvernight: false,
          notes:
              'Fastest route connecting domestic terminals. Includes 2.5h security & boarding buffer.',
          comfortClass: 'Economy (Air India / IndiGo / Vistara)',
          dataSource: TransportConfig.engineName,
          isEstimate: true,
          lastUpdated: now,
          bookingUrl: TransportConfig.flightBookingUrl,
        ),
      );
    }

    // 5. Select Best Recommendation
    _assignRecommendations(options, groundKm, travelers);

    _transitCache[cacheKey] = options;
    return options;
  }

  /// Automatically picks and marks one option as recommended with a short rationale
  void _assignRecommendations(
    List<TransportOptionModel> options,
    double distanceKm,
    TravelersModel travelers,
  ) {
    if (options.isEmpty) return;

    // Reset recommendations
    for (int i = 0; i < options.length; i++) {
      options[i] = options[i].copyWith(isRecommended: false, recommendationReason: null);
    }

    int bestIndex = 0;
    String reason = 'Best overall route';

    if (distanceKm > 600 && options.any((o) => o.mode == 'flight')) {
      bestIndex = options.indexWhere((o) => o.mode == 'flight');
      reason = 'Fastest connection for long distance';
    } else if (distanceKm < 180 && travelers.hasMinors) {
      bestIndex = options.indexWhere((o) => o.mode == 'car');
      reason = 'Private, direct & comfortable for family with children';
    } else if (options.any((o) => o.mode == 'train')) {
      bestIndex = options.indexWhere((o) => o.mode == 'train');
      reason = travelers.hasMinors
          ? 'Comfortable, spacious berths with dining on board'
          : 'Punctual, scenic & economical';
    } else if (options.any((o) => o.mode == 'bus')) {
      bestIndex = options.indexWhere((o) => o.mode == 'bus');
      reason = 'Frequent departures & budget friendly';
    }

    options[bestIndex] = options[bestIndex].copyWith(
      isRecommended: true,
      recommendationReason: reason,
    );
  }

  /// Synchronously generates travel legs connecting consecutive cities in a circuit
  List<TravelLegModel> generateLegsForCircuit({
    required List<CityStayModel> cities,
    required bool isRoundTrip,
    required TravelersModel travelers,
  }) {
    final legs = <TravelLegModel>[];
    if (cities.length < 2) return legs;

    for (int i = 0; i < cities.length - 1; i++) {
      final from = cities[i];
      final to = cities[i + 1];
      final straightLine = _locationService.calculateDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      final dist = (straightLine * roadRailWindingFactor).roundToDouble();
      final options = _calculateOptionsSync(from, to, dist, straightLine, travelers);
      final selected = options.firstWhere((o) => o.isRecommended, orElse: () => options.first);

      legs.add(
        TravelLegModel(
          id: 'leg_${from.id}_${to.id}',
          fromCity: from.name,
          toCity: to.name,
          fromLat: from.latitude,
          fromLng: from.longitude,
          toLat: to.latitude,
          toLng: to.longitude,
          distanceKm: dist,
          availableOptions: options,
          selectedOption: selected,
        ),
      );
    }

    if (isRoundTrip && cities.length >= 2) {
      final from = cities.last;
      final to = cities.first;
      final straightLine = _locationService.calculateDistance(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      final dist = (straightLine * roadRailWindingFactor).roundToDouble();
      final options = _calculateOptionsSync(from, to, dist, straightLine, travelers);
      final selected = options.firstWhere((o) => o.isRecommended, orElse: () => options.first);

      legs.add(
        TravelLegModel(
          id: 'leg_return_${from.id}_${to.id}',
          fromCity: from.name,
          toCity: to.name,
          fromLat: from.latitude,
          fromLng: from.longitude,
          toLat: to.latitude,
          toLng: to.longitude,
          distanceKm: dist,
          availableOptions: options,
          selectedOption: selected,
          isReturnLeg: true,
        ),
      );
    }

    return legs;
  }

  List<TransportOptionModel> _calculateOptionsSync(
    CityStayModel from,
    CityStayModel to,
    double groundKm,
    double straightLineKm,
    TravelersModel travelers,
  ) {
    final options = <TransportOptionModel>[];
    final now = DateTime.now();

    // 1. Train
    final trainDuration = (groundKm / TransportConfig.trainAvgSpeedKmH * 60).round();
    final trainAdultCost = (TransportConfig.trainBaseFare + groundKm * TransportConfig.trainPerKmRate).round();
    int trainMinorsCost = (travelers.minors * (trainAdultCost * 0.5)).round();
    final trainTotalGroup = (trainAdultCost * travelers.adults) + trainMinorsCost;
    final trainOvernight = groundKm >= 500 || trainDuration >= 450;

    options.add(
      TransportOptionModel(
        id: 'train_${from.name}_${to.name}',
        mode: 'train',
        modeName: 'Express / Mail Train',
        durationMinutes: trainDuration,
        estimatedCostPerPerson: trainAdultCost,
        estimatedTotalCost: trainTotalGroup,
        distanceKm: groundKm,
        isOvernight: trainOvernight,
        notes: trainOvernight ? 'Overnight journey with sleeper/AC berths available.' : 'Comfortable daytime train.',
        comfortClass: '3A / 2A / Sleeper',
        dataSource: TransportConfig.engineName,
        isEstimate: true,
        lastUpdated: now,
        bookingUrl: TransportConfig.trainBookingUrl,
      ),
    );

    // 2. Bus
    final busDuration = (groundKm / TransportConfig.busAvgSpeedKmH * 60).round();
    final busAdultCost = (TransportConfig.busBaseFare + groundKm * TransportConfig.busPerKmRate).round();
    int busMinorsCost = (travelers.minors * (busAdultCost * 0.5)).round();
    final busTotalGroup = (busAdultCost * travelers.adults) + busMinorsCost;
    final busOvernight = groundKm >= 400 || busDuration >= 420;

    options.add(
      TransportOptionModel(
        id: 'bus_${from.name}_${to.name}',
        mode: 'bus',
        modeName: 'Inter-City AC Bus',
        durationMinutes: busDuration,
        estimatedCostPerPerson: busAdultCost,
        estimatedTotalCost: busTotalGroup,
        distanceKm: groundKm,
        isOvernight: busOvernight,
        notes: 'AC Semi-Sleeper / Volvo service with highway halts.',
        comfortClass: 'AC Sleeper / Seater',
        dataSource: TransportConfig.engineName,
        isEstimate: true,
        lastUpdated: now,
        bookingUrl: TransportConfig.busBookingUrl,
      ),
    );

    // 3. Car / Taxi
    final carDuration = (groundKm / TransportConfig.carAvgSpeedKmH * 60).round();
    final isSuv = travelers.totalCount > TransportConfig.carSedanCapacity;
    final carRatePerKm = isSuv ? TransportConfig.carSuvPerKmRate : TransportConfig.carSedanPerKmRate;
    final tollEstimate = (groundKm * 0.9).round();
    final carTotalVehicle = (groundKm * carRatePerKm + tollEstimate).round();
    final carPerPerson = (carTotalVehicle / max(1, travelers.totalCount)).round();

    options.add(
      TransportOptionModel(
        id: 'car_${from.name}_${to.name}',
        mode: 'car',
        modeName: isSuv ? 'SUV Outstation Cab (6+1)' : 'Sedan Outstation Cab (4+1)',
        durationMinutes: carDuration,
        estimatedCostPerPerson: carPerPerson,
        estimatedTotalCost: carTotalVehicle,
        distanceKm: groundKm,
        isOvernight: false,
        notes: 'Private door-to-door cab with AC & flexible halts.',
        comfortClass: isSuv ? 'SUV (Innova / Ertiga)' : 'Sedan (Dzire / Etios)',
        dataSource: TransportConfig.engineName,
        isEstimate: true,
        lastUpdated: now,
        bookingUrl: TransportConfig.cabBookingUrl,
      ),
    );

    // 4. Flight (if above threshold and airport cities)
    if (straightLineKm >= TransportConfig.flightMinDistanceKm &&
        TransportConfig.hasCommercialAirport(from.name) &&
        TransportConfig.hasCommercialAirport(to.name)) {
      final flightAirMinutes = (straightLineKm / TransportConfig.flightAvgSpeedKmH * 60).round();
      final totalFlightDuration = flightAirMinutes + TransportConfig.flightAirportBufferMinutes;
      final flightAdultCost = (TransportConfig.flightBaseFare + straightLineKm * TransportConfig.flightPerKmRate).round();
      int flightMinorsCost = travelers.minors * flightAdultCost;
      final flightTotalGroup = (flightAdultCost * travelers.adults) + flightMinorsCost;

      options.add(
        TransportOptionModel(
          id: 'flight_${from.name}_${to.name}',
          mode: 'flight',
          modeName: 'Domestic Flight',
          durationMinutes: totalFlightDuration,
          estimatedCostPerPerson: flightAdultCost,
          estimatedTotalCost: flightTotalGroup,
          distanceKm: straightLineKm,
          isOvernight: false,
          notes: 'Fastest route connecting domestic terminals. Includes 2.5h security & boarding buffer.',
          comfortClass: 'Economy (Air India / IndiGo / Vistara)',
          dataSource: TransportConfig.engineName,
          isEstimate: true,
          lastUpdated: now,
          bookingUrl: TransportConfig.flightBookingUrl,
        ),
      );
    }

    _assignRecommendations(options, groundKm, travelers);
    return options;
  }

  /// Suggests nearby prominent cities to visit based on real geographic distance
  Future<List<NearbyCitySuggestion>> getNearbyCitySuggestions({
    required String baseCity,
    required double baseLat,
    required double baseLng,
    List<String> excludeCityNames = const [],
  }) async {
    final suggestions = <NearbyCitySuggestion>[];
    final excludeLower =
        excludeCityNames.map((c) => c.toLowerCase().trim()).toSet();
    excludeLower.add(baseCity.toLowerCase().trim());

    // Prominent Indian tourism destinations catalog
    const prominentCities = [
      {'name': 'Agra', 'lat': 27.1767, 'lng': 78.0081, 'state': 'Uttar Pradesh'},
      {'name': 'Jaipur', 'lat': 26.9124, 'lng': 75.7873, 'state': 'Rajasthan'},
      {'name': 'New Delhi', 'lat': 28.6139, 'lng': 77.2090, 'state': 'Delhi'},
      {'name': 'Udaipur', 'lat': 24.5854, 'lng': 73.7125, 'state': 'Rajasthan'},
      {'name': 'Jodhpur', 'lat': 26.2389, 'lng': 73.0243, 'state': 'Rajasthan'},
      {'name': 'Varanasi', 'lat': 25.3176, 'lng': 82.9739, 'state': 'Uttar Pradesh'},
      {'name': 'Amritsar', 'lat': 31.6340, 'lng': 74.8723, 'state': 'Punjab'},
      {'name': 'Chandigarh', 'lat': 30.7333, 'lng': 76.7794, 'state': 'Punjab'},
      {'name': 'Rishikesh', 'lat': 30.0869, 'lng': 78.2676, 'state': 'Uttarakhand'},
      {'name': 'Mumbai', 'lat': 19.0760, 'lng': 72.8777, 'state': 'Maharashtra'},
      {'name': 'Pune', 'lat': 18.5204, 'lng': 73.8567, 'state': 'Maharashtra'},
      {'name': 'Goa', 'lat': 15.2993, 'lng': 74.1240, 'state': 'Goa'},
      {'name': 'Bengaluru', 'lat': 12.9716, 'lng': 77.5946, 'state': 'Karnataka'},
      {'name': 'Mysuru', 'lat': 12.2958, 'lng': 76.6394, 'state': 'Karnataka'},
      {'name': 'Kochi', 'lat': 9.9312, 'lng': 76.2673, 'state': 'Kerala'},
      {'name': 'Munnar', 'lat': 10.0889, 'lng': 77.0595, 'state': 'Kerala'},
      {'name': 'Alappuzha', 'lat': 9.4981, 'lng': 76.3388, 'state': 'Kerala'},
    ];

    for (final city in prominentCities) {
      final name = city['name'] as String;
      if (excludeLower.contains(name.toLowerCase())) continue;

      final lat = city['lat'] as double;
      final lng = city['lng'] as double;
      final state = city['state'] as String;

      final straightLine = _locationService.calculateDistance(
        baseLat,
        baseLng,
        lat,
        lng,
      );
      final groundKm = (straightLine * roadRailWindingFactor).roundToDouble();

      // Only suggest reasonable nearby travel range (50 km to 400 km)
      if (groundKm >= 50 && groundKm <= 400) {
        final hours = (groundKm / TransportConfig.trainAvgSpeedKmH).toStringAsFixed(1);
        suggestions.add(
          NearbyCitySuggestion(
            name: name,
            state: state,
            latitude: lat,
            longitude: lng,
            distanceKm: groundKm,
            estimatedHours: '$hours hrs',
          ),
        );
      }
    }

    suggestions.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return suggestions.take(5).toList();
  }

  /// Optimizes route order using a Greedy Nearest Neighbor heuristic to minimize backtracking
  List<CityStayModel> optimizeRoute(
    List<CityStayModel> cities, {
    bool isRoundTrip = false,
  }) {
    if (cities.length <= 2) return List.from(cities);

    final unvisited = List<CityStayModel>.from(cities.sublist(1));
    final optimized = <CityStayModel>[cities.first]; // Keep start city fixed

    while (unvisited.isNotEmpty) {
      final current = optimized.last;
      int nearestIndex = 0;
      double shortestDist = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        final candidate = unvisited[i];
        final dist = _locationService.calculateDistance(
          current.latitude,
          current.longitude,
          candidate.latitude,
          candidate.longitude,
        );
        if (dist < shortestDist) {
          shortestDist = dist;
          nearestIndex = i;
        }
      }

      optimized.add(unvisited.removeAt(nearestIndex));
    }

    return optimized;
  }
}

/// Lightweight suggestion DTO for nearby cities
class NearbyCitySuggestion {
  final String name;
  final String state;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String estimatedHours;

  const NearbyCitySuggestion({
    required this.name,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.estimatedHours,
  });
}
