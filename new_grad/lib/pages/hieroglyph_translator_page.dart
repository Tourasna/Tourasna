import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/hieroglyphics_service.dart';

// ─────────────────────────────────────────────
//  COLOUR PALETTE
// ─────────────────────────────────────────────
class _C {
  static const bg = Color(0xFFEDE8DC);
  static const dark = Color(0xFF1A3C3C);
  static const gold = Color(0xFFD4AF37);
  static const bronze = Color(0xFFC5A059);
  static const cream = Color(0xFFF2EADC);
  static const amber = Color(0xFFFCD34D);
  static const white = Colors.white;
}

// ─────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────
enum ReadingDirection { rtl, ltr, ttb }

class HieroglyphSymbol {
  final String id;
  String name;
  String meaning;
  IconData icon;
  int confidence;
  bool needsReview;

  HieroglyphSymbol({
    required this.id,
    required this.name,
    required this.meaning,
    required this.icon,
    required this.confidence,
    this.needsReview = false,
  });
}

class AlternativeMatch {
  final String name;
  final String meaning;
  final IconData icon;
  final int confidence;
  const AlternativeMatch({
    required this.name,
    required this.meaning,
    required this.icon,
    required this.confidence,
  });
}

// ─────────────────────────────────────────────
//  STATIC FALLBACK DATA (used only if API fails)
// ─────────────────────────────────────────────
final _mockSymbols = <HieroglyphSymbol>[];
bool _looksLikeGardinerCode(String s) =>
    RegExp(r'^[A-Za-z]{1,2}\d+[a-z]?$').hasMatch(s);
const _alternatives = [
  AlternativeMatch(
    name: 'Owl (M)',
    meaning: 'Watchfulness',
    icon: Icons.remove_red_eye_outlined,
    confidence: 78,
  ),
  AlternativeMatch(
    name: 'Eagle (B)',
    meaning: 'Vision',
    icon: Icons.flight_outlined,
    confidence: 65,
  ),
  AlternativeMatch(
    name: 'Scarab (K)',
    meaning: 'Transformation',
    icon: Icons.autorenew_outlined,
    confidence: 52,
  ),
];

// ─────────────────────────────────────────────
//  ICON MAPPER
// ─────────────────────────────────────────────
IconData _iconForCategory(String category) {
  switch (category) {
    case 'humans':
      return Icons.person_outline;
    case 'birds':
      return Icons.flutter_dash;
    case 'body_parts':
      return Icons.accessibility_new_outlined;
    case 'food':
      return Icons.lunch_dining_outlined;
    case 'water':
      return Icons.water_outlined;
    case 'animals':
      return Icons.pets_outlined;
    case 'plants':
      return Icons.local_florist_outlined;
    case 'buildings':
      return Icons.account_balance_outlined;
    case 'tools':
      return Icons.handyman_outlined;
    case 'symbols':
      return Icons.auto_awesome_outlined;
    default:
      return Icons.help_outline;
  }
}

// ─────────────────────────────────────────────
//  MAIN PAGE
// ─────────────────────────────────────────────
class HieroglyphTranslatorPage extends StatefulWidget {
  const HieroglyphTranslatorPage({super.key});

  @override
  State<HieroglyphTranslatorPage> createState() =>
      _HieroglyphTranslatorPageState();
}

class _HieroglyphTranslatorPageState extends State<HieroglyphTranslatorPage>
    with TickerProviderStateMixin {
  int _step = 1;
  File? _imageFile;
  ReadingDirection _direction = ReadingDirection.rtl;
  late List<HieroglyphSymbol> _symbols;
  bool _processing = false;
  HieroglyphicsResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _symbols = List.from(_mockSymbols);
  }

  void _goToStep(int s) => setState(() => _step = s);

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _errorMessage = null;
      });
    }
  }

  Future<void> _processFragment() async {
    if (_imageFile == null) return;
    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    try {
      final result = await HieroglyphicsService.translate(
        _imageFile!,
        readingDirection: _direction.name,
      );

      setState(() {
        _processing = false;
        _result = result;

        if (!result.success || result.glyphs.isEmpty) {
          _errorMessage =
              'No hieroglyphs detected. Try a clearer photo with better lighting.';
          return;
        }

        _symbols = result.glyphs.asMap().entries.map((entry) {
          final g = entry.value;
          final signMeaning = result.signMeanings.firstWhere(
            (s) => s.code == g.gardinerCode,
            orElse: () => SignMeaning(
              code: g.gardinerCode,
              meaningEn: '',
              meaningAr: '',
              sound: '',
              category: '',
            ),
          );

          return HieroglyphSymbol(
            id: entry.key.toString(),
            name: g.gardinerCode,
            meaning: signMeaning.meaningEn.isNotEmpty
                ? signMeaning.meaningEn
                : 'Unknown',
            icon: _iconForCategory(signMeaning.category),
            confidence: (g.confidence * 100).round(),
            needsReview: g.confidence < 0.7,
          );
        }).toList();

        _step = 2;
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _C.bg,
                      _C.bg.withOpacity(0.92),
                      const Color(0xFFE8E0CC),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildStepper(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HERITAGE DECODER',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                    color: _C.bronze,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hieroglyph\nTranslator',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: _C.dark,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (_step > 1)
            GestureDetector(
              onTap: () => _goToStep(_step - 1),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.chevron_left, color: _C.dark),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          _StepDot(number: 1, label: 'UPLOAD', state: _stepState(1)),
          Expanded(child: _StepLine(active: _step >= 2)),
          _StepDot(number: 2, label: 'REVIEW', state: _stepState(2)),
          Expanded(child: _StepLine(active: _step >= 3)),
          _StepDot(number: 3, label: 'RESULT', state: _stepState(3)),
        ],
      ),
    );
  }

  _StepState _stepState(int n) {
    if (n < _step) return _StepState.done;
    if (n == _step) return _StepState.active;
    return _StepState.future;
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _Step1Upload(
          key: const ValueKey(1),
          imageFile: _imageFile,
          direction: _direction,
          processing: _processing,
          errorMessage: _errorMessage,
          onPickImage: _pickImage,
          onDirectionChanged: (d) => setState(() => _direction = d),
          onProcess: _processFragment,
        );
      case 2:
        return _Step2Review(
          key: const ValueKey(2),
          symbols: _symbols,
          onFinalize: () => _goToStep(3),
          onRetake: () => _goToStep(1),
          onSymbolUpdated: (updated) {
            setState(() {
              final idx = _symbols.indexWhere((s) => s.id == updated.id);
              if (idx >= 0) _symbols[idx] = updated;
            });
          },
        );
      case 3:
        return _Step3Result(
          key: const ValueKey(3),
          result: _result,
          onNewScan: () {
            setState(() {
              _step = 1;
              _imageFile = null;
              _result = null;
              _errorMessage = null;
              _symbols = List.from(_mockSymbols);
            });
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────
//  STEP 1 – UPLOAD
// ─────────────────────────────────────────────
class _Step1Upload extends StatelessWidget {
  final File? imageFile;
  final ReadingDirection direction;
  final bool processing;
  final String? errorMessage;
  final void Function(ImageSource) onPickImage;
  final void Function(ReadingDirection) onDirectionChanged;
  final VoidCallback onProcess;

  const _Step1Upload({
    super.key,
    required this.imageFile,
    required this.direction,
    required this.processing,
    required this.onPickImage,
    required this.onDirectionChanged,
    required this.onProcess,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Decode the whispers of the Pharaohs.',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: _C.dark.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          _UploadBox(imageFile: imageFile, onPickImage: onPickImage),
          const SizedBox(height: 28),
          _DirectionTip(),
          const SizedBox(height: 20),
          _DirectionSelector(
            selected: direction,
            onChanged: onDirectionChanged,
          ),
          const SizedBox(height: 28),
          _PrimaryButton(
            label: 'PROCESS FRAGMENT',
            icon: Icons.memory,
            loading: processing,
            onPressed: imageFile != null ? onProcess : null,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  final File? imageFile;
  final void Function(ImageSource) onPickImage;
  const _UploadBox({required this.imageFile, required this.onPickImage});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: _C.gold.withOpacity(0.6), width: 1.5),
        borderRadius: BorderRadius.circular(24),
        color: _C.cream.withOpacity(0.5),
      ),
      child: imageFile != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(
                    imageFile!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _GoldChip(
                    label: 'Change',
                    icon: Icons.edit,
                    onTap: () => _showImageSource(context),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.camera_alt_outlined, size: 48, color: _C.gold),
                  const SizedBox(height: 16),
                  Text(
                    'Upload Hieroglyphs',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: _C.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Upload photo from gallery or take a shot',
                    style: TextStyle(
                      fontSize: 12,
                      color: _C.dark.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GoldChip(
                        label: 'GALLERY',
                        icon: Icons.photo_library_outlined,
                        onTap: () => onPickImage(ImageSource.gallery),
                      ),
                      const SizedBox(width: 12),
                      _GoldChip(
                        label: 'CAMERA',
                        icon: Icons.camera_alt_outlined,
                        onTap: () => onPickImage(ImageSource.camera),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  void _showImageSource(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: _C.gold),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                onPickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: _C.gold),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                onPickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GoldChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _C.gold,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _C.dark),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _C.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Direction tip card ───────────────────────
class _DirectionTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.gold.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 14, color: _C.bronze),
              const SizedBox(width: 6),
              Text(
                'HOW TO DETERMINE READING DIRECTION',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: _C.bronze,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: _C.dark.withOpacity(0.75)),
              children: [
                const TextSpan(
                  text:
                      'Look at the direction characters face. Symbols point toward the beginning of the text, so you must read ',
                ),
                TextSpan(
                  text: 'into their faces',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _C.bronze,
                  ),
                ),
                TextSpan(
                  text: ' to follow the story.',
                  style: TextStyle(color: _C.dark.withOpacity(0.75)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              _DirectionIllustration(label: 'RIGHT-TO-LEFT', isRtl: true),
              SizedBox(width: 8),
              _DirectionIllustration(label: 'LEFT-TO-RIGHT', isRtl: false),
              SizedBox(width: 8),
              _DirectionIllustrationTTB(label: 'TOP-TO-BOTTOM'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DirectionIllustration extends StatefulWidget {
  final String label;
  final bool isRtl;
  const _DirectionIllustration({required this.label, required this.isRtl});

  @override
  State<_DirectionIllustration> createState() => _DirectionIllustrationState();
}

class _DirectionIllustrationState extends State<_DirectionIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.gold.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Image.asset(
              widget.isRtl
                  ? 'assets/icons/right_left.png'
                  : 'assets/icons/left_right.png',
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Transform.translate(
                offset: Offset(widget.isRtl ? -_anim.value : _anim.value, 0),
                child: Icon(
                  widget.isRtl ? Icons.arrow_back : Icons.arrow_forward,
                  size: 14,
                  color: _C.bronze,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: _C.dark.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionIllustrationTTB extends StatefulWidget {
  final String label;
  const _DirectionIllustrationTTB({required this.label});

  @override
  State<_DirectionIllustrationTTB> createState() =>
      _DirectionIllustrationTTBState();
}

class _DirectionIllustrationTTBState extends State<_DirectionIllustrationTTB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.gold.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Image.asset(
              'assets/icons/top_bottom.png',
              width: 58,
              height: 58,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 6),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: _C.dark.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Direction Selector ───────────────────────
class _DirectionSelector extends StatelessWidget {
  final ReadingDirection selected;
  final void Function(ReadingDirection) onChanged;
  const _DirectionSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'READING DIRECTION',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: _C.bronze,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _C.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.gold.withOpacity(0.5), width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ReadingDirection>(
              value: selected,
              isExpanded: true,
              dropdownColor: _C.cream,
              icon: Icon(Icons.keyboard_arrow_down, color: _C.gold),
              style: TextStyle(
                color: _C.dark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              items: const [
                DropdownMenuItem(
                  value: ReadingDirection.rtl,
                  child: Text('Right-to-Left (RTL)'),
                ),
                DropdownMenuItem(
                  value: ReadingDirection.ltr,
                  child: Text('Left-to-Right (LTR)'),
                ),
                DropdownMenuItem(
                  value: ReadingDirection.ttb,
                  child: Text('Top-to-Bottom (TTB)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  STEP 2 – REVIEW DETECTIONS
// ─────────────────────────────────────────────
class _Step2Review extends StatelessWidget {
  final List<HieroglyphSymbol> symbols;
  final VoidCallback onFinalize;
  final VoidCallback onRetake;
  final void Function(HieroglyphSymbol) onSymbolUpdated;

  const _Step2Review({
    super.key,
    required this.symbols,
    required this.onFinalize,
    required this.onRetake,
    required this.onSymbolUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Review Detections',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _C.dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${symbols.length} glyph${symbols.length == 1 ? '' : 's'} detected · tap any to refine.',
                style: TextStyle(
                  fontSize: 12,
                  color: _C.dark.withOpacity(0.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              itemCount: symbols.length,
              itemBuilder: (_, i) {
                final sym = symbols[i];
                return _SymbolCard(
                  symbol: sym,
                  onTap: () => _openAlternatives(context, sym),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              _PrimaryButton(
                label: 'FINALIZE & TRANSLATE',
                icon: Icons.auto_awesome,
                onPressed: onFinalize,
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onRetake,
                child: Text(
                  'RETAKE FRAGMENT SCAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: _C.dark.withOpacity(0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAlternatives(BuildContext context, HieroglyphSymbol sym) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlternativesSheet(
        symbol: sym,
        alternatives: _alternatives,
        onAccept: (alt) {
          final updated = HieroglyphSymbol(
            id: sym.id,
            name: alt.name,
            meaning: alt.meaning,
            icon: alt.icon,
            confidence: alt.confidence,
            needsReview: false,
          );
          onSymbolUpdated(updated);
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Symbol Card ──────────────────────────────
class _SymbolCard extends StatelessWidget {
  final HieroglyphSymbol symbol;
  final VoidCallback onTap;
  const _SymbolCard({required this.symbol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final uncertain = symbol.needsReview;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: uncertain ? _C.amber : _C.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.gold, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _C.gold.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ConfidenceBadge(pct: symbol.confidence),
                Icon(
                  uncertain ? Icons.info_outline : Icons.edit_outlined,
                  size: 18,
                  color: uncertain ? _C.dark : _C.bronze,
                ),
              ],
            ),
            const Spacer(),
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: uncertain ? _C.white.withOpacity(0.4) : _C.cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: GlyphIcon.image(
                  symbol.name,
                  size: 44,
                  background: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Text(
                    symbol.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _C.dark,
                    ),
                  ),
                  Text(
                    symbol.meaning,
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: _C.dark.withOpacity(0.6),
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

class _ConfidenceBadge extends StatelessWidget {
  final int pct;
  const _ConfidenceBadge({required this.pct});

  @override
  Widget build(BuildContext context) {
    final isHigh = pct >= 80;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isHigh ? Colors.green.shade100 : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: isHigh ? Colors.green.shade800 : Colors.red.shade700,
        ),
      ),
    );
  }
}

// ── Alternatives Sheet ───────────────────────
class _AlternativesSheet extends StatefulWidget {
  final HieroglyphSymbol symbol;
  final List<AlternativeMatch> alternatives;
  final void Function(AlternativeMatch) onAccept;
  const _AlternativesSheet({
    required this.symbol,
    required this.alternatives,
    required this.onAccept,
  });

  @override
  State<_AlternativesSheet> createState() => _AlternativesSheetState();
}

class _AlternativesSheetState extends State<_AlternativesSheet>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  double _slide = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _navigate(int dir) async {
    setState(() => _slide = dir.toDouble());
    await _ctrl.reverse();
    setState(
      () => _index =
          (_index + dir + widget.alternatives.length) %
          widget.alternatives.length,
    );
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final alt = widget.alternatives[_index];
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.cream,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.gold, width: 2),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Alternative Matches',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _C.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'REFINE DETECTION CONFIDENCE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: _C.bronze,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavBtn(icon: Icons.chevron_left, onTap: () => _navigate(-1)),
              Expanded(
                child: FadeTransition(
                  opacity: _fade,
                  child: Column(
                    children: [
                      _ConfidenceBadge(pct: alt.confidence),
                      const SizedBox(height: 12),
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _C.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _C.gold.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: _looksLikeGardinerCode(alt.name)
                            ? GlyphIcon.image(
                                alt.name,
                                size: 60,
                                background: Colors.transparent,
                              )
                            : Icon(alt.icon, size: 44, color: _C.dark),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        alt.name.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 1,
                          color: _C.dark,
                        ),
                      ),
                      Text(
                        alt.meaning,
                        style: TextStyle(
                          fontSize: 13,
                          color: _C.bronze,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _NavBtn(icon: Icons.chevron_right, onTap: () => _navigate(1)),
            ],
          ),
          const SizedBox(height: 24),
          _PrimaryButton(
            label: 'ACCEPT SYMBOL',
            icon: Icons.check,
            onPressed: () => widget.onAccept(alt),
          ),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _C.white.withOpacity(0.8),
          shape: BoxShape.circle,
          border: Border.all(color: _C.gold.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 20, color: _C.dark),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  STEP 3 – RESULT
// ─────────────────────────────────────────────
class _Step3Result extends StatelessWidget {
  final VoidCallback onNewScan;
  final HieroglyphicsResult? result;

  const _Step3Result({super.key, required this.onNewScan, this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ancient Wisdom Deciphered',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r != null
                ? '${r.glyphCount} glyph${r.glyphCount == 1 ? '' : 's'} decoded · ${r.readingDirection.toUpperCase()}'
                : 'Translation complete.',
            style: TextStyle(fontSize: 12, color: _C.dark.withOpacity(0.55)),
          ),
          const SizedBox(height: 24),

          // English
          _ResultCard(
            tag: 'ENGLISH INTERPRETATION',
            content: r?.english != null
                ? '"${r!.english}"'
                : '"No translation available."',
            dark: false,
          ),
          const SizedBox(height: 20),

          // Cultural context
          if (r?.historicalContextEn != null) ...[
            _CulturalContextCard(contextText: r!.historicalContextEn!),
            const SizedBox(height: 20),
          ],

          // Arabic
          _ResultCard(
            tag: 'الترجمة العربية',
            content: r?.arabic != null ? '"${r!.arabic}"' : '"غير متاح"',
            dark: true,
            rtl: true,
            trailing: GestureDetector(
              onTap: () {
                if (r?.arabic != null) {
                  Clipboard.setData(ClipboardData(text: r!.arabic!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Arabic text copied')),
                  );
                }
              },
              child: Icon(
                Icons.copy_outlined,
                size: 18,
                color: _C.bronze.withOpacity(0.6),
              ),
            ),
          ),

          // Sign breakdown
          if (r != null && r.signMeanings.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'SIGN BREAKDOWN',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: _C.bronze,
              ),
            ),
            const SizedBox(height: 12),
            ...r.signMeanings.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _C.cream.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      // Gardiner code badge
                      GlyphIcon.image(s.code, size: 44),
                      const SizedBox(width: 12),
                      // English meaning + sound
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.meaningEn.isNotEmpty ? s.meaningEn : 'Unknown',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _C.dark,
                              ),
                            ),
                            Text(
                              [
                                if (s.sound.isNotEmpty) s.sound,
                                if (s.category.isNotEmpty) s.category,
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 10,
                                color: _C.dark.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arabic meaning
                      if (s.meaningAr.isNotEmpty)
                        Text(
                          s.meaningAr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 12,
                            color: _C.bronze,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // New scan button
          GestureDetector(
            onTap: onNewScan,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                border: Border.all(color: _C.gold, width: 1.5),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  'NEW FRAGMENT SCAN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: _C.gold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String tag;
  final String content;
  final bool dark;
  final bool rtl;
  final Widget? trailing;
  const _ResultCard({
    required this.tag,
    required this.content,
    this.dark = false,
    this.rtl = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: dark ? _C.dark : _C.cream.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: dark ? null : Border.all(color: _C.gold.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: rtl
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: rtl
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              if (!rtl)
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _C.bronze,
                  ),
                ),
              if (rtl) ...[
                if (trailing != null) trailing!,
                Text(
                  tag,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: _C.bronze,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            textAlign: rtl ? TextAlign.right : TextAlign.left,
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.4,
              color: dark ? _C.cream : _C.dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _CulturalContextCard extends StatelessWidget {
  final String contextText;
  const _CulturalContextCard({required this.contextText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.cream.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.gold.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_outlined, size: 14, color: _C.bronze),
              const SizedBox(width: 6),
              Text(
                'CULTURAL CONTEXT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: _C.bronze,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            contextText,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: _C.dark.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────
enum _StepState { done, active, future }

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final _StepState state;
  const _StepDot({
    required this.number,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color labelColor;

    switch (state) {
      case _StepState.done:
        bg = _C.dark;
        fg = _C.white;
        labelColor = _C.dark;
        break;
      case _StepState.active:
        bg = _C.gold;
        fg = _C.white;
        labelColor = _C.gold;
        break;
      case _StepState.future:
        bg = _C.white;
        fg = _C.dark.withOpacity(0.4);
        labelColor = _C.dark.withOpacity(0.3);
        break;
    }

    return Opacity(
      opacity: state == _StepState.future ? 0.4 : 1.0,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  const _StepLine({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: active
              ? [_C.dark, _C.gold]
              : [_C.dark.withOpacity(0.15), _C.dark.withOpacity(0.15)],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onPressed;
  const _PrimaryButton({
    required this.label,
    this.icon,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? _C.dark : _C.dark.withOpacity(0.4),
          borderRadius: BorderRadius.circular(24),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _C.dark.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _C.gold,
                ),
              )
            else ...[
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: _C.cream,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 10),
                Icon(icon, size: 18, color: _C.gold),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
