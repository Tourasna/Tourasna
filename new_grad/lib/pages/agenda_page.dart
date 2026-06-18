import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/network_navigator.dart';
import '../models/agenda_item.dart';
import '../models/recommendation_item.dart';
import '../services/agenda_service.dart';
import '../services/auth_service.dart';
import '../services/landmark_service.dart';

class _C {
  static const papyrus = Color(0xFFF2EADC);
  static const teal = Color(0xFF1A3C3C);
  static const gold = Color(0xFFC5A059);
  static const surface = Color(0xFFEAE2D1);
  static const glass = Color(0x66FFFFFF);
  static const glassBorder = Color(0x33FFFFFF);
  static const cardBg = Color(0xCCFFFFFF);
}

enum _AgendaView { day, trip, month }

class AgendaPage extends StatefulWidget {
  final DateTime? initialDate;
  final String? prefilledTitle;
  const AgendaPage({super.key, this.initialDate, this.prefilledTitle});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final AgendaService agendaService = AgendaService();
  final Color darkColor = const Color(0xFF1A3C3C);
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  _AgendaView _view = _AgendaView.day;

  final DateTime _today = DateTime.now();

  final List<Map<String, dynamic>> _events = [];
  bool _loading = false;
  bool _handledIncomingPlace = false;

  final List<String> _timeSlots = List.generate(16, (i) {
    final h = i + 7;
    final dh = h > 12 ? h - 12 : h;
    final p = h < 12 ? 'AM' : 'PM';
    return '$dh:00 $p';
  });
  Widget _buildBlockedSlot() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _C.teal.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _C.teal.withValues(alpha: 0.06), width: 1),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_rounded,
              size: 13,
              color: _C.teal.withValues(alpha: 0.20),
            ),
            const SizedBox(width: 6),
            Text(
              'OCCUPIED',
              style: _sans.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: _C.teal.withValues(alpha: 0.20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editTimeDropdown({
    required String label,
    required String currentLabel,
    required String? value,
    required List<String> slots,
    required ValueChanged<String?> onChanged,
    String? startValue, // ← NEW: filters end slots
  }) {
    // filter end slots to only hours after start
    final filteredSlots = (label == 'END' && startValue != null)
        ? slots.where((t) {
            final startIdx = slots.indexOf(startValue);
            final thisIdx = slots.indexOf(t);
            return thisIdx > startIdx;
          }).toList()
        : slots;

    final displayed = value ?? currentLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _sans.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: _C.gold,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            int initialIndex = filteredSlots.indexOf(displayed);
            if (initialIndex < 0) initialIndex = 0;
            final ctrl = FixedExtentScrollController(initialItem: initialIndex);
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => Container(
                height: 300,
                decoration: const BoxDecoration(
                  color: _C.papyrus,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _C.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            label == 'START' ? 'Start Time' : 'End Time',
                            style: _serif.copyWith(fontSize: 18),
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
                                color: _C.teal,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Done',
                                style: _sans.copyWith(
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
                      child: filteredSlots.isEmpty
                          ? Center(
                              child: Text(
                                'No available end times',
                                style: _sans.copyWith(
                                  color: _C.teal.withValues(alpha: 0.40),
                                ),
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  height: 50,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _C.teal.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _C.gold.withValues(alpha: 0.30),
                                    ),
                                  ),
                                ),
                                ListWheelScrollView.useDelegate(
                                  controller: ctrl,
                                  itemExtent: 50,
                                  perspective: 0.003,
                                  diameterRatio: 2.2,
                                  physics: const FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: (i) =>
                                      onChanged(filteredSlots[i]),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: filteredSlots.length,
                                    builder: (_, i) {
                                      final sel = filteredSlots[i] == displayed;
                                      return Center(
                                        child: Text(
                                          filteredSlots[i],
                                          style: _sans.copyWith(
                                            fontSize: sel ? 18 : 15,
                                            fontWeight: sel
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: sel
                                                ? _C.teal
                                                : _C.teal.withValues(
                                                    alpha: 0.35,
                                                  ),
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
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: value != null
                  ? _C.teal.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value != null
                    ? _C.gold.withValues(alpha: 0.35)
                    : _C.teal.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: value != null
                      ? _C.gold
                      : _C.teal.withValues(alpha: 0.30),
                ),
                const SizedBox(width: 8),
                Expanded(
                  // ← fix
                  child: Text(
                    displayed,
                    style: _sans.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.teal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _C.teal.withValues(alpha: 0.30),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static const _slotHours = [
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
  ];
  static const _slotLabels = [
    '07:00',
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];
  static const _slotPeriods = [
    'AM',
    'AM',
    'AM',
    'AM',
    'AM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
    'PM',
  ];

  TextStyle get _serif => const TextStyle(
    fontFamily: 'Gambetta',
    fontWeight: FontWeight.w700,
    color: _C.teal,
  );
  TextStyle get _sans => const TextStyle(fontFamily: 'Satoshi', color: _C.teal);

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
        _eventDialog(prefilledTitle: args['name'], placeId: args['placeId']);
      });
    }
  }

  // ── load ──────────────────────────────────────
  Future<void> _loadAgendaForDay(DateTime day) async {
    setState(() => _loading = true);
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
                '${DateFormat('hh:mm a').format(e.start)} – '
                '${DateFormat('hh:mm a').format(e.end)}',
            'open': false,
            'placeId': e.placeId,
            'landmarkId': e.landmarkId,
            'latitude': e.latitude,
            'longitude': e.longitude,
          },
        ),
      );
    setState(() => _loading = false);
  }

  List<DateTime> _stripDays() =>
      List.generate(7, (i) => _selectedDay.subtract(Duration(days: 3 - i)));

  void _switchView(_AgendaView v) {
    setState(() => _view = v);
    if (v == _AgendaView.day) _loadAgendaForDay(_today);
  }

  // ── landmark picker sheet ─────────────────────
  Future<void> _openLandmarkPicker(int hour) async {
    final targetDay = _view == _AgendaView.day ? _today : _selectedDay;

    final dh = hour > 12 ? hour - 12 : hour;
    final p = hour < 12 ? 'AM' : 'PM';
    final prefilledStart = '$dh:00 $p';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LandmarkPickerSheet(
        serif: _serif,
        sans: _sans,
        timeSlots: _timeSlots,
        prefilledStart: prefilledStart,
        targetDay: targetDay,
        onConfirm: (landmark, start, end) async {
          try {
            await agendaService.create(
              AgendaItem(
                id: 0,
                title: landmark.name,
                start: _combine(targetDay, start),
                end: _combine(targetDay, end),
                placeId: null,
                landmarkId: landmark.id,
                notes: null,
              ),
            );
            if (!mounted) return;
            await _loadAgendaForDay(targetDay);
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
      ),
    );
  }

  // ── build ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.papyrus,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                    children: [
                      const SizedBox(height: 24),
                      _buildViewToggle(),
                      const SizedBox(height: 24),
                      if (_view == _AgendaView.day) ...[
                        _buildTodayHeader(),
                        const SizedBox(height: 24),
                        _buildTimeline(),
                      ] else if (_view == _AgendaView.trip) ...[
                        _buildDateStrip(),
                        const SizedBox(height: 32),
                        _buildTimeline(),
                      ] else ...[
                        _buildMonthCalendar(),
                        const SizedBox(height: 32),
                        _buildTimeline(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // ── only map FAB remains ──────────────
            if (_events.isNotEmpty &&
                _events.any(
                  (e) => e['landmarkId'] != null || e['placeId'] != null,
                ))
              Positioned(
                right: 20,
                bottom: 100,
                child: FloatingActionButton.extended(
                  heroTag: 'view_map',
                  backgroundColor: _C.teal,
                  onPressed: () {
                    final placeIds = _events
                        .where((e) => e['landmarkId'] != null)
                        .map((e) => e['landmarkId'].toString())
                        .toList();
                    navigateWithNetworkCheck(
                      context,
                      '/interactive_map',
                      arguments: {'placeIds': placeIds},
                    );
                  },
                  icon: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    'View on Map',
                    style: _sans.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── top bar ───────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _C.glass,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.glassBorder),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _C.teal,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text('My Agenda', style: _serif.copyWith(fontSize: 28)),
        ],
      ),
    );
  }

  // ── view toggle ───────────────────────────────
  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final segW = (constraints.maxWidth - 12) / 3;
          final idx = _AgendaView.values.indexOf(_view);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                left: idx * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: Container(
                  decoration: BoxDecoration(
                    color: _C.teal,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _C.teal.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _viewTab('Day', _AgendaView.day, segW),
                  _viewTab('Trip', _AgendaView.trip, segW),
                  _viewTab('Month', _AgendaView.month, segW),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _viewTab(String label, _AgendaView v, double w) {
    final active = _view == v;
    return GestureDetector(
      onTap: () => _switchView(v),
      child: SizedBox(
        width: w,
        height: 40,
        child: Center(
          child: Text(
            label,
            style: _sans.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? Colors.white : _C.teal,
            ),
          ),
        ),
      ),
    );
  }

  // ── today header ──────────────────────────────
  Widget _buildTodayHeader() {
    final dayName = DateFormat('EEEE').format(_today);
    final dayNum = DateFormat('d').format(_today);
    final month = DateFormat('MMMM yyyy').format(_today);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _C.teal,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _C.teal.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            dayNum,
            style: _serif.copyWith(
              fontSize: 52,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            // ← wrap this
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName.toUpperCase(),
                  style: _sans.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  month,
                  style: _sans.copyWith(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.60),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _C.gold.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.gold.withValues(alpha: 0.40)),
            ),
            child: Text(
              'TODAY',
              style: _sans.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _C.gold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── date strip ────────────────────────────────
  Widget _buildDateStrip() {
    final days = _stripDays();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final day = days[i];
          final active = isSameDay(day, _selectedDay);
          final dName = DateFormat('EEE').format(day).toUpperCase();
          final dNum = DateFormat('d').format(day);
          return GestureDetector(
            onTap: () async {
              setState(() {
                _selectedDay = day;
                _focusedDay = day;
              });
              final token = await AuthService().getValidToken();
              if (mounted && token != null) await _loadAgendaForDay(day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 60,
              decoration: BoxDecoration(
                color: active ? _C.teal : Colors.white.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: active
                      ? _C.teal
                      : Colors.white.withValues(alpha: 0.50),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: _C.teal.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dName,
                    style: _sans.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: active
                          ? Colors.white.withValues(alpha: 0.70)
                          : _C.teal.withValues(alpha: 0.40),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dNum,
                    style: _sans.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : _C.teal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── month calendar ────────────────────────────
  Widget _buildMonthCalendar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.glass,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.glassBorder),
      ),
      child: TableCalendar(
        focusedDay: _focusedDay,
        firstDay: DateTime(2000),
        lastDay: DateTime(2100),
        selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
        onDaySelected: (s, f) async {
          setState(() {
            _selectedDay = s;
            _focusedDay = f;
          });
          final token = await AuthService().getValidToken();
          if (mounted && token != null) await _loadAgendaForDay(s);
        },
        calendarStyle: CalendarStyle(
          todayDecoration: const BoxDecoration(
            color: _C.teal,
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: _C.gold,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          titleTextStyle: _serif.copyWith(fontSize: 16),
          formatButtonVisible: false,
          titleCentered: true,
        ),
      ),
    );
  }

  // ── timeline ──────────────────────────────────
  Widget _buildTimeline() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(color: _C.gold)),
      );
    }

    // ── map events to their start slot ────────────
    final Map<int, Map<String, dynamic>> slottedEvents = {};
    final Set<int> coveredHours = {};

    for (final event in _events) {
      final start = event['start'] as DateTime;
      final end = event['end'] as DateTime;

      slottedEvents[start.hour] = event;

      // hours strictly inside the range are hidden (absorbed into the card)
      for (final h in _slotHours) {
        if (h > start.hour && h < end.hour) {
          coveredHours.add(h);
        }
      }
    }

    return Stack(
      children: [
        // vertical decorative line
        Positioned(
          left: 42,
          top: 16,
          bottom: 16,
          child: Container(width: 1, color: _C.teal.withValues(alpha: 0.10)),
        ),
        Column(
          children: () {
            final List<Widget> rows = [];

            for (int i = 0; i < _slotHours.length; i++) {
              final hour = _slotHours[i];
              final label = _slotLabels[i];
              final period = _slotPeriods[i];

              // skip hours absorbed into a spanning card
              if (coveredHours.contains(hour)) continue;

              final event = slottedEvents[hour];

              // calculate how many slots this event spans
              int spanCount = 1;
              if (event != null) {
                final end = event['end'] as DateTime;
                for (int j = i + 1; j < _slotHours.length; j++) {
                  if (_slotHours[j] < end.hour) {
                    spanCount++;
                  } else {
                    break;
                  }
                }
              }

              // card height = spanCount slots + gaps between them
              const double slotHeight = 56; // empty slot height
              const double cardPadding = 20; // bottom padding per slot
              final double cardHeight = event != null
                  ? (spanCount * slotHeight) +
                        ((spanCount - 1) * cardPadding) +
                        (spanCount > 1 ? (spanCount - 1) * 0 : 0)
                  : slotHeight;

              rows.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // time label
                      SizedBox(
                        width: 48,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const SizedBox(height: 18),
                            Text(
                              label,
                              style: _sans.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: event != null
                                    ? _C.teal
                                    : _C.teal.withValues(alpha: 0.35),
                              ),
                            ),
                            Text(
                              period,
                              style: _sans.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: event != null
                                    ? _C.teal.withValues(alpha: 0.45)
                                    : _C.teal.withValues(alpha: 0.18),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // card or empty slot
                      Expanded(
                        child: event != null
                            ? _buildSpanningEventCard(event, cardHeight)
                            : _buildEmptySlot(hour),
                      ),
                    ],
                  ),
                ),
              );
            }

            return rows;
          }(),
        ),
      ],
    );
  }

  // ── event card ────────────────────────────────
  Widget _buildSpanningEventCard(Map<String, dynamic> event, double height) {
    final open = event['open'] == true;

    // format duration label e.g. "09:00 AM – 11:00 AM"
    final startFmt = DateFormat('hh:mm a').format(event['start'] as DateTime);
    final endFmt = DateFormat('hh:mm a').format(event['end'] as DateTime);
    final duration = (event['end'] as DateTime).difference(
      event['start'] as DateTime,
    );
    final durationLabel = duration.inMinutes >= 60
        ? '${duration.inHours}h${duration.inMinutes % 60 > 0 ? ' ${duration.inMinutes % 60}m' : ''}'
        : '${duration.inMinutes}m';

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => event['open'] = !open),
          onLongPress: () => _editEventDialog(event),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: height,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _C.cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _C.gold.withValues(alpha: 0.20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // title
                Text(
                  event['title'],
                  style: _serif.copyWith(fontSize: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // time range
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: _C.gold,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$startFmt – $endFmt',
                      style: _sans.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _C.teal.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // duration badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _C.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.gold.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    durationLabel,
                    style: _sans.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _C.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.teal.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() => event['open'] = false);
                      _editEventDialog(event);
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: _C.gold,
                      size: 16,
                    ),
                    label: Text(
                      'Edit',
                      style: _sans.copyWith(
                        color: _C.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: _C.teal.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      setState(() => event['open'] = false);
                      await _deleteEvent(event);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    label: Text(
                      'Remove',
                      style: _sans.copyWith(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── empty slot → opens landmark picker ────────
  Widget _buildEmptySlot(int hour) {
    return GestureDetector(
      onTap: () => _openLandmarkPicker(hour),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _C.gold.withValues(alpha: 0.22),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_circle_outline_rounded,
            color: _C.gold.withValues(alpha: 0.40),
            size: 24,
          ),
        ),
      ),
    );
  }

  // ── bottom nav ────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: _C.papyrus,
        border: Border(top: BorderSide(color: _C.teal.withValues(alpha: 0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildNavItem(
                  iconPath: 'assets/icons/explore.png',
                  label: 'Explore',
                  onPressed: () =>
                      navigateWithNetworkCheck(context, '/homescreen'),
                ),
                const SizedBox(width: 28),
                _buildNavItem(
                  iconPath: 'assets/icons/favs.png',
                  label: 'FAVs',
                  onPressed: () => navigateWithNetworkCheck(context, '/favs'),
                ),
              ],
            ),
            Row(
              children: [
                _buildNavItem(
                  iconPath: 'assets/icons/agenda.png',
                  label: 'Agenda',
                  isActive: true,
                  onPressed: () => navigateWithNetworkCheck(context, '/agenda'),
                ),
                const SizedBox(width: 28),
                _buildNavItem(
                  iconPath: 'assets/images/Discovery-3.png',
                  label: 'Discovery',
                  onPressed: () =>
                      navigateWithNetworkCheck(context, '/discovery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required String iconPath,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 62,
            height: 40, // ← reduced from 46
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? darkColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              iconPath,
              width: 38, // ← reduced from 42
              height: 38,
              fit: BoxFit.contain,
              color: isActive ? Colors.white : null,
              colorBlendMode: isActive ? BlendMode.srcIn : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isActive ? darkColor : const Color(0xFF1F1F1F),
              fontSize: 11, // ← reduced from 12.5
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── existing logic (unchanged) ─────────────────

  void _editEventDialog(Map<String, dynamic> event) {
    String? start;
    String? end;
    final currentStart = DateFormat(
      'h:mm a',
    ).format(event['start'] as DateTime);
    final currentEnd = DateFormat('h:mm a').format(event['end'] as DateTime);

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setD) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _C.papyrus,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: _C.gold.withValues(alpha: 0.20)),
              boxShadow: [
                BoxShadow(
                  color: _C.teal.withValues(alpha: 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── header ──────────────────────────
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _C.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _C.gold.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: _C.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Edit Time', style: _serif.copyWith(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 20),

                // ── landmark (read-only) ─────────────
                Text(
                  'LANDMARK',
                  style: _sans.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: _C.gold,
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
                    color: _C.teal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.teal.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: _C.gold,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['title'],
                          style: _sans.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _C.teal.withValues(alpha: 0.65),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // hint
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Icon(
                      Icons.info_outline_rounded,
                      size: 11,
                      color: _C.teal.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'To change the landmark, remove and re-add',
                        style: _sans.copyWith(
                          fontSize: 9,
                          color: _C.teal.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── time pickers ─────────────────────
                Text(
                  'RESCHEDULE',
                  style: _sans.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: _C.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _editTimeDropdown(
                        label: 'START',
                        currentLabel: currentStart,
                        value: start,
                        slots: _timeSlots,
                        onChanged: (v) => setD(() {
                          start = v;
                          // clear end if it's now invalid
                          if (end != null) {
                            final startIdx = _timeSlots.indexOf(v!);
                            final endIdx = _timeSlots.indexOf(end!);
                            if (endIdx <= startIdx) setD(() => end = null);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _editTimeDropdown(
                        label: 'END',
                        currentLabel: currentEnd,
                        value: end,
                        slots: _timeSlots,
                        startValue:
                            start ?? currentStart, // ← pass start for filtering
                        onChanged: (v) => setD(() => end = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── buttons ──────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _C.teal.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: _sans.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final newStart = start != null
                              ? _combine(_selectedDay, start!)
                              : event['start'] as DateTime;
                          final newEnd = end != null
                              ? _combine(_selectedDay, end!)
                              : event['end'] as DateTime;
                          if (!newEnd.isAfter(newStart)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('End time must be after start'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          try {
                            await agendaService.update(
                              AgendaItem(
                                id: event['id'],
                                title: event['title'],
                                start: newStart,
                                end: newEnd,
                                placeId: event['placeId'],
                                landmarkId: event['landmarkId'], // ← add
                                notes: null,
                              ),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            await _loadAgendaForDay(_selectedDay);
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
                              await _showFreeTimeSlotsDialog(
                                eventId: event['id'],
                                title: event['title'],
                                placeId: event['placeId'],
                                landmarkId: event['landmarkId'],
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
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: _C.teal,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _C.teal.withValues(alpha: 0.28),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Save',
                              style: _sans.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _C.papyrus,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: _C.gold.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: _C.teal.withValues(alpha: 0.12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.20)),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text('Remove Event', style: _serif.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'Remove "${event['title']}" from your agenda?',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _sans.copyWith(
                  fontSize: 13,
                  color: _C.teal.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _C.teal.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: _sans.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // confirm remove
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Remove',
                            style: _sans.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Future<void> _showFreeTimeSlotsDialog({
    required int eventId,
    required String title,
    String? placeId,
    int? landmarkId,
  }) async {
    final allItems = await agendaService.fetch(
      from: _selectedDay,
      to: _selectedDay.add(const Duration(days: 1)),
    );
    final otherItems = allItems.where((e) => e.id != eventId).toList();
    final freeSlots = _calculateFreeSlots(otherItems);
    if (!mounted) return;

    if (freeSlots.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Day is Full'),
          content: const Text(
            'No free time slots available. Try a different day.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _C.teal),
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
        title: Text('Time Conflict', style: _serif.copyWith(fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AVAILABLE SLOTS',
                style: _sans.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: _C.teal.withValues(alpha: 0.40),
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
                    final sStart = slot['start'] as DateTime;
                    final sEnd = slot['end'] as DateTime;
                    final label =
                        '${DateFormat('h:mm a').format(sStart)}  →  '
                        '${DateFormat('h:mm a').format(sEnd)}';
                    final mins = sEnd.difference(sStart).inMinutes;
                    final dur = mins >= 60
                        ? '${mins ~/ 60}h${mins % 60 > 0 ? ' ${mins % 60}m' : ''}'
                        : '${mins}m';
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        Navigator.pop(context);
                        await _applyFreeSlot(
                          eventId: eventId,
                          title: title,
                          placeId: placeId,
                          landmarkId: landmarkId,
                          newStart: sStart,
                          newEnd: sEnd,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _C.papyrus,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _C.teal.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _C.teal,
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
                                    style: _sans.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '$dur free',
                                    style: _sans.copyWith(
                                      fontSize: 11,
                                      color: _C.teal.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _C.gold,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

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
    busyItems.sort((a, b) => a.start.compareTo(b.start));
    final freeSlots = <Map<String, DateTime>>[];
    DateTime cursor = dayStart;
    for (final item in busyItems) {
      if (cursor.isBefore(item.start)) {
        DateTime sc = cursor;
        while (!sc.add(const Duration(hours: 2)).isAfter(item.start)) {
          freeSlots.add({'start': sc, 'end': sc.add(const Duration(hours: 2))});
          sc = sc.add(const Duration(hours: 1));
          if (freeSlots.length >= 8) break;
        }
      }
      if (item.end.isAfter(cursor)) cursor = item.end;
    }
    DateTime sc = cursor;
    while (!sc.add(const Duration(hours: 2)).isAfter(dayEnd)) {
      freeSlots.add({'start': sc, 'end': sc.add(const Duration(hours: 2))});
      sc = sc.add(const Duration(hours: 1));
      if (freeSlots.length >= 8) break;
    }
    return freeSlots;
  }

  Future<void> _applyFreeSlot({
    required int eventId,
    required String title,
    String? placeId,
    int? landmarkId,
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
          landmarkId: landmarkId,
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
          backgroundColor: _C.teal,
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

  // kept for prefilledTitle path (from recommendations / map args)
  void _eventDialog({
    String? prefilledTitle,
    String? placeId,
    int? prefilledHour,
  }) {
    final title = TextEditingController(text: prefilledTitle);
    String? start;
    if (prefilledHour != null) {
      final dh = prefilledHour == 0
          ? 12
          : prefilledHour > 12
          ? prefilledHour - 12
          : prefilledHour;
      final p = prefilledHour < 12 ? 'AM' : 'PM';
      final candidate = '$dh:00 $p';
      if (_timeSlots.contains(candidate)) start = candidate;
    }
    String? end;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text('Add Event', style: _serif.copyWith(fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: start,
                hint: const Text('Start Time'),
                items: _timeSlots
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setD(() => start = v),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: end,
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
              style: ElevatedButton.styleFrom(backgroundColor: _C.gold),
              onPressed: () async {
                if (start == null || end == null) return;
                final targetDay = _view == _AgendaView.day
                    ? _today
                    : _selectedDay;
                try {
                  await agendaService.create(
                    AgendaItem(
                      id: 0,
                      title: title.text,
                      start: _combine(targetDay, start!),
                      end: _combine(targetDay, end!),
                      placeId: placeId,
                      notes: null,
                    ),
                  );
                  if (!mounted) return;
                  Navigator.pop(context);
                  await _loadAgendaForDay(targetDay);
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
              child: const Text('Save', style: TextStyle(color: Colors.white)),
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
}

// ════════════════════════════════════════════════
// LANDMARK PICKER BOTTOM SHEET
// ════════════════════════════════════════════════

class _LandmarkPickerSheet extends StatefulWidget {
  final TextStyle serif;
  final TextStyle sans;
  final List<String> timeSlots;
  final String prefilledStart;
  final DateTime targetDay;
  final Future<void> Function(
    RecommendationItem landmark,
    String start,
    String end,
  )
  onConfirm;

  const _LandmarkPickerSheet({
    required this.serif,
    required this.sans,
    required this.timeSlots,
    required this.prefilledStart,
    required this.targetDay,
    required this.onConfirm,
  });

  @override
  State<_LandmarkPickerSheet> createState() => _LandmarkPickerSheetState();
}

class _LandmarkPickerSheetState extends State<_LandmarkPickerSheet> {
  final _searchCtrl = TextEditingController();

  List<RecommendationItem> _landmarks = [];
  bool _loadingLandmarks = false;
  RecommendationItem? _selected;
  String? _start;
  String? _end;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _start = widget.prefilledStart;
    _fetchLandmarks('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLandmarks(String q) async {
    setState(() => _loadingLandmarks = true);
    try {
      final result = await LandmarksService.search(
        q: q,
        category: '',
        page: 1,
        limit: 20,
        sortMode: 'POPULAR',
      );
      if (mounted) setState(() => _landmarks = result.data);
    } catch (_) {
      if (mounted) setState(() => _landmarks = []);
    } finally {
      if (mounted) setState(() => _loadingLandmarks = false);
    }
  }

  // ── time picker bottom sheet ──────────────────
  void _pickTime({required bool isStart}) {
    final allSlots = widget.timeSlots;

    // end slots must be strictly after the selected start
    final slots = isStart
        ? allSlots
        : (_start == null
              ? allSlots
              : allSlots.where((t) {
                  final startIdx = allSlots.indexOf(_start!);
                  final thisIdx = allSlots.indexOf(t);
                  return thisIdx > startIdx;
                }).toList());

    final current = isStart ? _start : _end;
    int initialIndex = slots.indexOf(current ?? slots[0]);
    if (initialIndex < 0) initialIndex = 0;

    final ctrl = FixedExtentScrollController(initialItem: initialIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: _C.papyrus,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.teal.withValues(alpha: 0.15),
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
                    style: widget.serif.copyWith(fontSize: 18),
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
                        color: _C.teal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Done',
                        style: widget.sans.copyWith(
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
              child: slots.isEmpty
                  ? Center(
                      child: Text(
                        'No available end times',
                        style: widget.sans.copyWith(
                          color: _C.teal.withValues(alpha: 0.40),
                        ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 50,
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            color: _C.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _C.gold.withValues(alpha: 0.30),
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
                              setState(() {
                                _start = slots[i];
                                // clear end if it's now <= new start
                                if (_end != null) {
                                  final startIdx = allSlots.indexOf(_start!);
                                  final endIdx = allSlots.indexOf(_end!);
                                  if (endIdx <= startIdx) _end = null;
                                }
                              });
                            } else {
                              setState(() => _end = slots[i]);
                            }
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: slots.length,
                            builder: (_, i) {
                              final selected =
                                  slots[i] == (isStart ? _start : _end);
                              return Center(
                                child: Text(
                                  slots[i],
                                  style: widget.sans.copyWith(
                                    fontSize: selected ? 18 : 15,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? _C.teal
                                        : _C.teal.withValues(alpha: 0.35),
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

  @override
  Widget build(BuildContext context) {
    final serif = widget.serif;
    final sans = widget.sans;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.50,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _C.papyrus,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            // ── handle ────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── header ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Add to Agenda', style: serif.copyWith(fontSize: 22)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _C.teal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: _C.teal,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── search bar ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.teal.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: sans.copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search landmarks...',
                    hintStyle: sans.copyWith(
                      fontSize: 14,
                      color: _C.teal.withValues(alpha: 0.35),
                    ),
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.search_rounded,
                      color: _C.teal.withValues(alpha: 0.40),
                      size: 20,
                    ),
                  ),
                  onChanged: (v) => _fetchLandmarks(v.trim()),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── landmark list ─────────────────────
            Expanded(
              child: _loadingLandmarks
                  ? const Center(
                      child: CircularProgressIndicator(color: _C.gold),
                    )
                  : _landmarks.isEmpty
                  ? Center(
                      child: Text(
                        'No landmarks found',
                        style: sans.copyWith(
                          color: _C.teal.withValues(alpha: 0.40),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _landmarks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final lm = _landmarks[i];
                        final sel = _selected?.id == lm.id;
                        final photo = lm.photoUrls.isNotEmpty
                            ? lm.photoUrls.first
                            : null;
                        return GestureDetector(
                          onTap: () => setState(() => _selected = lm),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: sel
                                  ? _C.teal
                                  : Colors.white.withValues(alpha: 0.70),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel
                                    ? _C.teal
                                    : _C.gold.withValues(alpha: 0.15),
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: _C.teal.withValues(alpha: 0.22),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: photo != null
                                      ? Image.network(
                                          photo,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _photoPlaceholder(),
                                        )
                                      : _photoPlaceholder(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lm.name,
                                        style: serif.copyWith(
                                          fontSize: 14,
                                          color: sel ? Colors.white : _C.teal,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        lm.category,
                                        style: sans.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: sel
                                              ? Colors.white.withValues(
                                                  alpha: 0.65,
                                                )
                                              : _C.gold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (sel)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: _C.gold,
                                    size: 22,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── time row + confirm ────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.50),
                border: Border(
                  top: BorderSide(color: _C.gold.withValues(alpha: 0.15)),
                ),
              ),
              child: Column(
                children: [
                  // time selectors
                  Row(
                    children: [
                      Expanded(
                        child: _timeTile(
                          label: 'START',
                          value: _start,
                          onTap: () => _pickTime(isStart: true),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: _C.teal.withValues(alpha: 0.08),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: _timeTile(
                          label: 'END',
                          value: _end,
                          onTap: () => _pickTime(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // confirm button
                  GestureDetector(
                    onTap:
                        (_selected == null ||
                            _start == null ||
                            _end == null ||
                            _confirming)
                        ? null
                        : () async {
                            setState(() => _confirming = true);
                            await widget.onConfirm(_selected!, _start!, _end!);
                            if (context.mounted) Navigator.pop(context);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            (_selected == null ||
                                _start == null ||
                                _end == null)
                            ? _C.teal.withValues(alpha: 0.30)
                            : _C.teal,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow:
                            (_selected != null &&
                                _start != null &&
                                _end != null)
                            ? [
                                BoxShadow(
                                  color: _C.teal.withValues(alpha: 0.28),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: _confirming
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
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
                                    color: _C.gold,
                                    size: 16,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── tappable time tile ────────────────────────
  Widget _timeTile({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: widget.sans.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: _C.gold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: value != null
                  ? _C.teal.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value != null
                    ? _C.gold.withValues(alpha: 0.35)
                    : _C.teal.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: value != null
                      ? _C.gold
                      : _C.teal.withValues(alpha: 0.30),
                ),
                const SizedBox(width: 6),
                Expanded(
                  // ← fix
                  child: Text(
                    value ?? 'Pick',
                    style: widget.sans.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value != null
                          ? _C.teal
                          : _C.teal.withValues(alpha: 0.35),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _C.teal.withValues(alpha: 0.30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPlaceholder() => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(Icons.image_outlined, color: _C.gold, size: 22),
  );
}
