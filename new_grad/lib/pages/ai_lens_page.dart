import 'package:flutter/material.dart';
import 'package:new_grad/pages/landmark_details_page.dart';
import '../services/ai_lens.dart';
import '../services/places_repo.dart';
import '../models/place.dart';

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

    // Step 1 → run camera + tflite
    final label = await _lens.runCamera();

    if (label == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cancelled.")));
      return;
    }

    // Step 2 → get place from Supabase
    final Place? place = await _repo.getByMLLabel(label);

    setState(() => _loading = false);

    if (place == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No match for label: $label")));
      return;
    }

    // Step 3 → go to viewer
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LandmarkDetailsPage(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Lens")),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _scan,
                child: const Text("Scan Landmark"),
              ),
      ),
    );
  }
}
