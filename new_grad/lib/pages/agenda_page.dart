import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/agenda_item.dart';
import '../services/agenda_service.dart';
import '../services/auth_service.dart';

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final AgendaService agendaService = AgendaService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 🔐 Wait until Firebase auth is actually ready
      final token = await AuthService().getValidToken();

      if (!mounted) return;

      if (token != null) {
        await _loadAgendaForDay(_selectedDay);
      } else {
        debugPrint('⚠️ AgendaPage: user not authenticated yet');
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
      height: 80,
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: open ? 8 : 0),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        event['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event['time'],
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      setState(() {
                        event['open'] = !open;
                      });
                    },
                  ),
                ],
              ),
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
