import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/constants/app_colors.dart';
import '../models/place_map.dart';

class NavigationScreen extends StatefulWidget {
  final List<Placemap> places; // كل الأماكن في اليوم
  final int currentPlaceIndex; // البداية من أنهي مكان

  const NavigationScreen({
    Key? key,
    required this.places,
    this.currentPlaceIndex = 0,
  }) : super(key: key);

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  late GoogleMapController _mapController;
  final FlutterTts _tts = FlutterTts();
  StreamSubscription<Position>? _positionStream;
  
  LatLng? _currentPosition;
  List<LatLng> _routePoints = [];
  int _currentPlaceIndex = 0;
  String _currentInstruction = 'Starting navigation...';
  double _distanceToNext = 0;
  double _totalDistance = 0;
  int _estimatedTime = 0;
  
  bool _isNavigating = true;

  @override
  void initState() {
    super.initState();
    _currentPlaceIndex = widget.currentPlaceIndex;
    _initTTS();
    _startNavigation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _tts.stop();
    super.dispose();
  }

  // 🔊 تجهيز الصوت
  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // 🧭 بدء التنقل
  Future<void> _startNavigation() async {
    // جلب الموقع الحالي
    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    // حساب المسار للمكان التالي
    await _calculateRoute();

    // بدء التتبع الحي
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onLocationUpdate);

    // نطق التعليمة الأولى
    _speak(_currentInstruction);
  }

  // 🗺️ حساب المسار
  Future<void> _calculateRoute() async {
    if (_currentPosition == null) return;
    if (_currentPlaceIndex >= widget.places.length) {
      _finishNavigation();
      return;
    }

    final nextPlace = widget.places[_currentPlaceIndex];
    
    // حساب المسافة
    _distanceToNext = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      nextPlace.latitude,
      nextPlace.longitude,
    );

    // توليد تعليمة بسيطة
    _currentInstruction = _generateInstruction(
      _currentPosition!,
      LatLng(nextPlace.latitude, nextPlace.longitude),
    );

    // رسم الخط على الخريطة
    _routePoints = [
      _currentPosition!,
      LatLng(nextPlace.latitude, nextPlace.longitude),
    ];

    // تقدير الوقت (بسرعة 40 كم/ساعة)
    _estimatedTime = (_distanceToNext / (40 * 1000 / 3600)).round();

    setState(() {});
  }

  // 📍 تحديث الموقع
  void _onLocationUpdate(Position position) {
    final newPosition = LatLng(position.latitude, position.longitude);
    
    setState(() {
      _currentPosition = newPosition;
    });

    // تحديث المسافة المتبقية
    if (_currentPlaceIndex < widget.places.length) {
      final nextPlace = widget.places[_currentPlaceIndex];
      
      _distanceToNext = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        nextPlace.latitude,
        nextPlace.longitude,
      );

      // لو وصل للمكان (أقل من 50 متر)
      if (_distanceToNext < 50) {
        _arriveAtPlace();
      } else if (_distanceToNext < 200) {
        // لو قرّب (أقل من 200 متر)
        _currentInstruction = 'Arriving at ${nextPlace.name} in ${_distanceToNext.round()} meters';
        _speak(_currentInstruction);
      }

      setState(() {});
    }

    // تحريك الكاميرا
    _mapController.animateCamera(
      CameraUpdate.newLatLng(newPosition),
    );
  }

  // 🎯 الوصول للمكان
  void _arriveAtPlace() {
    final arrivedPlace = widget.places[_currentPlaceIndex];
    
    _speak('You have arrived at ${arrivedPlace.name}');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arrived at ${arrivedPlace.name}'),
        content: const Text('Ready to go to the next place?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _finishNavigation();
            },
            child: const Text('End Trip'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goToNextPlace();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pyramid,
            ),
            child: const Text('Next Place'),
          ),
        ],
      ),
    );
  }

  // ➡️ الانتقال للمكان التالي
  void _goToNextPlace() {
    _currentPlaceIndex++;
    
    if (_currentPlaceIndex >= widget.places.length) {
      _finishNavigation();
    } else {
      _calculateRoute();
      final nextPlace = widget.places[_currentPlaceIndex];
      _speak('Navigating to ${nextPlace.name}');
    }
  }

  // ✅ إنهاء التنقل
  void _finishNavigation() {
    setState(() {
      _isNavigating = false;
    });
    
    _speak('You have completed your trip');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trip Completed!'),
        content: const Text('You have visited all places for today.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // الرجوع للخريطة الرئيسية
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tealDark,
            ),
            child: const Text('Back to Map'),
          ),
        ],
      ),
    );
  }

  // 🔊 نطق النص
  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  // 🧭 توليد تعليمة بسيطة
  String _generateInstruction(LatLng from, LatLng to) {
    final distance = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (distance > 1000) {
      return 'Continue for ${(distance / 1000).toStringAsFixed(1)} km';
    } else {
      return 'Continue for ${distance.round()} meters';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🗺️ الخريطة
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? const LatLng(30.0444, 31.2357),
              zoom: 16,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            polylines: {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routePoints,
                color: AppColors.pyramid,
                width: 6,
              ),
            },
            markers: _currentPlaceIndex < widget.places.length
                ? {
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: LatLng(
                        widget.places[_currentPlaceIndex].latitude,
                        widget.places[_currentPlaceIndex].longitude,
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  }
                : {},
          ),

          // 📊 لوحة المعلومات
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // الوجهة
                    Text(
                      _currentPlaceIndex < widget.places.length
                          ? widget.places[_currentPlaceIndex].name
                          : 'Trip Completed',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.tealDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // التعليمة
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.pyramid.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.navigation,
                            color: AppColors.pyramid,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentInstruction,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // المسافة والوقت
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoChip(
                          Icons.straighten,
                          '${(_distanceToNext / 1000).toStringAsFixed(1)} km',
                        ),
                        _buildInfoChip(
                          Icons.access_time,
                          '$_estimatedTime min',
                        ),
                        _buildInfoChip(
                          Icons.location_on,
                          '${_currentPlaceIndex + 1}/${widget.places.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔘 أزرار التحكم
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _speak(_currentInstruction);
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Repeat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.tealDark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('End Navigation'),
                          content: const Text('Are you sure you want to exit?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Exit'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('End'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.pyramid),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}