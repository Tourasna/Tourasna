import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/place.dart';

class ViewerPage extends StatelessWidget {
  final Place place;

  const ViewerPage({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    final url = place.infoJson?['glb_url'] ?? place.glbUrl;

    print("VIEWER → final GLB URL = $url");

    return Scaffold(
      appBar: AppBar(title: Text(place.name)),
      body: ModelViewer(
        key: UniqueKey(),

        src: ModelViewerSource.network(url), // ← NOW SUPPORTED
        alt: place.name,

        autoRotate: true,
        cameraControls: true,
        disableZoom: false,
        ar: false,

        backgroundColor: Colors.transparent,
        debugLogging: true,
      ),
    );
  }
}
