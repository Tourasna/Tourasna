class TripHistoryItem {
  final String id;
  final String destination;
  final DateTime startDate;
  final DateTime? endDate;
  final int placesVisited;
  final double totalDistance; // in km
  final List<String> visitedPlaceIds;
  final bool isCompleted;

  TripHistoryItem({
    required this.id,
    required this.destination,
    required this.startDate,
    this.endDate,
    required this.placesVisited,
    required this.totalDistance,
    required this.visitedPlaceIds,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'placesVisited': placesVisited,
      'totalDistance': totalDistance,
      'visitedPlaceIds': visitedPlaceIds,
      'isCompleted': isCompleted,
    };
  }

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    return TripHistoryItem(
      id: json['id'],
      destination: json['destination'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      placesVisited: json['placesVisited'],
      totalDistance: json['totalDistance'],
      visitedPlaceIds: List<String>.from(json['visitedPlaceIds']),
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}