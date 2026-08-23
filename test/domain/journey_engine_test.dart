import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/journey_engine.dart';

import 'fixtures.dart';
import 'route_path_stub.dart';

void main() {
  const engine = JourneyEngine();
  final morning = DateTime(2026, 9, 1, 6, 30);

  setUp(resetIds);

  group('journey stage derivation', () {
    test('no events and no absence means the day has not started', () {
      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: const [],
        allAlerts: const [],
      );
      expect(snapshot.stage, JourneyStage.notStarted);
    });

    test('a declared absence short-circuits the whole day', () {
      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: const [],
        allAlerts: const [],
        absence: absence('s1'),
      );
      expect(snapshot.stage, JourneyStage.absent);
    });

    test('a no-show is distinguished from a declared absence', () {
      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: const [],
        allAlerts: const [],
        absence: absence('s1', reason: AbsenceReason.noShowAtStop),
      );
      expect(snapshot.stage, JourneyStage.noShow);
    });

    test('boarding puts the student on the morning bus', () {
      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: [
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: 'trip-1',
          ),
        ],
        allAlerts: const [],
      );
      expect(snapshot.stage, JourneyStage.onMorningBus);
      expect(snapshot.isOnBoard, isTrue);
    });

    test('the full happy path ends at deliveredHome', () {
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning,
          tripId: 'trip-am',
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.alightedBus,
          at: morning.add(const Duration(minutes: 25)),
          tripId: 'trip-am',
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.enteredSchool,
          at: morning.add(const Duration(minutes: 27)),
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.exitedSchool,
          at: morning.add(const Duration(hours: 7)),
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning.add(const Duration(hours: 7, minutes: 5)),
          tripId: 'trip-pm',
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.alightedBus,
          at: morning.add(const Duration(hours: 7, minutes: 30)),
          tripId: 'trip-pm',
        ),
      ];

      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: events,
        allAlerts: const [],
      );
      expect(snapshot.stage, JourneyStage.deliveredHome);
      expect(snapshot.isSafelyResolved, isTrue);
    });

    test('boarding after a gate exit is the afternoon bus, not the morning one',
        () {
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.enteredSchool,
          at: morning,
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.exitedSchool,
          at: morning.add(const Duration(hours: 7)),
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning.add(const Duration(hours: 7, minutes: 4)),
          tripId: 'trip-pm',
        ),
      ];

      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: events,
        allAlerts: const [],
      );
      expect(snapshot.stage, JourneyStage.onAfternoonBus);
    });

    test('events arriving out of order are replayed chronologically', () {
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.alightedBus,
          at: morning.add(const Duration(minutes: 25)),
          tripId: 'trip-am',
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning,
          tripId: 'trip-am',
        ),
      ];

      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: events,
        allAlerts: const [],
      );
      expect(snapshot.stage, JourneyStage.arrivedAtSchool);
    });

    test('another student\'s events never leak into this snapshot', () {
      final events = [
        event(
          studentId: 's2',
          type: AttendanceEventType.boardedBus,
          at: morning,
          tripId: 'trip-am',
        ),
      ];

      final snapshot = engine.snapshotFor(
        studentId: 's1',
        allEvents: events,
        allAlerts: const [],
      );
      expect(snapshot.stage, JourneyStage.notStarted);
      expect(snapshot.events, isEmpty);
    });
  });

  group('left-on-bus detection', () {
    late Trip trip;
    late Map<String, Student> studentsById;

    setUp(() async {
      final stops = {
        'stop-a': stop('stop-a', 21.5300, 39.1600),
        'stop-b': stop('stop-b', 21.5350, 39.1650),
      };
      final students = [
        student('s1', stopId: 'stop-a'),
        student('s2', stopId: 'stop-b'),
      ];
      studentsById = {for (final s in students) s.id: s};

      trip = await buildPlanner().buildTrip(
        tripId: 'trip-am',
        route: route(stopIds: const ['stop-a', 'stop-b']),
        stopsById: stops,
        students: students,
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );
    });

    test('raises a critical alert when a boarder never scanned off', () {
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning,
          tripId: 'trip-am',
        ),
        event(
          studentId: 's2',
          type: AttendanceEventType.boardedBus,
          at: morning,
          tripId: 'trip-am',
        ),
        // Only s2 scanned off.
        event(
          studentId: 's2',
          type: AttendanceEventType.alightedBus,
          at: morning.add(const Duration(minutes: 25)),
          tripId: 'trip-am',
        ),
      ];

      final alerts = engine.reconcileTripCompletion(
        trip: trip,
        allEvents: events,
        studentsById: studentsById,
        now: morning.add(const Duration(minutes: 30)),
        idFactory: nextId,
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.kind, SafetyAlertKind.leftOnBus);
      expect(alerts.single.severity, AlertSeverity.critical);
      expect(alerts.single.studentId, 's1');
      expect(alerts.single.busId, trip.busId);
    });

    test('raises nothing when everyone scanned off', () {
      final events = [
        for (final id in ['s1', 's2']) ...[
          event(
            studentId: id,
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: 'trip-am',
          ),
          event(
            studentId: id,
            type: AttendanceEventType.alightedBus,
            at: morning.add(const Duration(minutes: 25)),
            tripId: 'trip-am',
          ),
        ],
      ];

      final alerts = engine.reconcileTripCompletion(
        trip: trip,
        allEvents: events,
        studentsById: studentsById,
        now: morning.add(const Duration(minutes: 30)),
        idFactory: nextId,
      );
      expect(alerts, isEmpty);
    });

    test('ignores events belonging to a different trip', () {
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning,
          tripId: 'some-other-trip',
        ),
      ];

      final alerts = engine.reconcileTripCompletion(
        trip: trip,
        allEvents: events,
        studentsById: studentsById,
        now: morning.add(const Duration(minutes: 30)),
        idFactory: nextId,
      );
      expect(alerts, isEmpty);
    });

    test('a student who never boarded raises no left-on-bus alert', () {
      final alerts = engine.reconcileTripCompletion(
        trip: trip,
        allEvents: const [],
        studentsById: studentsById,
        now: morning.add(const Duration(minutes: 30)),
        idFactory: nextId,
      );
      expect(alerts, isEmpty);
    });
  });

  group('gate-entry gap detection', () {
    late Trip trip;
    late Map<String, Student> studentsById;

    setUp(() async {
      final stops = {'stop-a': stop('stop-a', 21.5300, 39.1600)};
      final students = [student('s1', stopId: 'stop-a')];
      studentsById = {for (final s in students) s.id: s};

      trip = await buildPlanner().buildTrip(
        tripId: 'trip-am',
        route: route(stopIds: const ['stop-a']),
        stopsById: stops,
        students: students,
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );
    });

    test('flags a student who left the bus but never reached the gate', () {
      final alighted = morning.add(const Duration(minutes: 25));
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.alightedBus,
          at: alighted,
          tripId: 'trip-am',
        ),
      ];

      final alerts = engine.detectMissingGateEntries(
        trip: trip,
        allEvents: events,
        studentsById: studentsById,
        now: alighted.add(const Duration(minutes: 11)),
        idFactory: nextId,
      );

      expect(alerts, hasLength(1));
      expect(alerts.single.kind, SafetyAlertKind.missingGateEntry);
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('stays quiet inside the grace window', () {
      final alighted = morning.add(const Duration(minutes: 25));
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.alightedBus,
          at: alighted,
          tripId: 'trip-am',
        ),
      ];

      final alerts = engine.detectMissingGateEntries(
        trip: trip,
        allEvents: events,
        studentsById: studentsById,
        now: alighted.add(const Duration(minutes: 4)),
        idFactory: nextId,
      );
      expect(alerts, isEmpty);
    });

    test('stays quiet once the gate scan arrives', () {
      final alighted = morning.add(const Duration(minutes: 25));
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.alightedBus,
          at: alighted,
          tripId: 'trip-am',
        ),
        event(
          studentId: 's1',
          type: AttendanceEventType.enteredSchool,
          at: alighted.add(const Duration(minutes: 2)),
        ),
      ];

      final alerts = engine.detectMissingGateEntries(
        trip: trip,
        allEvents: events,
        studentsById: studentsById,
        now: alighted.add(const Duration(minutes: 20)),
        idFactory: nextId,
      );
      expect(alerts, isEmpty);
    });

    test('does not apply to afternoon runs', () async {
      final afternoonTrip = await buildPlanner().buildTrip(
        tripId: 'trip-pm',
        route: route(
          direction: TripDirection.fromSchool,
          stopIds: const ['stop-a'],
        ),
        stopsById: {'stop-a': stop('stop-a', 21.5300, 39.1600)},
        students: [student('s1', stopId: 'stop-a')],
        absences: const [],
        schoolLocation: schoolLocation,
        serviceDate: DateTime(2026, 9, 1),
      );

      final alerts = engine.detectMissingGateEntries(
        trip: afternoonTrip,
        allEvents: [
          event(
            studentId: 's1',
            type: AttendanceEventType.alightedBus,
            at: morning,
            tripId: 'trip-pm',
          ),
        ],
        studentsById: studentsById,
        now: morning.add(const Duration(hours: 1)),
        idFactory: nextId,
      );
      expect(alerts, isEmpty);
    });
  });

  group('no-show and manual-rate reporting', () {
    test('reports expected students who never boarded at a departed stop', () {
      const tripStop = TripStop(
        stopId: 'stop-a',
        sequence: 0,
        status: TripStopStatus.departed,
        expectedStudentIds: ['s1', 's2', 's3'],
      );
      final trip = Trip(
        id: 'trip-am',
        schoolId: testSchoolId,
        routeId: 'route-1',
        busId: 'bus-1',
        driverId: 'driver-1',
        direction: TripDirection.toSchool,
        serviceDate: DateTime(2026, 9, 1),
        status: TripStatus.inProgress,
        stops: const [tripStop],
        path: RoutePathStub.path,
      );

      final missing = engine.studentsWhoDidNotBoard(
        trip: trip,
        stop: tripStop,
        allEvents: [
          event(
            studentId: 's1',
            type: AttendanceEventType.boardedBus,
            at: morning,
            tripId: 'trip-am',
            stopId: 'stop-a',
          ),
        ],
      );

      expect(missing, ['s2', 's3']);
    });

    test('manual entry rate is zero for an empty log', () {
      expect(engine.manualEntryRate(const []), 0);
    });

    test('manual entry rate counts only hand-entered records', () {
      final events = [
        event(
          studentId: 's1',
          type: AttendanceEventType.boardedBus,
          at: morning,
        ),
        event(
          studentId: 's2',
          type: AttendanceEventType.boardedBus,
          at: morning,
          method: VerificationMethod.manualDriver,
        ),
      ];
      expect(engine.manualEntryRate(events), 0.5);
    });
  });
}
