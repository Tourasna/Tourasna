import 'package:flutter/material.dart';
import 'package:new_grad/pages/landmark_details_page.dart';
import '../models/recommendation_item.dart';
import '../services/ai_lens.dart';
import '../services/places_repo.dart';
import '../services/places_search_service.dart';
import 'trip_discovery.dart';
import 'discovery_details_page.dart';
import '../services/landmark_service.dart';
import '../services/agenda_service.dart';

final AILensService aiLens = AILensService();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);
  final Color bgColor = const Color(0xFFF2EADC);

  final PlacesRepo _placesRepo = PlacesRepo();
  final PlacesSearchService _placesSearchService = PlacesSearchService();

  List<RecommendationItem> _featuredPlaces = [];

  Future<void> _openMap() async {
    try {
      final agendaService = AgendaService();
      final today = DateTime.now();
      final from = DateTime(today.year, today.month, today.day);
      final to = from.add(const Duration(days: 1));
      final items = await agendaService.fetch(from: from, to: to);

      final placeIds = items
          .where((e) => e.landmarkId != null)
          .map((e) => e.landmarkId.toString())
          .toList();

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/interactive_map',
        arguments: {'placeIds': placeIds},
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/interactive_map',
        arguments: {'placeIds': <String>[]},
      );
    }
  }

  Future<void> _loadFeaturedPlaces() async {
    try {
      final result = await LandmarksService.search(
        q: '',
        category: '',
        page: 1,
        limit: 6,
        sortMode: 'POPULAR',
      );
      if (mounted) {
        setState(() => _featuredPlaces = result.data);
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadFeaturedPlaces();
  }

  List<RecommendationItem> _searchResults = [];
  bool _searching = false;

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

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _searching = false;
      });
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

  void _onPlaceSelected(RecommendationItem place) {
    setState(() => _searchResults.clear());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DiscoveryDetailsPage(item: place)),
    );
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
          // BACKGROUND IMAGE
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/homepage.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.white.withOpacity(0.15)),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // LOGO
                  // TOP BAR — logo + profile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset('assets/images/icon.png', height: 80),

                              const SizedBox(height: 6),

                              Text(
                                'Tourathna',
                                style: TextStyle(
                                  fontFamily: 'Gambetta',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: darkColor,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, "/profile"),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF7F1E6,
                                ).withOpacity(0.92),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: goldColor.withOpacity(0.3),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: darkColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SEARCH BAR
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E1D3).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        onChanged: _searchPlaces,
                        decoration: InputDecoration(
                          hintText: 'Search For Monument',
                          hintStyle: TextStyle(
                            color: darkColor.withOpacity(0.45),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.search,
                            color: darkColor.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // SEARCH RESULTS DROPDOWN
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 240),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F1E6),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: darkColor.withOpacity(0.08),
                          ),
                          itemBuilder: (_, i) {
                            final place = _searchResults[i];
                            return ListTile(
                              leading: Icon(Icons.place, color: goldColor),
                              title: Text(
                                place.name,
                                style: TextStyle(
                                  color: darkColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                place.category,
                                style: TextStyle(
                                  color: goldColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () => _onPlaceSelected(place),
                            );
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ALL SERVICES LABEL
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'ALL SERVICES',
                      style: TextStyle(
                        fontFamily: 'Gambetta',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: darkColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SERVICE BUTTONS
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _serviceButton(
                          iconPath: 'assets/images/map.png',
                          label: 'Map',
                          onTap: () => _openMap(),
                        ),
                        const SizedBox(width: 12),
                        _serviceButton(
                          iconPath: 'assets/images/lens.png',
                          label: 'AI Lens',
                          onTap: () async => await _runAILens(context),
                        ),
                        const SizedBox(width: 12),
                        _serviceButton(
                          iconPath: 'assets/images/personalized.png',
                          label: 'Planner',
                          onTap: () async => await _openTripDiscovery(),
                        ),
                        const SizedBox(width: 12),
                        _serviceButton(
                          iconPath:
                              'assets/images/Hieroglyphic_Translator_logo.png',
                          label: 'Translator',
                          onTap: () =>
                              Navigator.pushNamed(context, "/hieroglyph"),
                        ),
                        const SizedBox(width: 12),
                        _serviceButton(
                          iconPath: 'assets/images/story.png',
                          label: 'Storytelling',
                          onTap: () {
                            // TODO: navigate to TTS/Stories page
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // CHATBOT BANNER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/mocka'),
                      child: Stack(
                        children: [
                          // BACKGROUND PNG
                          ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.asset(
                              'assets/images/chatbot_bg.png',
                              height: 180, // adjust if needed
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),

                          // OPTIONAL overlay for readability
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(25),
                              color: Colors.black.withOpacity(0.08),
                            ),
                          ),

                          // EXISTING CHATBOT CONTENT
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F1E6).withOpacity(0.09),
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: goldColor.withOpacity(0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Chat with',
                                        style: TextStyle(
                                          color: darkColor.withOpacity(0.6),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Fahmy',
                                        style: TextStyle(
                                          fontFamily: 'Gambetta',
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: darkColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: darkColor,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          'ASK ME ANYTHING',
                                          style: TextStyle(
                                            color: goldColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: darkColor.withOpacity(0.08),
                                      ),
                                    ),
                                    Image.asset(
                                      'assets/images/chatmocka.png',
                                      height: 140,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // HIEROGLYPHICS BANNER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/hieroglyph'),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: darkColor,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Decode Ancient',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Hieroglyphics',
                                    style: TextStyle(
                                      fontFamily: 'Gambetta',
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: goldColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'TRY IT NOW',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '𓂀𓃭𓆣',
                              style: TextStyle(fontSize: 48, color: goldColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // FEATURED PLACES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FEATURED PLACES',
                          style: TextStyle(
                            fontFamily: 'Gambetta',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/discovery'),
                          child: Text(
                            'See All',
                            style: TextStyle(
                              color: goldColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 200,
                    child: _featuredPlaces.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(color: goldColor),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _featuredPlaces.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final item = _featuredPlaces[index];
                              final photoUrl = item.photoUrls.isNotEmpty
                                  ? item.photoUrls.first
                                  : null;
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DiscoveryDetailsPage(item: item),
                                  ),
                                ),
                                child: Container(
                                  width: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: const Color(0xFFE9E1D3),
                                    image: photoUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(photoUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.65),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: goldColor.withOpacity(0.85),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async => await _runAILens(context),
        backgroundColor: const Color(0xFFF2EADC),
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
        color: const Color(0xFFF2EADC),
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
                    isActive: true, // ← always active on HomePage
                    onPressed: () {},
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/icons/favs.png',
                    label: 'FAVs',
                    onPressed: () => Navigator.pushNamed(context, "/favs"),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildNavItem(
                    iconPath: 'assets/icons/agenda.png',
                    label: 'Agenda',
                    onPressed: () => Navigator.pushNamed(context, "/agenda"),
                  ),
                  const SizedBox(width: 28),
                  _buildNavItem(
                    iconPath: 'assets/images/Discovery-3.png',
                    label: 'Discovery',
                    onPressed: () => Navigator.pushNamed(context, "/discovery"),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F1E6).withOpacity(0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(iconPath, height: 48, width: 48),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: darkColor,
              ),
              textAlign: TextAlign.center,
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
            height: 40, // ← reduced from 46
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? darkColor : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              iconPath,
              width: 38, // ← reduced from 42
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
              fontSize: 11, // ← reduced from 12.5
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
