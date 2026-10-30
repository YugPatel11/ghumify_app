import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../constants/api_keys.dart';

class CrowdService {
  final http.Client _client;

  CrowdService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches crowd recommendations and alternatives for an itinerary
  /// Returns null when feature flag is off or upon error.
  Future<Map<String, dynamic>?> getCrowdRecommendations({
    required String city,
    required String date,
    String startTime = '09:00',
    String endTime = '18:00',
    bool avoidCrowds = false,
    int? budgetCap,
    List<Map<String, dynamic>>? candidates,
  }) async {
    // 1. Guard behind feature flag
    if (!ApiKeys.crowdAwareEnabled) {
      return null;
    }

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final uri = Uri.parse('${ApiKeys.backendBaseUrl}/api/crowd/recommend');

      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'city': city,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'avoidCrowds': avoidCrowds,
        if (budgetCap != null) 'budgetCap': budgetCap,
        if (candidates != null && candidates.isNotEmpty) 'candidates': candidates,
      });

      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Graceful degradation: never crash generation if crowd service fails
    }
    return null;
  }
}

