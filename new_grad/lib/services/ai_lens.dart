import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:new_grad/ai/landmark_classifier.dart';

/// Result of a successful AI Lens scan.
class ScanResult {
  /// Exact class name from labels.json — e.g. "Sphinx of Amenemhat III"
  final String className;

  /// Zero-based class index (0–126) — sent to backend for S3 reference-view lookup.
  final int classIndex;

  /// DB lookup key derived from className — e.g. "sphinx_of_amenemhat_iii"
  final String mlLabel;

  /// Base64-encoded scan photo — used as fallback if no S3 reference views exist yet.
  final String imageB64;

  ScanResult({
    required this.className,
    required this.classIndex,
    required this.mlLabel,
    required this.imageB64,
  });

  /// Converts a TFLite class name to the ml_label format used in the places table.
  /// Formula: lowercase, spaces→underscores, hyphens→underscores, remove commas/apostrophes.
  /// e.g. "Sphinx of Amenemhat III"           → "sphinx_of_amenemhat_iii"
  ///      "Statue of Ptah, Ramesses II, ..."   → "statue_of_ptah_ramesses_ii_and_sekhmet"
  ///      "Al-Azhar Mosque"                    → "al_azhar_mosque"
  static String toMlLabel(String className) {
    return className
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(',', '')
        .replaceAll("'", '');
  }
}

class AILensService {
  final ImagePicker _picker = ImagePicker();
  final LandmarkClassifier _classifier = LandmarkClassifier();

  /// Opens camera → reads bytes → runs TFLite → returns [ScanResult].
  /// Returns null if the user cancels or the model cannot classify the image.
  Future<ScanResult?> runCamera() async {
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
    final result = await _classifier.classifyFull(bytes);
    print(
      "AI → CLASSIFIER RETURNED = ${result?.label} (index ${result?.index})",
    );

    if (result == null) return null;

    return ScanResult(
      className: result.label,
      classIndex: result.index,
      mlLabel: ScanResult.toMlLabel(result.label),
      imageB64: base64Encode(bytes),
    );
  }

  void dispose() {
    _classifier.dispose();
  }
}
