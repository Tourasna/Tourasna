class Placemap  {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? description;
  final String? imageUrl;
  final String? estimatedVisitTime;
  final String? category;
  final int? stayMinutes;

  Placemap({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.description,
    this.imageUrl,
    this.estimatedVisitTime,
    this.category,
    this.stayMinutes,
  });

  factory Placemap.fromJson(Map<String, dynamic> j) {
    return Placemap(
      id: j['id']?.toString() ?? j['name'] ?? '',
      name: j['name'] ?? '',
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      description: j['description'] ?? '',
      imageUrl: j['imageUrl'] ?? j['image'] ?? '',
      estimatedVisitTime: j['estimatedVisitTime'] ?? j['time'] ?? '',
      category: j['category'] ?? '',
      stayMinutes: j['stay_minutes'] != null ? (j['stay_minutes'] as num).toInt() : null,
    );
  }
}