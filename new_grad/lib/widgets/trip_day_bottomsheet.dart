// lib/features/interactive_map/widgets/trip_day_bottomsheet.dart
import 'package:flutter/material.dart';
import '../models/place_map.dart';

class TripDayBottomSheet extends StatelessWidget {
  final List<Placemap> places;
  final int dayNumber;
  final Function(Placemap) onPlaceTap;

  const TripDayBottomSheet({Key? key, required this.places, required this.dayNumber, required this.onPlaceTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('Day $dayNumber Plan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemBuilder: (context, idx) {
                  final p = places[idx];
                  return ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(p.name),
                    subtitle: Text(p.estimatedVisitTime ?? ''),
                    onTap: () => onPlaceTap(p),
                  );
                },
                separatorBuilder: (_, __) => const Divider(),
                itemCount: places.length,
              ),
            )
          ],
        ),
      ),
    );
  }
}
