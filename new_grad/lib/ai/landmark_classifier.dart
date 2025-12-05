import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class LandmarkClassifier {
  static const _modelPath = 'assets/ml/landmark_classifier.tflite';
  static const _labelsPath = 'assets/ml/labels.json';

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

    print("CLASSIFIER → Loaded ${_labels.length} labels.");
    _initialized = true;
  }

  Future<String?> classify(Uint8List bytes) async {
    if (!_initialized) {
      await loadModel();
    }

    print("CLASSIFIER → Decoding image...");
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      print(
        "CLASSIFIER → decodeImage returned NULL. Image format not supported.",
      );
      return null;
    }

    // Read input tensor shape (1, H, W, 3)
    final inputShape = _interpreter.getInputTensors().first.shape;
    final int height = inputShape[1];
    final int width = inputShape[2];

    print("CLASSIFIER → Model input size = ${width}x${height}");

    // Resize image
    final img.Image resized = img.copyResize(
      image,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );

    print("CLASSIFIER → Resized.");

    // Build input tensor
    final input = List.generate(
      1,
      (_) => List.generate(height, (y) {
        return List.generate(width, (x) {
          final pixel = resized.getPixel(x, y);

          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;

          return [r, g, b];
        });
      }),
    );

    print("CLASSIFIER → Running inference...");
    final output = List.filled(1, List.filled(_labels.length, 0.0));

    _interpreter.run(input, output);

    final probs = output[0];

    print("CLASSIFIER → First 5 outputs: ${probs.take(5).toList()}");

    // Argmax
    int bestIndex = 0;
    double bestScore = probs[0];

    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > bestScore) {
        bestScore = probs[i];
        bestIndex = i;
      }
    }

    print("CLASSIFIER → bestIndex = $bestIndex, bestScore = $bestScore");
    print("CLASSIFIER → label = ${_labels[bestIndex]}");

    return _labels[bestIndex];
  }

  void dispose() {
    if (_initialized) {
      _interpreter.close();
    }
    _initialized = false;
  }
}
