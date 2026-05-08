import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/recommendation_item.dart';

class RecommendationDetailsPage extends StatefulWidget {
  final RecommendationItem item;
  const RecommendationDetailsPage({super.key, required this.item});

  @override
  State<RecommendationDetailsPage> createState() =>
      _RecommendationDetailsPageState();
}

class _PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final Set<int> _failedIndexes = {};
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final valid = <String>[];
    final validOriginalIndexes = <int>[];

    for (int i = 0; i < widget.photos.length; i++) {
      if (!_failedIndexes.contains(i)) {
        valid.add(widget.photos[i]);
        validOriginalIndexes.add(i);
      }
    }

    if (valid.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No photos available',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: valid.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => Image.network(
            valid[i],
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _failedIndexes.add(validOriginalIndexes[i]);
                    if (_current >= valid.length - 1) {
                      _current = 0;
                    }
                  });
                }
              });
              return Container(
                color: Colors.grey[200],
                child: const Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.grey,
                ),
              );
            },
          ),
        ),
        if (valid.length > 1)
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_current + 1}/${valid.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecommendationDetailsPageState extends State<RecommendationDetailsPage> {
  static const _teal = Color(0xFF1A3C3C);
  static const _gold = Color(0xFFC5A059);
  static const _bg = Color(0xFFF2EADC);
  static const _cream = Color(0xFFF5EFE4);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final photos = item.photoUrls;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // ── Header ──────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circle(Icons.arrow_back, () => Navigator.pop(context)),
                  const Text(
                    'MONUMENT DETAILS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: _teal,
                    ),
                  ),
                  _circle(Icons.share, () {}),
                ],
              ),

              const SizedBox(height: 20),

              // ── Photo carousel ───────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 240,
                      width: double.infinity,
                      child: photos.isNotEmpty
                          ? _PhotoCarousel(photos: photos)
                          : Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),

                    // Rating badge
                    Positioned(
                      top: 15,
                      left: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.rating?.toStringAsFixed(1) ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item.reviewCount != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                '(${_formatCount(item.reviewCount!)})',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Name ────────────────────────────────────
              Text(
                item.name,
                style: const TextStyle(
                  fontFamily: 'Gambetta',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _teal,
                ),
              ),

              const SizedBox(height: 15),

              // ── Info badges ──────────────────────────────
              Wrap(
                spacing: 6,
                runSpacing: 8,
                children: [
                  if (item.address != null)
                    _badge(
                      item.address!.trim().length > 35
                          ? '${item.address!.trim().substring(0, 35)}...'
                          : item.address!.trim(),
                      Icons.location_on,
                    ),
                  if (item.openingHours != null)
                    _badge(item.openingHours!, Icons.access_time),
                  if (item.priceRange != null)
                    _badge(
                      'EGP ${item.priceRange!}',
                      Icons.confirmation_number,
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Description ──────────────────────────────
              if (item.description != null)
                Text(
                  item.description!,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),

              const SizedBox(height: 30),

              // ── Google Maps button ───────────────────────
              if (item.googleMapsUrl != null)
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(item.googleMapsUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3C3C),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'OPEN IN GOOGLE MAPS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Widget _circle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _teal),
      ),
    );
  }

  Widget _badge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _gold),
          const SizedBox(width: 5),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
