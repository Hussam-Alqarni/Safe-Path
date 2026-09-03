import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/analytics.dart';

import 'fixtures.dart';

void main() {
  final morning = DateTime(2026, 9, 1, 6, 30);
  final planner = buildPlanner();

  final stopsById = {
    'stop-a': stop('stop-a', 21.5300, 39.1600),
    'stop-b': stop('stop-b', 21.5340, 39.1755),
  };

  setUp(resetIds);

  Future<Trip> buildTrip({String id = 'trip-1'}) => planner.buildTrip(
        tripId: id,
        route: route(stopIds: const ['stop-a', 'stop-b']),
        stopsById: stopsById,
        students: [
          student('s1', stopId: 'stop-a'),
          student('s2', stopId: 'stop-b'),
        ],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );

  group('daily attendance', () {
    test('counts only bus riders as expected', () {
      final result = Analytics.today(
        trips: const [],
        events: const [],
        students: [
          student('s1', stopId: 'stop-a'),
          student('walker', usesBus: false),
        ],
        date: morning,
      );
      expect(result.expected, 1);
    });

    test('counts a student once however many times they scan', () {
      final result = Analytics.today(
        trips: const [],
        events: [
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
          ),
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning.add(const Duration(hours: 7)),
          ),
        ],
        students: [student('s1', stopId: 'stop-a')],
        date: morning,
      );
      expect(result.present, 1);
      expect(result.rate, 1.0);
    });

    test('an empty roster yields a zero rate rather than dividing by zero', () {
      final result = Analytics.today(
        trips: const [],
        events: const [],
        students: const [],
        date: morning,
      );
      expect(result.rate, 0);
      expect(result.missing, 0);
    });

    test('reports how many are unaccounted for', () {
      final result = Analytics.today(
        trips: const [],
        events: [
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
          ),
        ],
        students: [
          student('s1', stopId: 'stop-a'),
          student('s2', stopId: 'stop-b'),
        ],
        date: morning,
      );
      expect(result.missing, 1);
    });
  });

  group('driver reliability', () {
    test('attributes records to the driver of their trip', () async {
      final trip = await buildTrip();
      final rows = Analytics.driverReliability(
        events: [
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: trip.id,
          ),
          event(
            studentId: 's2',
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: trip.id,
            method: VerificationMethod.manualDriver,
          ),
        ],
        trips: [trip],
      );

      expect(rows, hasLength(1));
      expect(rows.single.driverId, trip.driverId);
      expect(rows.single.totalRecords, 2);
      expect(rows.single.manualRate, 0.5);
    });

    test('ignores events with no trip, such as gate scans', () async {
      final trip = await buildTrip();
      final rows = Analytics.driverReliability(
        events: [
          event(
            studentId: 's1',
            type: AttendanceEventType.enteredSchool,
            at: morning,
          ),
        ],
        trips: [trip],
      );
      expect(rows, isEmpty);
    });

    test('ranks the worst rate first, since that is the one to act on',
        () async {
      final tripA = await buildTrip();
      final tripB = Trip(
        id: 'trip-2',
        schoolId: testSchoolId,
        routeId: 'route-2',
        busId: 'bus-2',
        driverId: 'driver-2',
        direction: TripDirection.toSchool,
        serviceDate: DateTime(2026, 9, 1),
        status: TripStatus.completed,
        stops: const [],
        path: tripA.path,
      );

      final rows = Analytics.driverReliability(
        events: [
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: tripA.id,
          ),
          event(
            studentId: 's2',
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: 'trip-2',
            method: VerificationMethod.manualDriver,
          ),
        ],
        trips: [tripA, tripB],
      );

      expect(rows.first.driverId, 'driver-2');
      expect(rows.first.manualRate, 1.0);
    });
  });

  group('punctuality', () {
    test('a trip whose stops were never reached is not reported', () async {
      final trip = await buildTrip();
      expect(Analytics.punctuality([trip]), isEmpty);
    });

    test('averages the delay across served stops', () async {
      final trip = await buildTrip();
      final withArrivals = trip.copyWith(
        stops: trip.stops
            .map(
              (s) => s.copyWith(
                actualArrival:
                    s.plannedArrival!.add(const Duration(minutes: 4)),
              ),
            )
            .toList(),
      );

      final rows = Analytics.punctuality([withArrivals]);
      expect(rows.single.averageDelayMinutes, 4);
      expect(rows.single.stopsServed, withArrivals.activeStops.length);
    });

    test('reports early arrivals as negative, not as zero', () async {
      // A bus that beats its timetable leaves a child on a pavement; hiding
      // that behind "on time" is the wrong kind of tidy.
      final trip = await buildTrip();
      final early = trip.copyWith(
        stops: trip.stops
            .map(
              (s) => s.copyWith(
                actualArrival:
                    s.plannedArrival!.subtract(const Duration(minutes: 3)),
              ),
            )
            .toList(),
      );

      expect(Analytics.punctuality([early]).single.averageDelayMinutes, -3);
    });

    test('every stop is given a planned arrival to be judged against',
        () async {
      final trip = await buildTrip();
      for (final stop in trip.activeStops) {
        expect(stop.plannedArrival, isNotNull);
      }
    });

    test('planned arrivals increase along the route', () async {
      final trip = await buildTrip();
      final served = trip.activeStops;
      for (var i = 1; i < served.length; i++) {
        expect(
          served[i].plannedArrival!.isAfter(served[i - 1].plannedArrival!),
          isTrue,
        );
      }
    });
  });

  group('data gaps', () {
    test('lists bus riders with no home recorded', () {
      final gaps = Analytics.missingHomeLocation([
        student('s1', stopId: 'stop-a'),
        student('walker', usesBus: false),
      ]);
      expect(gaps.map((s) => s.id), ['s1']);
    });

    test('a student with a home is not a gap', () {
      final withHome = student('s1', stopId: 'stop-a')
          .copyWith(homeLocation: schoolLocation);
      expect(Analytics.missingHomeLocation([withHome]), isEmpty);
    });
  });

  group('manual rate', () {
    test('is zero for an empty log', () {
      expect(Analytics.manualRate(const []), 0);
    });

    test('counts only hand-entered records', () {
      expect(
        Analytics.manualRate([
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
          ),
          event(
            studentId: 's2',
            type: AttendanceEventType.boardedBus,
            at: morning,
            method: VerificationMethod.manualStaff,
          ),
        ]),
        0.5,
      );
    });
  });
}
