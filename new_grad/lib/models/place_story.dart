class PlaceStory {
  final String id;
  final String name;
  final String description;
  final String category;
  final String? photoUrl;
  final String? glbUrl;
  final bool hasStory;

  const PlaceStory({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.photoUrl,
    this.glbUrl,
    required this.hasStory,
  });

  factory PlaceStory.fromJson(Map<String, dynamic> j) => PlaceStory(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    category: j['category'] as String? ?? '',
    photoUrl: j['photoUrl'] as String?,
    glbUrl: j['glbUrl'] as String?,
    hasStory: j['hasStory'] == true,
  );
}
