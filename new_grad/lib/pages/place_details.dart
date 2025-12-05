import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class PlaceDetailsPage extends StatelessWidget {
  final Map<String, dynamic> place;

  const PlaceDetailsPage({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final String name = place['name'] ?? "Unknown";
    final String description =
        place['description'] ?? "No description available.";
    final String glbUrl = place['glb_url'] ?? "";
    final double? latitude = place['latitude'];
    final double? longitude = place['longitude'];
    final Map<String, dynamic>? infoJson = place['info_json'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------
            // 3D MODEL VIEWER
            // -------------------------------
            if (glbUrl.isNotEmpty)
              SizedBox(
                height: 350,
                child: ModelViewer(
                  src: glbUrl,
                  alt: "3D model of $name",
                  ar: true,
                  autoRotate: true,
                  cameraControls: true,
                ),
              )
            else
              Container(
                height: 300,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Text("No 3D model available"),
              ),

            const SizedBox(height: 20),

            // -------------------------------
            // BASIC INFO
            // -------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),

            const SizedBox(height: 20),

            // -------------------------------
            // INFO JSON (Optional)
            // -------------------------------
            if (infoJson != null && infoJson.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "More Information",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    ...infoJson.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          "${e.key}: ${e.value}",
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            // -------------------------------
            // SHOW LAT/LONG
            // -------------------------------
            if (latitude != null && longitude != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Location",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text("Latitude: $latitude"),
                    Text("Longitude: $longitude"),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
