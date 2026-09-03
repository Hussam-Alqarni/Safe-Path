import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

/// Builds the marker bitmaps Google Maps draws.
///
/// The default coloured teardrops carry no information: a bus, a served stop
/// and a skipped stop all look like pins. Drawing them means state is legible
/// from shape and colour at a glance, and the bus can point where it is going.
///
/// Rendering a bitmap is expensive, so every icon is cached by its full
/// description and built at most once per session.
class MapMarkerFactory {
  MapMarkerFactory({required this.devicePixelRatio});

  final double devicePixelRatio;
  final _cache = <String, gmaps.BitmapDescriptor>{};

  /// A bus, drawn as a circle with a heading arrow.
  ///
  /// The arrow points up; Google rotates the marker itself, so the bitmap is
  /// heading-independent and one cached image serves every direction.
  Future<gmaps.BitmapDescriptor> bus({
    required Color color,
    required bool stale,
  }) {
    return _cached('bus-${color.toARGB32()}-$stale', 64, (canvas, size) {
      final centre = Offset(size / 2, size / 2);
      final paint = Paint()..color = color;

      if (!stale) {
        canvas.drawCircle(
          centre,
          size / 2,
          Paint()..color = color.withValues(alpha: 0.18),
        );
      }
      canvas.drawCircle(centre, size * 0.34, Paint()..color = Colors.white);
      canvas.drawCircle(
        centre,
        size * 0.34,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.07
          ..color = color,
      );

      // A chevron pointing to the top of the bitmap.
      final arrow = Path()
        ..moveTo(centre.dx, centre.dy - size * 0.20)
        ..lineTo(centre.dx + size * 0.14, centre.dy + size * 0.13)
        ..lineTo(centre.dx, centre.dy + size * 0.04)
        ..lineTo(centre.dx - size * 0.14, centre.dy + size * 0.13)
        ..close();
      canvas.drawPath(arrow, paint);
    });
  }

  /// A numbered stop. Filled when served, hollow when still to come, and
  /// struck through when skipped — the plan stays readable either way.
  Future<gmaps.BitmapDescriptor> stop({
    required Color color,
    required bool filled,
    required bool struck,
    int? sequence,
  }) {
    final key = 'stop-${color.toARGB32()}-$filled-$struck-$sequence';
    return _cached(key, 44, (canvas, size) {
      final centre = Offset(size / 2, size / 2);
      final radius = size * 0.34;

      canvas.drawCircle(centre, radius, Paint()..color = Colors.white);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.09
          ..color = color,
      );
      if (filled) {
        canvas.drawCircle(centre, radius * 0.52, Paint()..color = color);
      }
      if (struck) {
        final paint = Paint()
          ..strokeWidth = size * 0.08
          ..strokeCap = StrokeCap.round
          ..color = color;
        final r = radius * 0.62;
        canvas.drawLine(
          centre + Offset(-r, -r),
          centre + Offset(r, r),
          paint,
        );
      } else if (sequence != null) {
        _drawText(
          canvas,
          '$sequence',
          centre,
          size * 0.30,
          filled ? Colors.white : color,
        );
      }
    });
  }

  /// The school: a square, so it never reads as one more stop.
  Future<gmaps.BitmapDescriptor> school({required Color color}) {
    return _cached('school-${color.toARGB32()}', 48, (canvas, size) {
      final rect = Rect.fromCenter(
        center: Offset(size / 2, size / 2),
        width: size * 0.62,
        height: size * 0.62,
      );
      final rrect = RRect.fromRectAndRadius(
        rect,
        Radius.circular(size * 0.16),
      );
      canvas.drawRRect(rrect, Paint()..color = Colors.white);
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.08
          ..color = color,
      );
      final flag = Path()
        ..moveTo(size * 0.42, size * 0.64)
        ..lineTo(size * 0.42, size * 0.34)
        ..lineTo(size * 0.64, size * 0.41)
        ..lineTo(size * 0.42, size * 0.48)
        ..close();
      canvas.drawPath(flag, Paint()..color = color);
    });
  }

  /// A student's home: a house outline, distinct from both stop and school.
  Future<gmaps.BitmapDescriptor> home({required Color color}) {
    return _cached('home-${color.toARGB32()}', 44, (canvas, size) {
      final roof = Path()
        ..moveTo(size * 0.5, size * 0.26)
        ..lineTo(size * 0.76, size * 0.48)
        ..lineTo(size * 0.24, size * 0.48)
        ..close();
      final body = Rect.fromLTWH(
        size * 0.32,
        size * 0.48,
        size * 0.36,
        size * 0.26,
      );
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size * 0.42,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size * 0.42,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.06
          ..color = color,
      );
      canvas.drawPath(roof, Paint()..color = color);
      canvas.drawRect(body, Paint()..color = color);
    });
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset centre,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  Future<gmaps.BitmapDescriptor> _cached(
    String key,
    double logicalSize,
    void Function(Canvas canvas, double size) paint,
  ) async {
    final existing = _cache[key];
    if (existing != null) return existing;

    // Render at device resolution so the icon is crisp on a high-density
    // screen, then tell Maps the ratio so it scales back correctly.
    final ratio = math.max(devicePixelRatio, 1.0);
    final pixelSize = logicalSize * ratio;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(ratio);
    paint(canvas, logicalSize);

    final image = await recorder
        .endRecording()
        .toImage(pixelSize.round(), pixelSize.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final descriptor = gmaps.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
    _cache[key] = descriptor;
    return descriptor;
  }

  void clear() => _cache.clear();
}

/// A dark map style, so the map does not glow white inside a dark app.
///
/// Google Maps takes styling as a JSON string; this is the minimum set of
/// overrides that makes roads readable without turning the map into a
/// different product.
const String darkMapStyle = '''
[
 {"elementType":"geometry","stylers":[{"color":"#16262a"}]},
 {"elementType":"labels.text.fill","stylers":[{"color":"#9db2b6"}]},
 {"elementType":"labels.text.stroke","stylers":[{"color":"#0d1a1d"}]},
 {"featureType":"poi","stylers":[{"visibility":"simplified"}]},
 {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1f353a"}]},
 {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8ba3a8"}]},
 {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#254147"}]},
 {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2b4a50"}]},
 {"featureType":"transit","stylers":[{"visibility":"off"}]},
 {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0b1417"}]}
]
''';

/// A light style that quiets the map so the route reads as the subject.
const String lightMapStyle = '''
[
 {"featureType":"poi","stylers":[{"visibility":"simplified"}]},
 {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
 {"featureType":"transit","stylers":[{"visibility":"off"}]},
 {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}
]
''';
