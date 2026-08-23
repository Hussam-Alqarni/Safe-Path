import 'dart:math' as math;

/// A WGS-84 coordinate. Immutable, comparable, cheap to copy.
class LatLngPoint {
  const LatLngPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Great-circle distance in metres (haversine).
  double distanceTo(LatLngPoint other) {
    const earthRadiusMetres = 6371000.0;
    final dLat = _toRadians(other.latitude - latitude);
    final dLng = _toRadians(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMetres * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Initial bearing in degrees (0 = north, clockwise). Used to rotate the bus
  /// marker so it faces the direction of travel.
  double bearingTo(LatLngPoint other) {
    final lat1 = _toRadians(latitude);
    final lat2 = _toRadians(other.latitude);
    final dLng = _toRadians(other.longitude - longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  /// Linear interpolation toward [other]. Over the tens-of-metres distances a
  /// bus covers between pings, treating lat/lng as planar is accurate to well
  /// under a metre — far below GPS noise.
  LatLngPoint lerp(LatLngPoint other, double t) {
    final clamped = t.clamp(0.0, 1.0);
    return LatLngPoint(
      latitude + (other.latitude - latitude) * clamped,
      longitude + (other.longitude - longitude) * clamped,
    );
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is LatLngPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() =>
      'LatLngPoint(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';
}

/// A road-following path, stored as the ordered points a routing engine
/// returned. The single source of truth for where a bus is *supposed* to drive.
class RoutePath {
  RoutePath(this.points)
      : assert(points.length >= 2, 'A path needs at least two points'),
        _cumulative = _buildCumulative(points);

  final List<LatLngPoint> points;
  final List<double> _cumulative;

  /// Total path length in metres.
  double get totalDistanceMetres => _cumulative.last;

  static List<double> _buildCumulative(List<LatLngPoint> points) {
    final cumulative = <double>[0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative[i - 1] + points[i - 1].distanceTo(points[i]));
    }
    return cumulative;
  }

  /// The coordinate [metres] along the path from its start.
  ///
  /// This is what keeps a bus marker on the road: instead of interpolating in a
  /// straight line between two pings, the marker advances *along the geometry*,
  /// so it follows every bend of the street.
  LatLngPoint pointAtDistance(double metres) {
    if (metres <= 0) return points.first;
    if (metres >= totalDistanceMetres) return points.last;

    var low = 0;
    var high = _cumulative.length - 1;
    while (low < high - 1) {
      final mid = (low + high) ~/ 2;
      if (_cumulative[mid] <= metres) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final segmentLength = _cumulative[high] - _cumulative[low];
    if (segmentLength <= 0) return points[low];
    final t = (metres - _cumulative[low]) / segmentLength;
    return points[low].lerp(points[high], t);
  }

  /// Distance along the path of the point closest to [target].
  ///
  /// This is the cheap map-matching that stops a bus from appearing to drive
  /// through buildings: because the planned route is already known, snapping a
  /// noisy GPS fix onto it is a projection, not a routing call.
  double distanceAlongForNearest(LatLngPoint target) {
    var bestDistance = double.infinity;
    var bestAlong = 0.0;

    for (var i = 0; i < points.length - 1; i++) {
      final projected = _projectOntoSegment(target, points[i], points[i + 1]);
      final gap = target.distanceTo(projected.point);
      if (gap < bestDistance) {
        bestDistance = gap;
        bestAlong = _cumulative[i] + projected.alongSegmentMetres;
      }
    }
    return bestAlong;
  }

  /// Bearing of travel at [metres] along the path.
  double bearingAtDistance(double metres) {
    final here = pointAtDistance(metres);
    final ahead = pointAtDistance(
      math.min(metres + 12, totalDistanceMetres),
    );
    if (here == ahead) {
      final behind = pointAtDistance(math.max(metres - 12, 0));
      return behind.bearingTo(here);
    }
    return here.bearingTo(ahead);
  }

  /// The sub-path from [fromMetres] to the end — used to redraw only the
  /// remaining portion of a trip after a stop is skipped.
  RoutePath sliceFrom(double fromMetres) {
    if (fromMetres <= 0) return this;
    final remaining = <LatLngPoint>[pointAtDistance(fromMetres)];
    for (var i = 0; i < points.length; i++) {
      if (_cumulative[i] > fromMetres) remaining.add(points[i]);
    }
    if (remaining.length < 2) {
      return RoutePath([remaining.first, points.last]);
    }
    return RoutePath(remaining);
  }

  static _Projection _projectOntoSegment(
    LatLngPoint target,
    LatLngPoint a,
    LatLngPoint b,
  ) {
    // Planar projection in a local tangent frame. Accurate at street scale.
    final latScale = math.cos(LatLngPoint._toRadians(a.latitude));
    final ax = a.longitude * latScale;
    final ay = a.latitude;
    final bx = b.longitude * latScale;
    final by = b.latitude;
    final px = target.longitude * latScale;
    final py = target.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return _Projection(a, 0);

    final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    final point = a.lerp(b, t);
    return _Projection(point, a.distanceTo(point));
  }
}

class _Projection {
  const _Projection(this.point, this.alongSegmentMetres);
  final LatLngPoint point;
  final double alongSegmentMetres;
}
