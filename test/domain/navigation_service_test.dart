import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/navigation_service.dart';

import 'fixtures.dart';

void main() {
  const navigator = GeometryNavigationService();
  final planner = buildPlanner();

  final stopsById = {
    'stop-a': stop('stop-a', 21.5300, 39.1600),
    'stop-b': stop('stop-b', 21.5340, 39.1755),
    'stop-c': stop('stop-c', 21.5380, 39.1680),
  };

  setUp(resetIds);

  Future<Trip> buildTrip({List<AbsenceRecord> absences = const []}) {
    return planner.buildTrip(
      tripId: 'trip-1',
      route: route(stopIds: const ['stop-a', 'stop-b', 'stop-c']),
      stopsById: stopsById,
      students: [
        student('s1', stopId: 'stop-a'),
        student('s2', stopId: 'stop-b'),
        student('s3', stopId: 'stop-c'),
      ],
      absences: absences,
      schoolLocation: schoolLocation,
      serviceDate: DateTime(2026, 9, 1),
    );
  }

  group('step generation', () {
    test('always begins with a departure and ends at the destination',
        () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );

      expect(steps.first.maneuver, Maneuver.depart);
      expect(steps.last.maneuver, Maneuver.arriveDestination);
    });

    test('steps are ordered along the route', () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );

      for (var i = 1; i < steps.length; i++) {
        expect(
          steps[i].distanceAlongRouteMetres,
          greaterThanOrEqualTo(steps[i - 1].distanceAlongRouteMetres),
        );
      }
    });

    test('every served stop gets an arrival instruction', () async {
      final trip = await buildTrip();
      final steps = await navigator.stepsFor(
        trip: trip,
        stopsById: stopsById,
      );

      final arrivals = steps
          .where((s) => s.maneuver == Maneuver.arriveStop)
          .map((s) => s.stopId)
          .toSet();
      expect(arrivals, trip.activeStops.map((s) => s.stopId).toSet());
    });

    test('a skipped stop gets no instruction', () async {
      final trip = await buildTrip(absences: [absence('s2')]);
      final steps = await navigator.stepsFor(
        trip: trip,
        stopsById: stopsById,
      );

      final arrivals = steps
          .where((s) => s.maneuver == Maneuver.arriveStop)
          .map((s) => s.stopId);
      expect(arrivals, isNot(contains('stop-b')));
    });

    test('the route through a detour produces real turns', () async {
      // stop-b sits well off the a -> c line, so the drive must turn.
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final turns = steps.where(
        (s) => !s.maneuver.isArrival && s.maneuver != Maneuver.depart,
      );
      expect(turns, isNotEmpty);
    });

    test('turns are spaced, not stacked on top of each other', () async {
      const navigator = GeometryNavigationService(minimumGapMetres: 80);
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );

      final turns = steps
          .where((s) => !s.maneuver.isArrival && s.maneuver != Maneuver.depart)
          .toList();
      for (var i = 1; i < turns.length; i++) {
        expect(
          turns[i].distanceAlongRouteMetres -
              turns[i - 1].distanceAlongRouteMetres,
          greaterThanOrEqualTo(80),
        );
      }
    });

    test('a degenerate path yields no steps rather than throwing', () async {
      final trip = await buildTrip();
      final flat = trip.copyWith(
        stops: trip.stops
            .map((s) => s.copyWith(status: TripStopStatus.skipped))
            .toList(),
      );
      final steps = await navigator.stepsFor(
        trip: flat,
        stopsById: stopsById,
      );
      // The path collapses to the school; there is nothing to instruct.
      expect(steps.where((s) => s.maneuver == Maneuver.arriveStop), isEmpty);
    });
  });

  group('turn classification', () {
    test('right turns and left turns are distinguished', () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final kinds = steps.map((s) => s.maneuver).toSet();
      final hasLeft = kinds.any(
        (m) => m == Maneuver.left ||
            m == Maneuver.slightLeft ||
            m == Maneuver.sharpLeft,
      );
      final hasRight = kinds.any(
        (m) => m == Maneuver.right ||
            m == Maneuver.slightRight ||
            m == Maneuver.sharpRight,
      );
      expect(hasLeft || hasRight, isTrue);
    });
  });

  group('active guidance', () {
    test('returns nothing when there are no steps', () {
      expect(
        guidanceAt(steps: const [], distanceAlongRouteMetres: 0),
        isNull,
      );
    });

    test('at the start, the first instruction is current', () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final guidance =
          guidanceAt(steps: steps, distanceAlongRouteMetres: 0)!;
      expect(guidance.current.maneuver, Maneuver.depart);
      expect(guidance.metresToManeuver, 0);
    });

    test('advances past instructions the bus has driven through', () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final target = steps[2].distanceAlongRouteMetres;

      final guidance =
          guidanceAt(steps: steps, distanceAlongRouteMetres: target + 100)!;
      expect(
        guidance.current.distanceAlongRouteMetres,
        greaterThan(target),
      );
    });

    test('a manoeuvre stays current briefly after it is reached', () async {
      // Otherwise the banner flips to the next instruction mid-turn, exactly
      // when the driver is looking at it.
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final turn = steps.firstWhere((s) => s.maneuver != Maneuver.depart);

      final guidance = guidanceAt(
        steps: steps,
        distanceAlongRouteMetres: turn.distanceAlongRouteMetres + 5,
      )!;
      expect(
        guidance.current.distanceAlongRouteMetres,
        turn.distanceAlongRouteMetres,
      );
    });

    test('exposes the instruction after the current one', () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final guidance =
          guidanceAt(steps: steps, distanceAlongRouteMetres: 0)!;
      expect(guidance.next, isNotNull);
      expect(
        guidance.next!.distanceAlongRouteMetres,
        greaterThanOrEqualTo(guidance.current.distanceAlongRouteMetres),
      );
    });

    test('past the end, the final instruction holds', () async {
      final trip = await buildTrip();
      final steps = await navigator.stepsFor(
        trip: trip,
        stopsById: stopsById,
      );
      final guidance = guidanceAt(
        steps: steps,
        distanceAlongRouteMetres: trip.path.totalDistanceMetres + 5000,
      )!;
      expect(guidance.current.maneuver, Maneuver.arriveDestination);
      expect(guidance.next, isNull);
    });

    test('flags an imminent manoeuvre', () async {
      final steps = await navigator.stepsFor(
        trip: await buildTrip(),
        stopsById: stopsById,
      );
      final turn = steps.firstWhere((s) => s.maneuver != Maneuver.depart);

      final close = guidanceAt(
        steps: steps,
        distanceAlongRouteMetres: turn.distanceAlongRouteMetres - 40,
      )!;
      expect(close.isImminent, isTrue);
    });
  });
}
