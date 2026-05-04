/// Model representing location data from places_agenda table
/// 
/// Response from: GET /api/places/{placeId}/location
/// Example:
/// {
///   "placeId": "733bf15a-f976-11f0-90e8-e27eeb545af0",
///   "name": "The Egyptian Museum",
///   "latitude": 30.047327,
///   "longitude": 31.233646,
///   "category": "Museums"
/// }
class PlaceLocation {
  final String placeId;
  final String name;
  final double latitude;
  final double longitude;
  final String? category;

  PlaceLocation({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
  });

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      placeId: json['placeId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Unknown Place',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (category != null) 'category': category,
    };
  }

  @override
  String toString() {
    return 'PlaceLocation(placeId: $placeId, name: $name, lat: $latitude, lng: $longitude, category: $category)';
  }
}