class RecommendationItem {
  final int id;
  final String name;
  final String category;
  final String budget;
  final double? rating;
  final List<String> travelTypes;
  final double? score;
  final int? day;
  // ── Rich fields ──────────────────────────
  final String? description;
  final String? address;
  final String? openingHours;
  final String? phone;
  final String? website;
  final List<String> photoUrls;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String? priceRange;
  final int? startPrice;
  final int? endPrice;
  final int? reviewCount;

  RecommendationItem({
    required this.id,
    required this.name,
    required this.category,
    required this.budget,
    required this.rating,
    required this.travelTypes,
    required this.score,
    this.day,
    this.description,
    this.address,
    this.openingHours,
    this.phone,
    this.website,
    this.photoUrls = const [],
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.priceRange,
    this.startPrice,
    this.endPrice,
    this.reviewCount,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    List<String> parsePhotoUrls(dynamic val) {
      if (val == null) return [];
      if (val is List) return List<String>.from(val);
      if (val is String) {
        try {
          final decoded = val.split('|').map((e) => e.trim()).toList();
          return decoded;
        } catch (_) {
          return [];
        }
      }
      return [];
    }

    return RecommendationItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      budget: json['budget'],
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      travelTypes: List<String>.from(json['travel_types'] ?? []),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      day: json['day'],
      description: json['description'],
      address: json['address'],
      openingHours: json['opening_hours'],
      phone: json['phone'],
      website: json['website'],
      photoUrls: parsePhotoUrls(json['photo_urls']),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      googleMapsUrl: json['google_maps_url'],
      priceRange: json['price_range'],
      startPrice: json['start_price'],
      endPrice: json['end_price'],
      reviewCount: json['review_count'],
    );
  }
}

class TripPlanResult {
  final int tripDays;
  final int totalLandmarks;
  final List<TripDay> days;

  TripPlanResult({
    required this.tripDays,
    required this.totalLandmarks,
    required this.days,
  });

  factory TripPlanResult.fromJson(Map<String, dynamic> json) {
    return TripPlanResult(
      tripDays: json['trip_days'],
      totalLandmarks: json['total_landmarks'],
      days: (json['days'] as List).map((d) => TripDay.fromJson(d)).toList(),
    );
  }
}

class TripDay {
  final int day;
  final List<RecommendationItem> landmarks;

  TripDay({required this.day, required this.landmarks});

  factory TripDay.fromJson(Map<String, dynamic> json) {
    return TripDay(
      day: json['day'],
      landmarks: (json['landmarks'] as List)
          .map((l) => RecommendationItem.fromJson(l))
          .toList(),
    );
  }
}
