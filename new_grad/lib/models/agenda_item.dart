class AgendaItem {
  final int id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? placeId;
  final int? landmarkId;
  final double? latitude;
  final double? longitude;
  final String? notes;

  AgendaItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.placeId,
    this.landmarkId,
    this.latitude,
    this.longitude,
    this.notes,
  });

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    return AgendaItem(
      id: json['id'],
      title: json['title'],
      start: DateTime.parse(json['start_datetime']).toLocal(),
      end: DateTime.parse(json['end_datetime']).toLocal(),
      placeId: json['place_id']?.toString(),
      landmarkId: json['landmark_id'] != null
          ? int.tryParse(json['landmark_id'].toString())
          : null,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'startDateTime': start.toUtc().toIso8601String(),
      'endDateTime': end.toUtc().toIso8601String(),
      if (placeId != null) 'placeId': placeId,
      if (landmarkId != null) 'landmarkId': landmarkId,
      if (notes != null) 'notes': notes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'startDateTime': start.toUtc().toIso8601String(),
      'endDateTime': end.toUtc().toIso8601String(),
      if (title.isNotEmpty) 'title': title,
      if (placeId != null) 'placeId': placeId,
      if (landmarkId != null) 'landmarkId': landmarkId,
      'notes': notes,
    };
  }
}
