import 'place_map.dart';

class TripDay {
  final int day;
  final String? date;
  final List<Placemap> places;
  TripDay({required this.day, this.date, required this.places});

  factory TripDay.fromJson(Map<String, dynamic> j) {
    final list = (j['places'] ?? j['locations'] ?? []) as List;
    final places = list.map((e) => Placemap.fromJson(e as Map<String, dynamic>)).toList();
    return TripDay(day: j['day'] as int, date: j['date'] as String?, places: places);
  }
}

class Trip {
  final String tripId;
  final String destination;
  final List<TripDay> days;

  Trip({required this.tripId, required this.destination, required this.days});

  factory Trip.fromJson(Map<String, dynamic> j) {
    final daysList = (j['days'] as List).map((e) => TripDay.fromJson(e as Map<String, dynamic>)).toList();
    return Trip(
      tripId: j['tripId']?.toString() ?? j['user_id']?.toString() ?? '',
      destination: j['destination'] ?? '',
      days: daysList,
    );
  }

  List<Placemap> get allPlaces => days.expand((d) => d.places).toList();
}
