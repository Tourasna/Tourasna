class MapAgendaItem {
  final int agendaId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String placeId;
  final double latitude;
  final double longitude;
  final String? category;
  final String status;

  MapAgendaItem({
    required this.agendaId,
    required this.title,
    required this.start,
    required this.end,
    required this.placeId,
    required this.latitude,
    required this.longitude,
    this.category,
    this.status = 'pending',
  });

  factory MapAgendaItem.fromJson(Map<String, dynamic> json) {
    return MapAgendaItem(
      agendaId: json['agenda_id'],
      title: json['title'],
      start: DateTime.parse(json['start_datetime']),
      end: DateTime.parse(json['end_datetime']),
      placeId: json['place_id'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      category: json['category'],
      status: json['status'] ?? 'pending',
    );
  }
}