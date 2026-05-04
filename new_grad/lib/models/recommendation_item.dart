class RecommendationItem {
  final int id;
  final String name;
  final String category;
  final String budget;
  final double? rating;
  final List<String> travelTypes;
  final double? score;
  final int? day; // for TripPlan only

  RecommendationItem({
    required this.id,
    required this.name,
    required this.category,
    required this.budget,
    required this.rating,
    required this.travelTypes,
    required this.score,
    this.day,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
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
