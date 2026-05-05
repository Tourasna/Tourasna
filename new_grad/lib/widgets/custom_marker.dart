import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Creates a custom marker icon with pin shape and number label
Future<BitmapDescriptor> createCustomMarkerIcon({
  required String imagePath,
  required String label,
  required int number, // ⬅️ جديد: رقم الترتيب
  Color pinColor = const Color(0xFFC6873D),
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  const double pinWidth = 120;
  const double pinHeight = 150;
  const double imageSize = 80;

  // 1. Draw pin shape (teardrop)
  final pinPaint = Paint()
    ..color = pinColor
    ..style = PaintingStyle.fill;

  final path = Path();
  
  path.addOval(Rect.fromCircle(
    center: Offset(pinWidth / 2, pinWidth / 2),
    radius: pinWidth / 2,
  ));
  
  path.moveTo(pinWidth / 2 - 20, pinWidth - 5);
  path.lineTo(pinWidth / 2, pinHeight);
  path.lineTo(pinWidth / 2 + 20, pinWidth - 5);
  path.close();

  canvas.drawPath(path, pinPaint);

  // 2. Draw white circle for image
  final whitePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(pinWidth / 2, pinWidth / 2),
    imageSize / 2 + 8,
    whitePaint,
  );

  // 3. Draw image
  try {
    final image = await _loadImage(imagePath);
    final imageRect = Rect.fromCircle(
      center: Offset(pinWidth / 2, pinWidth / 2),
      radius: imageSize / 2,
    );
    
    canvas.save();
    canvas.clipPath(Path()..addOval(imageRect));
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: image,
      fit: BoxFit.cover,
    );
    canvas.restore();
  } catch (e) {
    print("❌ Error loading image $imagePath: $e");
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(pinWidth / 2, pinWidth / 2),
      15,
      iconPaint,
    );
  }

  // 4. ⬅️ NEW: Draw number badge (top-right corner)
  final badgeRadius = 18.0;
  final badgeCenter = Offset(pinWidth - badgeRadius - 4, badgeRadius + 4);
  
  // Badge background (white circle with shadow)
  final shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.3)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  canvas.drawCircle(badgeCenter, badgeRadius + 1, shadowPaint);
  
  final badgePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);
  
  // Badge border
  final borderPaint = Paint()
    ..color = pinColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;
  canvas.drawCircle(badgeCenter, badgeRadius, borderPaint);
  
  // Number text
  final textPainter = TextPainter(
    text: TextSpan(
      text: number.toString(),
      style: TextStyle(
        color: pinColor,
        fontSize: number > 9 ? 16 : 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      badgeCenter.dx - textPainter.width / 2,
      badgeCenter.dy - textPainter.height / 2,
    ),
  );

  // 5. Convert to image
  final picture = recorder.endRecording();
  final img = await picture.toImage(pinWidth.toInt(), pinHeight.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

/// Creates a simple pin marker without custom image (for user location)
Future<BitmapDescriptor> createSimplePinMarker({
  Color pinColor = const Color(0xFF4285F4),
  Color centerColor = Colors.white,
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);

  const double pinWidth = 90;
  const double pinHeight = 120;

  // Draw pin shape
  final pinPaint = Paint()
    ..color = pinColor
    ..style = PaintingStyle.fill;

  final path = Path();
  path.addOval(Rect.fromCircle(
    center: Offset(pinWidth / 2, pinWidth / 2),
    radius: pinWidth / 2,
  ));
  path.moveTo(pinWidth / 2 - 18, pinWidth - 5);
  path.lineTo(pinWidth / 2, pinHeight);
  path.lineTo(pinWidth / 2 + 18, pinWidth - 5);
  path.close();

  canvas.drawPath(path, pinPaint);

  // Draw white center circle
  final centerPaint = Paint()
    ..color = centerColor
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(pinWidth / 2, pinWidth / 2),
    22,
    centerPaint,
  );

  // Draw blue inner circle
  final innerPaint = Paint()
    ..color = pinColor
    ..style = PaintingStyle.fill;

  canvas.drawCircle(
    Offset(pinWidth / 2, pinWidth / 2),
    12,
    innerPaint,
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(pinWidth.toInt(), pinHeight.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  
  return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
}

Future<ui.Image> _loadImage(String path) async {
  final completer = Completer<ui.Image>();
  final imageProvider = AssetImage(path);
  final stream = imageProvider.resolve(const ImageConfiguration());
  stream.addListener(ImageStreamListener((info, _) {
    completer.complete(info.image);
  }));
  return completer.future;
}