import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_map.dart';

class TransportOptionsDialog {
  /// Show transport options (Uber, Google Maps, etc.)
  static Future<void> show({
    required BuildContext context,
    required Placemap destination,
    double? currentLat,
    double? currentLng,
  }) async {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                const Icon(
                  Icons.directions_car,
                  size: 28,
                  color: Color(0xFF2F6A6E),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Navigate to',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        destination.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2F6A6E),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            
            // Uber Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: const Text(
                'Uber',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Book a ride now'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await _launchUber(
                  destinationLat: destination.latitude,
                  destinationLng: destination.longitude,
                  pickupLat: currentLat,
                  pickupLng: currentLng,
                  context: context,
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Careem Option (متوفر في مصر)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A859),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: const Text(
                'Careem',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Popular in Egypt'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await _launchCareem(
                  destinationLat: destination.latitude,
                  destinationLng: destination.longitude,
                  pickupLat: currentLat,
                  pickupLng: currentLng,
                  context: context,
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Google Maps Option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.map,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              title: const Text(
                'Google Maps',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: const Text('Drive yourself'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                Navigator.pop(ctx);
                await _launchGoogleMaps(
                  destinationLat: destination.latitude,
                  destinationLng: destination.longitude,
                  context: context,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Launch Uber app
  static Future<void> _launchUber({
    required double destinationLat,
    required double destinationLng,
    double? pickupLat,
    double? pickupLng,
    required BuildContext context,
  }) async {
    // Uber Deep Link
    String uberUrl = 'uber://?action=setPickup'
        '&dropoff[latitude]=$destinationLat'
        '&dropoff[longitude]=$destinationLng';
    
    if (pickupLat != null && pickupLng != null) {
      uberUrl += '&pickup[latitude]=$pickupLat'
          '&pickup[longitude]=$pickupLng';
    }
    
    final uri = Uri.parse(uberUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Uber website
        final webUrl = Uri.parse(
          'https://m.uber.com/ul/?action=setPickup'
          '&dropoff[latitude]=$destinationLat'
          '&dropoff[longitude]=$destinationLng',
        );
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error launching Uber: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not open Uber. Please install the app.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// Launch Careem app
  static Future<void> _launchCareem({
    required double destinationLat,
    required double destinationLng,
    double? pickupLat,
    double? pickupLng,
    required BuildContext context,
  }) async {
    // Careem Deep Link
    String careemUrl = 'careem://ride?'
        'dropoff_latitude=$destinationLat'
        '&dropoff_longitude=$destinationLng';
    
    if (pickupLat != null && pickupLng != null) {
      careemUrl += '&pickup_latitude=$pickupLat'
          '&pickup_longitude=$pickupLng';
    }
    
    final uri = Uri.parse(careemUrl);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to Careem website
        final webUrl = Uri.parse('https://www.careem.com/');
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Error launching Careem: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not open Careem. Please install the app.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  /// Launch Google Maps
  static Future<void> _launchGoogleMaps({
    required double destinationLat,
    required double destinationLng,
    required BuildContext context,
  }) async {
    final url = 'google.navigation:q=$destinationLat,$destinationLng&mode=d';
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1'
          '&destination=$destinationLat,$destinationLng'
          '&travelmode=driving',
        );
        await launchUrl(webUrl);
      }
    } catch (e) {
      print('❌ Error launching Google Maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not open Google Maps',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}