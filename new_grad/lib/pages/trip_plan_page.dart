import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recommendation_item.dart';
import '../services/recommendation_service.dart';
import '../services/agenda_service.dart';
import '../models/agenda_item.dart';
import 'agenda_page.dart';
import 'recommendation_landmark_details.dart';

// ─────────────────────────────────────────────
//  COLOUR PALETTE
// ─────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFF2EADC);
  static const dark = Color(0xFF1A3C3C);
  static const gold = Color(0xFFD4AF37);
  static const bronze = Color(0xFFC5A059);
  static const cream = Color(0xFFEAE2D1);
  static const white = Colors.white;
}

const _dayColors = [
  [Color(0xFFDC2626), Color(0xFFFEE2E2)],
  [Color(0xFF2563EB), Color(0xFFDBEAFE)],
  [Color(0xFF059669), Color(0xFFD1FAE5)],
  [Color(0xFF7C3AED), Color(0xFFEDE9FE)],
  [Color(0xFFD97706), Color(0xFFFEF3C7)],
  [Color(0xFFDB2777), Color(0xFFFCE7F3)],
  [Color(0xFF0891B2), Color(0xFFCFFAFE)],
];

// ─────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────
class _TripPlace {
  final RecommendationItem item;
  bool liked;
  bool visible;
  _TripPlace({required this.item, this.liked = false, this.visible = true});
}

class _TripDay {
  final int number;
  final List<_TripPlace> places;
  _TripDay({required this.number, required this.places});
}

// ─────────────────────────────────────────────
//  MAIN PAGE
// ─────────────────────────────────────────────
class TripPlanPage extends StatefulWidget {
  final TripPlanResult tripResult;
  const TripPlanPage({super.key, required this.tripResult});

  @override
  State<TripPlanPage> createState() => _TripPlanPageState();
}

class _TripPlanPageState extends State<TripPlanPage> {
  final RecommendationService _recService = RecommendationService();
  late List<_TripDay> _days;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _days = widget.tripResult.days
        .map(
          (d) => _TripDay(
            number: d.day,
            places: d.landmarks.map((l) => _TripPlace(item: l)).toList(),
          ),
        )
        .toList();
  }

  _TripDay get _currentDay => _days[_selectedDay];
  List<_TripPlace> get _visiblePlaces =>
      _currentDay.places.where((p) => p.visible).toList();

  Future<void> _onLike(_TripPlace place) async {
    setState(() => place.liked = true);
    try {
      await _recService.sendFeedback(
        landmarkName: place.item.name,
        eventType: 'like',
      );
    } catch (_) {}
  }

  Future<void> _onDislike(_TripPlace place) async {
    setState(() => place.visible = false);
    try {
      await _recService.sendFeedback(
        landmarkName: place.item.name,
        eventType: 'dislike',
      );
    } catch (_) {}
  }

  void _openDayAgendaModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) =>
          _DayAgendaDialog(day: _currentDay, visiblePlaces: _visiblePlaces),
    );
  }

  void _openSinglePlaceModal(_TripPlace place) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) =>
          _SinglePlaceAgendaDialog(place: place, dayNumber: _selectedDay + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Center(
              child: _AddAgendaButton(
                dayNumber: _selectedDay + 1,
                onTap: _openDayAgendaModal,
              ),
            ),
            const SizedBox(height: 20),
            _buildDayTabs(),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: _buildPlaceList(),
              ),
            ),
            _AIPersonalizedNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _C.white.withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_left, color: _C.dark, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trip Plan',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: _C.dark,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your personalized ${widget.tripResult.tripDays}-day journey through Egypt.',
            style: TextStyle(
              fontSize: 13,
              color: _C.dark.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(_days.length, (i) {
          final active = i == _selectedDay;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.only(right: i < _days.length - 1 ? 10 : 0),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: active ? _C.dark : _C.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: active
                        ? Colors.transparent
                        : _C.bronze.withValues(alpha: 0.2),
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: _C.dark.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'DAY ${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: active
                          ? _C.white
                          : _C.dark.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlaceList() {
    final visible = _visiblePlaces;
    final colors = _dayColors[_selectedDay % _dayColors.length];

    if (visible.isEmpty) {
      return Center(
        key: ValueKey('empty-$_selectedDay'),
        child: Text(
          'No places remaining for this day.',
          style: TextStyle(
            color: _C.dark.withValues(alpha: 0.35),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      key: ValueKey(_selectedDay),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      itemCount: visible.length,
      itemBuilder: (_, i) {
        final place = visible[i];
        final timeHour = 9 + (i * 2);
        final timeLabel = timeHour < 12
            ? '$timeHour:00 AM'
            : timeHour == 12
            ? '12:00 PM'
            : '${timeHour - 12}:00 PM';

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecommendationDetailsPage(item: place.item),
            ),
          ),
          child: _PlaceCard(
            key: ValueKey(place.item.name),
            place: place,
            timeLabel: timeLabel,
            timeColor: colors[0],
            timeBg: colors[1],
            onLike: () => _onLike(place),
            onDislike: () => _onDislike(place),
            onAddCalendar: () => _openSinglePlaceModal(place),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  ADD AGENDA BUTTON
// ─────────────────────────────────────────────
class _AddAgendaButton extends StatelessWidget {
  final int dayNumber;
  final VoidCallback onTap;
  const _AddAgendaButton({required this.dayNumber, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: _C.dark,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: _C.dark.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month, size: 16, color: _C.gold),
            const SizedBox(width: 10),
            Text(
              'ADD DAY $dayNumber TO AGENDA',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: _C.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PLACE CARD
// ─────────────────────────────────────────────
class _PlaceCard extends StatefulWidget {
  final _TripPlace place;
  final String timeLabel;
  final Color timeColor;
  final Color timeBg;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onAddCalendar;

  const _PlaceCard({
    super.key,
    required this.place,
    required this.timeLabel,
    required this.timeColor,
    required this.timeBg,
    required this.onLike,
    required this.onDislike,
    required this.onAddCalendar,
  });

  @override
  State<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<_PlaceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fade = Tween<double>(begin: 1, end: 0).animate(_ctrl);
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.4, 0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleDislike() async {
    await _ctrl.forward();
    widget.onDislike();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.place.item;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _C.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _C.bronze.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: _C.dark.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: item.photoUrls.isNotEmpty
                        ? Image.network(
                            item.photoUrls.first,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 88,
                              height: 88,
                              color: _C.dark.withValues(alpha: 0.12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 28,
                                    color: _C.dark.withValues(alpha: 0.22),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.category,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: _C.dark.withValues(alpha: 0.3),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            width: 88,
                            height: 88,
                            color: _C.dark.withValues(alpha: 0.12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 28,
                                  color: _C.dark.withValues(alpha: 0.22),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.category,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: _C.dark.withValues(alpha: 0.3),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.timeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.timeLabel,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: widget.timeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.star, size: 12, color: _C.bronze),
                          const SizedBox(width: 2),
                          Text(
                            (item.rating ?? 0).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _C.bronze,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _C.dark,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.budget.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: _C.bronze.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _CircleAction(
                      icon: widget.place.liked
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      color: widget.place.liked
                          ? _C.gold
                          : _C.dark.withValues(alpha: 0.35),
                      bgColor: widget.place.liked
                          ? _C.gold.withValues(alpha: 0.12)
                          : _C.white.withValues(alpha: 0.5),
                      borderColor: widget.place.liked
                          ? _C.gold
                          : _C.bronze.withValues(alpha: 0.2),
                      onTap: widget.place.liked ? null : widget.onLike,
                    ),
                    const SizedBox(height: 6),
                    _CircleAction(
                      icon: Icons.thumb_down_outlined,
                      color: _C.dark.withValues(alpha: 0.35),
                      bgColor: _C.white.withValues(alpha: 0.5),
                      borderColor: _C.bronze.withValues(alpha: 0.2),
                      onTap: _handleDislike,
                    ),
                    const SizedBox(height: 6),
                    _CircleAction(
                      icon: Icons.calendar_month_outlined,
                      color: _C.dark.withValues(alpha: 0.5),
                      bgColor: _C.white.withValues(alpha: 0.5),
                      borderColor: _C.bronze.withValues(alpha: 0.2),
                      onTap: widget.onAddCalendar,
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
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _CircleAction({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 17, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED DATE PICKER WIDGET
// ─────────────────────────────────────────────
Widget _buildDatePicker(
  BuildContext context,
  DateTime selectedDate,
  ValueChanged<DateTime> onChanged,
  String label,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
          color: _C.dark.withValues(alpha: 0.4),
        ),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF1A3C3C),
                  onPrimary: Colors.white,
                  surface: Color(0xFFEAE2D1),
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.bronze.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: _C.dark, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMM d yyyy').format(selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _C.dark,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: _C.dark.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
//  DAY AGENDA DIALOG
// ─────────────────────────────────────────────
class _DayAgendaDialog extends StatefulWidget {
  final _TripDay day;
  final List<_TripPlace> visiblePlaces;
  const _DayAgendaDialog({required this.day, required this.visiblePlaces});

  @override
  State<_DayAgendaDialog> createState() => _DayAgendaDialogState();
}

class _DayAgendaDialogState extends State<_DayAgendaDialog> {
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final selectedDate = _selectedDate;
    final agendaService = AgendaService();

    try {
      // Check conflicts
      final existing = await agendaService.fetch(
        from: selectedDate,
        to: selectedDate.add(const Duration(days: 1)),
      );

      if (existing.isNotEmpty) {
        setState(() => _saving = false);
        if (!mounted) return;

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD4AF37),
                  size: 28,
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Date Already Has Events',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This date already has ${existing.length} event${existing.length > 1 ? 's' : ''} scheduled:',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ...existing.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC5A059),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A3C3C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    'Adding this day may cause time conflicts with your existing events.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5D4037),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Pick Different Date',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A3C3C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Add Anyway',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
      }

      setState(() => _saving = true);
      const startHour = 9;
      const durationHours = 2;

      for (int i = 0; i < widget.visiblePlaces.length; i++) {
        final place = widget.visiblePlaces[i];
        final slotStart = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          startHour + (i * durationHours),
          0,
        );
        final slotEnd = slotStart.add(const Duration(hours: durationHours));

        await agendaService.create(
          AgendaItem(
            id: 0,
            title: place.item.name,
            start: slotStart,
            end: slotEnd,
            placeId: null,
            notes: '${place.item.category} • ${place.item.budget} budget',
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgendaPage(initialDate: selectedDate),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final isConflict =
          e.toString().toLowerCase().contains('overlap') ||
          e.toString().toLowerCase().contains('conflict') ||
          e.toString().contains('409');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConflict
                ? 'Some time slots conflict. Try a different date.'
                : 'Failed to save: $e',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.visiblePlaces.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: _C.cream,
          borderRadius: BorderRadius.circular(28),
          border: const Border(top: BorderSide(color: _C.gold, width: 4)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schedule Day ${widget.day.number}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _C.dark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ADD DAY ${widget.day.number} TO YOUR AGENDA',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: _C.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: _C.dark.withValues(alpha: 0.4),
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _LandmarksBar(count: count, total: widget.day.places.length),
              const SizedBox(height: 20),
              Text(
                'SCHEDULE SUMMARY',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: _C.dark.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(widget.visiblePlaces.length, (i) {
                final place = widget.visiblePlaces[i];
                final timeHour = 9 + (i * 2);
                final timeLabel = timeHour < 12
                    ? '$timeHour:00 AM'
                    : timeHour == 12
                    ? '12:00 PM'
                    : '${timeHour - 12}:00 PM';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _C.bronze.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _C.bronze,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          place.item.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: _C.dark.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (context, setLocal) => _buildDatePicker(
                  context,
                  _selectedDate,
                  (d) => setState(() => _selectedDate = d),
                  'SELECT START DATE',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: 'CANCEL',
                      filled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _DialogButton(
                      label: _saving ? 'SAVING...' : 'CONFIRM',
                      filled: true,
                      onTap: _saving ? () {} : _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SINGLE PLACE AGENDA DIALOG
// ─────────────────────────────────────────────
class _SinglePlaceAgendaDialog extends StatefulWidget {
  final _TripPlace place;
  final int dayNumber;
  const _SinglePlaceAgendaDialog({
    required this.place,
    required this.dayNumber,
  });

  @override
  State<_SinglePlaceAgendaDialog> createState() =>
      _SinglePlaceAgendaDialogState();
}

class _SinglePlaceAgendaDialogState extends State<_SinglePlaceAgendaDialog> {
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  final List<String> _timeSlots = List.generate(16, (i) {
    final h = i + 7;
    final dh = h > 12 ? h - 12 : h;
    final p = h < 12 ? 'AM' : 'PM';
    return '$dh:00 $p';
  });

  String? _start;
  String? _end;

  void _pickTime(StateSetter setD, bool isStart) {
    final allSlots = _timeSlots;
    final slots = isStart
        ? allSlots
        : (_start == null
              ? allSlots
              : allSlots.where((t) {
                  final si = allSlots.indexOf(_start!);
                  final ti = allSlots.indexOf(t);
                  return ti > si;
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
          color: Color(0xFFEAE2D1),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.dark.withOpacity(0.15),
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
                    style: const TextStyle(
                      fontFamily: 'Gambetta',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: _C.dark,
                    ),
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
                        color: _C.dark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
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
                      color: _C.dark.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.bronze.withOpacity(0.30)),
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
                          _start = slots[i];
                          if (_end != null) {
                            final si = allSlots.indexOf(_start!);
                            final ei = allSlots.indexOf(_end!);
                            if (ei <= si) _end = null;
                          }
                        });
                      } else {
                        setD(() => _end = slots[i]);
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: slots.length,
                      builder: (_, i) {
                        final sel = slots[i] == (isStart ? _start : _end);
                        return Center(
                          child: Text(
                            slots[i],
                            style: TextStyle(
                              fontSize: sel ? 18 : 15,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: sel ? _C.dark : _C.dark.withOpacity(0.35),
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

  DateTime _combine(DateTime day, String time) {
    final parts = time.split(RegExp(r'[: ]'));
    int h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final isPm = parts[2] == 'PM';
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return DateTime(day.year, day.month, day.day, h, m).toUtc();
  }

  Future<void> _confirm(StateSetter setD) async {
    if (_start == null || _end == null) return;
    setD(() => _saving = true);

    final agendaService = AgendaService();
    final start = _combine(_selectedDate, _start!);
    final end = _combine(_selectedDate, _end!);

    try {
      await agendaService.create(
        AgendaItem(
          id: 0,
          title: widget.place.item.name,
          start: start,
          end: end,
          placeId: null,
          landmarkId: widget.place.item.id,
          notes:
              '${widget.place.item.category} • ${widget.place.item.budget} budget',
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Added to agenda'),
            ],
          ),
          backgroundColor: _C.dark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setD(() => _saving = false);

      final isConflict =
          e.toString().toLowerCase().contains('overlap') ||
          e.toString().toLowerCase().contains('conflict') ||
          e.toString().contains('409');

      if (!isConflict) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
        return;
      }

      // fetch free slots
      final allItems = await agendaService.fetch(
        from: _selectedDate,
        to: _selectedDate.add(const Duration(days: 1)),
      );

      final dayStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        7,
        0,
      ).toUtc();
      final dayEnd = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        22,
        0,
      ).toUtc();
      final sorted = List.of(allItems)
        ..sort((a, b) => a.start.compareTo(b.start));
      final freeSlots = <Map<String, DateTime>>[];
      DateTime cursor = dayStart;
      for (final item in sorted) {
        if (cursor.isBefore(item.start)) {
          DateTime sc = cursor;
          while (!sc.add(const Duration(hours: 2)).isAfter(item.start)) {
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
      while (!sc.add(const Duration(hours: 2)).isAfter(dayEnd)) {
        freeSlots.add({'start': sc, 'end': sc.add(const Duration(hours: 2))});
        sc = sc.add(const Duration(hours: 1));
        if (freeSlots.length >= 8) break;
      }

      if (freeSlots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That day is full. Pick a different date.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // show free slots sheet
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Color(0xFFEAE2D1),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _C.dark.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
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
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time Conflict',
                        style: TextStyle(
                          fontFamily: 'Gambetta',
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          color: _C.dark,
                        ),
                      ),
                      Text(
                        'Pick an available slot below',
                        style: TextStyle(
                          fontSize: 11,
                          color: _C.dark.withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'AVAILABLE SLOTS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: _C.bronze,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: freeSlots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final sStart = freeSlots[i]['start']!;
                    final sEnd = freeSlots[i]['end']!;
                    String fmt(DateTime d) {
                      final h = d.hour > 12
                          ? d.hour - 12
                          : d.hour == 0
                          ? 12
                          : d.hour;
                      final m = d.minute.toString().padLeft(2, '0');
                      final p = d.hour < 12 ? 'AM' : 'PM';
                      return '$h:$m $p';
                    }

                    final mins = sEnd.difference(sStart).inMinutes;
                    final dur = mins >= 60
                        ? '${mins ~/ 60}h${mins % 60 > 0 ? ' ${mins % 60}m' : ''}'
                        : '${mins}m';
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await agendaService.create(
                            AgendaItem(
                              id: 0,
                              title: widget.place.item.name,
                              start: sStart,
                              end: sEnd,
                              placeId: null,
                              landmarkId: widget.place.item.id,
                              notes:
                                  '${widget.place.item.category} • ${widget.place.item.budget} budget',
                            ),
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Added to agenda'),
                                ],
                              ),
                              backgroundColor: _C.dark,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        } catch (_) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Still conflicts. Try another slot.',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _C.cream.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.dark.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _C.dark,
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
                                    '${fmt(sStart)}  →  ${fmt(sEnd)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _C.dark,
                                    ),
                                  ),
                                  Text(
                                    '$dur free',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _C.dark.withOpacity(0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: _C.bronze),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: StatefulBuilder(
        builder: (_, setD) => Container(
          decoration: BoxDecoration(
            color: _C.cream,
            borderRadius: BorderRadius.circular(28),
            border: const Border(top: BorderSide(color: _C.gold, width: 4)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.place.item.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _C.dark,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ADD TO YOUR AGENDA',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                              color: _C.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.close,
                        color: _C.dark.withOpacity(0.4),
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _LandmarksBar(count: 1, total: 1),
                const SizedBox(height: 20),

                // date picker
                _buildDatePicker(
                  context,
                  _selectedDate,
                  (d) => setD(() => _selectedDate = d),
                  'SELECT DATE',
                ),
                const SizedBox(height: 20),

                // time pickers
                Text(
                  'SCHEDULE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: _C.bronze,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(setD, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _start != null
                                ? _C.dark.withOpacity(0.06)
                                : Colors.white.withOpacity(0.50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _start != null
                                  ? _C.bronze.withOpacity(0.35)
                                  : _C.dark.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: _start != null
                                    ? _C.bronze
                                    : _C.dark.withOpacity(0.30),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _start ?? 'Start',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _start != null
                                        ? _C.dark
                                        : _C.dark.withOpacity(0.35),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: _C.dark.withOpacity(0.30),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(setD, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _end != null
                                ? _C.dark.withOpacity(0.06)
                                : Colors.white.withOpacity(0.50),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _end != null
                                  ? _C.bronze.withOpacity(0.35)
                                  : _C.dark.withOpacity(0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 15,
                                color: _end != null
                                    ? _C.bronze
                                    : _C.dark.withOpacity(0.30),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _end ?? 'End',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _end != null
                                        ? _C.dark
                                        : _C.dark.withOpacity(0.35),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: _C.dark.withOpacity(0.30),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        label: 'CANCEL',
                        filled: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _DialogButton(
                        label: _saving ? 'SAVING...' : 'CONFIRM',
                        filled: true,
                        onTap: (_saving || _start == null || _end == null)
                            ? () {}
                            : () => _confirm(setD),
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
}

// ─────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────
class _LandmarksBar extends StatelessWidget {
  final int count;
  final int total;
  const _LandmarksBar({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) => Stack(
          children: [
            Container(
              width: constraints.maxWidth * fraction,
              decoration: BoxDecoration(
                color: _C.cream,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LANDMARKS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: _C.dark.withValues(alpha: 0.4),
                    ),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: _C.dark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? _C.dark : _C.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: _C.dark.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: filled ? _C.white : _C.dark.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class _AIPersonalizedNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(18),
        border: const Border(left: BorderSide(color: _C.gold, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: _C.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-Personalized Journey',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _C.dark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your liked choices help our AI engine tailor destinations that match your pace, interests, and the unique Egyptian heritage.',
                  style: TextStyle(
                    fontSize: 10,
                    color: _C.dark.withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
