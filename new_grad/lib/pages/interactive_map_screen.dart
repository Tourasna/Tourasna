import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/api_keys.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/enhanced_animations.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shimmer/shimmer.dart';

import '../interactive_map_feature.dart';

/// InteractiveMapScreen - ONLY for Agenda
/// 
/// This screen displays places from user's agenda on the map.
/// Input: List<String> placeIds (REQUIRED)
class InteractiveMapScreen extends StatefulWidget {
  // ✅ REQUIRED: placeIds from Agenda
  final List<String> placeIds;
  
  const InteractiveMapScreen({
    Key? key,
    required this.placeIds, // ← REQUIRED, not optional
  }) : super(key: key);

  @override
  State<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends State<InteractiveMapScreen> {
  late GoogleMapController _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  String _mapStyle = '';
  bool _isMapReady = false;

  late MapProvider mapProvider;

  @override
  void initState() {
    super.initState();

    // Load map style
    rootBundle.loadString('assets/map_styles/heritage_map.json').then((s) {
      setState(() {
        _mapStyle = s;
      });
    });

    // Initialize MapProvider
    mapProvider = MapProvider(
      tripRepository: TripRepository(recService: RecommendationService()),
      directionsService: DirectionsService(apiKey: ApiKeys.googleMapsApiKey),
      placesRepository: PlacesRepository.create(),
    );

    // ✅ ALWAYS load from placeIds (no check needed)
    Future.microtask(() async {
      print("🗺️ Loading trip from ${widget.placeIds.length} agenda places");
      await mapProvider.loadTripFromPlaceIds(context, widget.placeIds);
      mapProvider.startLiveLocationTracking(context);
      
      setState(() {
        _isMapReady = true;
      });
    });
  }

  @override
  void dispose() {
    mapProvider.stopLiveLocationTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: mapProvider,
      child: Scaffold(
        body: SafeArea(
          child: Consumer<MapProvider>(
            builder: (context, provider, _) {
              if (provider.loading) {
                return Center(
                  child: Shimmer.fromColors(
                    baseColor: AppColors.cream,
                    highlightColor: AppColors.pyramid.withOpacity(0.3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: 150,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Loading your agenda...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // ✅ Check if trip is loaded
              if (provider.trip == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No trip loaded',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please add places to your agenda',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final trip = provider.trip!;

              return Column(
                children: [
                  // Top Bar
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.tealDark, size: 28),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Back to Agenda',
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'My Agenda Trip',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.tealDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history, color: AppColors.pyramid, size: 28),
                          onPressed: () {
                            Navigator.push(
                              context,
                              FadePageRoute(
                                page: const TripHistoryScreen(),
                              ),
                            );
                          },
                          tooltip: 'Trip History',
                        ),
                      ],
                    ),
                  ),

                  // Map
                  Expanded(
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(30.0444, 31.2357),
                            zoom: 12,
                          ),
                          onTap: (LatLng location) {
                            if (provider.isSelectingStartLocation) {
                              provider.setCustomStartLocation(location);
                            }
                          },
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _controller.complete(controller);
                            if (_mapStyle.isNotEmpty) {
                              _mapController.setMapStyle(_mapStyle);
                            }
                          },
                          markers: provider.markers,
                          polylines: provider.polylines,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          compassEnabled: true,
                          mapToolbarEnabled: false,
                          zoomControlsEnabled: false,
                          buildingsEnabled: true,
                          trafficEnabled: false,
                        ),

                        // Distance/Duration Card
                        Positioned(
                          top: 16,
                          right: 12,
                          child: Card(
                            color: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.route,
                                        size: 16,
                                        color: AppColors.pyramid,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        provider.distanceText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.tealDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: AppColors.pyramid,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        provider.durationText,
                                        style: const TextStyle(
                                          color: AppColors.brownDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Zoom & Location Buttons
                        Positioned(
                          top: 120,
                          right: 12,
                          child: Column(
                            children: [
                              FloatingActionButton(
                                heroTag: 'zoom_in',
                                mini: true,
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.tealDark,
                                onPressed: () {
                                  _mapController.animateCamera(
                                    CameraUpdate.zoomIn(),
                                  );
                                },
                                child: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                heroTag: 'zoom_out',
                                mini: true,
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.tealDark,
                                onPressed: () {
                                  _mapController.animateCamera(
                                    CameraUpdate.zoomOut(),
                                  );
                                },
                                child: const Icon(Icons.remove),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton(
                                heroTag: 'my_location',
                                mini: true,
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.pyramid,
                                onPressed: () async {
                                  await provider.refreshUserLocation(context);
                                  if (provider.visiblePlaces.isNotEmpty &&
                                      provider.visiblePlaces.first.id == 'user') {
                                    _mapController.animateCamera(
                                      CameraUpdate.newLatLngZoom(
                                        LatLng(
                                          provider.visiblePlaces.first.latitude,
                                          provider.visiblePlaces.first.longitude,
                                        ),
                                        15,
                                      ),
                                    );
                                  }
                                },
                                child: PulseAnimation(
                                  child: const Icon(Icons.my_location),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // View Places List Button
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 90,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.tealDark,
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final places = provider.visiblePlaces;
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (_) => TripDayBottomSheet(
                                  places: places,
                                  dayNumber: 1,
                                  onPlaceTap: (place) {
                                    Navigator.pop(context);
                                    _moveToPlace(place);
                                    _showPlaceInfo(place);
                                  },
                                ),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.list_alt),
                                const SizedBox(width: 8),
                                Text(
                                  'View ${widget.placeIds.length} Places',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        floatingActionButton: Consumer<MapProvider>(
          builder: (context, provider, _) {
            if (provider.loading || !_isMapReady) {
              return const SizedBox.shrink();
            }
            
            return FloatingActionButton.extended(
              onPressed: _startNavigation,
              icon: const Icon(Icons.navigation),
              label: const Text('Start Trip'),
              backgroundColor: AppColors.pyramid,
            );
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Future<void> _startNavigation() async {
    final provider = mapProvider;
    
    await provider.refreshUserLocation(context);
    
    if (provider.visiblePlaces.isEmpty) {
      if (!mounted) return;
      _showEnhancedSnackBar(
        context,
        'No places found!',
        Icons.warning_amber,
        Colors.red,
      );
      return;
    }
    
    final placesToVisit = provider.visiblePlaces
        .where((place) => place.id != 'user')
        .toList();
    
    if (placesToVisit.isEmpty) {
      if (!mounted) return;
      _showEnhancedSnackBar(
        context,
        'No places to visit!',
        Icons.warning_amber,
        Colors.red,
      );
      return;
    }
    
    if (!mounted) return;
    Navigator.push(
      context,
      SlidePageRoute(
        page: ActiveTripScreen(
          places: placesToVisit,
          startingLocation: provider.customStartLocation ??
              (provider.visiblePlaces.isNotEmpty && provider.visiblePlaces.first.id == 'user'
                  ? LatLng(
                      provider.visiblePlaces.first.latitude,
                      provider.visiblePlaces.first.longitude,
                    )
                  : null),
        ),
      ),
    );
  }

  void _showEnhancedSnackBar(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _moveToPlace(Placemap p) {
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 15),
    );
  }

  void _showPlaceInfo(Placemap p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return PlaceInfoCard(
          place: p,
          onNavigate: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }
}