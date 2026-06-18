import 'package:flutter/material.dart';
import '../models/recommendation_item.dart';
import '../services/recommendation_service.dart';
import 'dart:ui' as ui;
import 'recommendation_landmark_details.dart';
import '../models/agenda_item.dart';
import '../services/agenda_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────
//  COLOUR PALETTE
// ─────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFEDE8DC);
  static const dark = Color(0xFF1A3C3C);
  static const gold = Color(0xFFD4AF37);
  static const bronze = Color(0xFFC5A059);
  static const cream = Color(0xFFF2EADC);
  static const white = Colors.white;
}

// ─────────────────────────────────────────────
//  DATA MODEL (wraps RecommendationItem)
// ─────────────────────────────────────────────
class _Place {
  final RecommendationItem item;
  bool liked;
  bool disliked;
  bool visible;

  _Place({
    required this.item,
    this.liked = false,
    this.disliked = false,
    this.visible = true,
  });
}

// ─────────────────────────────────────────────
//  MAIN PAGE
// ─────────────────────────────────────────────
class DailyPlanPage extends StatefulWidget {
  const DailyPlanPage({super.key});

  @override
  State<DailyPlanPage> createState() => _DailyPlanPageState();
}

class _DailyPlanPageState extends State<DailyPlanPage> {
  final RecommendationService _service = RecommendationService();

  List<_Place> _places = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await _service.getDayPlan();
      setState(() {
        _places = data.map((item) => _Place(item: item)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
    _fetchUserLocation();
  }

  double _userLat = 30.0444; // Cairo default
  double _userLng = 31.2357;

  Future<void> _fetchUserLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 4));
      if (mounted)
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
        });
    } catch (_) {}
  }

  Future<void> _onLike(_Place place) async {
    setState(() => place.liked = true);
    try {
      await _service.sendFeedback(
        landmarkName: place.item.name,
        eventType: 'like',
      );
    } catch (_) {}
  }

  Future<void> _onDislike(_Place place) async {
    setState(() {
      place.disliked = true;
      place.visible = false;
    });
    try {
      await _service.sendFeedback(
        landmarkName: place.item.name,
        eventType: 'dislike',
      );
    } catch (_) {}
  }

  void _onAddToSchedule(_Place place) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pick a day for ${place.item.name}',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A3C3C),
            onPrimary: Colors.white,
            surface: Color(0xFFF2EADC),
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final agendaService = AgendaService();
    final timeSlots = List.generate(16, (i) {
      final h = i + 7;
      final dh = h > 12 ? h - 12 : h;
      final p = h < 12 ? 'AM' : 'PM';
      return '$dh:00 $p';
    });

    String? start;
    String? end;

    final serif = const TextStyle(
      fontFamily: 'Gambetta',
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A3C3C),
    );
    final sans = const TextStyle(
      fontFamily: 'Satoshi',
      color: Color(0xFF1A3C3C),
    );

    void pickTime(StateSetter setD, bool isStart) {
      final allSlots = timeSlots;
      final slots = isStart
          ? allSlots
          : (start == null
                ? allSlots
                : allSlots.where((t) {
                    final si = allSlots.indexOf(start!);
                    final ti = allSlots.indexOf(t);
                    return ti > si;
                  }).toList());

      final current = isStart ? start : end;
      int initialIndex = slots.indexOf(current ?? slots[0]);
      if (initialIndex < 0) initialIndex = 0;
      final ctrl = FixedExtentScrollController(initialItem: initialIndex);

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          height: 300,
          decoration: const BoxDecoration(
            color: Color(0xFFF2EADC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3C3C).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      isStart ? 'Start Time' : 'End Time',
                      style: serif.copyWith(fontSize: 18),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A3C3C),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Done',
                          style: sans.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 50,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3C3C).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFC5A059).withOpacity(0.30),
                        ),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: ctrl,
                      itemExtent: 50,
                      perspective: 0.003,
                      diameterRatio: 2.2,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) {
                        if (isStart) {
                          setD(() {
                            start = slots[i];
                            if (end != null) {
                              final si = allSlots.indexOf(start!);
                              final ei = allSlots.indexOf(end!);
                              if (ei <= si) end = null;
                            }
                          });
                        } else {
                          setD(() => end = slots[i]);
                        }
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: slots.length,
                        builder: (_, i) {
                          final sel = slots[i] == (isStart ? start : end);
                          return Center(
                            child: Text(
                              slots[i],
                              style: sans.copyWith(
                                fontSize: sel ? 18 : 15,
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: sel
                                    ? const Color(0xFF1A3C3C)
                                    : const Color(0xFF1A3C3C).withOpacity(0.35),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (_, setD) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF2EADC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C3C).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A059).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFC5A059).withOpacity(0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFC5A059),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Add to Agenda', style: serif.copyWith(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 20),

                // landmark (read-only)
                Text(
                  'LANDMARK',
                  style: sans.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: const Color(0xFFC5A059),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3C3C).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF1A3C3C).withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_rounded,
                        color: Color(0xFFC5A059),
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          place.item.name,
                          style: sans.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A3C3C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // time pickers
                Text(
                  'SCHEDULE',
                  style: sans.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: const Color(0xFFC5A059),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => pickTime(setD, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: start != null
                                ? const Color(0xFF1A3C3C).withOpacity(0.06)
                                : Colors.white.withOpacity(0.50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: start != null
                                  ? const Color(0xFFC5A059).withOpacity(0.35)
                                  : const Color(0xFF1A3C3C).withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: start != null
                                    ? const Color(0xFFC5A059)
                                    : const Color(0xFF1A3C3C).withOpacity(0.30),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  start ?? 'Start',
                                  style: sans.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: start != null
                                        ? const Color(0xFF1A3C3C)
                                        : const Color(
                                            0xFF1A3C3C,
                                          ).withOpacity(0.35),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: const Color(
                                  0xFF1A3C3C,
                                ).withOpacity(0.30),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => pickTime(setD, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: end != null
                                ? const Color(0xFF1A3C3C).withOpacity(0.06)
                                : Colors.white.withOpacity(0.50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: end != null
                                  ? const Color(0xFFC5A059).withOpacity(0.35)
                                  : const Color(0xFF1A3C3C).withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: end != null
                                    ? const Color(0xFFC5A059)
                                    : const Color(0xFF1A3C3C).withOpacity(0.30),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  end ?? 'End',
                                  style: sans.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: end != null
                                        ? const Color(0xFF1A3C3C)
                                        : const Color(
                                            0xFF1A3C3C,
                                          ).withOpacity(0.35),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: const Color(
                                  0xFF1A3C3C,
                                ).withOpacity(0.30),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // confirm button
                GestureDetector(
                  onTap: (start == null || end == null)
                      ? null
                      : () async {
                          DateTime combine(DateTime day, String time) {
                            final parts = time.split(RegExp(r'[: ]'));
                            int h = int.parse(parts[0]);
                            int m = int.parse(parts[1]);
                            final isPm = parts[2] == 'PM';
                            if (isPm && h != 12) h += 12;
                            if (!isPm && h == 12) h = 0;
                            return DateTime(day.year, day.month, day.day, h, m);
                          }

                          try {
                            await agendaService.create(
                              AgendaItem(
                                id: 0,
                                title: place.item.name,
                                start: combine(pickedDate, start!),
                                end: combine(pickedDate, end!),
                                placeId: null,
                                landmarkId: place.item.id,
                                notes: null,
                              ),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: const [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Added to agenda'),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF1A3C3C),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            final isConflict =
                                e.toString().toLowerCase().contains(
                                  'overlap',
                                ) ||
                                e.toString().toLowerCase().contains(
                                  'conflict',
                                ) ||
                                e.toString().contains('409');
                            if (isConflict) {
                              Navigator.pop(context);
                              // show free slots
                              final allItems = await agendaService.fetch(
                                from: pickedDate,
                                to: pickedDate.add(const Duration(days: 1)),
                              );
                              if (!mounted) return;

                              // calculate free slots
                              final dayStart = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                7,
                                0,
                              );
                              final dayEnd = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                22,
                                0,
                              );
                              final sorted = List.of(allItems)
                                ..sort((a, b) => a.start.compareTo(b.start));
                              final freeSlots = <Map<String, DateTime>>[];
                              DateTime cursor = dayStart;
                              for (final item in sorted) {
                                if (cursor.isBefore(item.start)) {
                                  DateTime sc = cursor;
                                  while (!sc
                                      .add(const Duration(hours: 2))
                                      .isAfter(item.start)) {
                                    freeSlots.add({
                                      'start': sc,
                                      'end': sc.add(const Duration(hours: 2)),
                                    });
                                    sc = sc.add(const Duration(hours: 1));
                                    if (freeSlots.length >= 8) break;
                                  }
                                }
                                if (item.end.isAfter(cursor)) cursor = item.end;
                              }
                              DateTime sc = cursor;
                              while (!sc
                                  .add(const Duration(hours: 2))
                                  .isAfter(dayEnd)) {
                                freeSlots.add({
                                  'start': sc,
                                  'end': sc.add(const Duration(hours: 2)),
                                });
                                sc = sc.add(const Duration(hours: 1));
                                if (freeSlots.length >= 8) break;
                              }

                              if (freeSlots.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'That day is full. Pick a different date.',
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                                return;
                              }

                              // show styled free slots bottom sheet
                              await showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    20,
                                    24,
                                    32,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2EADC),
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(32),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF1A3C3C,
                                            ).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(
                                                0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.orange
                                                    .withOpacity(0.3),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Time Conflict',
                                                style: serif.copyWith(
                                                  fontSize: 20,
                                                ),
                                              ),
                                              Text(
                                                'Pick an available slot below',
                                                style: sans.copyWith(
                                                  fontSize: 11,
                                                  color: const Color(
                                                    0xFF1A3C3C,
                                                  ).withOpacity(0.45),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        'AVAILABLE SLOTS',
                                        style: sans.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.8,
                                          color: const Color(0xFFC5A059),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 320,
                                        ),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: freeSlots.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(height: 8),
                                          itemBuilder: (ctx, i) {
                                            final slot = freeSlots[i];
                                            final sStart = slot['start']!;
                                            final sEnd = slot['end']!;
                                            final fmt = (DateTime d) =>
                                                '${d.hour > 12
                                                    ? d.hour - 12
                                                    : d.hour == 0
                                                    ? 12
                                                    : d.hour}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
                                            final label =
                                                '${fmt(sStart)}  →  ${fmt(sEnd)}';
                                            final mins = sEnd
                                                .difference(sStart)
                                                .inMinutes;
                                            final dur = mins >= 60
                                                ? '${mins ~/ 60}h${mins % 60 > 0 ? ' ${mins % 60}m' : ''}'
                                                : '${mins}m';
                                            return GestureDetector(
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                try {
                                                  print(
                                                    '🕐 Trying slot: $sStart → $sEnd',
                                                  );
                                                  print(
                                                    '🕐 Existing items on that day:',
                                                  );
                                                  for (final item in allItems) {
                                                    print(
                                                      '   ${item.title}: ${item.start} → ${item.end}',
                                                    );
                                                  }
                                                  await agendaService.create(
                                                    AgendaItem(
                                                      id: 0,
                                                      title: place.item.name,
                                                      start: sStart,
                                                      end: sEnd,
                                                      placeId: null,
                                                      landmarkId: place.item.id,
                                                      notes: null,
                                                    ),
                                                  );
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: const [
                                                          Icon(
                                                            Icons.check_circle,
                                                            color: Colors.white,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Added to agenda',
                                                          ),
                                                        ],
                                                      ),
                                                      backgroundColor:
                                                          const Color(
                                                            0xFF1A3C3C,
                                                          ),
                                                      behavior: SnackBarBehavior
                                                          .floating,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                      ),
                                                      margin:
                                                          const EdgeInsets.all(
                                                            16,
                                                          ),
                                                    ),
                                                  );
                                                } catch (_) {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Still conflicts. Try another slot.',
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF7F1E6,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF1A3C3C,
                                                    ).withOpacity(0.08),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF1A3C3C,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: const Icon(
                                                        Icons.access_time,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            label,
                                                            style: sans
                                                                .copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                          Text(
                                                            '$dur free',
                                                            style: sans.copyWith(
                                                              fontSize: 11,
                                                              color:
                                                                  const Color(
                                                                    0xFF1A3C3C,
                                                                  ).withOpacity(
                                                                    0.45,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .chevron_right_rounded,
                                                      color: Color(0xFFC5A059),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 56,
                    decoration: BoxDecoration(
                      color: (start == null || end == null)
                          ? const Color(0xFF1A3C3C).withOpacity(0.30)
                          : const Color(0xFF1A3C3C),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: (start != null && end != null)
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF1A3C3C,
                                ).withOpacity(0.28),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ADD TO AGENDA',
                            style: sans.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFFC5A059),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _places.where((p) => p.visible).toList();

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error
                  ? _buildError()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CompassBanner(
                            places: _places.where((p) => p.visible).toList(),
                            userLat: _userLat,
                            userLng: _userLng,
                          ),
                          const SizedBox(height: 16),
                          _AINote(),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 260,
                            child: visible.isEmpty
                                ? _EmptyState()
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    itemCount: visible.length,
                                    itemBuilder: (_, i) {
                                      final p = visible[i];
                                      return GestureDetector(
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                RecommendationDetailsPage(
                                                  item: p.item,
                                                ),
                                          ),
                                        ),
                                        child: _PlaceCard(
                                          place: p,
                                          rank: i + 1,
                                          onLike: () => _onLike(p),
                                          onDislike: () => _onDislike(p),
                                          onAdd: () => _onAddToSchedule(p),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _C.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_left, color: _C.dark, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Daily Plan',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _C.dark,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'TOP 10 IDEAS FOR TODAY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: _C.bronze,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: _C.dark.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load recommendations',
            style: TextStyle(color: _C.dark.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRecommendations,
            style: ElevatedButton.styleFrom(backgroundColor: _C.dark),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  COMPASS BANNER
// ─────────────────────────────────────────────
class _CompassBanner extends StatelessWidget {
  final List<_Place> places;
  final double userLat;
  final double userLng;
  const _CompassBanner({
    required this.places,
    this.userLat = 30.0444,
    this.userLng = 31.2357,
  });

  double _bearing(double lat2, double lng2) {
    final dLng = (lng2 - userLng) * (math.pi / 180);
    final lat1 = userLat * (math.pi / 180);
    final la2 = lat2 * (math.pi / 180);
    final y = math.sin(dLng) * math.cos(la2);
    final x =
        math.cos(lat1) * math.sin(la2) -
        math.sin(lat1) * math.cos(la2) * math.cos(dLng);
    return math.atan2(y, x) * (180 / math.pi);
  }

  @override
  Widget build(BuildContext context) {
    // top recommendation bearing for needle
    double needleBearing = 45.0;
    if (places.isNotEmpty) {
      final top = places.first;
      final lat = top.item.latitude;
      final lng = top.item.longitude;
      if (lat != null && lng != null) needleBearing = _bearing(lat, lng);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      height: 200,
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.gold.withOpacity(0.2)),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final cx = constraints.maxWidth / 2;
          final cy = constraints.maxHeight / 2;
          // radius where dots are placed — slightly inside the compass circle
          final dotRadius = math.min(cx, cy) * 0.72;

          final dots = <Widget>[];
          final visible = places.where((p) => p.visible).take(4).toList();

          for (int i = 0; i < visible.length; i++) {
            final lat = visible[i].item.latitude;
            final lng = visible[i].item.longitude;
            if (lat == null || lng == null) continue;

            final b = _bearing(lat, lng);
            // canvas: 0° = east, bearing: 0° = north → subtract 90°
            final angle = (b - 90) * (math.pi / 180);
            final dx = cx + dotRadius * math.cos(angle);
            final dy = cy + dotRadius * math.sin(angle);

            dots.add(
              Positioned(
                left: dx - 11, // center the 22px dot
                top: dy - 11,
                child: _MapDot(number: i + 1, active: i == 0),
              ),
            );
          }

          return Stack(
            children: [
              Center(child: _CompassIllustration(bearing: needleBearing)),
              ...dots,
            ],
          );
        },
      ),
    );
  }
}

class _CompassIllustration extends StatelessWidget {
  final double bearing;
  const _CompassIllustration({this.bearing = 45.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.25,
      child: CustomPaint(
        size: const Size(280, 180),
        painter: _CompassPainter(bearing: bearing),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double bearing;
  const _CompassPainter({this.bearing = 45.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A3C3C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.height * 0.45;

    canvas.drawCircle(Offset(cx, cy), r, paint);
    canvas.drawLine(Offset(cx - r * 1.6, cy), Offset(cx + r * 1.6, cy), paint);
    canvas.drawLine(Offset(cx, cy - r * 1.1), Offset(cx, cy + r * 1.1), paint);

    final diamondPaint = Paint()
      ..color = const Color(0xFFC5A059).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final d = r * 1.3;
    final path = Path()
      ..moveTo(cx - d, cy)
      ..lineTo(cx, cy - d * 0.7)
      ..lineTo(cx + d, cy)
      ..lineTo(cx, cy + d * 0.7)
      ..close();
    canvas.drawPath(path, diamondPaint);

    final needlePaint = Paint()
      ..color = const Color(0xFF1A3C3C)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // convert bearing to canvas angle (0° = north = up = -π/2)
    final angle = (bearing - 90) * (3.14159265 / 180);
    final nx = cx + r * 0.7 * math.cos(angle);
    final ny = cy + r * 0.7 * math.sin(angle);

    canvas.drawLine(Offset(cx, cy), Offset(nx, ny), needlePaint);
    // tail in opposite direction
    final tx = cx - r * 0.3 * math.cos(angle);
    final ty = cy - r * 0.3 * math.sin(angle);
    canvas.drawLine(
      Offset(cx, cy),
      Offset(tx, ty),
      Paint()
        ..color = const Color(0xFFC5A059)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      Paint()..color = const Color(0xFF1A3C3C),
    );

    _drawText(
      canvas,
      'W',
      Offset(cx - r - 18, cy - 8),
      const TextStyle(
        color: Color(0xFF1A3C3C),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
    _drawText(
      canvas,
      'E',
      Offset(cx + r + 6, cy - 8),
      const TextStyle(
        color: Color(0xFF1A3C3C),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.bearing != bearing;
}

class _MapDot extends StatelessWidget {
  final int number;
  final bool active;
  const _MapDot({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: active ? _C.gold : _C.dark,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AI NOTE BANNER
// ─────────────────────────────────────────────
class _AINote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(16),
        border: const Border(left: BorderSide(color: _C.gold, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI-Personalized Journey',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: _C.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your liked choices help our AI engine tailor destinations that match your pace, interests, and the unique Egyptian heritage.',
            style: TextStyle(fontSize: 11, color: _C.dark.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PLACE CARD
// ─────────────────────────────────────────────
class _PlaceCard extends StatelessWidget {
  final _Place place;
  final int rank;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onAdd;

  const _PlaceCard({
    required this.place,
    required this.rank,
    required this.onLike,
    required this.onDislike,
    required this.onAdd,
  });

  @override
  Widget _categoryPlaceholder(String category) {
    return Container(
      width: double.infinity,
      height: 140,
      color: _C.dark.withOpacity(0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 36,
            color: _C.dark.withOpacity(0.25),
          ),
          const SizedBox(height: 4),
          Text(
            category,
            style: TextStyle(
              fontSize: 9,
              color: _C.dark.withOpacity(0.4),
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget build(BuildContext context) {
    final item = place.item;

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── image area
          Stack(
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: _C.dark.withOpacity(0.12),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: item.photoUrls.isNotEmpty
                      ? Image.network(
                          item.photoUrls.first,
                          width: double.infinity,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _categoryPlaceholder(item.category),
                        )
                      : _categoryPlaceholder(item.category),
                ),
              ),
              // rank badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _C.dark,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              // rating badge
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _C.cream,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 10, color: _C.gold),
                      const SizedBox(width: 2),
                      Text(
                        (item.rating ?? 0).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _C.dark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // budget badge
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _C.dark.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    item.budget.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── info + actions
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _C.dark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _C.bronze,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      // like
                      _ActionIcon(
                        icon: place.liked
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        color: place.liked ? _C.gold : _C.dark.withOpacity(0.4),
                        onTap: place.liked ? null : onLike,
                      ),
                      const SizedBox(width: 8),
                      // dislike (only if not liked)
                      if (!place.liked)
                        _ActionIcon(
                          icon: Icons.thumb_down_outlined,
                          color: _C.dark.withOpacity(0.4),
                          onTap: onDislike,
                        ),
                      const Spacer(),
                      // add to agenda
                      _ActionIcon(
                        icon: Icons.calendar_month_outlined,
                        color: _C.dark.withOpacity(0.5),
                        onTap: onAdd,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ActionIcon({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_off_outlined,
            size: 48,
            color: _C.dark.withOpacity(0.2),
          ),
          const SizedBox(height: 8),
          Text(
            'All places removed',
            style: TextStyle(color: _C.dark.withOpacity(0.4), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
