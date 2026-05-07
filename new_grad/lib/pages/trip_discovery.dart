import 'package:flutter/material.dart';
import '../services/context_service.dart';
import '../services/recommendation_service.dart';
import 'daily_plan.dart';
import 'trip_plan_page.dart';

class _Colors {
  static const papyrus = Color(0xFFF2E8D5);
  static const teal = Color(0xFF1A3C3C);
  static const gold = Color(0xFFC5A059);
  static const glass = Color(0x73FFFFFF);
  static const glassBorder = Color(0x80FFFFFF);
}

enum PlanMode { daily, trip }

enum BudgetLevel { low, mid, high }

class _VibeOption {
  final String emoji;
  final String label;
  final String apiValue;
  const _VibeOption(this.emoji, this.label, this.apiValue);
}

class TripDiscoveryPage extends StatefulWidget {
  const TripDiscoveryPage({super.key});

  @override
  State<TripDiscoveryPage> createState() => _TripDiscoveryPageState();
}

class _TripDiscoveryPageState extends State<TripDiscoveryPage>
    with TickerProviderStateMixin {
  final ContextService _contextService = ContextService();

  PlanMode _mode = PlanMode.daily;
  BudgetLevel _budget = BudgetLevel.mid;
  String? _selectedVibe;
  int _tripDays = 1;
  bool _loading = false;

  late AnimationController _ornamentCtrl;
  late AnimationController _slideCtrl;

  static const _vibes = [
    _VibeOption('🧍', 'Solo', 'solo'),
    _VibeOption('💑', 'Couple', 'couple'),
    _VibeOption('👨‍👩‍👧', 'Family', 'family'),
    _VibeOption('👑', 'Luxury', 'luxury'),
  ];

  @override
  void initState() {
    super.initState();
    _ornamentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _ornamentCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _setMode(PlanMode mode) {
    setState(() => _mode = mode);
    if (mode == PlanMode.trip) {
      _slideCtrl.forward();
    } else {
      _slideCtrl.reverse();
    }
  }

  String get _budgetApiValue {
    switch (_budget) {
      case BudgetLevel.low:
        return 'low';
      case BudgetLevel.mid:
        return 'medium';
      case BudgetLevel.high:
        return 'high';
    }
  }

  Future<void> _submit() async {
    if (_selectedVibe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a travel vibe')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _contextService.setContext(
        budget: _budgetApiValue,
        travelType: _selectedVibe!,
      );

      if (!mounted) return;

      if (_mode == PlanMode.daily) {
        setState(() => _loading = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DailyPlanPage()),
        );
      } else {
        // TripPlan → pick start date first
        setState(() => _loading = false);
        await _pickStartDateAndFillAgenda();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save preferences')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _pickStartDateAndFillAgenda() async {
    // Fetch TripPlan results
    setState(() => _loading = true);

    try {
      final tripResult = await RecommendationService().getTripPlan(
        tripDays: _tripDays,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      // Navigate to TripPlanPage with real data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TripPlanPage(tripResult: tripResult)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load trip plan: $e')));
    }
  }

  TextStyle get _serifBold => const TextStyle(
    fontFamily: 'Gambetta',
    fontWeight: FontWeight.w700,
    color: _Colors.teal,
  );

  TextStyle get _sansBody =>
      const TextStyle(fontFamily: 'Satoshi', color: _Colors.teal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.papyrus,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildModeSwitcher(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                children: [
                  if (_mode == PlanMode.trip) ...[
                    _buildTimelineSection(),
                    const SizedBox(height: 20),
                  ],
                  _buildVibeSection(),
                  const SizedBox(height: 20),
                  _buildBudgetSection(),
                  const SizedBox(height: 28),
                  _buildDivider(),
                  const SizedBox(height: 20),
                  _buildCompleteButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip Discovery',
                      style: _serifBold.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PERSONALIZATION REQUIREMENTS',
                      style: _sansBody.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: _Colors.teal.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              RotationTransition(
                turns: _ornamentCtrl,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _Colors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '✦',
                      style: TextStyle(color: _Colors.gold, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
        ),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final halfW = (constraints.maxWidth - 12) / 2;
            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: _mode == PlanMode.daily
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    width: halfW,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _Colors.teal,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                          color: _Colors.teal.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _modeTab('Daily Plan', PlanMode.daily, halfW),
                    _modeTab('Trip Plan', PlanMode.trip, halfW),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _modeTab(String label, PlanMode mode, double width) {
    final active = _mode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: SizedBox(
        width: width,
        height: 46,
        child: Center(
          child: Text(
            label,
            style: _sansBody.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: active ? Colors.white : _Colors.teal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: '📅',
            title: 'Timeline',
            subtitle: 'How long is your Egyptian journey?',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: _Colors.teal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRIP DAYS',
                        style: _sansBody.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '14 DAY MAX',
                        style: _sansBody.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _Colors.teal.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      _stepButton(
                        icon: Icons.remove,
                        onTap: () => setState(() {
                          if (_tripDays > 1) _tripDays--;
                        }),
                        active: _tripDays > 1,
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 24,
                        child: Center(
                          child: Text(
                            '$_tripDays',
                            style: _serifBold.copyWith(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _stepButton(
                        icon: Icons.add,
                        onTap: () => setState(() {
                          if (_tripDays < 14) _tripDays++;
                        }),
                        active: _tripDays < 14,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = true,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary ? _Colors.teal : Colors.white.withValues(alpha: 0.6),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: _Colors.teal.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isPrimary
              ? Colors.white
              : (active ? _Colors.teal : _Colors.teal.withValues(alpha: 0.2)),
        ),
      ),
    );
  }

  Widget _buildVibeSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: '🧭',
            title: 'Travel Vibe',
            subtitle: 'What kind of traveller are you?',
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.6,
            children: _vibes.map((v) => _vibeChip(v)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _vibeChip(_VibeOption vibe) {
    final selected = _selectedVibe == vibe.apiValue;
    return GestureDetector(
      onTap: () => setState(() => _selectedVibe = vibe.apiValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? _Colors.teal : Colors.white.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _Colors.teal
                : _Colors.teal.withValues(alpha: 0.06),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _Colors.teal.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(vibe.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              vibe.label,
              style: _sansBody.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : _Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: '👛',
            title: 'Budget Level',
            subtitle: 'Choose your planned spending level',
          ),
          const SizedBox(height: 20),
          _budgetSegmentedControl(),
        ],
      ),
    );
  }

  Widget _budgetSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.50)),
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final segW = (constraints.maxWidth - 12) / 3;
          final idx = BudgetLevel.values.indexOf(_budget);
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: idx * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: Container(
                  decoration: BoxDecoration(
                    color: _Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _Colors.teal.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _budgetOption(BudgetLevel.low, '💰', 'LOW', segW),
                  _budgetOption(BudgetLevel.mid, '💳', 'MID', segW),
                  _budgetOption(BudgetLevel.high, '👑', 'HIGH', segW),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _budgetOption(
    BudgetLevel level,
    String icon,
    String label,
    double width,
  ) {
    final active = _budget == level;
    return GestureDetector(
      onTap: () => setState(() => _budget = level),
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              icon,
              style: TextStyle(
                fontSize: 22,
                color: active ? Colors.white : _Colors.teal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: _sansBody.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 1.8,
                color: active ? Colors.white : _Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _Colors.teal.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '𓆣',
            style: TextStyle(
              fontSize: 20,
              color: _Colors.teal.withValues(alpha: 0.30),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _Colors.teal.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteButton() {
    return GestureDetector(
      onTap: _loading ? null : _submit,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: _loading ? _Colors.teal.withValues(alpha: 0.5) : _Colors.teal,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _Colors.teal.withValues(alpha: 0.30),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'COMPLETE SELECTION',
                    style: _sansBody.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 2.5,
                    ),
                  ),
            const Icon(
              Icons.chevron_right_rounded,
              color: _Colors.gold,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _Colors.glass,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _Colors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: _Colors.teal.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _Colors.gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Colors.gold.withValues(alpha: 0.22)),
          ),
          child: Center(
            child: Text(icon, style: const TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _serifBold.copyWith(fontSize: 17)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: _sansBody.copyWith(
                fontSize: 11,
                color: _Colors.teal.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
