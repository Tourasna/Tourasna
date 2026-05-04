import '../remote/places_api_service.dart';
import '../../models/place_location.dart';

/// Repository for accessing place location data
/// 
/// ✅ Single source of truth for place coordinates
/// ✅ Fetches data from places_agenda table via Backend API
/// ✅ Uses ApiClient for authentication & base URL
class PlacesRepository {
  final PlacesApiService apiService;

  PlacesRepository({required this.apiService});
  
  // Factory constructor for easy instantiation
  factory PlacesRepository.create() {
    return PlacesRepository(
      apiService: PlacesApiService(),
    );
  }

  /// Get location for a single place by placeId
  /// 
  /// Returns PlaceLocation with latitude, longitude, and category
  /// Throws exception if place not found or API fails
  Future<PlaceLocation> getPlaceLocation(String placeId) async {
    try {
      print('📍 PlacesRepository: Getting location for placeId: $placeId');
      return await apiService.getPlaceLocation(placeId);
    } catch (e) {
      print('❌ PlacesRepository: Failed to get location for $placeId: $e');
      rethrow;
    }
  }

  /// Get locations for multiple places (batch request)
  /// 
  /// Useful for fetching multiple agenda items at once
  Future<List<PlaceLocation>> getMultiplePlaceLocations(
    List<String> placeIds,
  ) async {
    try {
      print('📍 PlacesRepository: Getting ${placeIds.length} locations');
      return await apiService.getMultiplePlaceLocations(placeIds);
    } catch (e) {
      print('❌ PlacesRepository: Failed to get multiple locations: $e');
      rethrow;
    }
  }

  /// Check if a placeId exists in the database
  /// 
  /// Returns true if place exists, false otherwise
  Future<bool> placeExists(String placeId) async {
    try {
      await getPlaceLocation(placeId);
      return true;
    } catch (e) {
      return false;
    }
  }
}