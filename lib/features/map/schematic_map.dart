import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';

/// A self-contained map renderer.
///
/// Google Maps is the production renderer, but it needs a platform API key and
/// a network. This one needs neither, so the app is never a grey rectangle:
/// a fresh clone runs, a demo works on a school's guest wi-fi, and widget
/// tests can assert on the map without stubbing a platform channel.
class SchematicMap extends StatelessWidget {
  const SchematicMap({
    required this.path,
    required this.stops,
    required this.stopsById,
    required this.school,
    this.busPosition,
    this.homes = const [],
    this.showSchool = true,
    super.key,
  });

  final RoutePath path;
  final List<TripStop> stops;
  final Map<String, BusStop> stopsById;
  final LatLngPoint school;
  final InterpolatedPosition? busPosition;

  /// Student homes, so the walk from a door to its stop is visible.
  final List<LatLngPoint> homes;

  final bool showSchool;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SchematicPainter(
          path: path,
          stops: stops,
          stopsById: stopsById,
          school: school,
          busPosition: busPosition,
          homes: homes,
          showSchool: showSchool,
          canvas: c.sunken,
          grid: c.line,
          routeRemaining: c.routeLine,
          routeDone: c.routeLineDone,
          stopPending: c.brand,
          stopDone: c.delivered,
          stopSkipped: c.absent,
          schoolColor: c.atSchool,
          busColor: c.onBus,
          busStale: c.absent,
          surface: c.surface,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SchematicPainter extends CustomPainter {
  _SchematicPainter({
    required this.path,
    required this.stops,
    required this.stopsById,
    required this.school,
    required this.busPosition,
    required this.homes,
    required this.showSchool,
    required this.canvas,
    required this.grid,
    required this.routeRemaining,
    required this.routeDone,
    required this.stopPending,
    required this.stopDone,
    required this.stopSkipped,
    required this.schoolColor,
    required this.busColor,
    required this.busStale,
    required this.surface,
  });

  final RoutePath path;
  final List<TripStop> stops;
  final Map<String, BusStop> stopsById;
  final LatLngPoint school;
  final InterpolatedPosition? busPosition;
  final List<LatLngPoint> homes;
  final bool showSchool;

  final Color canvas;
  final Color grid;
  final Color routeRemaining;
  final Color routeDone;
  final Color stopPending;
  final Color stopDone;
  final Color stopSkipped;
  final Color schoolColor;
  final Color busColor;
  final Color busStale;
  final Color surface;

  static const _padding = 34.0;

  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = canvas);

    final bounds = _bounds();
    Offset toScreen(LatLngPoint p) => _project(p, bounds, size);

    _paintGrid(c, size);
    _paintRoute(c, toScreen);
    _paintHomes(c, toScreen);
    _paintStops(c, toScreen);
    if (showSchool) _paintSchool(c, toScreen(school));
    final bus = busPosition;
    if (bus != null) _paintBus(c, toScreen(bus.point), bus);
  }

  /// A faint grid reads as "map" without pretending to be streets it is not.
  void _paintGrid(Canvas c, Size size) {
    final paint = Paint()
      ..color = grid.withValues(alpha: 0.32)
      ..strokeWidth = 1;
    const spacing = 44.0;
    for (var x = spacing; x < size.width; x += spacing) {
      c.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = spacing; y < size.height; y += spacing) {
      c.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintRoute(Canvas c, Offset Function(LatLngPoint) toScreen) {
    if (path.points.length < 2) return;

    final travelled = busPosition?.distanceAlongRoute ?? 0;
    final donePath = Path();
    final remainingPath = Path();

    var accumulated = 0.0;
    var startedRemaining = false;
    final origin = toScreen(path.points.first);
    donePath.moveTo(origin.dx, origin.dy);

    for (var i = 1; i < path.points.length; i++) {
      final segment = path.points[i - 1].distanceTo(path.points[i]);
      final screen = toScreen(path.points[i]);
      accumulated += segment;

      if (accumulated <= travelled) {
        donePath.lineTo(screen.dx, screen.dy);
      } else {
        if (!startedRemaining) {
          final anchor = toScreen(path.pointAtDistance(travelled));
          donePath.lineTo(anchor.dx, anchor.dy);
          remainingPath.moveTo(anchor.dx, anchor.dy);
          startedRemaining = true;
        }
        remainingPath.lineTo(screen.dx, screen.dy);
      }
    }

    // A wide translucent casing under a solid core reads as a road rather than
    // a hairline, and keeps the line legible over the grid.
    final casing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = routeRemaining.withValues(alpha: 0.16);

    c.drawPath(remainingPath, casing);
    c.drawPath(
      remainingPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = routeRemaining,
    );
    c.drawPath(
      donePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = routeDone,
    );
  }

  void _paintStops(Canvas c, Offset Function(LatLngPoint) toScreen) {
    for (final stop in stops) {
      final location = stopsById[stop.stopId]?.location;
      if (location == null) continue;

      final centre = toScreen(location);
      final (color, filled) = switch (stop.status) {
        TripStopStatus.skipped => (stopSkipped, false),
        TripStopStatus.departed => (stopDone, true),
        TripStopStatus.arrived => (stopPending, true),
        TripStopStatus.pending => (stopPending, false),
      };

      c.drawCircle(centre, 9, Paint()..color = surface);
      c.drawCircle(
        centre,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
      if (filled) {
        c.drawCircle(centre, 4.2, Paint()..color = color);
      }
      if (stop.status == TripStopStatus.skipped) {
        // A skipped stop is struck through rather than hidden: the plan must
        // still show it was scheduled and dropped.
        final paint = Paint()
          ..strokeWidth = 2
          ..color = color;
        c.drawLine(
          centre + const Offset(-5, -5),
          centre + const Offset(5, 5),
          paint,
        );
      }
    }
  }

  /// Small hollow markers, deliberately quieter than stops: a home is context
  /// for a stop, not a place the bus goes.
  void _paintHomes(Canvas c, Offset Function(LatLngPoint) toScreen) {
    if (homes.isEmpty) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = stopPending.withValues(alpha: 0.55);

    for (final home in homes) {
      final centre = toScreen(home);
      c.drawRect(
        Rect.fromCenter(center: centre, width: 7, height: 7),
        paint,
      );
    }
  }

  void _paintSchool(Canvas c, Offset centre) {
    final rect = Rect.fromCenter(center: centre, width: 26, height: 26);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    c.drawRRect(rrect, Paint()..color = surface);
    c.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = schoolColor,
    );

    // A small pennant, unmistakable at this size where a glyph would blur.
    final flag = Path()
      ..moveTo(centre.dx - 4, centre.dy + 6)
      ..lineTo(centre.dx - 4, centre.dy - 7)
      ..lineTo(centre.dx + 6, centre.dy - 4)
      ..lineTo(centre.dx - 4, centre.dy - 1)
      ..close();
    c.drawPath(flag, Paint()..color = schoolColor);
  }

  void _paintBus(Canvas c, Offset centre, InterpolatedPosition bus) {
    final color = bus.isStale ? busStale : busColor;

    if (!bus.isStale) {
      c.drawCircle(centre, 20, Paint()..color = color.withValues(alpha: 0.14));
    }
    c.drawCircle(centre, 13, Paint()..color = surface);
    c.drawCircle(
      centre,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color,
    );

    // A heading arrow: direction of travel is information a static dot loses.
    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate((bus.bearing - 90) * math.pi / 180);
    final arrow = Path()
      ..moveTo(7, 0)
      ..lineTo(-4, -5.2)
      ..lineTo(-1.6, 0)
      ..lineTo(-4, 5.2)
      ..close();
    c.drawPath(arrow, Paint()..color = color);
    c.restore();
  }

  _Bounds _bounds() {
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;

    void include(LatLngPoint p) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    for (final point in path.points) {
      include(point);
    }
    for (final home in homes) {
      include(home);
    }
    if (showSchool) include(school);

    // Degenerate bounds (a single point) would divide by zero when projecting.
    if ((maxLat - minLat).abs() < 1e-6) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 1e-6) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    return _Bounds(minLat, maxLat, minLng, maxLng);
  }

  /// Equal-aspect projection: the drawing keeps real proportions instead of
  /// stretching to fill, so a north-south route does not look like a wide one.
  Offset _project(LatLngPoint p, _Bounds b, Size size) {
    final usableWidth = size.width - _padding * 2;
    final usableHeight = size.height - _padding * 2;
    if (usableWidth <= 0 || usableHeight <= 0) return Offset.zero;

    final latSpan = b.maxLat - b.minLat;
    final lngSpan = b.maxLng - b.minLng;
    final lngScale = math.cos((b.minLat + b.maxLat) / 2 * math.pi / 180);
    final spanX = lngSpan * lngScale;

    final scale = math.min(usableWidth / spanX, usableHeight / latSpan);
    final drawnWidth = spanX * scale;
    final drawnHeight = latSpan * scale;
    final offsetX = _padding + (usableWidth - drawnWidth) / 2;
    final offsetY = _padding + (usableHeight - drawnHeight) / 2;

    final x = offsetX + (p.longitude - b.minLng) * lngScale * scale;
    final y = offsetY + (b.maxLat - p.latitude) * scale;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(_SchematicPainter old) =>
      old.busPosition?.distanceAlongRoute != busPosition?.distanceAlongRoute ||
      old.busPosition?.isStale != busPosition?.isStale ||
      old.path != path ||
      old.stops != stops ||
      old.homes != homes ||
      old.canvas != canvas;
}

class _Bounds {
  const _Bounds(this.minLat, this.maxLat, this.minLng, this.maxLng);
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;
}

/// A legend, so the symbols above never need explaining out loud.
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppStrings.of(context);
    final text = Theme.of(context).textTheme.labelSmall;

    Widget item(Color color, String label, {bool hollow = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: hollow ? null : color,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
            ),
            const SizedBox(width: Gap.xs),
            Text(label, style: text?.copyWith(color: c.inkSoft)),
          ],
        );

    return Wrap(
      spacing: Gap.lg,
      runSpacing: Gap.sm,
      children: [
        item(c.delivered, s.legendServed),
        item(c.brand, s.legendUpcoming, hollow: true),
        item(c.absent, s.legendSkipped, hollow: true),
      ],
    );
  }
}
