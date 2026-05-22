import 'package:flutter/material.dart';
import '../models/recommendation_item.dart';
import '../services/favorites_service.dart';

class _C {
  static const papyrus = Color(0xFFF2EADC);
  static const teal = Color(0xFF1A3C3C);
  static const gold = Color(0xFFC5A059);
  static const surface = Color(0xFFEAE2D1);
  static const cardBg = Color(0xCCFFFFFF);
}

class FavsPage extends StatefulWidget {
  const FavsPage({super.key});

  @override
  State<FavsPage> createState() => _FavsPageState();
}

class _FavsPageState extends State<FavsPage> {
  final FavoritesService favoritesService = FavoritesService();

  bool _loading = true;
  List<RecommendationItem> _favorites = [];

  TextStyle get _serif => const TextStyle(
    fontFamily: 'Gambetta',
    fontWeight: FontWeight.w700,
    color: _C.teal,
  );
  TextStyle get _sans => const TextStyle(fontFamily: 'Satoshi', color: _C.teal);

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);
    _favorites = await favoritesService.list();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _removeFavorite(RecommendationItem item) async {
    await favoritesService.remove(item.id);
    if (mounted) setState(() => _favorites.removeWhere((f) => f.id == item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.papyrus,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _C.gold))
                  : _favorites.isEmpty
                  ? _buildEmpty()
                  : _buildGrid(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── top bar ───────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.teal.withValues(alpha: 0.08)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _C.teal,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text('Favourites', style: _serif.copyWith(fontSize: 28)),
          const Spacer(),
          if (_favorites.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _C.gold.withValues(alpha: 0.25)),
              ),
              child: Text(
                '${_favorites.length} saved',
                style: _sans.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.gold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── empty state ───────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.gold.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: _C.gold.withValues(alpha: 0.25)),
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              color: _C.gold.withValues(alpha: 0.60),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text('No favourites yet', style: _serif.copyWith(fontSize: 20)),
          const SizedBox(height: 8),
          Text(
            'Explore landmarks and save your\nfavourites here',
            textAlign: TextAlign.center,
            style: _sans.copyWith(
              fontSize: 13,
              color: _C.teal.withValues(alpha: 0.50),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/discovery'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _C.teal,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _C.teal.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                'Explore Landmarks',
                style: _sans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── grid ──────────────────────────────────────
  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: _favorites.length,
      itemBuilder: (_, i) => _favCard(_favorites[i]),
    );
  }

  // ── fav card ──────────────────────────────────
  Widget _favCard(RecommendationItem item) {
    final photo = item.photoUrls.isNotEmpty ? item.photoUrls.first : null;

    return GestureDetector(
      onLongPress: () => _showAgendaSheet(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _C.surface,
          image: photo != null
              ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
              : null,
          boxShadow: [
            BoxShadow(
              color: _C.teal.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // name + category
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Gambetta',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _C.gold.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
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

            // heart button
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => _removeFavorite(item),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── bottom nav ────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 85,
      decoration: BoxDecoration(
        color: _C.papyrus,
        border: Border(top: BorderSide(color: _C.teal.withValues(alpha: 0.05))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _navItem(
              'assets/icons/explore.png',
              'Explore',
              () => Navigator.pushNamed(context, '/homescreen'),
            ),
            _navItem('assets/icons/favs.png', 'FAVs', () {}, isActive: true),
            _navItem(
              'assets/icons/agenda.png',
              'Agenda',
              () => Navigator.pushNamed(context, '/agenda'),
            ),
            _navItem(
              'assets/images/Discovery-3.png',
              'Discovery',
              () => Navigator.pushNamed(context, '/discovery'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    String iconPath,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
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
              color: isActive ? _C.teal : Colors.transparent,
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
            style: _sans.copyWith(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
              color: isActive ? _C.teal : const Color(0xFF1F1F1F),
            ),
          ),
        ],
      ),
    );
  }

  // ── agenda sheet ──────────────────────────────
  void _showAgendaSheet(RecommendationItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _C.papyrus,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _C.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.name,
              style: _serif.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _sheetAction(
              icon: Icons.event_rounded,
              label: 'Add to Agenda',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/agenda', arguments: item);
              },
            ),
            const SizedBox(height: 10),
            _sheetAction(
              icon: Icons.favorite_border_rounded,
              label: 'Remove from Favourites',
              isRed: true,
              onTap: () async {
                Navigator.pop(context);
                await _removeFavorite(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isRed = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isRed
              ? Colors.red.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isRed
                ? Colors.red.withValues(alpha: 0.20)
                : _C.teal.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isRed ? Colors.redAccent : _C.gold, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: _sans.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isRed ? Colors.redAccent : _C.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
