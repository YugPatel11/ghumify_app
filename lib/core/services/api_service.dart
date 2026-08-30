import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';
import '../models/itinerary_model.dart';

class ApiService {
  // Use 10.0.2.2 for Android emulator to access localhost Next.js backend
  // In production, this would be the Vercel URL
  static const String _baseUrl = 'http://10.0.2.2:3000/api';

  Future<Map<String, dynamic>> planItinerary({
    required Map<String, dynamic> origin,
    required List<PlaceModel> destinations,
    String mode = 'driving',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/itinerary/plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin': origin,
          'destinations': destinations.map((d) => {
            'id': d.id,
            'name': d.name,
            'lat': d.latitude,
            'lng': d.longitude,
          }).toList(),
          'mode': mode,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to plan itinerary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error calling backend: $e');
    }
  }
}
