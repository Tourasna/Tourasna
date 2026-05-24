import 'package:flutter/material.dart';
import '../models/recommendation_item.dart';
import '../services/landmark_service.dart';
import 'discovery_details_page.dart';
import '../services/favorites_service.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FavoritesService _favoritesService = FavoritesService();
  final Set<int> _favoriteIds = {};

  // ── Sort mode ──────────────────────────────────
  String _sortMode = 'POPULAR'; // or 'HIDDEN_GEMS'

  // ── Category filter ────────────────────────────
  List<String> _categories = [];
  final Set<String> _selectedCategories = {};
  bool _loadingCategories = true;

  // ── Results ────────────────────────────────────
  List<RecommendationItem> _results = [];
  int _total = 0;
  int _page = 1;
  static const int _limit = 20;
  bool _loadingInitial = true;
  bool _loadingMore = false;

  String _query = '';
  DateTime? _lastSearch;

  // ── Category → Icon mapping ────────────────────
  static const Map<String, IconData> _categoryIcons = {
    'Ancient Monument': Icons.account_balance,
    'Pharaonic Site': Icons.temple_hindu,
    'Islamic Monument': Icons.mosque,
    'Coptic Site': Icons.church,
    'Museum': Icons.museum,
    'Art Gallery': Icons.palette,
    'Cultural Center': Icons.theater_comedy,
    'Park / Garden': Icons.park,
    'Nature Reserve': Icons.forest,
    'Zoo / Aquarium': Icons.pets,
    'Bazaar / Souq': Icons.storefront,
    'Shopping Mall': Icons.shopping_bag,
    'Gold & Jewelry Market': Icons.diamond,
    'Souvenir Shop': Icons.card_giftcard,
    'Antiques': Icons.hourglass_empty,
    'Nile Cruise': Icons.sailing,
    'Nile View Restaurant': Icons.restaurant,
    'Rooftop Restaurant': Icons.roofing,
    'Traditional Restaurant': Icons.dinner_dining,
    'Activity': Icons.hiking,
    'Horse Riding': Icons.sports,
    'Water & Amusement Parks': Icons.water,
    'Theme Park': Icons.attractions,
    'Escape Room': Icons.videogame_asset,
    'Sport & Recreation': Icons.fitness_center,
    'Day Trip Site': Icons.explore,
    'Landmark': Icons.place,
    'Concerts & Shows': Icons.event,
  };
  IconData _iconFor(String category) => _categoryIcons[category] ?? Icons.place;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _fetchLandmarks(reset: true);
    _loadFavoriteIds();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final favs = await _favoritesService.list();
      if (mounted) {
        setState(() {
          _favoriteIds
            ..clear()
            ..addAll(favs.map((f) => f.id));
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await LandmarksService.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  void _onSearchChanged() {
    final now = DateTime.now();
    _lastSearch = now;
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_lastSearch == now && mounted) {
        if (_searchController.text != _query) {
          _query = _searchController.text;
          _fetchLandmarks(reset: true);
        }
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && !_loadingInitial && _results.length < _total) {
        _loadMore();
      }
    }
  }

  Future<void> _fetchLandmarks({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loadingInitial = true;
        _page = 1;
        _results = [];
      });
    }

    try {
      final result = await LandmarksService.search(
        q: _query,
        category: _selectedCategories.length == 1
            ? _selectedCategories.first
            : '',
        page: _page,
        limit: _limit,
        sortMode: _sortMode,
      );

      if (mounted) {
        setState(() {
          _results = reset ? result.data : [..._results, ...result.data];
          _total = result.total;
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingInitial = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loadingInitial) return;
    if (_results.length >= _total) return;

    setState(() {
      _loadingMore = true;
      _page++;
    });

    try {
      final result = await LandmarksService.search(
        q: _query,
        category: _selectedCategories.length == 1
            ? _selectedCategories.first
            : '',
        page: _page,
        limit: _limit,
        sortMode: _sortMode,
      );

      if (mounted) {
        final existingIds = _results.map((e) => e.id).toSet();
        final newItems = result.data
            .where((e) => !existingIds.contains(e.id))
            .toList();
        setState(() {
          _results = [..._results, ...newItems];
          _total = result.total;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMore = false;
          _page--;
        });
      }
    }
  }

  void _toggleCategory(String cat) {
    setState(() {
      if (_selectedCategories.contains(cat)) {
        _selectedCategories.remove(cat);
      } else {
        _selectedCategories.add(cat);
      }
    });
    _fetchLandmarks(reset: true);
  }

  void _clearAllCategories() {
    setState(() => _selectedCategories.clear());
    _fetchLandmarks(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9E1D3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: darkColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Discover Egypt",
                    style: TextStyle(
                      fontFamily: 'Gambetta',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: darkColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── SEARCH ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E1D3),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search For Monument",
                    hintStyle: TextStyle(
                      color: darkColor.withOpacity(0.45),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: darkColor.withOpacity(0.5)),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: darkColor),
                            onPressed: () {
                              _searchController.clear();
                              _query = '';
                              _fetchLandmarks(reset: true);
                            },
                          )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── POPULAR / HIDDEN GEMS ──────────────────────
              Row(
                children: [
                  _sortButton(
                    label: 'POPULAR',
                    icon: Icons.star,
                    mode: 'POPULAR',
                  ),
                  const SizedBox(width: 10),
                  _sortButton(
                    label: 'HIDDEN GEMS',
                    icon: Icons.diamond,
                    mode: 'HIDDEN_GEMS',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── SELECTED CATEGORY CHIPS ────────────────────
              if (_selectedCategories.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _selectedCategories.map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9E1D3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_iconFor(cat), size: 16, color: darkColor),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _toggleCategory(cat),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: darkColor.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    GestureDetector(
                      onTap: _clearAllCategories,
                      child: Text(
                        'CLEAR ALL',
                        style: TextStyle(
                          color: goldColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // ── CATEGORY FILTER ROW ────────────────────────
              if (!_loadingCategories)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // ALL CATEGORIES button
                        final isAll = _selectedCategories.isEmpty;
                        return GestureDetector(
                          onTap: _clearAllCategories,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isAll
                                  ? darkColor
                                  : const Color(0xFFE9E1D3),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.grid_view,
                                  size: 15,
                                  color: isAll
                                      ? goldColor
                                      : darkColor.withOpacity(0.6),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ALL CATEGORIES',
                                  style: TextStyle(
                                    color: isAll ? Colors.white : darkColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final cat = _categories[index - 1];
                      final isSelected = _selectedCategories.contains(cat);
                      return GestureDetector(
                        onTap: () => _toggleCategory(cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? darkColor
                                : const Color(0xFFE9E1D3),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _iconFor(cat),
                                size: 15,
                                color: isSelected
                                    ? goldColor
                                    : darkColor.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : darkColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 10),

              // ── RESULTS COUNT ──────────────────────────────
              if (!_loadingInitial)
                Text(
                  '$_total places found',
                  style: TextStyle(
                    color: darkColor.withOpacity(0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              const SizedBox(height: 10),

              // ── LIST ───────────────────────────────────────
              Expanded(
                child: _loadingInitial
                    ? Center(child: CircularProgressIndicator(color: goldColor))
                    : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No places found',
                          style: TextStyle(color: darkColor.withOpacity(0.5)),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: _results.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _results.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: goldColor,
                                ),
                              ),
                            );
                          }
                          return _LandmarkCard(
                            item: _results[index],
                            darkColor: darkColor,
                            goldColor: goldColor,
                            isFavorite: _favoriteIds.contains(
                              _results[index].id,
                            ),
                            onFavoriteToggle: () async {
                              final item = _results[index];
                              final isFav = _favoriteIds.contains(item.id);
                              setState(() {
                                if (isFav) {
                                  _favoriteIds.remove(item.id);
                                } else {
                                  _favoriteIds.add(item.id);
                                }
                              });
                              try {
                                if (isFav) {
                                  await _favoritesService.remove(item.id);
                                } else {
                                  await _favoritesService.add(item.id);
                                }
                              } catch (_) {
                                // Revert on failure
                                setState(() {
                                  if (isFav) {
                                    _favoriteIds.add(item.id);
                                  } else {
                                    _favoriteIds.remove(item.id);
                                  }
                                });
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortButton({
    required String label,
    required IconData icon,
    required String mode,
  }) {
    final isSelected = _sortMode == mode;
    return GestureDetector(
      onTap: () {
        if (_sortMode != mode) {
          setState(() => _sortMode = mode);
          _fetchLandmarks(reset: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? darkColor : const Color(0xFFE9E1D3),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? goldColor : darkColor.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : darkColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CARD ───────────────────────────────────────────────────────────────────
class _LandmarkCard extends StatelessWidget {
  final RecommendationItem item;
  final Color darkColor;
  final Color goldColor;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _LandmarkCard({
    required this.item,
    required this.darkColor,
    required this.goldColor,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final photoUrl = item.photoUrls.isNotEmpty ? item.photoUrls.first : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DiscoveryDetailsPage(item: item)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: const Color(0xFFF7F1E6),
        ),
        child: Column(
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              child: Stack(
                children: [
                  photoUrl != null
                      ? Image.network(
                          photoUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: onFavoriteToggle,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFavorite ? Colors.red : darkColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENT
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME + RATING
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: 'Gambetta',
                            fontWeight: FontWeight.w700,
                            color: darkColor,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      if (item.rating != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                color: darkColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // TAGS
                  Wrap(
                    spacing: 6,
                    children: [
                      _tag(item.category),
                      if (item.budget.isNotEmpty)
                        _tag(item.budget.toUpperCase()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: const Color(0xFFE9E1D3),
      child: Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EADC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: goldColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
