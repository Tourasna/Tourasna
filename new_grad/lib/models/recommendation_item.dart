class RecommendationItem {
  final int id;
  final String name;
  final String category;
  final String budget;
  final double rating;
  final List<String> travelTypes;
  final double score;

  RecommendationItem({
    required this.id,
    required this.name,
    required this.category,
    required this.budget,
    required this.rating,
    required this.travelTypes,
    required this.score,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      budget: json['budget'],
      rating: (json['rating'] as num).toDouble(),
      travelTypes: List<String>.from(json['travel_types']),
      score: (json['score'] as num).toDouble(),
    );
  }
}
