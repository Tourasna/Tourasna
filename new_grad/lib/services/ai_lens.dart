import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:new_grad/ai/landmark_classifier.dart';

class AILensService {
  final ImagePicker _picker = ImagePicker();
  final LandmarkClassifier _classifier = LandmarkClassifier();

  /// Opens camera → reads bytes → runs TFLite → returns label
  Future<String?> runCamera() async {
    print("AI → Opening camera...");

    final XFile? picture = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1080,
    );

    print("AI → picture = $picture");

    if (picture == null) {
      print("AI → USER CANCELED CAMERA");
      return null;
    }

    final Uint8List bytes = await picture.readAsBytes();
    print("AI → bytes.length = ${bytes.length}");

    print("AI → Running classifier...");
    final String? label = await _classifier.classify(bytes);

    print("AI → CLASSIFIER RETURNED = $label");

    return label;
  }

  void dispose() {
    _classifier.dispose();
  }
}
