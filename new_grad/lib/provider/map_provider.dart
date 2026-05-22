import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/widgets/enhanced_animations.dart';
import '../data/repositories/trip_repository.dart';
import '../data/repositories/places_repository.dart'; // ← NEW
import '../data/remote/directions_service.dart';
import '../models/trip.dart';
import '../models/place_map.dart';
import '../models/place_location.dart'; // ← NEW
import '../widgets/custom_marker.dart';
import '../widgets/place_search_dialog.dart';
import 'dart:async';

class MapProvider extends ChangeNotifier {
  final TripRepository tripRepository;
  final DirectionsService directionsService;
  final PlacesRepository placesRepository; // ← NEW

  Trip? trip;
  int selectedDayIndex = 0;
  List<Placemap> visiblePlaces = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool loading = true;
  String distanceText = '';
  String durationText = '';

  bool userLocationAvailable = false;
  String? locationErrorMessage;

  LatLng? customStartLocation;
  bool isSelectingStartLocation = false;

  StreamSubscription<Position>? _positionStream;
  final Map<String, BitmapDescriptor> _iconCache = {};

  MapProvider({
    required this.tripRepository,
    required this.directionsService,
    required this.placesRepository, // ← NEW
  });

  // ════════════════════════════════════════════════════════════════════════
  // 🆕 NEW: Load trip from Agenda placeIds
  // ════════════════════════════════════════════════════════════════════════

  /// Load trip from list of placeIds (from Agenda)
  ///
  /// This method fetches coordinates from Backend using PlacesRepository
  /// and creates a single-day trip with all places
  Future<void> loadTripFromPlaceIds(
    BuildContext context,
    List<String> placeIds,
  ) async {
    print("🟡 loadTripFromPlaceIds() started with ${placeIds.length} places");
    loading = true;
    notifyListeners();

    try {
      print("📡 Fetching locations from Backend...");

      // convert string IDs to ints for the new endpoint
      final landmarkIds = placeIds
          .map((id) => int.tryParse(id))
          .whereType<int>()
          .toList();

      final List<PlaceLocation> locations = landmarkIds.isNotEmpty
          ? await placesRepository.getMultipleByLandmarkIds(landmarkIds)
          : [];

      print("✅ Fetched ${locations.length} locations from Backend");

      // rest unchanged from here...

      // 2. Convert PlaceLocation → Placemap
      final List<Placemap> places = locations.map((loc) {
        return Placemap(
          id: loc.placeId,
          name: loc.name,
          latitude: loc.latitude,
          longitude: loc.longitude,
          category: loc.category,
          description: null,
          imageUrl: null,
          estimatedVisitTime: null,
        );
      }).toList();

      print("✅ Converted to ${places.length} Placemap objects");

      // 3. Create Trip object (single day with all places)
      trip = Trip(
        tripId: 'agenda_trip_${DateTime.now().millisecondsSinceEpoch}',
        destination: 'My Agenda Trip',
        days: [
          TripDay(
            day: 1,
            date: DateTime.now().toIso8601String().split('T')[0],
            places: places,
          ),
        ],
      );

      print("✅ Trip created with ${trip!.days[0].places.length} places");

      // 4. Get user location (optional)
      LatLng? userLocation = await _tryGetUserLocation(context);

      if (userLocation != null) {
        userLocationAvailable = true;
        _addUserLocationToTrip(userLocation);
      } else {
        userLocationAvailable = false;
        if (context.mounted) {
          await _showLocationOptionsDialog(context);
        }
      }

      // 5. Set day 0 (build markers + route)
      await setDay(0);

      loading = false;
      print("✅ loadTripFromPlaceIds() finished successfully");
      notifyListeners();

      // 6. Show success animation
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: SuccessAnimation(
              onComplete: () {
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        );
      }
    } catch (e, st) {
      print("❌ Error in loadTripFromPlaceIds(): $e");
      print(st);
      loading = false;
      notifyListeners();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorAnimation(
                message: 'Failed to load trip from agenda.\nPlease try again.',
                onRetry: () {
                  Navigator.pop(ctx);
                  loadTripFromPlaceIds(context, placeIds);
                },
              ),
            ),
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // ✅ EXISTING: Load trip from JSON (unchanged)
  // ════════════════════════════════════════════════════════════════════════

  Future<void> loadMockTrip(BuildContext context) async {
    print("🟡 loadMockTrip() started");
    loading = true;
    notifyListeners();

    try {
      trip = await tripRepository.getMockTrip();
      print("✅ Trip loaded: ${trip != null}");

      LatLng? userLocation = await _tryGetUserLocation(context);

      if (userLocation != null) {
        userLocationAvailable = true;
        _addUserLocationToTrip(userLocation);
      } else {
        userLocationAvailable = false;
        if (context.mounted) {
          await _showLocationOptionsDialog(context);
        }
      }

      await setDay(0);
      loading = false;
      print("✅ loadMockTrip() finished successfully");
      notifyListeners();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            child: SuccessAnimation(
              onComplete: () {
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        );
      }
    } catch (e, st) {
      print("❌ Error in loadMockTrip(): $e");
      print(st);
      loading = false;
      notifyListeners();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorAnimation(
                message: 'Failed to load trip.\nPlease try again.',
                onRetry: () {
                  Navigator.pop(ctx);
                  loadMockTrip(context);
                },
              ),
            ),
          ),
        );
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // REST OF THE CODE (UNCHANGED)
  // ════════════════════════════════════════════════════════════════════════

  Future<LatLng?> _tryGetUserLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        locationErrorMessage = 'Location services are disabled';
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          locationErrorMessage = 'Location permission denied';
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        locationErrorMessage = 'Location permission permanently denied';
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));

      print("📍 User location: ${position.latitude}, ${position.longitude}");
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print("⚠️ Error getting user location: $e");
      locationErrorMessage = 'Could not get your location';
      return null;
    }
  }

  Future<void> _showLocationOptionsDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.location_on, color: Color(0xFFC6873D), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Choose Starting Point',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              locationErrorMessage ?? 'How would you like to start your trip?',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),

            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                loading = true;
                notifyListeners();

                final location = await _tryGetUserLocation(context);
                if (location != null) {
                  userLocationAvailable = true;
                  _addUserLocationToTrip(location);
                  await setDay(selectedDayIndex);
                } else {
                  if (context.mounted) {
                    await _showLocationOptionsDialog(context);
                  }
                }

                loading = false;
                notifyListeners();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2F6A6E)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.my_location, color: Color(0xFF2F6A6E), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Use Current Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Start from where you are now',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                Navigator.pop(ctx);

                await showDialog(
                  context: context,
                  builder: (dialogContext) => PlaceSearchDialog(
                    onPlaceSelected: (location, placeName) {
                      Navigator.of(dialogContext).pop();

                      customStartLocation = location;
                      _addUserLocationToTrip(location);
                      setDay(selectedDayIndex);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Starting point set: $placeName',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    },
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFC6873D)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Color(0xFFC6873D), size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Hotel, address, landmark...',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                print("✅ Starting trip from first place");
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.place, color: Colors.grey, size: 28),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start from First Place',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Begin directly at destination',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void setCustomStartLocation(LatLng location) {
    if (!isSelectingStartLocation) return;

    customStartLocation = location;
    isSelectingStartLocation = false;

    print(
      "📍 Custom start location set: ${location.latitude}, ${location.longitude}",
    );

    _addUserLocationToTrip(location);
    setDay(selectedDayIndex);
    notifyListeners();
  }

  void _addUserLocationToTrip(LatLng userLocation) {
    if (trip == null || trip!.days.isEmpty) return;

    for (var day in trip!.days) {
      if (day.places.isEmpty || day.places.first.id != 'user') {
        day.places.insert(
          0,
          Placemap(
            id: 'user',
            name: customStartLocation != null
                ? 'Selected Start Point'
                : 'Your Location',
            latitude: userLocation.latitude,
            longitude: userLocation.longitude,
            category: 'Start Point',
          ),
        );
      }
    }
  }

  Future<void> refreshUserLocation(BuildContext context) async {
    print("🔄 Trying to refresh user location...");

    final newLocation = await _tryGetUserLocation(context);
    if (newLocation == null) {
      print("⚠️ No new location available to refresh");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.location_off, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    locationErrorMessage ?? 'Could not update location',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => refreshUserLocation(context),
            ),
          ),
        );
      }
      return;
    }

    userLocationAvailable = true;
    customStartLocation = null;

    if (trip == null || trip!.days.isEmpty) {
      print("⚠️ Trip not loaded yet, skipping refresh");
      return;
    }

    for (var day in trip!.days) {
      if (day.places.isNotEmpty && day.places.first.id == 'user') {
        day.places[0] = Placemap(
          id: 'user',
          name: 'Your Location',
          latitude: newLocation.latitude,
          longitude: newLocation.longitude,
          category: 'Start Point',
        );
      } else {
        day.places.insert(
          0,
          Placemap(
            id: 'user',
            name: 'Your Location',
            latitude: newLocation.latitude,
            longitude: newLocation.longitude,
            category: 'Start Point',
          ),
        );
      }
    }

    await _buildMarkers();
    await _buildRoute();
    notifyListeners();
    print("✅ User location refreshed successfully");
  }

  void startLiveLocationTracking(BuildContext context) {
    if (customStartLocation != null) return;

    print("🟢 Starting live location tracking...");

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          print(
            "📍 Live location update: ${position.latitude}, ${position.longitude}",
          );

          if (trip == null || trip!.days.isEmpty) return;

          userLocationAvailable = true;

          for (final day in trip!.days) {
            final userPlace = Placemap(
              id: 'user',
              name: 'Your Location',
              latitude: position.latitude,
              longitude: position.longitude,
              category: 'Start Point',
            );

            if (day.places.isEmpty || day.places.first.id != 'user') {
              day.places.insert(0, userPlace);
            } else {
              day.places[0] = userPlace;
            }
          }

          _buildMarkers();
          _buildRoute();
          notifyListeners();
        });
  }

  void stopLiveLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    print("🔴 Live location tracking stopped.");
  }

  Future<void> setDay(int idx) async {
    print("🟡 setDay($idx) called");
    if (trip == null) {
      print("⚠️ Trip is null in setDay");
      return;
    }

    selectedDayIndex = idx;
    visiblePlaces = trip!.days[idx].places;
    print("📍 Day $idx has ${visiblePlaces.length} places");

    try {
      await _buildMarkers();
      await _buildRoute();
      print("✅ Markers and route built successfully for day $idx");
    } catch (e, st) {
      print("❌ Error in setDay(): $e");
      print(st);
    }

    notifyListeners();
  }

  Future<void> _buildMarkers() async {
    print("🧩 Building markers for ${visiblePlaces.length} places");

    final newMarkers = <String, Marker>{};
    int placeNumber = 0;

    for (final p in visiblePlaces) {
      try {
        BitmapDescriptor icon;

        if (p.id == 'user') {
          if (!_iconCache.containsKey('user')) {
            print("📍 Creating user location icon");
            _iconCache['user'] = await createSimplePinMarker(
              pinColor: const Color(0xFF4285F4),
              centerColor: Colors.white,
            );
          }
          icon = _iconCache['user']!;

          newMarkers[p.id] = Marker(
            markerId: MarkerId(p.id),
            position: LatLng(p.latitude, p.longitude),
            icon: icon,
            infoWindow: InfoWindow(title: p.name, snippet: p.category),
            anchor: const Offset(0.5, 1.0),
          );
          continue;
        }

        placeNumber++;
        String iconKey = '${p.category}_${p.id}_$placeNumber';

        if (!_iconCache.containsKey(iconKey)) {
          String iconPath;
          Color pinColor;

          if (p.category?.contains('Pharaonic') == true ||
              p.category?.contains('Archaeological') == true) {
            iconPath = 'assets/icons/Pharaonic and Archaeological Tourism.png';
            pinColor = const Color(0xFFC6873D);
          } else if (p.category?.contains('Islamic') == true ||
              p.category?.contains('Coptic') == true) {
            iconPath = 'assets/icons/Islamic and Coptic Tourism.png';
            pinColor = const Color(0xFF2F6A6E);
          } else if (p.category?.contains('Modern') == true ||
              p.category?.contains('Leisure') == true) {
            iconPath = 'assets/icons/Modern and Leisure Tourism.png';
            pinColor = const Color(0xFF596A77);
          } else if (p.category?.contains('Culinary') == true ||
              p.category?.contains('Traditional') == true ||
              p.category?.contains('Market') == true ||
              p.category?.contains('Food') == true ||
              p.category?.contains('Shopping') == true) {
            iconPath = 'assets/icons/Culinary and Traditional Markets.png';
            pinColor = const Color(0xFF5B3E2F);
          } else {
            iconPath = 'assets/icons/default.png';
            pinColor = const Color(0xFFC6873D);
          }

          _iconCache[iconKey] = await createCustomMarkerIcon(
            imagePath: iconPath,
            label: p.name,
            number: placeNumber,
            pinColor: pinColor,
          );
        }

        icon = _iconCache[iconKey]!;

        newMarkers[p.id] = Marker(
          markerId: MarkerId(p.id),
          position: LatLng(p.latitude, p.longitude),
          icon: icon,
          infoWindow: InfoWindow(
            title: '$placeNumber. ${p.name}',
            snippet: p.category,
          ),
          anchor: const Offset(0.5, 1.0),
        );
      } catch (e, st) {
        print("❌ Error creating marker for ${p.name}: $e");
        print(st);
      }
    }

    markers = newMarkers.values.toSet();
    print("✅ Finished building ${markers.length} markers");
  }

  Future<void> _buildRoute() async {
    print("🚗 Building route...");

    if (visiblePlaces.length < 2) {
      print("⚠️ Not enough places to build route");
      polylines = {};
      distanceText = '';
      durationText = '';
      return;
    }

    try {
      final res = await directionsService.getRoute(visiblePlaces);

      polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: res.polylinePoints,
          width: 6,
          color: Colors.blue,
          patterns: [PatternItem.dash(30), PatternItem.gap(20)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };

      distanceText =
          '${(res.totalDistanceMeters / 1000).toStringAsFixed(1)} km';
      final mins = (res.totalDurationSeconds / 60).round();
      durationText = '$mins min';

      print(
        "✅ Route built successfully: ${res.polylinePoints.length} points, $distanceText, $durationText",
      );
    } catch (e, st) {
      print("❌ Error in _buildRoute(): $e");
      print(st);
    }
  }

  @override
  void dispose() {
    stopLiveLocationTracking();
    super.dispose();
  }
}
