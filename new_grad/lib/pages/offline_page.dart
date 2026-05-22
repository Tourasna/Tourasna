import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

// ── palette ───────────────────────────────────────────────────────────────────
class _C {
  static const papyrus = Color(0xFFF2EADC);
  static const teal = Color(0xFF1A3C3C);
  static const gold = Color(0xFFC5A059);
  static const nightBg = Color(0xFF0D1F1F);
  static const nightTeal = Color(0xFFB8C9C9);
  static const silver = Color(0xFFB8B8C8);
}

// ── obstacle types ────────────────────────────────────────────────────────────
enum _ObstacleType { canopicJar, sarcophagus, obelisk, falcon }

class _Obstacle {
  double x;
  double y;
  final _ObstacleType type;

  _Obstacle({required this.x, required this.y, required this.type});

  double get w {
    switch (type) {
      case _ObstacleType.canopicJar:
        return 28;
      case _ObstacleType.sarcophagus:
        return 48;
      case _ObstacleType.obelisk:
        return 22;
      case _ObstacleType.falcon:
        return 36;
    }
  }

  double get h {
    switch (type) {
      case _ObstacleType.canopicJar:
        return 44;
      case _ObstacleType.sarcophagus:
        return 28;
      case _ObstacleType.obelisk:
        return 56;
      case _ObstacleType.falcon:
        return 28;
    }
  }

  String get emoji {
    switch (type) {
      case _ObstacleType.canopicJar:
        return '🏺';
      case _ObstacleType.sarcophagus:
        return '⚱️';
      case _ObstacleType.obelisk:
        return '🗿';
      case _ObstacleType.falcon:
        return '🦅';
    }
  }

  double get fontSize {
    switch (type) {
      case _ObstacleType.canopicJar:
        return 30;
      case _ObstacleType.sarcophagus:
        return 26;
      case _ObstacleType.obelisk:
        return 28;
      case _ObstacleType.falcon:
        return 28;
    }
  }
}

// ── page ──────────────────────────────────────────────────────────────────────
class OfflinePage extends StatefulWidget {
  final String returnRoute;
  final Object? returnArguments;

  const OfflinePage({
    super.key,
    required this.returnRoute,
    this.returnArguments,
  });

  @override
  State<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends State<OfflinePage>
    with SingleTickerProviderStateMixin {
  static const double _gravity = 2800.0;
  static const double _jumpVelocity = 820.0;
  static const double _groundY = 0.0;
  static const double _groundOff = 56.0;
  static const double _scarabLeft = 56.0;
  static const double _scarabW = 38.0;
  static const double _scarabH = 38.0;
  static const double _initialSpeed = 220.0;
  static const double _maxSpeed = 560.0;
  static const double _speedInc = 8.0;
  static const List<double> _falconHeights = [70, 110, 150];

  bool _gameActive = false;
  bool _gameOver = false;
  int _score = 0;
  double _scarabY = _groundY;
  double _velY = 0.0;
  double _speed = _initialSpeed;
  bool _isNight = false;
  double _nightBlend = 0.0;

  final List<_Obstacle> _obstacles = [];
  final _rng = Random();

  late AnimationController _ticker;
  Timer? _spawnTimer;
  DateTime _lastFrame = DateTime.now();
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_gameLoop);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _spawnTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _gameActive = true;
      _gameOver = false;
      _score = 0;
      _scarabY = _groundY;
      _velY = 0;
      _speed = _initialSpeed;
      _isNight = false;
      _nightBlend = 0.0;
      _obstacles.clear();
    });
    _lastFrame = DateTime.now();
    _ticker.repeat();
    _scheduleNext();
  }

  void _scheduleNext() {
    _spawnTimer?.cancel();
    if (!_gameActive) return;
    final gapMs = (2200 - (_speed - _initialSpeed) * 2)
        .clamp(800, 2200)
        .toInt();
    _spawnTimer = Timer(Duration(milliseconds: gapMs), () {
      if (_gameActive) {
        _spawnObstacle();
        _scheduleNext();
      }
    });
  }

  void _spawnObstacle() {
    if (!_gameActive || !mounted) return;
    final falconChance = (_score >= 200) ? 0.30 : 0.0;
    final roll = _rng.nextDouble();
    _ObstacleType type;
    double yPos = 0;
    if (roll < falconChance) {
      type = _ObstacleType.falcon;
      yPos = _falconHeights[_rng.nextInt(_falconHeights.length)];
    } else {
      final groundTypes = [
        _ObstacleType.canopicJar,
        _ObstacleType.sarcophagus,
        _ObstacleType.obelisk,
      ];
      type = groundTypes[_rng.nextInt(groundTypes.length)];
      yPos = 0;
    }
    final arenaW = MediaQuery.of(context).size.width - 48;
    setState(
      () => _obstacles.add(_Obstacle(x: arenaW + 10, y: yPos, type: type)),
    );
  }

  void _jump() {
    if (!_gameActive) return;
    if (_scarabY > 2.0) return;
    setState(() => _velY = _jumpVelocity);
    HapticFeedback.lightImpact();
  }

  void _gameLoop() {
    if (!_gameActive || !mounted) return;
    final now = DateTime.now();
    final dt = now.difference(_lastFrame).inMicroseconds / 1e6;
    _lastFrame = now;

    setState(() {
      _velY -= _gravity * dt;
      _scarabY = (_scarabY + _velY * dt).clamp(_groundY, 1000.0);
      if (_scarabY <= _groundY) {
        _scarabY = _groundY;
        _velY = 0;
      }

      _speed = (_speed + _speedInc * dt).clamp(_initialSpeed, _maxSpeed);

      if (_score >= 500 && _nightBlend < 1.0) {
        _nightBlend = (_nightBlend + dt * 0.8).clamp(0.0, 1.0);
        _isNight = _nightBlend > 0.5;
      }

      for (final obs in _obstacles) {
        obs.x -= _speed * dt;
      }

      _obstacles.removeWhere((obs) {
        if (obs.x < -obs.w - 20) {
          _score += 10;
          return true;
        }
        return false;
      });

      _checkCollision();
    });
  }

  void _checkCollision() {
    const shrink = 7.0;
    final sL = _scarabLeft + shrink;
    final sR = _scarabLeft + _scarabW - shrink;
    final sB = _groundOff + _scarabY + shrink;
    final sT = _groundOff + _scarabY + _scarabH - shrink;

    for (final obs in _obstacles) {
      final rL = obs.x + shrink;
      final rR = obs.x + obs.w - shrink;
      final rB = _groundOff + obs.y + shrink;
      final rT = _groundOff + obs.y + obs.h - shrink;
      if (sR > rL && sL < rR && sT > rB && sB < rT) {
        _endGame();
        return;
      }
    }
  }

  void _endGame() {
    _gameActive = false;
    _gameOver = true;
    _ticker.stop();
    _spawnTimer?.cancel();
    HapticFeedback.heavyImpact();
  }

  Future<void> _tryReconnect() async {
    setState(() => _checking = true);
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 3));
      if (!mounted) return;
      if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
        Navigator.pushReplacementNamed(
          context,
          widget.returnRoute,
          arguments: widget.returnArguments,
        );
      } else {
        setState(() => _checking = false);
        _showStillOfflineSnackbar();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      _showStillOfflineSnackbar();
    }
  }

  void _showStillOfflineSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'Still offline. Try again.',
              style: TextStyle(
                fontFamily: 'Satoshi',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: _C.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Color _lerp(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  Color get _bgColor => _lerp(_C.papyrus, _C.nightBg, _nightBlend);
  Color get _accentColor => _lerp(_C.gold, _C.silver, _nightBlend);
  Color get _textColor => _lerp(_C.teal, _C.nightTeal, _nightBlend);
  Color get _arenaBg => _lerp(
    Colors.white.withOpacity(0.4),
    Colors.white.withOpacity(0.05),
    _nightBlend,
  );

  List<Widget> _buildStars() {
    final positions = [
      [0.15, 0.7],
      [0.30, 0.85],
      [0.50, 0.75],
      [0.65, 0.90],
      [0.80, 0.80],
      [0.20, 0.60],
      [0.45, 0.65],
      [0.70, 0.70],
      [0.10, 0.50],
      [0.90, 0.55],
      [0.55, 0.55],
      [0.35, 0.45],
    ];
    final arenaW = MediaQuery.of(context).size.width - 48;
    return positions
        .map(
          (p) => Positioned(
            left: arenaW * p[0],
            bottom: 200.0 * p[1],
            child: Opacity(
              opacity: _nightBlend * 0.6,
              child: const Text(
                '✦',
                style: TextStyle(fontSize: 8, color: Colors.white),
              ),
            ),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    _isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                    color: _accentColor,
                    size: 24,
                  ),
                  Text(
                    'SCORE : $_score',
                    style: TextStyle(
                      fontFamily: 'Satoshi',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                      color: _accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text(
                'OFFLINE MODE',
                style: TextStyle(
                  fontFamily: 'Satoshi',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: _accentColor.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'No Connection',
                style: TextStyle(
                  fontFamily: 'Gambetta',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your journey is paused. Guide our sacred scarab while we find your path.',
                style: TextStyle(
                  fontFamily: 'Gambetta',
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: _textColor.withOpacity(0.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    if (!_gameActive && !_gameOver)
                      _startGame();
                    else if (_gameActive)
                      _jump();
                    else if (_gameOver)
                      _startGame();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _arenaBg,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: _accentColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _textColor.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        children: [
                          if (_isNight) ..._buildStars(),

                          Positioned(
                            bottom: _groundOff,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1.5,
                              color: _accentColor.withOpacity(0.3),
                            ),
                          ),

                          Positioned(
                            bottom: _groundOff + _scarabY,
                            left: _scarabLeft,
                            child: const Text(
                              '🪲',
                              style: TextStyle(fontSize: 32),
                            ),
                          ),

                          ..._obstacles.map(
                            (obs) => Positioned(
                              bottom: _groundOff + obs.y,
                              left: obs.x,
                              child: Text(
                                obs.emoji,
                                style: TextStyle(fontSize: obs.fontSize),
                              ),
                            ),
                          ),

                          if (!_gameActive && !_gameOver)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: _textColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _accentColor.withOpacity(0.4),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_upward_rounded,
                                        color: _accentColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'TAP TO BEGIN TRIAL',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.5,
                                        color: _textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '🦅 falcon appears after 200pts',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 8,
                                        letterSpacing: 1.0,
                                        color: _textColor.withOpacity(0.45),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '🌙 night falls after 500pts',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontSize: 8,
                                        letterSpacing: 1.0,
                                        color: _textColor.withOpacity(0.45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (_gameOver)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 20,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _bgColor.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: _accentColor.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'SANDSTORM DETECTED',
                                          style: TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2.0,
                                            color: _textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Legacy: $_score',
                                          style: TextStyle(
                                            fontFamily: 'Gambetta',
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: _accentColor,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        GestureDetector(
                                          onTap: _startGame,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _textColor,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'RETRY JOURNEY',
                                              style: TextStyle(
                                                fontFamily: 'Satoshi',
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 2.0,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: _checking ? null : _tryReconnect,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: double.infinity,
                  height: 58,
                  decoration: BoxDecoration(
                    color: _textColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _textColor.withOpacity(0.28),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: _accentColor,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'TRY TO RECONNECT',
                                style: TextStyle(
                                  fontFamily: 'Satoshi',
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Center(
                child: Text(
                  'TOURATHNA 2026',
                  style: TextStyle(
                    fontFamily: 'Satoshi',
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.0,
                    color: _accentColor.withOpacity(0.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
