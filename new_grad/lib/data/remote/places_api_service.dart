import 'dart:convert';
import '../../models/place_location.dart';
import '../../services/api_client.dart'; // ✅ FIXED: 4 levels up

/// Service to fetch place location data from Backend
///
/// ✅ Uses existing ApiClient for consistency
/// ✅ Inherits authentication from ApiClient
/// ✅ Uses same base URL (http://13.50.201.36)
class PlacesApiService {
  // We don't need baseUrl or authToken parameters anymore
  // ApiClient handles everything internally

  PlacesApiService();

  /// Fetch location for a specific placeId from places_agenda table
  ///
  /// Endpoint: GET /api/places/{placeId}/location
  /// Response:
  /// {
  ///   "placeId": "733bf15a-f976-11f0-90e8-e27eeb545af0",
  ///   "name": "The Egyptian Museum",
  ///   "latitude": 30.047327,
  ///   "longitude": 31.233646,
  ///   "category": "Museums"
  /// }
  Future<PlaceLocation> getPlaceLocation(String placeId) async {
    try {
      print('🔍 Fetching location for placeId: $placeId');

      // ✅ Use ApiClient.get instead of direct http.get
      // ApiClient automatically adds auth token and uses correct base URL
      final response = await ApiClient.get('/api/places-map/$placeId/location');

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final location = PlaceLocation.fromJson(json);
        print('✅ Location fetched: $location');
        return location;
      } else {
        throw Exception(
          'Failed to fetch place location: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching place location: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Batch fetch multiple places (optional - for future use)
  ///
  /// Endpoint: POST /api/places/locations
  /// Body: { "placeIds": ["id1", "id2", ...] }
  Future<List<PlaceLocation>> getMultiplePlaceLocations(
    List<String> placeIds,
  ) async {
    try {
      print('🔍 Fetching locations for ${placeIds.length} places');

      // ✅ Use ApiClient.post
      final response = await ApiClient.post(
        '/api/places-map/locations',
        body: {'placeIds': placeIds},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final locations = jsonList
            .map((json) => PlaceLocation.fromJson(json as Map<String, dynamic>))
            .toList();
        print('✅ Fetched ${locations.length} locations');
        return locations;
      } else {
        throw Exception(
          'Failed to fetch multiple locations: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching multiple locations: $e');
      print(stackTrace);
      rethrow;
    }
  }
}
