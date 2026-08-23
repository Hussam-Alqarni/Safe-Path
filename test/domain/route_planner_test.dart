import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';

import 'fixtures.dart';

void main() {
  final planner = buildPlanner();
  final serviceDate = DateTime(2026, 9, 1);

  final stopsById = {
    'stop-a': stop('stop-a', 21.5300, 39.1600),
    // Deliberately off the a -> c line: skipping it is a real detour saved.
    'stop-b': stop('stop-b', 21.5340, 39.1755),
    'stop-c': stop('stop-c', 21.5380, 39.1680),
  };
  final allStopIds = ['stop-a', 'stop-b', 'stop-c'];

  List<Student> threeStudents() => [
        student('s1', stopId: 'stop-a'),
        student('s2', stopId: 'stop-b'),
        student('s3', stopId: 'stop-c'),
      ];

  setUp(resetIds);

  Future<Trip> build({
    List<Student>? students,
    List<AbsenceRecord> absences = const [],
    TripDirection direction = TripDirection.toSchool,
  }) {
    return planner.buildTrip(
      tripId: 'trip-1',
      route: route(direction: direction, stopIds: allStopIds),
      stopsById: stopsById,
      students: students ?? threeStudents(),
      absences: absences,
      schoolLocation: schoolLocation,
      serviceDate: serviceDate,
    );
  }

  group('trip construction', () {
    test('serves every stop when nobody is absent', () async {
      final trip = await build();
      expect(trip.stops, hasLength(3));
      expect(
        trip.stops.every((s) => s.status == TripStopStatus.pending),
        isTrue,
      );
      expect(trip.expectedStudentIds, {'s1', 's2', 's3'});
    });

    test('skips a stop whose only student is absent', () async {
      final trip = await build(absences: [absence('s2')]);

      final skipped = trip.stops.firstWhere((s) => s.stopId == 'stop-b');
      expect(skipped.status, TripStopStatus.skipped);
      expect(skipped.skipReason, 'allStudentsAbsent');
      expect(skipped.expectedStudentIds, isEmpty);
    });

    test('keeps a stop when only some of its students are absent', () async {
      final students = [
        student('s1', stopId: 'stop-a'),
        student('s2', stopId: 'stop-a'),
        student('s3', stopId: 'stop-c'),
      ];
      final trip = await build(students: students, absences: [absence('s1')]);

      final stopA = trip.stops.firstWhere((s) => s.stopId == 'stop-a');
      expect(stopA.status, TripStopStatus.pending);
      expect(stopA.expectedStudentIds, ['s2']);
    });

    test('a skipped stop is retained in the plan, never deleted', () async {
      final trip = await build(absences: [absence('s2')]);
      expect(trip.stops.map((s) => s.stopId), allStopIds);
      expect(trip.activeStops, hasLength(2));
    });

    test('an absence scoped to one direction does not affect the other',
        () async {
      final trip = await build(
        absences: [absence('s2', direction: TripDirection.fromSchool)],
        direction: TripDirection.toSchool,
      );
      final stopB = trip.stops.firstWhere((s) => s.stopId == 'stop-b');
      expect(stopB.status, TripStopStatus.pending);
    });

    test('students who do not ride the bus are never assigned to a stop',
        () async {
      final students = [
        student('s1', stopId: 'stop-a'),
        student('walker', stopId: 'stop-a', usesBus: false),
      ];
      final trip = await build(students: students);
      final stopA = trip.stops.firstWhere((s) => s.stopId == 'stop-a');
      expect(stopA.expectedStudentIds, ['s1']);
    });

    test('stop distances increase monotonically along the drawn path',
        () async {
      final trip = await build();
      final served = trip.activeStops.toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      for (var i = 1; i < served.length; i++) {
        expect(
          served[i].distanceAlongRouteMetres,
          greaterThan(served[i - 1].distanceAlongRouteMetres),
          reason:
              'stop ${served[i].stopId} must lie beyond ${served[i - 1].stopId}',
        );
      }
    });

    test('every stop is close to the path drawn through it', () async {
      final trip = await build();
      for (final tripStop in trip.activeStops) {
        final location = stopsById[tripStop.stopId]!.location;
        final onPath =
            trip.path.pointAtDistance(tripStop.distanceAlongRouteMetres);
        expect(
          location.distanceTo(onPath),
          lessThan(30),
          reason: '${tripStop.stopId} drifted off its own route',
        );
      }
    });

    test('a morning run finishes at the school', () async {
      final trip = await build();
      expect(trip.path.points.last.distanceTo(schoolLocation), lessThan(5));
    });

    test('an afternoon run starts at the school', () async {
      final trip = await build(direction: TripDirection.fromSchool);
      expect(trip.path.points.first.distanceTo(schoolLocation), lessThan(5));
    });

    test('a trip with every student absent still produces a valid plan',
        () async {
      final trip = await build(
        absences: [absence('s1'), absence('s2'), absence('s3')],
      );
      expect(trip.activeStops, isEmpty);
      expect(trip.path.points.length, greaterThanOrEqualTo(2));
      expect(trip.nextStop, isNull);
    });
  });

  group('mid-trip replanning', () {
    test('skipping a stop shortens the remaining path', () async {
      final trip = await build();
      final before = trip.path.totalDistanceMetres;

      final replanned = await planner.skipStop(
        trip: trip,
        stopId: 'stop-b',
        stopsById: stopsById,
        schoolLocation: schoolLocation,
        reason: 'guardianDeclaredAbsence',
      );

      expect(replanned.path.totalDistanceMetres, lessThan(before));
      final stopB = replanned.stops.firstWhere((s) => s.stopId == 'stop-b');
      expect(stopB.status, TripStopStatus.skipped);
      expect(stopB.skipReason, 'guardianDeclaredAbsence');
    });

    test('skipping preserves the order and identity of the other stops',
        () async {
      final trip = await build();
      final replanned = await planner.skipStop(
        trip: trip,
        stopId: 'stop-b',
        stopsById: stopsById,
        schoolLocation: schoolLocation,
        reason: 'test',
      );

      expect(replanned.stops.map((s) => s.stopId), allStopIds);
      expect(replanned.stops.map((s) => s.sequence), [0, 1, 2]);
      expect(replanned.activeStops.map((s) => s.stopId), ['stop-a', 'stop-c']);
    });

    test('a stop already departed is never retroactively skipped', () async {
      final trip = await build();
      final withDeparted = trip.copyWith(
        stops: trip.stops
            .map(
              (s) => s.stopId == 'stop-a'
                  ? s.copyWith(status: TripStopStatus.departed)
                  : s,
            )
            .toList(),
      );

      final replanned = await planner.skipStop(
        trip: withDeparted,
        stopId: 'stop-a',
        stopsById: stopsById,
        schoolLocation: schoolLocation,
        reason: 'too late',
      );

      final stopA = replanned.stops.firstWhere((s) => s.stopId == 'stop-a');
      expect(stopA.status, TripStopStatus.departed);
    });

    test('restoring a stop puts it back on the path', () async {
      final trip = await build(absences: [absence('s2')]);
      final skippedLength = trip.path.totalDistanceMetres;

      final restored = await planner.restoreStop(
        trip: trip,
        stopId: 'stop-b',
        studentIds: const ['s2'],
        stopsById: stopsById,
        schoolLocation: schoolLocation,
      );

      final stopB = restored.stops.firstWhere((s) => s.stopId == 'stop-b');
      expect(stopB.status, TripStopStatus.pending);
      expect(stopB.expectedStudentIds, ['s2']);
      expect(restored.path.totalDistanceMetres, greaterThan(skippedLength));
    });

    test('skip then restore returns to the original plan length', () async {
      final trip = await build();
      final original = trip.path.totalDistanceMetres;

      final skipped = await planner.skipStop(
        trip: trip,
        stopId: 'stop-b',
        stopsById: stopsById,
        schoolLocation: schoolLocation,
        reason: 'test',
      );
      final restored = await planner.restoreStop(
        trip: skipped,
        stopId: 'stop-b',
        studentIds: const ['s2'],
        stopsById: stopsById,
        schoolLocation: schoolLocation,
      );

      expect(restored.path.totalDistanceMetres, closeTo(original, 1));
    });

    test('replanning recomputes distances for the stops that remain', () async {
      final trip = await build();
      final before = trip.stops
          .firstWhere((s) => s.stopId == 'stop-c')
          .distanceAlongRouteMetres;

      final replanned = await planner.skipStop(
        trip: trip,
        stopId: 'stop-b',
        stopsById: stopsById,
        schoolLocation: schoolLocation,
        reason: 'test',
      );
      final after = replanned.stops
          .firstWhere((s) => s.stopId == 'stop-c')
          .distanceAlongRouteMetres;

      expect(after, isNot(closeTo(before, 0.001)));
      expect(after, lessThan(before));
    });
  });

  group('a stop that is already on the way', () {
    // A stop the bus drives past anyway saves dwell time when skipped, not
    // distance. Asserting a shorter path here would encode a false promise.
    test('skipping it never lengthens the route', () async {
      final collinearStops = {
        'stop-a': stop('stop-a', 21.5300, 39.1600),
        'stop-mid': stop('stop-mid', 21.5340, 39.1640),
        'stop-c': stop('stop-c', 21.5380, 39.1680),
      };
      final trip = await planner.buildTrip(
        tripId: 'trip-collinear',
        route: route(stopIds: const ['stop-a', 'stop-mid', 'stop-c']),
        stopsById: collinearStops,
        students: [
          student('s1', stopId: 'stop-a'),
          student('s2', stopId: 'stop-mid'),
          student('s3', stopId: 'stop-c'),
        ],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: serviceDate,
      );

      final replanned = await planner.skipStop(
        trip: trip,
        stopId: 'stop-mid',
        stopsById: collinearStops,
        schoolLocation: schoolLocation,
        reason: 'test',
      );

      expect(
        replanned.path.totalDistanceMetres,
        lessThanOrEqualTo(trip.path.totalDistanceMetres + 1),
      );
      expect(replanned.activeStops, hasLength(2));
    });
  });

  group('nextStop', () {
    test('returns the first stop still to be served', () async {
      final trip = await build(absences: [absence('s1')]);
      expect(trip.nextStop?.stopId, 'stop-b');
    });

    test('returns null once every stop is done', () async {
      final trip = await build();
      final finished = trip.copyWith(
        stops: trip.stops
            .map((s) => s.copyWith(status: TripStopStatus.departed))
            .toList(),
      );
      expect(finished.nextStop, isNull);
    });
  });
}
