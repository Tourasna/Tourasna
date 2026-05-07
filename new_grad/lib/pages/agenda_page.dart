import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/agenda_item.dart';
import '../services/agenda_service.dart';
import '../services/auth_service.dart';

class AgendaPage extends StatefulWidget {
  final DateTime? initialDate;
  final String? prefilledTitle;
  const AgendaPage({super.key, this.initialDate, this.prefilledTitle});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final AgendaService agendaService = AgendaService();

  late DateTime _focusedDay;
  late DateTime _selectedDay;

  final Color actionColor = const Color(0xFFAC975D);

  final List<Map<String, dynamic>> _events = [];
  bool loading = false;

  bool _handledIncomingPlace = false;

  final List<String> _timeSlots = List.generate(48, (i) {
    final h = i ~/ 2;
    final m = i % 2 == 0 ? '00' : '30';
    final p = h < 12 ? 'AM' : 'PM';
    final dh = h == 0
        ? 12
        : h > 12
        ? h - 12
        : h;
    return '$dh:$m $p';
  });

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = widget.initialDate ?? DateTime.now();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final token = await AuthService().getValidToken();
      if (!mounted) return;
      if (token != null) {
        await _loadAgendaForDay(_selectedDay);
        // ← Auto-open dialog if a title was passed
        if (widget.prefilledTitle != null) {
          _eventDialog(prefilledTitle: widget.prefilledTitle);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_handledIncomingPlace) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args != null && args['name'] != null) {
      _handledIncomingPlace = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _eventDialog(
          prefilledTitle: args['name'],
          placeId: args['placeId'], // ← placeId from search
        );
      });
    }
  }

  void _editEventDialog(Map<String, dynamic> event) {
    final titleController = TextEditingController(text: event['title']);
    String? start;
    String? end;

    final currentStart = DateFormat(
      'h:mm a',
    ).format(event['start'] as DateTime);
    final currentEnd = DateFormat('h:mm a').format(event['end'] as DateTime);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setD) => AlertDialog(
          title: const Text('Edit Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _timeSlots.contains(currentStart) ? currentStart : null,
                hint: Text('Start: $currentStart'),
                items: _timeSlots
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setD(() => start = v),
              ),
              DropdownButtonFormField<String>(
                value: _timeSlots.contains(currentEnd) ? currentEnd : null,
                hint: Text('End: $currentEnd'),
                items: _timeSlots
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setD(() => end = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAC975D),
              ),
              onPressed: () async {
                final newStart = start != null
                    ? _combine(_selectedDay, start!)
                    : event['start'] as DateTime;
                final newEnd = end != null
                    ? _combine(_selectedDay, end!)
                    : event['end'] as DateTime;

                if (!newEnd.isAfter(newStart)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  await agendaService.update(
                    AgendaItem(
                      id: event['id'],
                      title: titleController.text,
                      start: newStart,
                      end: newEnd,
                      placeId: event['placeId'],
                      notes: null,
                    ),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadAgendaForDay(_selectedDay);
                } catch (e) {
                  if (!mounted) return;

                  // ── Check if it's a conflict error ──────────
                  final isConflict =
                      e.toString().toLowerCase().contains('overlap') ||
                      e.toString().toLowerCase().contains('conflict') ||
                      e.toString().contains('409');

                  if (isConflict) {
                    Navigator.pop(context); // close edit dialog first
                    await _showFreeTimeSlotsDialog(
                      eventId: event['id'],
                      title: titleController.text,
                      placeId: event['placeId'],
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
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── FREE TIME SLOTS DIALOG ───────────────────────────────────────
  Future<void> _showFreeTimeSlotsDialog({
    required int eventId,
    required String title,
    String? placeId,
  }) async {
    // Load all events for this day
    final allItems = await agendaService.fetch(
      from: _selectedDay,
      to: _selectedDay.add(const Duration(days: 1)),
    );

    // Filter out the event being edited
    final otherItems = allItems.where((e) => e.id != eventId).toList();

    // Calculate free 2-hour slots between 7AM and 10PM
    final freeSlots = _calculateFreeSlots(otherItems);

    if (!mounted) return;

    if (freeSlots.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.event_busy, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Day is Full'),
            ],
          ),
          content: const Text(
            'There are no free time slots available on this day.\n\nTry a different day or remove an existing event first.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A3C3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.schedule, color: Color(0xFFAC975D), size: 26),
                SizedBox(width: 10),
                Text(
                  'Time Conflict',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFAC975D), width: 1),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Color(0xFFAC975D), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'That slot is taken. Pick a free time below.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'AVAILABLE SLOTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Colors.black45,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: freeSlots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final slot = freeSlots[i];
                    final slotStart = slot['start'] as DateTime;
                    final slotEnd = slot['end'] as DateTime;
                    final label =
                        '${DateFormat('h:mm a').format(slotStart)}  →  ${DateFormat('h:mm a').format(slotEnd)}';
                    final duration = slotEnd.difference(slotStart).inMinutes;
                    final durationLabel = duration >= 60
                        ? '${duration ~/ 60}h${duration % 60 > 0 ? ' ${duration % 60}m' : ''}'
                        : '${duration}m';

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        Navigator.pop(context);
                        await _applyFreeSlot(
                          eventId: eventId,
                          title: title,
                          placeId: placeId,
                          newStart: slotStart,
                          newEnd: slotEnd,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2E8D5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF1A3C3C).withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A3C3C),
                                borderRadius: BorderRadius.circular(10),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF1A3C3C),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$durationLabel free',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFAC975D),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  // ── CALCULATE FREE 2-HOUR SLOTS BETWEEN 7AM AND 10PM ─────────────
  List<Map<String, DateTime>> _calculateFreeSlots(List<AgendaItem> busyItems) {
    final dayStart = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      7,
      0,
    );
    final dayEnd = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      22,
      0,
    );

    // Sort busy items by start time
    busyItems.sort((a, b) => a.start.compareTo(b.start));

    final freeSlots = <Map<String, DateTime>>[];
    DateTime cursor = dayStart;

    for (final item in busyItems) {
      final busyStart = item.start;
      final busyEnd = item.end;

      // Gap before this busy item
      if (cursor.isBefore(busyStart)) {
        final gapMinutes = busyStart.difference(cursor).inMinutes;
        if (gapMinutes >= 60) {
          // Offer slots in 2-hour blocks within the gap
          DateTime slotCursor = cursor;
          while (slotCursor.add(const Duration(hours: 2)).isBefore(busyStart) ||
              slotCursor.add(const Duration(hours: 2)) == busyStart) {
            freeSlots.add({
              'start': slotCursor,
              'end': slotCursor.add(const Duration(hours: 2)),
            });
            slotCursor = slotCursor.add(const Duration(hours: 1));
            if (freeSlots.length >= 8) break; // max 8 suggestions
          }
        }
      }

      if (busyEnd.isAfter(cursor)) cursor = busyEnd;
    }

    // Gap after last busy item until end of day
    if (cursor.isBefore(dayEnd)) {
      DateTime slotCursor = cursor;
      while (slotCursor.add(const Duration(hours: 2)).isBefore(dayEnd) ||
          slotCursor.add(const Duration(hours: 2)) == dayEnd) {
        freeSlots.add({
          'start': slotCursor,
          'end': slotCursor.add(const Duration(hours: 2)),
        });
        slotCursor = slotCursor.add(const Duration(hours: 1));
        if (freeSlots.length >= 8) break;
      }
    }

    return freeSlots;
  }

  // ── APPLY THE CHOSEN FREE SLOT ────────────────────────────────────
  Future<void> _applyFreeSlot({
    required int eventId,
    required String title,
    String? placeId,
    required DateTime newStart,
    required DateTime newEnd,
  }) async {
    try {
      await agendaService.update(
        AgendaItem(
          id: eventId,
          title: title,
          start: newStart,
          end: newEnd,
          placeId: placeId,
          notes: null,
        ),
      );
      await _loadAgendaForDay(_selectedDay);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Event rescheduled successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF1A3C3C),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reschedule: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    // Confirm before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Event'),
        content: Text('Remove "${event['title']}" from your agenda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await agendaService.delete(event['id']);
      await _loadAgendaForDay(_selectedDay);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }
  // ───────────────── LOAD AGENDA ─────────────────

  Future<void> _loadAgendaForDay(DateTime day) async {
    setState(() => loading = true);

    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));

    final items = await agendaService.fetch(from: from, to: to);

    _events
      ..clear()
      ..addAll(
        items.map(
          (e) => {
            'id': e.id,
            'title': e.title,
            'start': e.start,
            'end': e.end,
            'time':
                '${DateFormat('hh:mm a').format(e.start)} - ${DateFormat('hh:mm a').format(e.end)}',
            'open': false,
            'placeId': e.placeId, // ← IMPORTANT: placeId stored here
          },
        ),
      );

    setState(() => loading = false);
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    final todayNum = DateFormat('d').format(_selectedDay);
    final todayText = DateFormat('EEEE').format(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFF5E5D1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5E5D1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // ← NEW: Updated FloatingActionButton with two buttons
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ NEW: View on Map button (only shown if events have placeIds)
          if (_events.isNotEmpty && _events.any((e) => e['placeId'] != null))
            FloatingActionButton.extended(
              heroTag: 'view_map',
              backgroundColor: const Color(0xFF2F6A6E), // Teal color
              onPressed: () {
                // Collect placeIds from events
                final placeIds = _events
                    .where((e) => e['placeId'] != null)
                    .map((e) => e['placeId'] as String)
                    .toList();

                if (placeIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.white),
                          SizedBox(width: 12),
                          Text('No places with location data found'),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                print("🗺️ Navigating to map with ${placeIds.length} places");

                // ✅ Navigate to InteractiveMapScreen with placeIds
                Navigator.pushNamed(
                  context,
                  '/interactive_map',
                  arguments: {'placeIds': placeIds},
                );
              },
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text(
                'View on Map',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ✅ Original Add Event button (unchanged)
          FloatingActionButton(
            heroTag: 'add_event',
            backgroundColor: actionColor,
            onPressed: _showAddEventDialog,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      body: Column(
        children: [
          _calendar(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  todayNum,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    todayText,
                    style: const TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (_, i) => _buildEventCard(i),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(context),
    );
  }

  // ───────────────── CALENDAR ─────────────────

  Widget _calendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/calendar_wallpaper.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E5D1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Icon(Icons.calendar_today),
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMMM yyyy').format(_focusedDay),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2100),
                  headerVisible: false,
                  selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                  onDaySelected: (s, f) async {
                    setState(() {
                      _selectedDay = s;
                      _focusedDay = f;
                    });

                    final token = await AuthService().getValidToken();
                    if (!mounted) return;

                    if (token != null) {
                      await _loadAgendaForDay(s);
                    } else {
                      debugPrint(
                        '⚠️ Calendar tap ignored: user not authenticated yet',
                      );
                    }
                  },

                  calendarStyle: CalendarStyle(
                    todayDecoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: actionColor,
                      shape: BoxShape.circle,
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

  // ───────────────── EVENT CARD ─────────────────

  Widget _buildEventCard(int index) {
    final event = _events[index];
    final bool open = event['open'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Container(
            height: 80,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E5D1),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['time'],
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(open ? Icons.expand_less : Icons.more_vert),
                  onPressed: () {
                    setState(() => event['open'] = !open);
                  },
                ),
              ],
            ),
          ),

          // ── Action buttons (edit / delete) ──────────────
          if (open)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Edit
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => event['open'] = false);
                        _editEventDialog(event);
                      },
                      icon: const Icon(Icons.edit, color: Color(0xFFAC975D)),
                      label: const Text(
                        'Edit Time',
                        style: TextStyle(color: Color(0xFFAC975D)),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.black12),
                  // Delete
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        setState(() => event['open'] = false);
                        await _deleteEvent(event);
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Remove',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ───────────────── ADD / EDIT ─────────────────

  void _showAddEventDialog() {
    _eventDialog();
  }

  void _eventDialog({
    String? prefilledTitle,
    String? placeId, // ← NEW: Accept placeId parameter
  }) {
    final title = TextEditingController(text: prefilledTitle);
    String? start;
    String? end;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setD) => AlertDialog(
          title: const Text('Add Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField(
                hint: const Text('Start Time'),
                items: _timeSlots
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setD(() => start = v),
              ),
              DropdownButtonFormField(
                hint: const Text('End Time'),
                items: _timeSlots
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setD(() => end = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (start == null || end == null) return;

                try {
                  await agendaService.create(
                    AgendaItem(
                      id: 0,
                      title: title.text,
                      start: _combine(_selectedDay, start!),
                      end: _combine(_selectedDay, end!),
                      placeId: placeId, // ← IMPORTANT
                      notes: null,
                    ),
                  );

                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadAgendaForDay(_selectedDay);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _combine(DateTime day, String time) {
    final parts = time.split(RegExp(r'[: ]'));
    int h = int.parse(parts[0]);
    int m = int.parse(parts[1]);
    final isPm = parts[2] == 'PM';

    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;

    return DateTime(day.year, day.month, day.day, h, m);
  }

  // ───────────────── NAV BAR ─────────────────

  Widget _bottomNav(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      color: const Color(0xFFF5E5D1),
      height: 85,
      notchMargin: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(
              'assets/icons/explore.png',
              'Explore',
              () => Navigator.pushNamed(context, '/homescreen'),
            ),
            _navItem(
              'assets/icons/favs.png',
              'FAVs',
              () => Navigator.pushNamed(context, '/favs'),
            ),
            _navItem(
              'assets/icons/profile.png',
              'Profile',
              () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icon, width: 40),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
