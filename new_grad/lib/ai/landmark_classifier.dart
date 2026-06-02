import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of a successful classification.
class ClassificationResult {
  /// Exact class name string from labels.json — e.g. "Sphinx of Amenemhat III"
  final String label;

  /// Zero-based class index (0–126) — used for S3 reference-view lookup.
  final int index;

  /// Confidence score (0.0–1.0).
  final double confidence;

  ClassificationResult({
    required this.label,
    required this.index,
    required this.confidence,
  });
}

class LandmarkClassifier {
  static const _modelPath = 'assets/ml/landmark_classifier.tflite';
  static const _labelsPath = 'assets/ml/labels.json';

  /// Minimum confidence to count as a valid detection.
  /// Below this → return null ("not identified").
  static const _threshold = 0.25;

  /// YOLOv8 output: [1, 4 + numClasses, numAnchors]
  /// For 640×640 input with 127 classes:
  ///   numAnchors = 80²+40²+20² = 8400
  ///   numFeatures = 4 (bbox) + 127 (classes) = 131
  static const _numAnchors = 8400;
  static const _bboxOffset = 4; // first 4 rows are cx,cy,w,h

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;

  Future<void> loadModel() async {
    if (_initialized) return;
    print("CLASSIFIER → Loading model...");
    _interpreter = await Interpreter.fromAsset(_modelPath);

    print("CLASSIFIER → Loading labels...");
    final raw = await rootBundle.loadString(_labelsPath);
    final Map<String, dynamic> decoded = jsonDecode(raw);
    _labels = List.generate(decoded.length, (i) => decoded["$i"].toString());
    print("CLASSIFIER → ${_labels.length} labels loaded.");

    // Log tensor shapes for debugging
    final inShape = _interpreter.getInputTensors().first.shape;
    final outShape = _interpreter.getOutputTensors().first.shape;
    print("CLASSIFIER → input shape:  $inShape");
    print("CLASSIFIER → output shape: $outShape");

    _initialized = true;
  }

  /// Returns the best-matching monument, or null if confidence < threshold.
  /// Handles YOLOv8 detection output: [1, 4+numClasses, numAnchors].
  Future<ClassificationResult?> classifyFull(Uint8List bytes) async {
    if (!_initialized) await loadModel();

    print("CLASSIFIER → Decoding image...");
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      print("CLASSIFIER → decodeImage returned NULL");
      return null;
    }

    // Read input shape [1, H, W, 3]
    final inputShape = _interpreter.getInputTensors().first.shape;
    final int height = inputShape[1];
    final int width = inputShape[2];
    print("CLASSIFIER → Resizing to ${width}×${height}");

    final img.Image resized = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    // Build input tensor [1, H, W, 3] normalised 0–1
    final input = List.generate(
      1,
      (_) => List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        });
      }),
    );

    // Output buffer matching YOLOv8 detection shape [1, 131, 8400]
    final numFeatures = _bboxOffset + _labels.length; // 4 + 127 = 131
    final output = List.generate(
      1,
      (_) => List.generate(
        numFeatures,
        (_) => List<double>.filled(_numAnchors, 0.0),
      ),
    );

    print("CLASSIFIER → Running YOLOv8 inference...");
    _interpreter.run(input, output);

    // Find anchor + class with highest score
    // output[0][4+j][i] = score for class j at anchor i
    int bestClass = 0;
    double bestScore = 0.0;

    for (int i = 0; i < _numAnchors; i++) {
      for (int j = 0; j < _labels.length; j++) {
        final score = output[0][_bboxOffset + j][i];
        if (score > bestScore) {
          bestScore = score;
          bestClass = j;
        }
      }
    }

    print(
      "CLASSIFIER → bestClass=$bestClass  bestScore=${bestScore.toStringAsFixed(4)}  label=${_labels[bestClass]}",
    );

    if (bestScore < _threshold) {
      print("CLASSIFIER → below threshold ($_threshold) — returning null");
      return null;
    }

    return ClassificationResult(
      label: _labels[bestClass],
      index: bestClass,
      confidence: bestScore,
    );
  }

  /// Backward-compatible wrapper — returns only the label string.
  Future<String?> classify(Uint8List bytes) async {
    final result = await classifyFull(bytes);
    return result?.label;
  }

  void dispose() {
    if (_initialized) _interpreter.close();
    _initialized = false;
  }
}
