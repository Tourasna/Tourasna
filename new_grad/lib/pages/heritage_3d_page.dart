import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/place.dart';
import '../services/three_d_model_service.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color kBg = Color(0xFFF2EADC);
const Color kTeal = Color(0xFF1A3C3C);
const Color kGold = Color(0xFFC5A059);
const Color kGoldAlt = Color(0xFFD4AF37);
const Color kInputBg = Color(0xFFEAE2D1);
const Color kCardBg = Color(0x99FFFFFF);

const TextStyle kSerif = TextStyle(fontFamily: 'Gambetta', color: kTeal);
const TextStyle kSans = TextStyle(fontFamily: 'Satoshi', color: kTeal);

// ─── Generation state ─────────────────────────────────────────────────────────
enum _GenState { requesting, generating, shapeReady, textured, failed }

// ─── Page ─────────────────────────────────────────────────────────────────────
class Heritage3DPage extends StatefulWidget {
  final Place place;
  final String className;
  final int classIndex;
  final String imageB64;

  const Heritage3DPage({
    super.key,
    required this.place,
    required this.className,
    required this.classIndex,
    required this.imageB64,
  });

  @override
  State<Heritage3DPage> createState() => _Heritage3DPageState();
}

class _Heritage3DPageState extends State<Heritage3DPage> {
  final _svc = ThreeDModelService();

  _GenState _genState = _GenState.requesting;
  WebViewController? _webCtrl;
  String? _glbUrl;
  double _zoom = 1.0;
  bool _autoSpin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startGeneration());
  }

  // ── generation lifecycle ───────────────────────────────────────────────────

  Future<void> _startGeneration() async {
    setState(() => _genState = _GenState.requesting);
    try {
      final status = await _svc.requestModel(
        widget.className,
        widget.classIndex,
        widget.imageB64,
      );

      if (!mounted) return;

      if ((status.state == ModelState.shapeReady ||
              status.state == ModelState.textured) &&
          status.bestUrl != null) {
        final isTextured = status.state == ModelState.textured;
        _loadWebView(
          status.bestUrl!,
          isTextured ? _GenState.textured : _GenState.shapeReady,
        );
        if (!isTextured) _pollTexture();
        return;
      }

      if (status.state == ModelState.failed ||
          status.state == ModelState.notFound) {
        setState(() => _genState = _GenState.failed);
        return;
      }

      setState(() => _genState = _GenState.generating);
      _pollShape();
    } catch (_) {
      if (mounted) setState(() => _genState = _GenState.failed);
    }
  }

  Future<void> _pollShape() async {
    final status = await _svc.pollUntilShapeReady(widget.className);
    if (!mounted) return;
    if (status.hasModel && status.bestUrl != null) {
      _loadWebView(status.bestUrl!, _GenState.shapeReady);
      _pollTexture();
    } else {
      setState(() => _genState = _GenState.failed);
    }
  }

  Future<void> _pollTexture() async {
    final status = await _svc.pollForTexture(widget.className);
    if (!mounted) return;
    if (status.textureUrl != null) {
      _webCtrl?.runJavaScript(
        "setModel('${Uri.encodeFull(status.textureUrl!)}');",
      );
      setState(() {
        _genState = _GenState.textured;
        _glbUrl = status.textureUrl;
      });
    }
  }

  void _loadWebView(String url, _GenState nextState) {
    final ctrl = WebViewController();
    ctrl
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            ctrl.runJavaScript("setModel('${Uri.encodeFull(url)}');");
            _applyAutoSpin(_autoSpin, ctrl);
            _applyZoom(_zoom, ctrl);
          },
        ),
      )
      ..loadFlutterAsset('assets/html/3d_viewer.html');

    setState(() {
      _webCtrl = ctrl;
      _glbUrl = url;
      _genState = nextState;
    });
  }

  // ── WebView controls ───────────────────────────────────────────────────────

  void _applyZoom(double zoom, [WebViewController? ctrl]) {
    final c = ctrl ?? _webCtrl;
    final fov = (45.0 / zoom).clamp(10.0, 90.0);
    c?.runJavaScript(
      "var mv=document.querySelector('model-viewer');"
      "if(mv)mv.fieldOfView='${fov.toStringAsFixed(1)}deg';",
    );
  }

  void _applyAutoSpin(bool spin, [WebViewController? ctrl]) {
    final c = ctrl ?? _webCtrl;
    if (spin) {
      c?.runJavaScript(
        "var mv=document.querySelector('model-viewer');"
        "if(mv)mv.setAttribute('auto-rotate','');",
      );
    } else {
      c?.runJavaScript(
        "var mv=document.querySelector('model-viewer');"
        "if(mv)mv.removeAttribute('auto-rotate');",
      );
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Stack(
          children: [
            // Papyrus texture
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.15,
                  child: Image.network(
                    'https://www.transparenttextures.com/patterns/handmade-paper.png',
                    repeat: ImageRepeat.repeat,
                    fit: BoxFit.none,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            // Grain
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.04,
                  child: CustomPaint(painter: _NoisePainter()),
                ),
              ),
            ),

            Column(
              children: [
                _Header(place: widget.place, genState: _genState),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _ViewerSection(
                          genState: _genState,
                          webCtrl: _webCtrl,
                          zoom: _zoom,
                          onRetry: _startGeneration,
                        ),
                        const SizedBox(height: 20),
                        _ToolsetSection(
                          zoom: _zoom,
                          autoSpin: _autoSpin,
                          modelLoaded: _webCtrl != null,
                          genState: _genState,
                          onZoomChanged: (v) {
                            setState(() => _zoom = v);
                            _applyZoom(v);
                          },
                          onAutoSpinToggle: () {
                            setState(() => _autoSpin = !_autoSpin);
                            _applyAutoSpin(_autoSpin);
                          },
                          onReset: () {
                            setState(() {
                              _zoom = 1.0;
                              _autoSpin = true;
                            });
                            _applyZoom(1.0);
                            _applyAutoSpin(true);
                          },
                        ),
                        const SizedBox(height: 32),
                        _DescriptionSection(place: widget.place),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Place place;
  final _GenState genState;
  const _Header({required this.place, required this.genState});

  static Color _badgeColor(_GenState s) {
    switch (s) {
      case _GenState.textured:
        return kGoldAlt;
      case _GenState.shapeReady:
        return kGold;
      case _GenState.generating:
        return kGold;
      case _GenState.failed:
        return Colors.redAccent;
      default:
        return kTeal;
    }
  }

  static String _badgeLabel(_GenState s) {
    switch (s) {
      case _GenState.textured:
        return '✦ Textured';
      case _GenState.shapeReady:
        return '◈ Shape Ready';
      case _GenState.generating:
        return 'Generating...';
      case _GenState.failed:
        return '✕ Failed';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.category.toUpperCase(),
                  style: kSans.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: kGold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  place.name,
                  style: kSerif.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                if (genState != _GenState.requesting)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (genState == _GenState.generating)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 9,
                              height: 9,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  kGold,
                                ),
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _badgeColor(genState).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _badgeColor(genState).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            _badgeLabel(genState),
                            style: kSans.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _badgeColor(genState),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              _HeaderBtn(
                icon: Icons.info_outline_rounded,
                onTap: () => _showInfo(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              place.name,
              style: kSerif.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              place.description,
              style: kSans.copyWith(
                fontSize: 13,
                height: 1.6,
                color: kTeal.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: kGold.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: kTeal.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 16, color: kTeal),
      ),
    );
  }
}

// ─── Viewer Section ───────────────────────────────────────────────────────────
class _ViewerSection extends StatelessWidget {
  final _GenState genState;
  final WebViewController? webCtrl;
  final double zoom;
  final VoidCallback onRetry;

  const _ViewerSection({
    required this.genState,
    required this.webCtrl,
    required this.zoom,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final modelLoaded = webCtrl != null;

    return SizedBox(
      height: modelLoaded ? 320 : 380,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient glow ──────────────────────────────────────────────────
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              width: modelLoaded ? 400 : 320,
              height: modelLoaded ? 400 : 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kGoldAlt.withOpacity(modelLoaded ? 0.22 : 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Outer ring ────────────────────────────────────────────────────
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              width: modelLoaded ? 360 : 280,
              height: modelLoaded ? 360 : 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: kGoldAlt.withOpacity(modelLoaded ? 0.25 : 0.15),
                  width: modelLoaded ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: kGoldAlt.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // ── Inner ring ────────────────────────────────────────────────────
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              width: modelLoaded ? 260 : 200,
              height: modelLoaded ? 260 : 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kGoldAlt.withOpacity(0.12)),
              ),
            ),
          ),

          // ── Light ray ─────────────────────────────────────────────────────
          Positioned(
            right: MediaQuery.of(context).size.width * 0.2,
            top: 0,
            bottom: 0,
            child: Transform.rotate(
              angle: 35 * 3.14159 / 180,
              child: Container(
                width: 1.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x44FFFFFF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Core: WebView OR loading circle ───────────────────────────────
          if (modelLoaded)
            Positioned(
              top: 20,
              bottom: 20,
              left: 24,
              right: 24,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: WebViewWidget(controller: webCtrl!),
              ),
            )
          else
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: ClipOval(child: _loadingContent()),
              ),
            ),

          // ── Gold bottom line ──────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, kGoldAlt, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Drag hint ─────────────────────────────────────────────────────
          if (modelLoaded)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kTeal.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kGoldAlt.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_with_rounded, size: 11, color: kGoldAlt),
                      const SizedBox(width: 6),
                      Text(
                        'DRAG TO ROTATE',
                        style: kSans.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Texturing badge ───────────────────────────────────────────────
          if (genState == _GenState.shapeReady && modelLoaded)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kGoldAlt.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 8,
                      height: 8,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(kGoldAlt),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TEXTURING',
                      style: kSans.copyWith(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: kGoldAlt,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Textured badge ────────────────────────────────────────────────
          if (genState == _GenState.textured && modelLoaded)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: kGoldAlt.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kGoldAlt.withOpacity(0.5)),
                ),
                child: Text(
                  '✦ TEXTURED',
                  style: kSans.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: kGoldAlt,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadingContent() {
    if (genState == _GenState.generating || genState == _GenState.requesting) {
      return Container(
        decoration: BoxDecoration(
          color: kTeal.withOpacity(0.06),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(kGoldAlt),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'GENERATING',
              style: kSans.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: kGoldAlt.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '3D MODEL',
              style: kSans.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: kTeal.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '8–25 min',
              style: kSans.copyWith(
                fontSize: 10,
                color: kGold.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (genState == _GenState.failed) {
      return Container(
        decoration: BoxDecoration(
          color: kTeal.withOpacity(0.06),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: kTeal.withOpacity(0.3),
            ),
            const SizedBox(height: 10),
            Text(
              'Failed',
              style: kSans.copyWith(
                fontSize: 11,
                color: kTeal.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: kGoldAlt.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kGoldAlt.withOpacity(0.5)),
                ),
                child: Text(
                  'RETRY',
                  style: kSans.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: kGoldAlt,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kTeal.withOpacity(0.04),
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.view_in_ar_rounded,
            size: 52,
            color: kGoldAlt.withOpacity(0.4),
          ),
          const SizedBox(height: 10),
          Text(
            '3D MODEL',
            style: kSans.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
              color: kTeal.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Toolset Section ──────────────────────────────────────────────────────────
class _ToolsetSection extends StatelessWidget {
  final double zoom;
  final bool autoSpin;
  final bool modelLoaded;
  final _GenState genState;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onAutoSpinToggle;
  final VoidCallback onReset;

  const _ToolsetSection({
    required this.zoom,
    required this.autoSpin,
    required this.modelLoaded,
    required this.genState,
    required this.onZoomChanged,
    required this.onAutoSpinToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: modelLoaded ? 1.0 : 0.4,
        child: Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: kGoldAlt.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: kTeal.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MAGNIFICATION',
                    style: kSans.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: kGold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${zoom.toStringAsFixed(1)}x',
                        style: kSans.copyWith(
                          fontSize: 10,
                          color: kTeal.withOpacity(0.6),
                        ),
                      ),
                      if (!modelLoaded) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kTeal.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            genState == _GenState.generating
                                ? 'GENERATING'
                                : 'AWAITING MODEL',
                            style: kSans.copyWith(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: kTeal.withOpacity(0.35),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Zoom slider ───────────────────────────────────────────────
              Row(
                children: [
                  _ZoomBtn(
                    icon: Icons.remove,
                    onTap: modelLoaded
                        ? () => onZoomChanged(
                            double.parse(
                              ((zoom - 0.1).clamp(0.5, 3.0)).toStringAsFixed(1),
                            ),
                          )
                        : () {},
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: kGoldAlt,
                        inactiveTrackColor: kTeal.withOpacity(0.1),
                        thumbColor: kGoldAlt,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayColor: kGoldAlt.withOpacity(0.15),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: zoom,
                        min: 0.5,
                        max: 3.0,
                        onChanged: modelLoaded ? onZoomChanged : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ZoomBtn(
                    icon: Icons.add,
                    onTap: modelLoaded
                        ? () => onZoomChanged(
                            double.parse(
                              ((zoom + 0.1).clamp(0.5, 3.0)).toStringAsFixed(1),
                            ),
                          )
                        : () {},
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Action buttons ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.refresh_rounded,
                      label: autoSpin ? 'SPINNING' : 'AUTO-SPIN',
                      active: autoSpin,
                      onTap: modelLoaded ? onAutoSpinToggle : () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.grid_view_rounded,
                      label: 'RESET',
                      active: false,
                      onTap: modelLoaded ? onReset : () {},
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

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: kTeal.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: kTeal),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: active ? kGoldAlt : kTeal.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: active ? null : Border.all(color: kTeal.withOpacity(0.1)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: kGoldAlt.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? Colors.white : kTeal),
            const SizedBox(height: 6),
            Text(
              label,
              style: kSans.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: active ? Colors.white : kTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Description Section ──────────────────────────────────────────────────────
class _DescriptionSection extends StatelessWidget {
  final Place place;
  const _DescriptionSection({required this.place});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Container(
          color: kTeal,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.10,
                  child: CustomPaint(painter: _GridPatternPainter()),
                ),
              ),
              Positioned(
                top: -40,
                right: -40,
                child: Opacity(
                  opacity: 0.05,
                  child: Icon(
                    Icons.filter_vintage_rounded,
                    size: 200,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: kGoldAlt.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        size: 24,
                        color: kGoldAlt,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      place.name,
                      style: kSerif.copyWith(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF2EADC),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      place.description.isNotEmpty
                          ? place.description
                          : 'No description available.',
                      style: kSans.copyWith(
                        fontSize: 12,
                        color: const Color(0xFFF2EADC).withOpacity(0.6),
                        height: 1.65,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Painters ─────────────────────────────────────────────────────────────────
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const step = 30.0;
    for (double x = 0; x <= size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y <= size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kTeal.withOpacity(0.3)
      ..strokeWidth = 0.5;
    const spacing = 4.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        if ((x.toInt() + y.toInt()) % 8 == 0)
          canvas.drawCircle(Offset(x, y), 0.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
