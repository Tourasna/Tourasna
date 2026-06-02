import 'package:flutter/material.dart';
import 'package:new_grad/pages/heritage_3d_page.dart';

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

    // Step 1 — camera + TFLite → ScanResult
    final ScanResult? scan = await _lens.runCamera();

    if (scan == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cancelled.")));
      return;
    }

    print(
      "AI LENS → className=${scan.className}  classIndex=${scan.classIndex}  mlLabel=${scan.mlLabel}",
    );

    // Step 2 — look up place by derived ml_label
    final Place? place = await _repo.getByMLLabel(scan.mlLabel);

    setState(() => _loading = false);

    if (place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "No monument or landmark identified — try again with a different artifact or angle",
          ),
        ),
      );
      return;
    }

    // Step 3 — Heritage3DPage: shows place info + triggers 3D generation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Heritage3DPage(
          place: place,
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
