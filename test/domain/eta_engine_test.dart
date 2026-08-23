import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/eta_engine.dart';

import 'fixtures.dart';

void main() {
  const engine = EtaEngine();
  final now = DateTime(2026, 9, 1, 6, 30);
  final planner = buildPlanner();

  final stopsById = {
    'stop-a': stop('stop-a', 21.5300, 39.1600),
    'stop-b': stop('stop-b', 21.5340, 39.1660),
    'stop-c': stop('stop-c', 21.5380, 39.1700),
  };

  setUp(resetIds);

  Future<Trip> buildTrip() => planner.buildTrip(
        tripId: 'trip-1',
        route: route(stopIds: const ['stop-a', 'stop-b', 'stop-c']),
        stopsById: stopsById,
        students: [
          student('s1', stopId: 'stop-a'),
          student('s2', stopId: 'stop-b'),
          student('s3', stopId: 'stop-c'),
        ],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );

  group('eta computation', () {
    test('produces an eta for every stop still ahead', () async {
      final trip = await buildTrip();
      final etas = engine.etasFor(trip: trip, currentSpeedKmh: 30, now: now);
      expect(etas, hasLength(3));
      // A morning run begins at its first stop, so that stop's eta is "now",
      // not a future time. Nothing may ever be scheduled in the past.
      expect(etas.every((e) => !e.eta.isBefore(now)), isTrue);
      expect(etas.first.remainingMetres, closeTo(0, 1));
    });

    test('etas grow with distance along the route', () async {
      final trip = await buildTrip();
      final etas = engine.etasFor(trip: trip, currentSpeedKmh: 30, now: now);
      for (var i = 1; i < etas.length; i++) {
        expect(etas[i].minutesAway, greaterThanOrEqualTo(etas[i - 1].minutesAway));
      }
    });

    test('skipped stops get no eta', () async {
      final trip = await planner.buildTrip(
        tripId: 'trip-1',
        route: route(stopIds: const ['stop-a', 'stop-b', 'stop-c']),
        stopsById: stopsById,
        students: [
          student('s1', stopId: 'stop-a'),
          student('s3', stopId: 'stop-c'),
        ],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );
      final etas = engine.etasFor(trip: trip, currentSpeedKmh: 30, now: now);
      expect(etas.map((e) => e.stopId), isNot(contains('stop-b')));
    });

    test('a stalled bus does not produce an infinite eta', () async {
      final trip = await buildTrip();
      final etas = engine.etasFor(trip: trip, currentSpeedKmh: 0, now: now);
      expect(etas, isNotEmpty);
      for (final eta in etas) {
        expect(eta.minutesAway, lessThan(600));
        expect(eta.eta.isBefore(now), isFalse);
      }
    });

    test('a negative or NaN speed falls back rather than corrupting the eta',
        () async {
      final trip = await buildTrip();
      final negative = engine.etasFor(trip: trip, currentSpeedKmh: -5, now: now);
      final nan =
          engine.etasFor(trip: trip, currentSpeedKmh: double.nan, now: now);
      // Measured at a stop genuinely ahead of the bus, not the one it is on.
      expect(negative.last.minutesAway, greaterThan(0));
      expect(nan.last.minutesAway, greaterThan(0));
      expect(negative.last.minutesAway, nan.last.minutesAway);
    });

    test('a faster bus arrives sooner', () async {
      final trip = await buildTrip();
      final slow = engine.etasFor(trip: trip, currentSpeedKmh: 15, now: now);
      final fast = engine.etasFor(trip: trip, currentSpeedKmh: 60, now: now);
      expect(fast.last.minutesAway, lessThan(slow.last.minutesAway));
    });

    test('progress along the route shrinks the remaining distance', () async {
      final trip = await buildTrip();
      final atStart = engine.etasFor(trip: trip, currentSpeedKmh: 30, now: now);

      final advanced = trip.copyWith(distanceCoveredMetres: 500);
      final later =
          engine.etasFor(trip: advanced, currentSpeedKmh: 30, now: now);

      expect(later.last.remainingMetres, lessThan(atStart.last.remainingMetres));
    });
  });

  group('notification triggers', () {
    test('fires an approach warning inside the threshold', () async {
      final trip = await buildTrip();
      final firstStop = trip.stops.first;
      // Park the bus just under five minutes of driving from the first stop.
      final advanced = trip.copyWith(
        distanceCoveredMetres: firstStop.distanceAlongRouteMetres - 900,
      );

      final etas = engine.etasFor(trip: advanced, currentSpeedKmh: 30, now: now);
      final triggers =
          engine.evaluateTriggers(trip: advanced, etas: etas, now: now);

      expect(triggers.approaching, contains('stop-a'));
    });

    test('does not fire an approach warning twice for the same stop', () async {
      final trip = await buildTrip();
      final firstStop = trip.stops.first;
      final advanced = trip.copyWith(
        distanceCoveredMetres: firstStop.distanceAlongRouteMetres - 900,
        stops: trip.stops
            .map(
              (s) => s.stopId == 'stop-a'
                  ? s.copyWith(approachNotified: true)
                  : s,
            )
            .toList(),
      );

      final etas = engine.etasFor(trip: advanced, currentSpeedKmh: 30, now: now);
      final triggers =
          engine.evaluateTriggers(trip: advanced, etas: etas, now: now);

      expect(triggers.approaching, isNot(contains('stop-a')));
    });

    test('fires an arrival trigger once the bus is at the stop', () async {
      final trip = await buildTrip();
      final firstStop = trip.stops.first;
      final atStop = trip.copyWith(
        distanceCoveredMetres: firstStop.distanceAlongRouteMetres - 10,
      );

      final etas = engine.etasFor(trip: atStop, currentSpeedKmh: 5, now: now);
      final triggers =
          engine.evaluateTriggers(trip: atStop, etas: etas, now: now);

      expect(triggers.arrived, contains('stop-a'));
      expect(triggers.approaching, isNot(contains('stop-a')));
    });

    test('never fires for a skipped stop', () async {
      final trip = await planner.buildTrip(
        tripId: 'trip-1',
        route: route(stopIds: const ['stop-a', 'stop-b', 'stop-c']),
        stopsById: stopsById,
        students: [
          student('s1', stopId: 'stop-a'),
          student('s3', stopId: 'stop-c'),
        ],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );

      final etas = engine.etasFor(trip: trip, currentSpeedKmh: 30, now: now);
      final triggers = engine.evaluateTriggers(trip: trip, etas: etas, now: now);

      expect(triggers.approaching, isNot(contains('stop-b')));
      expect(triggers.arrived, isNot(contains('stop-b')));
    });

    test('a distant stop does not warn early', () async {
      final farStops = {
        'stop-a': stop('stop-a', 21.4000, 39.1000),
        'stop-far': stop('stop-far', 21.6000, 39.3000),
      };
      final trip = await planner.buildTrip(
        tripId: 'trip-long',
        route: route(stopIds: const ['stop-a', 'stop-far']),
        stopsById: farStops,
        students: [
          student('s1', stopId: 'stop-a'),
          student('s2', stopId: 'stop-far'),
        ],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );

      final etas = engine.etasFor(trip: trip, currentSpeedKmh: 30, now: now);
      final farEta = etas.firstWhere((e) => e.stopId == 'stop-far');
      expect(farEta.minutesAway, greaterThan(5));

      final triggers = engine.evaluateTriggers(trip: trip, etas: etas, now: now);
      expect(triggers.approaching, isNot(contains('stop-far')));
      expect(triggers.arrived, isNot(contains('stop-far')));
    });
  });

  group('stale position guarding', () {
    test('a missing timestamp is always stale', () {
      expect(
        engine.isPositionStale(
          lastPingAt: null,
          now: now,
          staleAfter: const Duration(seconds: 30),
        ),
        isTrue,
      );
    });

    test('a fresh ping is not stale', () {
      expect(
        engine.isPositionStale(
          lastPingAt: now.subtract(const Duration(seconds: 5)),
          now: now,
          staleAfter: const Duration(seconds: 30),
        ),
        isFalse,
      );
    });

    test('silence beyond the window is stale', () {
      expect(
        engine.isPositionStale(
          lastPingAt: now.subtract(const Duration(seconds: 45)),
          now: now,
          staleAfter: const Duration(seconds: 30),
        ),
        isTrue,
      );
    });
  });
}
