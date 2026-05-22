import 'package:flutter/material.dart';
import '../models/place_story.dart';
import '../services/storytelling_service.dart';
import '../services/google_tts_service.dart';
import '../services/api_keys.dart';

// ─── Design tokens ────────────────────────────────
const Color kBg = Color(0xFFF2EADC);
const Color kTeal = Color(0xFF1A3C3C);
const Color kGold = Color(0xFFC5A059);
const Color kInput = Color(0xFFEAE2D1);

const TextStyle kSerif = TextStyle(fontFamily: 'Gambetta', color: kTeal);
const TextStyle kSans = TextStyle(fontFamily: 'Satoshi', color: kTeal);

// ─── Category config ──────────────────────────────
const _categories = [
  ('🌐', 'All'),
  ('▲', 'Pyramids'),
  ('🏛️', 'Architecture & Landmarks'),
  ('🏢', 'Museums & Cultural Sites'),
  ('🗿', 'Statues & Sculptures'),
  ('⚱️', 'Funerary Objects'),
  ('📜', 'Stelae & Carved Artifacts'),
  ('✨', 'Religious Structures & Artifacts'),
  ('🎨', 'Modern Monuments & Public Art'),
];

class StorytellingPage extends StatefulWidget {
  const StorytellingPage({super.key});
  @override
  State<StorytellingPage> createState() => _StorytellingPageState();
}

class _StorytellingPageState extends State<StorytellingPage> {
  List<PlaceStory> _all = [];
  List<PlaceStory> _filtered = [];
  bool _loading = true;
  int _catIndex = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final places = await StorytellingService.getAllPlaces();
      if (!mounted) return;
      setState(() {
        _all = places;
        _filtered = places;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final cat = _catIndex == 0 ? null : _categories[_catIndex].$2;
    final query = _query.toLowerCase();
    setState(() {
      _filtered = _all.where((p) {
        final matchCat = cat == null || p.category == cat;
        final matchQuery =
            query.isEmpty ||
            p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query);
        return matchCat && matchQuery;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildIntro(),
            _buildSearch(),
            const SizedBox(height: 12),
            _buildCategoryChips(),
            const SizedBox(height: 8),
            Expanded(child: _loading ? _buildLoading() : _buildList()),
          ],
        ),
      ),
    );
  }

  // ── header ────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kInput,
            shape: BoxShape.circle,
            border: Border.all(color: kTeal.withOpacity(0.08)),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: kTeal,
          ),
        ),
      ),
    );
  }

  // ── intro ─────────────────────────────────────
  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chronicles of the Nile',
            style: kSans.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.0,
              color: kGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Storytellings',
            style: kSerif.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Journey through the sacred chronicles where history breathes in every line.',
            style: kSerif.copyWith(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: kTeal.withOpacity(0.55),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── search ────────────────────────────────────
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: kInput,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: kTeal.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.search_rounded, color: kTeal.withOpacity(0.4), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: kSans.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search Chronicles...',
                  hintStyle: kSans.copyWith(
                    fontSize: 13,
                    color: kTeal.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  _query = v.trim();
                  _filter();
                },
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  // ── category chips ────────────────────────────
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _catIndex;
          final (emoji, label) = _categories[i];
          return GestureDetector(
            onTap: () {
              _catIndex = i;
              _filter();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? kGold : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(999),
                border: active
                    ? null
                    : Border.all(color: kGold.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(
                    label.toUpperCase(),
                    style: kSans.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3,
                      color: active ? Colors.white : kTeal,
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

  // ── loading ───────────────────────────────────
  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: kGold));
  }

  // ── list ──────────────────────────────────────
  Widget _buildList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 48,
              color: kGold.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No chronicles found',
              style: kSerif.copyWith(
                fontSize: 16,
                color: kTeal.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    // pin the first item as featured if on "All" with no query
    final showFeatured =
        _catIndex == 0 && _query.isEmpty && _filtered.isNotEmpty;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      itemCount: _filtered.length + (showFeatured ? 0 : 0),
      itemBuilder: (_, i) {
        final place = _filtered[i];
        if (showFeatured && i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeaturedCard(place),
              const SizedBox(height: 28),
              if (_filtered.length > 1) ...[
                _buildSectionHeader(
                  'All Chronicles',
                  '${_filtered.length - 1} stories',
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildStoryCard(place),
        );
      },
    );
  }

  // ── section header ────────────────────────────
  Widget _buildSectionHeader(String title, String sub) {
    return Row(
      children: [
        Text(
          title,
          style: kSerif.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: kGold.withOpacity(0.2))),
        const SizedBox(width: 12),
        Text(
          sub,
          style: kSans.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: kGold,
          ),
        ),
      ],
    );
  }

  // ── featured card ─────────────────────────────
  Widget _buildFeaturedCard(PlaceStory place) {
    return GestureDetector(
      onTap: () => _openPlayer(place),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // photo or placeholder
              place.photoUrl != null
                  ? Image.network(
                      place.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoPlaceholder(),
                    )
                  : _photoPlaceholder(),

              // gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [kTeal, Color(0x661A3C3C), Colors.transparent],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),

              // gold bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 5, color: kGold),
              ),

              // content
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'FEATURED SAGA',
                            style: kSans.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3.0,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (place.hasStory)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: kGold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'READY',
                                style: kSans.copyWith(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        place.name,
                        style: kSerif.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        place.description.length > 100
                            ? '${place.description.substring(0, 100)}...'
                            : place.description,
                        style: kSans.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: kGold,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow_rounded,
                              color: kTeal,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'HEAR THE SAGA',
                              style: kSans.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                color: kTeal,
                              ),
                            ),
                          ],
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
  }

  // ── story card ────────────────────────────────
  Widget _buildStoryCard(PlaceStory place) {
    return GestureDetector(
      onTap: () => _openPlayer(place),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kGold.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: kTeal.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 90,
                height: 90,
                child: place.photoUrl != null
                    ? Image.network(
                        place.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
              ),
            ),
            const SizedBox(width: 14),

            // info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.category.toUpperCase(),
                    style: kSans.copyWith(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: kGold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.name,
                    style: kSerif.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    place.description.length > 60
                        ? '${place.description.substring(0, 60)}...'
                        : place.description,
                    style: kSans.copyWith(
                      fontSize: 11,
                      color: kTeal.withOpacity(0.5),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // play / status
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: place.hasStory ? kGold : kTeal.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      place.hasStory
                          ? Icons.play_arrow_rounded
                          : Icons.auto_awesome_rounded,
                      color: place.hasStory ? kTeal : kGold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    place.hasStory ? 'READY' : 'GENERATE',
                    style: kSans.copyWith(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: place.hasStory ? kGold : kTeal.withOpacity(0.4),
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

  // ── photo placeholder ─────────────────────────
  Widget _photoPlaceholder() {
    return Container(
      color: kInput,
      child: Center(
        child: Icon(
          Icons.account_balance_rounded,
          color: kGold.withOpacity(0.4),
          size: 28,
        ),
      ),
    );
  }

  // ── open player ───────────────────────────────
  void _openPlayer(PlaceStory place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _StoryPlayerPage(place: place)),
    );
  }
}

// ══════════════════════════════════════════════════════
// STORY PLAYER PAGE
// ══════════════════════════════════════════════════════

class _StoryPlayerPage extends StatefulWidget {
  final PlaceStory place;
  const _StoryPlayerPage({required this.place});

  @override
  State<_StoryPlayerPage> createState() => _StoryPlayerPageState();
}

class _StoryPlayerPageState extends State<_StoryPlayerPage> {
  late final GoogleTTSService _tts;

  bool _loading = false;
  bool _playing = false;
  bool _paused = false;
  String? _story;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tts = GoogleTTSService(apiKey: ApiKeys.googleMapsApiKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStory());
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _loadStory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final story = await StorytellingService.getStory(widget.place.id);
      if (!mounted) return;
      setState(() {
        _story = story;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_story == null) return;

    if (_playing && !_paused) {
      await _tts.pause();
      setState(() => _paused = true);
      return;
    }
    if (_playing && _paused) {
      await _tts.resume();
      setState(() => _paused = false);
      return;
    }

    _tts.setVoiceForText(_story!, preferredGender: 'male');
    setState(() {
      _playing = true;
      _paused = false;
    });
    await _tts.speakStory(_story!);
    if (mounted)
      setState(() {
        _playing = false;
        _paused = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _tts.stop();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kInput,
                        shape: BoxShape.circle,
                        border: Border.all(color: kTeal.withOpacity(0.08)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: kTeal,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kGold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withOpacity(0.25)),
                    ),
                    child: Text(
                      widget.place.category,
                      style: kSans.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kGold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // photo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: widget.place.photoUrl != null
                            ? Image.network(
                                widget.place.photoUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: kInput,
                                child: Center(
                                  child: Icon(
                                    Icons.account_balance_rounded,
                                    size: 48,
                                    color: kGold.withOpacity(0.4),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // name
                    Text(
                      widget.place.name,
                      style: kSerif.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // play button
                    GestureDetector(
                      onTap: _loading ? null : _togglePlay,
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _loading ? kTeal.withOpacity(0.4) : kTeal,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: kTeal.withOpacity(0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _loading
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Summoning the chronicle...',
                                      style: kSans.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _playing && !_paused
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: kGold,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _playing && !_paused
                                          ? 'PAUSE STORY'
                                          : _playing && _paused
                                          ? 'RESUME STORY'
                                          : 'HEAR THE STORY',
                                      style: kSans.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.20),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Could not load story. Tap retry.',
                                style: kSans.copyWith(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _loadStory,
                              child: Text(
                                'RETRY',
                                style: kSans.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // story text
                    if (_story != null) ...[
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: kGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'THE CHRONICLE',
                            style: kSans.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: kGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _story!,
                        style: kSans.copyWith(
                          fontSize: 15,
                          color: kTeal.withOpacity(0.75),
                          height: 1.8,
                        ),
                      ),
                    ] else if (!_loading) ...[
                      // description fallback
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: kGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ABOUT',
                            style: kSans.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                              color: kGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.place.description,
                        style: kSans.copyWith(
                          fontSize: 15,
                          color: kTeal.withOpacity(0.75),
                          height: 1.8,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
