class Place {
  final String id; // ✅ UUID MUST BE STRING
  final String name;
  final String description;
  final String category;
  final double? latitude;
  final double? longitude;
  final String imageUrl;
  final String glbUrl;
  final String mlLabel;
  final Map<String, dynamic>? infoJson;

  Place({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.latitude,
    this.longitude,
    required this.imageUrl,
    required this.glbUrl,
    required this.mlLabel,
    this.infoJson,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'].toString(), // ✅ DIRECT UUID PASS
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      latitude: json['latitude'] == null
          ? null
          : double.tryParse(json['latitude'].toString()),
      longitude: json['longitude'] == null
          ? null
          : double.tryParse(json['longitude'].toString()),
      imageUrl: json['image_url']?.toString() ?? '',
      glbUrl: json['glb_url']?.toString() ?? '',
      mlLabel: json['ml_label']?.toString() ?? '',
      infoJson: json['info_json'],
    );
  }
}
