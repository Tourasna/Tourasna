import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../models/place_map.dart';

class PlaceInfoCard extends StatelessWidget {
  final Placemap place;
  final VoidCallback onNavigate;

  const PlaceInfoCard({
    Key? key,
    required this.place,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7, // ✅ Max 70% of screen
      ),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView( // ✅ Scrollable
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              place.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(height: 12),

            // Category
            if (place.category != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.pyramid.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.category, size: 16, color: AppColors.pyramid),
                    const SizedBox(width: 6),
                    Text(
                      place.category!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.pyramid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Image
            if (place.imageUrl != null && place.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: place.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.pyramid),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description (Scrollable)
            if (place.description != null && place.description!.isNotEmpty) ...[
              const Text(
                'About',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(
                  maxHeight: 150, // ✅ Max height for description
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.pyramid.withOpacity(0.2)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    place.description!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Visit Time
            if (place.estimatedVisitTime != null) ...[
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18, color: AppColors.pyramid),
                  const SizedBox(width: 8),
                  Text(
                    'Visit time: ${place.estimatedVisitTime}',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ✅ NO Navigation Button - Removed
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}