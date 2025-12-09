import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/place.dart';
import 'viewer_page.dart';

class LandmarkDetailsPage extends StatefulWidget {
  final Place place;

  const LandmarkDetailsPage({super.key, required this.place});

  @override
  State<LandmarkDetailsPage> createState() => _LandmarkDetailsPageState();
}

class _LandmarkDetailsPageState extends State<LandmarkDetailsPage> {
  final supabase = Supabase.instance.client;
  final FlutterTts flutterTts = FlutterTts();

  bool _storyLoading = false;

  Future<void> _startStoryFlow() async {
    try {
      setState(() => _storyLoading = true);

      //Fetch existing story safely
      final existing = await supabase
          .from('storytelling')
          .select('story')
          .eq('place_id', widget.place.id)
          .maybeSingle();

      String storyText;

      if (existing == null || existing['story'] == null) {
        //Generate story once using Edge Function
        final res = await supabase.functions.invoke(
          'generate-story',
          body: {"place_id": widget.place.id},
        );

        if (res.status != 200 ||
            res.data == null ||
            res.data['story'] == null) {
          throw "Story generation failed";
        }

        storyText = res.data['story'].toString();
      } else {
        //Use cached story
        storyText = existing['story'].toString();
      }

      // Speak story
      await _speakStory(storyText);
    } catch (e) {
      debugPrint("STORY ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Story error")));
    } finally {
      if (mounted) {
        setState(() => _storyLoading = false);
      }
    }
  }

  Future<void> _speakStory(String text) async {
    if (text.trim().isEmpty) {
      throw "Empty story text";
    }

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final description = widget.place.description ?? "No description available.";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.place.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Text(description, style: const TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _storyLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.volume_up),
                label: const Text(
                  "Start Story",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: _storyLoading ? null : _startStoryFlow,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ViewerPage(place: widget.place),
                    ),
                  );
                },
                child: const Text(
                  "View 3D Model",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
