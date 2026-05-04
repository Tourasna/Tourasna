class AgendaItem {
  final int id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? placeId;
  final String? notes;

  AgendaItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.placeId,
    this.notes,
  });

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    return AgendaItem(
      id: json['id'],
      title: json['title'],
      start: DateTime.parse(json['start_datetime']),
      end: DateTime.parse(json['end_datetime']),
      placeId: json['place_id'],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'startDateTime': start.toIso8601String(),
      'endDateTime': end.toIso8601String(),
      if (placeId != null) 'placeId': placeId,
      if (notes != null) 'notes': notes,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'startDateTime': start.toIso8601String(),
      'endDateTime': end.toIso8601String(),
      if (title.isNotEmpty) 'title': title,
      'placeId': placeId,
      'notes': notes,
    };
  }
}
