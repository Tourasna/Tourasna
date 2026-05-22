import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_keys.dart';
import '../../../core/widgets/enhanced_animations.dart';
import '../models/place_map.dart';
import '../models/trip_history.dart';
import '../services/trip_history_service.dart';
import '../services/google_tts_service.dart';
import '../data/remote/directions_service.dart';
import '../widgets/transport_options_dialog.dart';
import 'trip_history_screen.dart';

class ActiveTripScreen extends StatefulWidget {
  final List<Placemap> places;
  final LatLng? startingLocation;
  final String? preferredLanguage;

  const ActiveTripScreen({
    Key? key,
    required this.places,
    this.startingLocation,
    this.preferredLanguage,
  }) : super(key: key);

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  StreamSubscription<Position>? _positionStream;
  int _currentPlaceIndex = 0;
  Position? _currentPosition;
  bool _hasArrivedDialogShown = false;
  bool _isTripActive = true;

  // ✅ TTS Service
  late final GoogleTTSService _tts;
  bool _hasAnnouncedApproaching = false;
  bool _hasPlayedStory = false;
  bool _isPlaying = false;

  // ✅ Current voice info
  String _selectedVoiceDisplayName = 'Charon';
  String _selectedVoiceGender = 'male';
  String _detectedLanguage = 'en-US';

  // Distance
  final DirectionsService _directionsService = DirectionsService(
    apiKey: ApiKeys.googleMapsApiKey,
  );
  double? _remainingDistance;
  Timer? _distanceUpdateTimer;

  // History
  final TripHistoryService _historyService = TripHistoryService();
  late String _tripId;
  DateTime? _tripStartTime;
  double _totalDistanceTraveled = 0;
  List<String> _visitedPlaceIds = [];

  @override
  void initState() {
    super.initState();
    _tripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';
    _tripStartTime = DateTime.now();
    _tts = GoogleTTSService(apiKey: ApiKeys.googleMapsApiKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ← start tracking immediately, language detection in background
      _startLocationTracking();
      _startDistanceUpdates();
      // ← language detection deferred separately so it doesn't block
      Future.microtask(() => _initializeLanguageAndVoice());
    });
  }

  /// ✅ Initialize language and voice for current place
  Future<void> _initializeLanguageAndVoice() async {
    try {
      if (_currentPlaceIndex >= widget.places.length) return;
      final place = widget.places[_currentPlaceIndex];
      final text = place.description ?? place.name;

      // run in a Future so it doesn't block the frame
      await Future(() {
        _detectedLanguage = _tts.detectLanguage(text);
      });

      if (!mounted) return;

      _tts.setLanguage(_detectedLanguage);
      final voices = _tts.getVoicesForLanguage(_detectedLanguage);

      if (voices.isNotEmpty) {
        final selectedVoice = voices.firstWhere(
          (v) => v['gender'] == _selectedVoiceGender,
          orElse: () => voices.first,
        );
        _tts.setVoice(selectedVoice['code']!);
        if (mounted) {
          setState(() {
            _selectedVoiceDisplayName =
                selectedVoice['displayName'] ?? selectedVoice['name']!;
          });
        }
      }
    } catch (e) {
      print('⚠️ Language init failed silently: $e');
      // fallback to English — trip still works
      _detectedLanguage = 'en-US';
    }
  }

  /// ✅ Update language when moving to next place
  Future<void> _updateLanguageForCurrentPlace() async {
    try {
      if (_currentPlaceIndex >= widget.places.length) return;
      final place = widget.places[_currentPlaceIndex];
      final text = place.description ?? place.name;

      final newLanguage = await Future(() => _tts.detectLanguage(text));
      if (newLanguage == _detectedLanguage) return;

      _detectedLanguage = newLanguage;
      _tts.setLanguage(_detectedLanguage);
      final voices = _tts.getVoicesForLanguage(_detectedLanguage);
      if (voices.isNotEmpty) {
        final selectedVoice = voices.firstWhere(
          (v) => v['gender'] == _selectedVoiceGender,
          orElse: () => voices.first,
        );
        _tts.setVoice(selectedVoice['code']!);
        if (mounted) {
          setState(() {
            _selectedVoiceDisplayName =
                selectedVoice['displayName'] ?? selectedVoice['name']!;
          });
        }
      }
    } catch (e) {
      print('⚠️ Language update failed silently: $e');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _tts.dispose();
    _positionStream?.cancel();
    _distanceUpdateTimer?.cancel();
    super.dispose();
  }

  /// 🎭 Speak story
  Future<void> _speakStory(String text) async {
    if (_isPlaying) {
      await _tts.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    try {
      if (mounted) setState(() => _isPlaying = true);
      await _tts.speakStory(text);
    } catch (e) {
      print('❌ TTS Error: $e');
      _showErrorSnackBar('Could not play audio');
    } finally {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopAndExit() async {
    await _tts.stop();
    if (mounted) Navigator.pop(context);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 VOICE SELECTOR - ✅ FIXED to use current detected language
  // ═══════════════════════════════════════════════════════════════════════════

  void _showVoiceSelector() {
    _tts.stop();
    if (mounted) setState(() => _isPlaying = false);

    // ✅ Use already detected language, don't re-detect!
    final availableVoices = _tts.getVoicesForLanguage(_detectedLanguage);
    final currentVoice = _tts.getCurrentVoice();

    final langInfo = _tts.getSupportedLanguages().firstWhere(
      (l) => l['code'] == _detectedLanguage,
      orElse: () => {'code': 'en-US', 'name': 'English', 'flag': '🇺🇸'},
    );

    print('════════════════════════════════════════════');
    print('🎤 VOICE SELECTOR OPENED');
    print('🌍 Current Language: $_detectedLanguage');
    print(
      '🎤 Available Voices: ${availableVoices.map((v) => v['displayName']).toList()}',
    );
    print('════════════════════════════════════════════');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title with detected language
            Row(
              children: [
                Text(langInfo['flag']!, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose Tour Guide',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tealDark,
                        ),
                      ),
                      Text(
                        'Language: ${langInfo['name']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Voice options
            ...availableVoices.map((voice) {
              final isSelected = voice['code'] == currentVoice;
              final isMale = voice['gender'] == 'male';
              final displayName = voice['displayName'] ?? voice['name']!;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.pyramid.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.pyramid
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isMale
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.pink.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isMale ? Icons.man : Icons.woman,
                      size: 32,
                      color: isMale ? Colors.blue : Colors.pink,
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.pyramid
                          : AppColors.tealDark,
                    ),
                  ),
                  subtitle: Text(
                    voice['style']!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview button
                      IconButton(
                        icon: Icon(
                          Icons.play_circle_fill,
                          size: 36,
                          color: isSelected ? AppColors.pyramid : Colors.grey,
                        ),
                        onPressed: () async {
                          await _tts.stop();
                          _tts.setVoice(voice['code']!);

                          // Preview text based on language
                          String preview = _detectedLanguage.startsWith('ar')
                              ? 'مرحباً بكم في مصر، أرض الفراعنة والحضارات العريقة.'
                              : _detectedLanguage.startsWith('fr')
                              ? 'Bienvenue en Égypte, terre des pharaons.'
                              : _detectedLanguage.startsWith('de')
                              ? 'Willkommen in Ägypten, dem Land der Pharaonen.'
                              : _detectedLanguage.startsWith('es')
                              ? 'Bienvenidos a Egipto, tierra de los faraones.'
                              : _detectedLanguage.startsWith('it')
                              ? 'Benvenuti in Egitto, terra dei faraoni.'
                              : 'Welcome to Egypt, the land of pharaohs and ancient wonders.';

                          await _tts.speakStory(preview);
                        },
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.pyramid,
                          size: 28,
                        ),
                    ],
                  ),
                  onTap: () {
                    _tts.setVoice(voice['code']!);
                    setState(() {
                      _selectedVoiceDisplayName = displayName;
                      _selectedVoiceGender = voice['gender']!;
                    });
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              isMale ? Icons.man : Icons.woman,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text('Tour guide: $displayName'),
                          ],
                        ),
                        backgroundColor: AppColors.tealDark,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              );
            }).toList(),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📍 LOCATION & DISTANCE
  // ═══════════════════════════════════════════════════════════════════════════

  void _startDistanceUpdates() {
    _updateRemainingDistance();
    _distanceUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateRemainingDistance(),
    );
  }

  Future<void> _updateRemainingDistance() async {
    if (_currentPosition == null || _currentPlaceIndex >= widget.places.length)
      return;

    try {
      final currentPlace = widget.places[_currentPlaceIndex];
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        currentPlace.latitude,
        currentPlace.longitude,
      );

      if (mounted) setState(() => _remainingDistance = distance);
      _fetchAccurateDistance(currentPlace);
    } catch (e) {
      print('⚠️ Distance error: $e');
    }
  }

  Future<void> _fetchAccurateDistance(Placemap destination) async {
    try {
      final routePlaces = [
        Placemap(
          id: 'current',
          name: 'Current',
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
        ),
        destination,
      ];
      final result = await _directionsService.getRoute(routePlaces);

      if (mounted &&
          _currentPlaceIndex < widget.places.length &&
          widget.places[_currentPlaceIndex].id == destination.id) {
        setState(
          () => _remainingDistance = result.totalDistanceMeters.toDouble(),
        );
      }
    } catch (e) {
      print('⚠️ Accurate distance error: $e');
    }
  }

  void _startLocationTracking() async {
    // check permission before starting stream
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('⚠️ Location permission not granted, skipping tracking');
      return;
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          if (_currentPosition != null) {
            _totalDistanceTraveled +=
                Geolocator.distanceBetween(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  position.latitude,
                  position.longitude,
                ) /
                1000;
          }
          if (mounted) setState(() => _currentPosition = position);
          if (_currentPlaceIndex < widget.places.length &&
              !_hasArrivedDialogShown) {
            _checkArrival(position);
          }
        });
  }

  void _checkArrival(Position position) {
    final currentPlace = widget.places[_currentPlaceIndex];
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      currentPlace.latitude,
      currentPlace.longitude,
    );

    if (distance <= 100 && distance > 50 && !_hasPlayedStory) {
      _hasPlayedStory = true;
      HapticFeedback.lightImpact();

      String storyText = currentPlace.name;
      if (currentPlace.description?.isNotEmpty == true) {
        storyText += '. ' + currentPlace.description!;
      }
      _speakStory(storyText);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.headphones, color: Colors.white),
                SizedBox(width: 12),
                Text('🎭 Listening to story...'),
              ],
            ),
            backgroundColor: AppColors.pyramid,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    if (distance <= 50 && distance > 20 && !_hasAnnouncedApproaching) {
      _hasAnnouncedApproaching = true;
      HapticFeedback.lightImpact();
    }

    if (distance < 20 && !_hasArrivedDialogShown) {
      _hasArrivedDialogShown = true;
      if (!_visitedPlaceIds.contains(currentPlace.id)) {
        _visitedPlaceIds.add(currentPlace.id);
      }
      HapticFeedback.heavyImpact();
      _showArrivalDialog();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎉 DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showArrivalDialog() {
    _tts.stop();
    if (mounted) setState(() => _isPlaying = false);

    final place = widget.places[_currentPlaceIndex];
    final hasNext = _currentPlaceIndex < widget.places.length - 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.celebration, color: AppColors.pyramid, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'You Arrived!',
                style: TextStyle(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.pyramid.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: AppColors.pyramid),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('🎉 Enjoy your visit!', style: TextStyle(fontSize: 16)),
            if (hasNext) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Next: ${widget.places[_currentPlaceIndex + 1].name}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.tealDark,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (hasNext)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _finishTrip();
              },
              child: const Text('End Trip'),
            ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              hasNext ? _goToNextPlace() : _finishTrip();
            },
            icon: Icon(hasNext ? Icons.navigation : Icons.check),
            label: Text(hasNext ? 'Next' : 'Finish'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.pyramid),
          ),
        ],
      ),
    );
  }

  void _goToNextPlace() {
    _currentPlaceIndex++;
    _hasArrivedDialogShown = false;
    _hasAnnouncedApproaching = false;
    _hasPlayedStory = false;
    _remainingDistance = null;

    if (mounted) setState(() {});

    _updateLanguageForCurrentPlace(); // fire and forget, no await needed

    if (_currentPlaceIndex < widget.places.length) {
      _updateRemainingDistance();
    } else {
      _finishTrip();
    }
  }

  void _skipCurrentPlace() {
    HapticFeedback.mediumImpact();
    _tts.stop();
    if (mounted) setState(() => _isPlaying = false);

    _goToNextPlace();

    if (_currentPlaceIndex < widget.places.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped to ${widget.places[_currentPlaceIndex].name}'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _finishTrip() async {
    await _tts.stop();

    if (mounted) {
      setState(() {
        _isTripActive = false;
        _isPlaying = false;
      });
    }

    HapticFeedback.heavyImpact();

    if (_tripStartTime != null) {
      await _historyService.saveTripHistory(
        TripHistoryItem(
          id: _tripId,
          destination: 'Cairo Trip',
          startDate: _tripStartTime!,
          endDate: DateTime.now(),
          placesVisited: _visitedPlaceIds.length,
          totalDistance: _totalDistanceTraveled,
          visitedPlaceIds: _visitedPlaceIds,
          isCompleted: _currentPlaceIndex >= widget.places.length - 1,
        ),
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Trip Completed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Congratulations! 🎉', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            _buildSummaryRow(
              Icons.place,
              'Places',
              '${_visitedPlaceIds.length}/${widget.places.length}',
            ),
            _buildSummaryRow(
              Icons.route,
              'Distance',
              '${_totalDistanceTraveled.toStringAsFixed(1)} km',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                FadePageRoute(page: const TripHistoryScreen()),
              );
            },
            child: const Text('History'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealDark,
            ),
            child: const Text(
              'Back to Map',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.pyramid),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎨 BUILD UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final currentPlace = _currentPlaceIndex < widget.places.length
        ? widget.places[_currentPlaceIndex]
        : null;

    final langInfo = _tts.getSupportedLanguages().firstWhere(
      (l) => l['code'] == _detectedLanguage,
      orElse: () => {'flag': '🌍'},
    );

    return WillPopScope(
      onWillPop: () async {
        await _tts.stop();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.tealDark,
          title: const Text('Active Trip'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('End Trip?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _stopAndExit();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('End'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            // ✅ Voice selector with correct flag and displayName
            TextButton.icon(
              onPressed: _showVoiceSelector,
              icon: Text(
                langInfo['flag']!,
                style: const TextStyle(fontSize: 20),
              ),
              label: Text(
                _selectedVoiceDisplayName,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                size: 28,
              ),
              onPressed: () {
                if (currentPlace != null) {
                  String text = currentPlace.name;
                  if (currentPlace.description?.isNotEmpty == true)
                    text += '. ' + currentPlace.description!;
                  _speakStory(text);
                }
              },
            ),
          ],
        ),
        body: currentPlace == null
            ? const Center(child: Text('Trip Completed!'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: (_currentPlaceIndex + 1) / widget.places.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.pyramid,
                      ),
                      minHeight: 8,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Place ${_currentPlaceIndex + 1} of ${widget.places.length}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      currentPlace.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tealDark,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_remainingDistance != null)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.pyramid.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: AppColors.pyramid,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Distance',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    _remainingDistance! > 1000
                                        ? '${(_remainingDistance! / 1000).toStringAsFixed(1)} km'
                                        : '${_remainingDistance!.round()} m',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.tealDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    if (currentPlace.category != null)
                      _buildInfoChip(Icons.category, currentPlace.category!),
                    if (currentPlace.estimatedVisitTime != null)
                      _buildInfoChip(
                        Icons.access_time,
                        currentPlace.estimatedVisitTime!,
                      ),

                    if (currentPlace.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.pyramid.withOpacity(0.1),
                              AppColors.tealDark.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.pyramid.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isPlaying
                                      ? Icons.graphic_eq
                                      : Icons.auto_stories,
                                  color: AppColors.pyramid,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'About',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: () => _speakStory(
                                    currentPlace.name +
                                        '. ' +
                                        currentPlace.description!,
                                  ),
                                  icon: Icon(
                                    _isPlaying ? Icons.stop : Icons.play_arrow,
                                    size: 18,
                                  ),
                                  label: Text(_isPlaying ? 'Stop' : 'Listen'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isPlaying
                                        ? Colors.red
                                        : AppColors.pyramid,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currentPlace.description!,
                              style: const TextStyle(fontSize: 14, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _skipCurrentPlace,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Skip'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: Colors.orange,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => TransportOptionsDialog.show(
                          context: context,
                          destination: currentPlace,
                          currentLat: _currentPosition?.latitude,
                          currentLng: _currentPosition?.longitude,
                        ),
                        icon: const Icon(Icons.directions_car),
                        label: const Text('Choose Transport'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pyramid,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.pyramid, size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
