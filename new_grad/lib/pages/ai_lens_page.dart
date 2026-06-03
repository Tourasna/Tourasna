import 'package:flutter/material.dart';
import 'ai_lens_landmark_page.dart';
import '../services/ai_lens.dart';
import '../services/places_repo.dart';
import '../models/place.dart';
import '../models/recommendation_item.dart';

class AILensPage extends StatefulWidget {
  const AILensPage({super.key});

  @override
  State<AILensPage> createState() => _AILensPageState();
}

class _AILensPageState extends State<AILensPage> {
  final AILensService _lens = AILensService();
  final PlacesRepo _repo = PlacesRepo();

  bool _loading = false;

  Future<void> _scan() async {
    setState(() => _loading = true);

    // Step 1 — camera + TFLite → ScanResult
    final ScanResult? scan = await _lens.runCamera();

    if (scan == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cancelled.')));
      return;
    }

    print(
      'AI LENS → className=${scan.className}  '
      'classIndex=${scan.classIndex}  mlLabel=${scan.mlLabel}',
    );

    // Step 2 — fetch Place by ml_label
    final Place? place = await _repo.getByMLLabel(scan.mlLabel);

    if (place == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No monument or landmark identified — '
            'try again with a different artifact or angle',
          ),
        ),
      );
      return;
    }

    // Step 3 — fetch RecommendationItem for rich data (photos, address, etc.)
    // Falls back gracefully to null if the search returns nothing
    RecommendationItem? item;
    try {
      item = await _repo.searchRecommendationByName(place.name);
    } catch (_) {
      // Non-fatal — AiLensLandmarkPage will fall back to Place data
    }

    setState(() => _loading = false);

    // Step 4 — navigate to landmark page
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiLensLandmarkPage(
          place: place,
          item: item,
          className: scan.className,
          classIndex: scan.classIndex,
          imageB64: scan.imageB64,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Lens')),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _scan,
                child: const Text('Scan Landmark'),
              ),
      ),
    );
  }
}
