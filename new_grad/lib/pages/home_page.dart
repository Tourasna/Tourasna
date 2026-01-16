import 'package:flutter/material.dart';
import 'package:new_grad/pages/landmark_details_page.dart';
import '../widgets/context_bottom_sheet.dart';
import '../models/recommendation_item.dart';
import '../services/recommendation_service.dart';
import '../utils/recommendation_images.dart';
import '../services/ai_lens.dart';
import '../services/places_repo.dart';
import '../services/auth_service.dart';

final AILensService aiLens = AILensService();

// 🔑 SINGLE shared AuthService instance
final AuthService authService = AuthService();

// 🔌 Repo depends on auth
final PlacesRepo placesRepo = PlacesRepo(authService);

final Set<String> favoriteTitles = {};

Future<void> runAILens(BuildContext context) async {
  final label = await aiLens.runCamera();
  if (label == null) return;

  final place = await placesRepo.getByMLLabel(label);

  if (place == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("No match for label")));
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          LandmarkDetailsPage(place: place, authService: authService),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final RecommendationService recommendationService;

  List<RecommendationItem> _recommendations = [];
  bool _loadingRecs = true;
  bool _recError = false;

  @override
  void initState() {
    super.initState();
    recommendationService = RecommendationService(authService);
  }

  Future<void> _loadRecommendations() async {
    try {
      final data = await recommendationService.getRecommendations();
      setState(() {
        _recommendations = data;
        _loadingRecs = false;
      });
    } catch (_) {
      setState(() {
        _recError = true;
        _loadingRecs = false;
      });
    }
  }

  Future<void> _ensureContextThenLoadRecommendations() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ContextBottomSheet(),
    );

    if (result == true) {
      await _loadRecommendations();
    }
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
                              onTap: () {},
                            ),
                          ),
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/lens.png',
                              label: 'AI Lens',
                              onTap: () async {
                                await runAILens(context);
                              },
                            ),
                          ),
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/story.png',
                              label: 'StoryTellings',
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/tts.png',
                              label: 'TTS',
                              onTap: () {},
                            ),
                          ),
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/personalized.png',
                              label: 'Recommendations',
                              onTap: () async {
                                await _ensureContextThenLoadRecommendations();
                              },
                            ),
                          ),
                          Flexible(
                            child: _serviceButton(
                              iconPath: 'assets/images/contextual.png',
                              label: 'Contextual Awareness',
                              onTap: () {},
                            ),
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
                      Navigator.pushNamed(context, '/chatbot');
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
                          Image.asset('assets/images/isis.png', height: 80),
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
                            return _recommendationCard(
                              imageForCategory(item.category),
                              item.name,
                            );
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
          await runAILens(context);
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
                    onPressed: () {},
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

  Widget _recommendationCard(String imagePath, String title) {
    final bool isFavorite = favoriteTitles.contains(title);

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
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isFavorite) {
                    favoriteTitles.remove(title);
                  } else {
                    favoriteTitles.add(title);
                  }
                });
              },
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: Colors.black,
                size: 26,
              ),
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
            height: 40,
            alignment: Alignment.center,
            decoration: label == 'Explore'
                ? BoxDecoration(
                    color: const Color(0xFFE9DDC9),
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: Image.asset(
              iconPath,
              width: 42,
              height: 42,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F1F1F),
              fontSize: 14.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
