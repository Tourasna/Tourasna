import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' show Response;
import 'api_client.dart';

enum ModelState { generating, shapeReady, textured, failed, notFound }

class ModelStatus {
  final ModelState state;
  final String? shapeUrl;
  final String? textureUrl;
  final String? errorCode;

  ModelStatus({
    required this.state,
    this.shapeUrl,
    this.textureUrl,
    this.errorCode,
  });

  /// Best GLB available right now (textured > shape).
  String? get bestUrl => textureUrl ?? shapeUrl;

  bool get hasModel => shapeUrl != null || textureUrl != null;

  factory ModelStatus.fromJson(Map<String, dynamic> j) {
    final s = (j['status'] ?? 'not_found') as String;
    final state =
        {
          'generating': ModelState.generating,
          'shape_ready': ModelState.shapeReady,
          'textured': ModelState.textured,
          'failed': ModelState.failed,
          'not_found': ModelState.notFound,
        }[s] ??
        ModelState.notFound;
    return ModelStatus(
      state: state,
      shapeUrl: j['shapeUrl'] as String?,
      textureUrl: j['textureUrl'] as String?,
      errorCode: j['errorCode'] as String?,
    );
  }
}

class ThreeDModelService {
  /// Kick off (or look up cached) 3D generation for a monument.
  ///
  /// [className]  — exact class_name string from the TFLite labels.json
  ///                e.g. "Sphinx of Amenemhat III"
  /// [classIndex] — bestIndex from LandmarkClassifier (0–126)
  /// [imageB64]   — the user's scan photo as base64; used only when no S3
  ///                reference views exist for this monument yet.
  Future<ModelStatus> requestModel(
    String className,
    int classIndex,
    String imageB64,
  ) async {
    final Response res = await ApiClient.post(
      '/api/3dmodel/generate',
      body: {'className': className, 'classIndex': classIndex},
    );
    return ModelStatus.fromJson(_decode(res));
  }

  Future<ModelStatus> getStatus(String className) async {
    final Response res = await ApiClient.get(
      '/api/3dmodel/status?className=${Uri.encodeQueryComponent(className)}',
    );
    return ModelStatus.fromJson(_decode(res));
  }

  /// Poll until shape is ready (or failed/timed-out).
  /// Returns as soon as shapeUrl is available — texture keeps cooking in background.
  /// [timeout] covers worst-case cold start (25 min per spec).
  Future<ModelStatus> pollUntilShapeReady(
    String className, {
    Duration interval = const Duration(seconds: 6),
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final st = await getStatus(className);
      if (st.state == ModelState.shapeReady ||
          st.state == ModelState.textured ||
          st.state == ModelState.failed)
        return st;
      await Future.delayed(interval);
    }
    return ModelStatus(state: ModelState.failed, errorCode: 'TIMEOUT');
  }

  /// Optional: keep polling in background until textured GLB lands (10-20 min).
  /// Use to silently upgrade the viewer from shape to textured mesh.
  Future<ModelStatus> pollForTexture(
    String className, {
    Duration interval = const Duration(seconds: 30),
    Duration timeout = const Duration(minutes: 25),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final st = await getStatus(className);
      if (st.state == ModelState.textured || st.state == ModelState.failed)
        return st;
      await Future.delayed(interval);
    }
    return await getStatus(className);
  }

  Map<String, dynamic> _decode(Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) return body;
    } catch (_) {}
    return {'status': 'not_found'};
  }
}
