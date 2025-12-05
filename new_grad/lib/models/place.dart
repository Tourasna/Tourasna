class Place {
  final int id;
  final String name;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final String glbUrl;
  final String mlLabel;
  final Map<String, dynamic>? infoJson;

  Place({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.glbUrl,
    required this.mlLabel,
    required this.infoJson,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    dynamic idValue = json['id'];

    int parsedId;
    if (idValue is int) {
      parsedId = idValue;
    } else if (idValue is String) {
      parsedId = int.tryParse(idValue) ?? -1; // fallback
    } else {
      parsedId = -1; // completely wrong type
    }

    return Place(
      id: parsedId,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
      longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
      imageUrl: json['image_url']?.toString() ?? '',
      glbUrl: json['glb_url']?.toString() ?? '',
      mlLabel: json['ml_label']?.toString() ?? '',
      infoJson: json['info_json'],
    );
  }
}
