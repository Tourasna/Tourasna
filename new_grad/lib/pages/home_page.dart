import 'package:flutter/material.dart';
import 'package:new_grad/pages/landmark_details_page.dart';
import '../models/recommendation_item.dart';
import '../services/recommendation_service.dart';
import '../utils/recommendation_images.dart';
import '../services/ai_lens.dart';
import '../services/places_repo.dart';
import '../services/favorites_service.dart';
import '../services/places_search_service.dart';
import '../models/place_search_item.dart';
import 'trip_discovery.dart';

final AILensService aiLens = AILensService();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RecommendationService _recommendationService = RecommendationService();
  final FavoritesService _favoritesService = FavoritesService();
  final PlacesRepo _placesRepo = PlacesRepo();
  final PlacesSearchService _placesSearchService = PlacesSearchService();

  final Set<int> _favoriteIds = {};

  List<RecommendationItem> _recommendations = [];
  bool _loadingRecs = false;
  bool _recError = false;

  // 🔍 SEARCH STATE
  List<PlaceSearchItem> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _runAILens(BuildContext context) async {
    final label = await aiLens.runCamera();
    if (label == null) return;

    final place = await _placesRepo.getByMLLabel(label);

    if (place == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No match for label")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LandmarkDetailsPage(place: place)),
    );
  }

  // ─────────────────────────────────────────────
  // LIVE SEARCH
  // ─────────────────────────────────────────────
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults.clear());
      return;
    }

    setState(() => _searching = true);

    try {
      final results = await _placesSearchService.search(
        query: query,
        city: 'Cairo',
      );
      setState(() => _searchResults = results);
    } catch (_) {
      setState(() => _searchResults = []);
    } finally {
      setState(() => _searching = false);
    }
  }

  void _onPlaceSelected(PlaceSearchItem place) {
    setState(() => _searchResults.clear());

    Navigator.pushNamed(
      context,
      '/agenda',
      arguments: {'name': place.name, 'placeId': place.id},
    );
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final favs = await _favoritesService.list();
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(favs.map((f) => f.id));
      });
    } catch (_) {
      // Fail silently — favorites are non-critical
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final data = await _recommendationService.getDayPlan();
      setState(() {
        _recommendations = data;
        _loadingRecs = false;
      });
      await _loadFavoriteIds();
    } catch (e) {
      print('❌ LOAD RECOMMENDATIONS ERROR: $e');
      setState(() {
        _recError = true;
        _loadingRecs = false;
      });
    }
  }

  Future<void> _openTripDiscovery() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TripDiscoveryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/homepage.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.white.withOpacity(0.2)),

          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 50),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Image.asset(
                        'assets/images/new logo.png',
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: TextField(
                        onChanged: _searchPlaces,
                        decoration: InputDecoration(
                          hintText: 'Search For Monument',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    // 🔍 SEARCH RESULTS
                    if (_searching)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      )
                    else if (_searchResults.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 8,
                        ),
                        child: Container(
                          height: 210,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (_, i) {
                              final place = _searchResults[i];
                              return ListTile(
                                title: Text(place.name),
                                subtitle: Text(place.subcategory),
                                onTap: () => _onPlaceSelected(place),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 0, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ALL SERVICES',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: 120,
                  child: PageView(
                    controller: PageController(viewportFraction: 0.9),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/map.png',
                              label: 'Map',
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  "/interactive_map",
                                );
                              },
                            ),
                          ),
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/lens.png',
                              label: 'AI Lens',
                              onTap: () async {
                                await _runAILens(context);
                              },
                            ),
                          ),
                          _serviceButton(
                            iconPath: 'assets/images/personalized.png',
                            label: 'Recommendations',
                            onTap: () async {
                              await _openTripDiscovery();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Navigator.pushNamed(context, '/mocka');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5E5D1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Chat Now\nWith Chatbot',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Image.asset(
                            'assets/images/chatmocka.png',
                            height: 80,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 0, 12),
                  child: Text(
                    'FOR YOU: RECOMMENDATIONS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                SizedBox(
                  height: 220,
                  child: _loadingRecs
                      ? const Center(child: CircularProgressIndicator())
                      : _recError
                      ? const Center(
                          child: Text("Failed to load recommendations"),
                        )
                      : _recommendations.isEmpty
                      ? const Center(child: Text("No recommendations yet"))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _recommendations.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 15),
                          itemBuilder: (context, index) {
                            final item = _recommendations[index];
                            return _recommendationCard(item);
                          },
                        ),
                ),

                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _runAILens(context);
        },
        backgroundColor: const Color(0xFFF5E5D1),
        elevation: 8.0,
        shape: const CircleBorder(),
        child: Image.asset(
          'assets/icons/camera.png',
          width: 48,
          height: 48,
          fit: BoxFit.contain,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        color: const Color(0xFFF5E5D1),
        height: 85,
        notchMargin: 8.0,
        elevation: 3.0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
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
                    onPressed: () {},
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/icons/favs.png',
                    label: 'FAVs',
                    onPressed: () {
                      Navigator.pushNamed(context, "/favs");
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNavItem(
                    iconPath: 'assets/icons/agenda.png',
                    label: 'Agenda',
                    onPressed: () {
                      Navigator.pushNamed(context, "/agenda");
                    },
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/icons/profile.png',
                    label: 'Profile',
                    onPressed: () {
                      Navigator.pushNamed(context, "/profile");
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceButton({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(iconPath, height: 55, width: 55),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard(RecommendationItem item) {
    final bool isFavorite = _favoriteIds.contains(item.id);
    final String imagePath = imageForCategory(item.category);

    return GestureDetector(
      onTap: () {},
      child: Stack(
        children: [
          Container(
            width: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Gradient + title
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ❤️ Favorite button
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () async {
                setState(() {
                  if (isFavorite) {
                    _favoriteIds.remove(item.id);
                  } else {
                    _favoriteIds.add(item.id);
                  }
                });
                if (isFavorite) {
                  await _favoritesService.remove(item.id);
                } else {
                  await _favoritesService.add(item.id);
                }
              },
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // 👍 👎 Feedback buttons
          Positioned(
            bottom: 36,
            right: 8,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      await _recommendationService.sendFeedback(
                        landmarkName: item.name,
                        eventType: 'like',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('👍 Liked ${item.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } catch (_) {}
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thumb_up,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    try {
                      await _recommendationService.sendFeedback(
                        landmarkName: item.name,
                        eventType: 'dislike',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('👎 Disliked ${item.name}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    } catch (_) {}
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thumb_down,
                      color: Colors.white,
                      size: 14,
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

  Widget _buildNavItem({
    required String iconPath,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 38,
            alignment: Alignment.center,
            decoration: label == 'Explore'
                ? BoxDecoration(
                    color: const Color(0xFFE9DDC9),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Image.asset(
              iconPath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 0),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F1F1F),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
