import 'package:flutter/material.dart';
import '../models/recommendation_item.dart';
import '../services/recommendation_service.dart';
import 'agenda_page.dart';
import 'dart:ui' as ui;
import 'recommendation_landmark_details.dart';

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
    // Step 1 — pick a day
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

    // Step 2 — navigate to AgendaPage on that day
    // The existing _eventDialog in AgendaPage will auto-open with the title prefilled
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgendaPage(
          initialDate: pickedDate,
          prefilledTitle: place.item.name,
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
                          _CompassBanner(count: visible.length),
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
  final int count;
  const _CompassBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      height: 200,
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.gold.withOpacity(0.2)),
      ),
      child: Stack(
        children: [
          Center(child: _CompassIllustration()),
          Positioned(
            left: 24,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(
                count > 4 ? 4 : count,
                (i) => _MapDot(
                  number: i + 1,
                  active: i == 2,
                  leftOffset: i * 14.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.25,
      child: CustomPaint(
        size: const Size(280, 180),
        painter: _CompassPainter(),
      ),
    );
  }
}

class _CompassPainter extends CustomPainter {
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
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.7, cy - r * 0.4),
      needlePaint,
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapDot extends StatelessWidget {
  final int number;
  final bool active;
  final double leftOffset;
  const _MapDot({
    required this.number,
    required this.active,
    required this.leftOffset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: number == 1 ? 0 : 4, left: leftOffset),
      child: Container(
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
