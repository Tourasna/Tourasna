import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recommendation_item.dart';
import '../utils/network_navigator.dart';

class DiscoveryDetailsPage extends StatefulWidget {
  final RecommendationItem item;

  const DiscoveryDetailsPage({super.key, required this.item});

  @override
  State<DiscoveryDetailsPage> createState() => _DiscoveryDetailsPageState();
}

class _DiscoveryDetailsPageState extends State<DiscoveryDetailsPage> {
  final Color bgColor = const Color(0xFFF2EADC);
  final Color darkColor = const Color(0xFF1A3C3C);
  final Color goldColor = const Color(0xFFC5A059);

  int _currentPhoto = 0;

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
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        icon: Icon(icon, color: goldColor),
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
        onPressed: onTap,
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
                  isActive: true,
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

  Future<void> _openMaps() async {
    final url = widget.item.googleMapsUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final photos = item.photoUrls;
    final description = item.description ?? 'No description available.';

    return Scaffold(
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
                    onTap: () => Navigator.pop(context),
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
                    'PLACE DETAILS',
                    style: TextStyle(
                      color: darkColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 42),
                ],
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo carousel
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
                                  if (item.rating != null)
                                    Positioned(
                                      top: 16,
                                      left: 16,
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
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 15,
                                              color: Colors.amber,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.rating!.toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
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
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            width: i == _currentPhoto ? 18 : 6,
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
                      item.category.toUpperCase(),
                      style: TextStyle(
                        color: goldColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      item.name,
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
                        if (item.address != null)
                          _infoChip(Icons.location_on, item.address!),
                        if (item.openingHours != null)
                          _infoChip(Icons.access_time, item.openingHours!),
                        if (item.priceRange != null)
                          _infoChip(
                            Icons.confirmation_num,
                            '${item.priceRange} EGP',
                          ),
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

                    if (item.googleMapsUrl != null)
                      _mainButton(
                        icon: Icons.map_outlined,
                        text: 'OPEN IN GOOGLE MAPS',
                        onTap: _openMaps,
                        dark: true,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
