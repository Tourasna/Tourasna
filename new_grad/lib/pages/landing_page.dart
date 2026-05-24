import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ── palette ───────────────────────────────────────────────────────────────────
class _C {
  static const cream = Color(0xFFF2EADC);
  static const teal = Color(0xFF1A3C3C);
  static const gold = Color(0xFFC5A059);
}

// ── glyph layout ──────────────────────────────────────────────────────────────
class _G {
  final String ch;
  final double top, left, size, delay, dur;
  const _G(this.ch, this.top, this.left, this.size, this.delay, this.dur);
}

const _layout = [
  _G('𓆙', 0.09, 0.08, 36, 0.2, 5.5),
  _G('𓃠', 0.38, 0.82, 28, 1.1, 6.2),
  _G('𓆣', 0.72, 0.07, 42, 1.9, 4.9),
  _G('𓉔', 0.60, 0.20, 24, 0.7, 5.3),
  _G('𓂀', 0.18, 0.76, 26, 2.4, 6.0),
  _G('𓋴', 0.55, 0.88, 22, 3.0, 5.0),
  _G('𓆑', 0.75, 0.70, 20, 1.5, 6.5),
  _G('𓇯', 0.50, 0.04, 18, 2.8, 5.8),
];

// ── page ──────────────────────────────────────────────────────────────────────
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  bool _checking = true; // checking Firebase auth on launch
  bool _revealed = false; // user tapped to reveal buttons

  double _rippleX = 0, _rippleY = 0;

  // controllers
  late final AnimationController _logoCtrl;
  late final AnimationController _typeCtrl;
  late final AnimationController _subtitleCtrl;
  late final AnimationController _hintCtrl;
  late final AnimationController _rippleCtrl;
  late final AnimationController _flashCtrl;
  late final AnimationController _preOutCtrl;
  late final AnimationController _postInCtrl;
  late final List<AnimationController> _glyphCtrls;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _typeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _subtitleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _hintCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _preOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _postInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _glyphCtrls = List.generate(_layout.length, (i) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (_layout[i].dur * 1000).toInt()),
      );
      Future.delayed(
        Duration(milliseconds: (_layout[i].delay * 1000).toInt()),
        () {
          if (mounted) c.repeat(reverse: true);
        },
      );
      return c;
    });

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Small delay so splash feels intentional
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      // Already logged in — skip landing, go home
      Navigator.pushReplacementNamed(context, '/homescreen');
      return;
    }

    // Not logged in — show landing and start animations
    setState(() => _checking = false);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _logoCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _typeCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) _subtitleCtrl.forward();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _typeCtrl.dispose();
    _subtitleCtrl.dispose();
    _hintCtrl.dispose();
    _rippleCtrl.dispose();
    _flashCtrl.dispose();
    _preOutCtrl.dispose();
    _postInCtrl.dispose();
    for (final c in _glyphCtrls) c.dispose();
    super.dispose();
  }

  // ── tap handler ───────────────────────────────

  void _onTap(TapDownDetails details) {
    if (_revealed || _checking) return;
    setState(() {
      _revealed = true;
      _rippleX = details.globalPosition.dx;
      _rippleY = details.globalPosition.dy;
    });
    HapticFeedback.lightImpact();
    _rippleCtrl.forward(from: 0);
    _flashCtrl.forward(from: 0);
    _preOutCtrl.forward();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _postInCtrl.forward();
    });
  }

  // ── animations ────────────────────────────────

  Animation<double> get _logoScale => TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
  ]).animate(_logoCtrl);

  Animation<double> get _logoOpacity => Tween(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.3)));

  Animation<double> get _typeProgress =>
      CurvedAnimation(parent: _typeCtrl, curve: Curves.linear);

  Animation<double> get _subtitleOpacity =>
      CurvedAnimation(parent: _subtitleCtrl, curve: Curves.easeOut);

  Animation<double> get _hintScale => Tween(
    begin: 1.0,
    end: 1.22,
  ).animate(CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut));

  Animation<double> get _hintOpacity => Tween(
    begin: 0.55,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _hintCtrl, curve: Curves.easeInOut));

  Animation<double> get _rippleScale =>
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut);

  Animation<double> get _rippleOpacity => Tween(
    begin: 1.0,
    end: 0.0,
  ).animate(CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeIn));

  Animation<double> get _flashOpacity => TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 28),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 72),
  ]).animate(_flashCtrl);

  Animation<double> get _preOpacity => Tween(
    begin: 1.0,
    end: 0.0,
  ).animate(CurvedAnimation(parent: _preOutCtrl, curve: Curves.easeIn));

  Animation<Offset> get _preSlide => Tween(
    begin: Offset.zero,
    end: const Offset(0, -0.05),
  ).animate(CurvedAnimation(parent: _preOutCtrl, curve: Curves.easeIn));

  Animation<double> get _postOpacity => CurvedAnimation(
    parent: _postInCtrl,
    curve: const Interval(0, 0.8, curve: Curves.easeOut),
  );

  Animation<Offset> get _postSlide => Tween(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _postInCtrl, curve: Curves.easeOut));

  // ── build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // While checking auth — plain cream screen with logo
    if (_checking) {
      return Scaffold(
        backgroundColor: _C.cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _logoWidget(100),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: _C.gold,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.cream,
      body: GestureDetector(
        onTapDown: _revealed ? null : _onTap,
        child: Stack(
          children: [
            // floating hieroglyphs
            ..._buildGlyphs(size),

            // corner ornaments
            _orn(true, true, false),
            _orn(false, true, false),
            _orn(true, false, false),
            _orn(false, false, false),

            // gold flash
            AnimatedBuilder(
              animation: _flashCtrl,
              builder: (_, __) => Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _flashOpacity.value * 0.65,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.8,
                          colors: [Color(0x50C5A059), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ripple
            AnimatedBuilder(
              animation: _rippleCtrl,
              builder: (_, __) {
                if (_rippleCtrl.value == 0) return const SizedBox.shrink();
                final maxR = size.longestSide * 1.4;
                final r = maxR * _rippleScale.value;
                return Positioned(
                  left: _rippleX - r / 2,
                  top: _rippleY - r / 2,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _rippleOpacity.value * 0.4,
                      child: Container(
                        width: r,
                        height: r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x60C5A059), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── pre-tap block ──
            AnimatedBuilder(
              animation: Listenable.merge([
                _preOutCtrl,
                _logoCtrl,
                _typeCtrl,
                _subtitleCtrl,
                _hintCtrl,
              ]),
              builder: (_, __) {
                if (_revealed && _preOutCtrl.isCompleted)
                  return const SizedBox.shrink();
                return FadeTransition(
                  opacity: _revealed
                      ? _preOpacity
                      : const AlwaysStoppedAnimation(1.0),
                  child: SlideTransition(
                    position: _revealed
                        ? _preSlide
                        : const AlwaysStoppedAnimation(Offset.zero),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // logo bounce-in
                          FadeTransition(
                            opacity: _logoOpacity,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: _logoWidget(110),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // typewriter title
                          AnimatedBuilder(
                            animation: _typeCtrl,
                            builder: (_, __) {
                              const full = 'TOURASNA';
                              final n = (full.length * _typeProgress.value)
                                  .floor();
                              return Text(
                                full.substring(0, n),
                                style: const TextStyle(
                                  fontFamily: 'Gambetta',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 34,
                                  letterSpacing: 10,
                                  color: _C.teal,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // subtitle
                          FadeTransition(
                            opacity: _subtitleOpacity,
                            child: const Text(
                              'Unlock Ancient Secrets',
                              style: TextStyle(
                                fontFamily: 'Gambetta',
                                fontStyle: FontStyle.italic,
                                fontSize: 16,
                                color: _C.gold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 56),

                          // tap hint
                          FadeTransition(
                            opacity: _subtitleOpacity,
                            child: AnimatedBuilder(
                              animation: _hintCtrl,
                              builder: (_, __) => Column(
                                children: [
                                  Transform.scale(
                                    scale: _hintScale.value,
                                    child: Opacity(
                                      opacity: _hintOpacity.value,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _C.gold.withOpacity(0.45),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _C.gold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'TAP TO BEGIN',
                                    style: TextStyle(
                                      fontFamily: 'Satoshi',
                                      fontSize: 9,
                                      letterSpacing: 3,
                                      color: _C.teal.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── post-tap block ──
            if (_revealed)
              AnimatedBuilder(
                animation: _postInCtrl,
                builder: (_, __) => FadeTransition(
                  opacity: _postOpacity,
                  child: SlideTransition(
                    position: _postSlide,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _logoWidget(62),
                            const SizedBox(height: 14),

                            const Text(
                              'TOURASNA',
                              style: TextStyle(
                                fontFamily: 'Gambetta',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 6,
                                color: _C.teal,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // divider
                            Row(
                              children: [
                                Expanded(child: _line()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    '𓂀',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _C.gold.withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                Expanded(child: _line()),
                              ],
                            ),
                            const SizedBox(height: 22),

                            Text(
                              'Your divine guide\nthrough ancient Egypt awaits',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Gambetta',
                                fontStyle: FontStyle.italic,
                                fontSize: 15,
                                color: _C.teal.withOpacity(0.55),
                                height: 1.65,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Sign In
                            _PrimaryBtn(
                              label: 'SIGN IN',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/login'),
                            ),
                            const SizedBox(height: 12),

                            // Register
                            _GhostBtn(
                              label: 'CREATE ACCOUNT',
                              onTap: () =>
                                  Navigator.pushNamed(context, '/signup'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── helpers ───────────────────────────────────

  Widget _logoWidget(double size) => SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      'assets/images/icon.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: _C.teal),
        child: Center(
          child: Text(
            '𓆣',
            style: TextStyle(fontSize: size * 0.45, color: _C.gold),
          ),
        ),
      ),
    ),
  );

  Widget _line() => Container(
    height: 1,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.transparent, Color(0x70C5A059), Colors.transparent],
      ),
    ),
  );

  Widget _orn(bool left, bool top, bool _) => Positioned(
    top: top ? 20 : null,
    bottom: !top ? 20 : null,
    left: left ? 20 : null,
    right: !left ? 20 : null,
    child: Opacity(
      opacity: _revealed ? 0.08 : 0.20,
      child: Transform.scale(
        scaleX: left ? 1 : -1,
        scaleY: top ? 1 : -1,
        child: const Text('𓏤', style: TextStyle(fontSize: 20, color: _C.gold)),
      ),
    ),
  );

  List<Widget> _buildGlyphs(Size size) => List.generate(_layout.length, (i) {
    final g = _layout[i];
    return AnimatedBuilder(
      animation: _glyphCtrls[i],
      builder: (_, __) {
        final t = _glyphCtrls[i].value;
        final dy = sin(t * pi) * -20;
        final rot = sin(t * pi) * 0.07;
        final op = _revealed ? 0.08 : (sin(t * pi) * 0.40).clamp(0.0, 0.40);
        return Positioned(
          top: size.height * g.top + dy,
          left: size.width * g.left,
          child: Opacity(
            opacity: op,
            child: Transform.rotate(
              angle: rot,
              child: Text(
                g.ch,
                style: TextStyle(fontSize: g.size, color: _C.teal),
              ),
            ),
          ),
        );
      },
    );
  });
}

// ── buttons ───────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});

  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapUp: (_) {
      setState(() => _down = false);
      widget.onTap();
    },
    onTapCancel: () => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: _C.teal,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _C.teal.withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 3,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

class _GhostBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostBtn({required this.label, required this.onTap});

  @override
  State<_GhostBtn> createState() => _GhostBtnState();
}

class _GhostBtnState extends State<_GhostBtn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapUp: (_) {
      setState(() => _down = false);
      widget.onTap();
    },
    onTapCancel: () => setState(() => _down = false),
    child: AnimatedScale(
      scale: _down ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.teal.withOpacity(0.22), width: 1.5),
        ),
        child: Center(
          child: Text(
            widget.label,
            style: const TextStyle(
              fontFamily: 'Satoshi',
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 3,
              color: _C.teal,
            ),
          ),
        ),
      ),
    ),
  );
}
