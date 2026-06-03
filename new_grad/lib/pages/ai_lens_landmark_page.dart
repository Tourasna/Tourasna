import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';
import '../models/recommendation_item.dart';
import '../services/google_tts_service.dart';
import '../services/api_keys.dart';
import '../services/storytelling_service.dart';
import '../utils/network_navigator.dart';
import 'heritage_3d_page.dart';

class AiLensLandmarkPage extends StatefulWidget {
  final Place place;
  final RecommendationItem? item;
  final String className;
  final int classIndex;
  final String imageB64;

  const AiLensLandmarkPage({
    super.key,
    required this.place,
    required this.className,
    required this.classIndex,
    required this.imageB64,
    this.item,
  });

  @override
  State<AiLensLandmarkPage> createState() => _AiLensLandmarkPageState();
}

class _AiLensLandmarkPageState extends State<AiLensLandmarkPage>
    with WidgetsBindingObserver {
  late final GoogleTTSService _tts;

  bool _storyLoading = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  String? _cachedStory;
  String _preferredGender = 'male';
  int _currentPhoto = 0;

  static const String _voicePrefKey = 'tts_preferred_gender';

  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<String> get _photos {
    final urls = widget.item?.photoUrls ?? [];
    if (urls.isNotEmpty) return urls;
    if (widget.place.imageUrl.isNotEmpty) return [widget.place.imageUrl];
    final photoFromInfo = widget.place.infoJson?['photo_url']?.toString();
    if (photoFromInfo != null && photoFromInfo.isNotEmpty) {
      return [photoFromInfo];
    }
    return [
      'https://tourasna-assets.s3.amazonaws.com/landmarks/places/${widget.place.id}/photo_1.jpg',
    ];
  }

  double? get _rating => widget.item?.rating;
  String? get _address => widget.item?.address;
  String? get _openingHours => widget.item?.openingHours;
  String? get _priceRange {
    if (widget.item?.priceRange != null) return widget.item!.priceRange;
    if (widget.item?.startPrice != null)
      return '${widget.item!.startPrice} EGP';
    return null;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts = GoogleTTSService(apiKey: ApiKeys.googleMapsApiKey);
    _loadVoicePreference();
  }

  Future<void> _loadVoicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_voicePrefKey);
    if (saved != null && mounted) setState(() => _preferredGender = saved);
  }

  Future<void> _saveVoicePreference(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_voicePrefKey, gender);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tts.stop();
    _tts.shutdown();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _tts.stop();
      if (mounted)
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
    }
  }

  // ── Story ──────────────────────────────────────────────────────────────────

  Future<void> _startStoryFlow() async {
    if (_storyLoading) return;

    if (_isPlaying && !_isPaused) {
      await _tts.pause();
      if (mounted) setState(() => _isPaused = true);
      return;
    }
    if (_isPlaying && _isPaused) {
      await _tts.resume();
      if (mounted) setState(() => _isPaused = false);
      return;
    }

    try {
      setState(() => _storyLoading = true);
      final storyText = _cachedStory ??= await StorytellingService.getStory(
        widget.place.id,
      );
      _tts.setVoiceForText(storyText, preferredGender: _preferredGender);
      if (!mounted) return;
      setState(() {
        _storyLoading = false;
        _isPlaying = true;
        _isPaused = false;
      });
      await _tts.speakStory(storyText);
      if (mounted)
        setState(() {
          _isPlaying = false;
          _isPaused = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _storyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Story error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVoiceSelector() {
    _tts.stop();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Narrator',
              style: TextStyle(
                color: darkColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Charon'),
                    selected: _preferredGender == 'male',
                    selectedColor: goldColor,
                    onSelected: (_) {
                      _preferredGender = 'male';
                      _saveVoicePreference('male');
                      Navigator.pop(context);
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Kore'),
                    selected: _preferredGender == 'female',
                    selectedColor: goldColor,
                    onSelected: (_) {
                      _preferredGender = 'female';
                      _saveVoicePreference('female');
                      Navigator.pop(context);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.75),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: goldColor.withOpacity(.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: goldColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: darkColor.withOpacity(.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool dark = true,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                ),
              )
            : Icon(icon, color: goldColor),
        label: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
            color: dark ? Colors.white : darkColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: dark ? darkColor : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: dark ? Colors.transparent : goldColor.withOpacity(.2),
            ),
          ),
        ),
        onPressed: loading ? null : onTap,
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 260,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E1D3),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Icon(Icons.image_outlined, size: 50, color: Colors.grey[400]),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            blurRadius: 15,
            color: Colors.black.withOpacity(.08),
            offset: const Offset(0, -4),
          ),
        ],
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
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? darkColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              iconPath,
              width: 38,
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
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    IconData storyIcon;
    String storyLabel;
    if (_storyLoading) {
      storyIcon = Icons.hourglass_top;
      storyLabel = 'Loading Story';
    } else if (_isPlaying && !_isPaused) {
      storyIcon = Icons.pause;
      storyLabel = 'Pause Story';
    } else if (_isPlaying && _isPaused) {
      storyIcon = Icons.play_arrow;
      storyLabel = 'Resume Story';
    } else {
      storyIcon = Icons.volume_up;
      storyLabel = 'Hear Monument Story';
    }

    final photos = _photos;
    final description =
        widget.item?.description ??
        widget.place.description ??
        'No description available.';
    final category = widget.place.category;

    return WillPopScope(
      onWillPop: () async {
        await _tts.stop();
        return true;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar: _buildBottomNav(),
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () {
                        _tts.stop();
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.chevron_left, color: darkColor),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'MONUMENT DETAILS',
                      style: TextStyle(
                        color: darkColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: _showVoiceSelector,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(Icons.record_voice_over, color: darkColor),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable body ────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Photo carousel ─────────────────────────────────────
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: photos.isNotEmpty
                            ? SizedBox(
                                height: 260,
                                child: Stack(
                                  children: [
                                    PageView.builder(
                                      itemCount: photos.length,
                                      onPageChanged: (i) =>
                                          setState(() => _currentPhoto = i),
                                      itemBuilder: (_, i) => Image.network(
                                        photos[i],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        errorBuilder: (_, __, ___) =>
                                            _photoPlaceholder(),
                                      ),
                                    ),

                                    // Rating badge
                                    if (_rating != null)
                                      Positioned(
                                        top: 16,
                                        left: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              .35,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                size: 15,
                                                color: Colors.amber,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _rating!.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    // AI Identified badge
                                    Positioned(
                                      top: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(.35),
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 13,
                                              color: Colors.amber,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'AI IDENTIFIED',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Dot indicators
                                    if (photos.length > 1)
                                      Positioned(
                                        bottom: 12,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(
                                            photos.length,
                                            (i) => Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              width: i == _currentPhoto
                                                  ? 18
                                                  : 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: i == _currentPhoto
                                                    ? Colors.white
                                                    : Colors.white.withOpacity(
                                                        .5,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : _photoPlaceholder(),
                      ),

                      const SizedBox(height: 22),

                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: goldColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        widget.place.name,
                        style: TextStyle(
                          color: darkColor,
                          fontSize: 31,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_address != null)
                            _infoChip(Icons.location_on, _address!),
                          if (_openingHours != null)
                            _infoChip(Icons.access_time, _openingHours!),
                          if (_priceRange != null)
                            _infoChip(Icons.confirmation_num, _priceRange!),
                          _infoChip(Icons.view_in_ar_rounded, '3D Available'),
                        ],
                      ),

                      const SizedBox(height: 18),

                      Text(
                        description,
                        style: TextStyle(
                          color: darkColor.withOpacity(.8),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Story button
                      _mainButton(
                        icon: storyIcon,
                        text: storyLabel,
                        onTap: _startStoryFlow,
                        dark: true,
                        loading: _storyLoading,
                      ),

                      const SizedBox(height: 12),

                      // 3D Model button
                      _mainButton(
                        icon: Icons.view_in_ar,
                        text: 'View 3D Model',
                        dark: false,
                        onTap: () {
                          _tts.stop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Heritage3DPage(
                                place: widget.place,
                                className: widget.className,
                                classIndex: widget.classIndex,
                                imageB64: widget.imageB64,
                              ),
                            ),
                          );
                        },
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
}
