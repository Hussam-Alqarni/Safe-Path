import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/models/geo.dart';

void main() {
  const jeddahCentre = LatLngPoint(21.5433, 39.1728);

  group('LatLngPoint', () {
    test('distance between two known points is plausible', () {
      const a = LatLngPoint(21.5433, 39.1728);
      const b = LatLngPoint(21.5533, 39.1728); // ~1.11 km due north
      expect(a.distanceTo(b), closeTo(1112, 20));
    });

    test('distance to self is zero', () {
      expect(jeddahCentre.distanceTo(jeddahCentre), 0);
    });

    test('bearing due north is ~0 degrees', () {
      const north = LatLngPoint(21.5533, 39.1728);
      expect(jeddahCentre.bearingTo(north), closeTo(0, 1));
    });

    test('bearing due east is ~90 degrees', () {
      const east = LatLngPoint(21.5433, 39.1828);
      expect(jeddahCentre.bearingTo(east), closeTo(90, 1));
    });

    test('lerp clamps outside the unit interval', () {
      const other = LatLngPoint(21.5533, 39.1828);
      expect(jeddahCentre.lerp(other, -1), jeddahCentre);
      expect(jeddahCentre.lerp(other, 5), other);
    });
  });

  group('RoutePath', () {
    RoutePath buildLShape() => RoutePath(const [
          LatLngPoint(21.5400, 39.1700),
          LatLngPoint(21.5450, 39.1700),
          LatLngPoint(21.5450, 39.1760),
        ]);

    test('rejects a path with fewer than two points', () {
      expect(
        () => RoutePath(const [LatLngPoint(21.5, 39.1)]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('total distance is the sum of its legs', () {
      final path = buildLShape();
      final legOne = path.points[0].distanceTo(path.points[1]);
      final legTwo = path.points[1].distanceTo(path.points[2]);
      expect(path.totalDistanceMetres, closeTo(legOne + legTwo, 0.5));
    });

    test('pointAtDistance clamps at both ends', () {
      final path = buildLShape();
      expect(path.pointAtDistance(-50), path.points.first);
      expect(path.pointAtDistance(1e9), path.points.last);
    });

    test('pointAtDistance follows the bend rather than cutting the corner', () {
      final path = buildLShape();
      final cornerDistance = path.points[0].distanceTo(path.points[1]);
      final atCorner = path.pointAtDistance(cornerDistance);

      // Walking exactly one leg must land on the corner, not on a diagonal
      // shortcut toward the end point.
      expect(atCorner.latitude, closeTo(path.points[1].latitude, 1e-6));
      expect(atCorner.longitude, closeTo(path.points[1].longitude, 1e-6));
    });

    test('pointAtDistance advances monotonically', () {
      final path = buildLShape();
      var previous = 0.0;
      for (var d = 0.0; d <= path.totalDistanceMetres; d += 25) {
        final travelled = path.points.first.distanceTo(path.pointAtDistance(d));
        expect(travelled, greaterThanOrEqualTo(previous - 1));
        previous = travelled;
      }
    });

    test('distanceAlongForNearest snaps an off-road fix onto the path', () {
      final path = buildLShape();
      // A GPS fix drifted ~30 m east of the first leg.
      const noisyFix = LatLngPoint(21.5425, 39.1703);
      final along = path.distanceAlongForNearest(noisyFix);

      final expected = path.points[0].distanceTo(
        const LatLngPoint(21.5425, 39.1700),
      );
      expect(along, closeTo(expected, 15));
    });

    test('distanceAlongForNearest returns 0 at the path start', () {
      final path = buildLShape();
      expect(path.distanceAlongForNearest(path.points.first), closeTo(0, 1));
    });

    test('sliceFrom keeps the remaining geometry only', () {
      final path = buildLShape();
      final half = path.totalDistanceMetres / 2;
      final remainder = path.sliceFrom(half);

      expect(
        remainder.totalDistanceMetres,
        closeTo(path.totalDistanceMetres - half, 5),
      );
      expect(remainder.points.last, path.points.last);
    });

    test('sliceFrom(0) is a no-op', () {
      final path = buildLShape();
      expect(path.sliceFrom(0).totalDistanceMetres, path.totalDistanceMetres);
    });

    test('bearingAtDistance points along the current leg', () {
      final path = buildLShape();
      // First leg runs due north.
      expect(path.bearingAtDistance(10), closeTo(0, 5));
    });
  });
}
