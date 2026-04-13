class PlaceSearchItem {
  final String id;
  final String city;
  final String name;
  final String subcategory;
  final double? rating;
  final String? ranking;
  final String? address;
  final double latitude;
  final double longitude;

  PlaceSearchItem({
    required this.id,
    required this.city,
    required this.name,
    required this.subcategory,
    this.rating,
    this.ranking,
    this.address,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceSearchItem.fromJson(Map<String, dynamic> json) {
    return PlaceSearchItem(
      id: json['id'],
      city: json['city'],
      name: json['name'],
      subcategory: json['subcategory'],
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      ranking: json['ranking'],
      address: json['address'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
    );
  }
}
