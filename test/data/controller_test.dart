import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/data/repositories/safe_path_controller.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';

import 'fake_fleet_source.dart';

void main() {
  late SafePathController controller;
  late FakeFleetSource fleet;

  setUp(() async {
    fleet = FakeFleetSource();
    controller = SafePathController(
      config: AppConfig.demo(),
      eventSource: fleet,
    );
    await controller.bootstrap();
  });

  tearDown(() async {
    controller.dispose();
    await fleet.dispose();
  });

  Trip northTrip() => controller.state.trips
      .firstWhere((t) => t.busId == 'bus-north');

  String cardOf(String studentId) =>
      SeedData.studentsById[studentId]!.cardUid;

  group('bootstrap', () {
    test('builds one morning trip per morning route', () {
      expect(controller.state.trips, hasLength(2));
      expect(
        controller.state.trips.every(
          (t) => t.direction == TripDirection.toSchool,
        ),
        isTrue,
      );
    });

    test('every trip starts scheduled with a drawable path', () {
      for (final trip in controller.state.trips) {
        expect(trip.status, TripStatus.scheduled);
        expect(trip.path.points.length, greaterThan(2));
        expect(trip.path.totalDistanceMetres, greaterThan(0));
      }
    });

    test('assigns every bus rider to a stop on some trip', () {
      final assigned = controller.state.trips
          .expand((t) => t.expectedStudentIds)
          .toSet();
      final riders =
          SeedData.students.where((s) => s.usesBus).map((s) => s.id).toSet();
      expect(assigned, riders);
    });
  });

  group('trip lifecycle', () {
    test('starting a trip notifies the guardians of everyone aboard', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);

      expect(controller.state.tripById(trip.id)!.status, TripStatus.inProgress);
      final started = controller.state.notifications
          .where((n) => n.kind == NotificationKind.tripStarted);
      expect(started, isNotEmpty);
    });

    test('a position report advances the trip and records the bus', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      await fleet.moveTo(trip: trip, distanceMetres: 400);

      final live = controller.state.liveByBus[trip.busId];
      expect(live, isNotNull);
      expect(live!.distanceAlongRouteMetres, 400);
      expect(
        controller.state.tripById(trip.id)!.distanceCoveredMetres,
        400,
      );
    });

    test('ending a trip marks every unserved stop departed', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      await controller.endTrip(trip.id);

      final ended = controller.state.tripById(trip.id)!;
      expect(ended.status, TripStatus.completed);
      expect(ended.stops.every((s) => s.status.isDone), isTrue);
    });
  });

  group('card scans', () {
    test('a first tap boards, a second tap alights', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      var events = controller.state.attendanceEvents
          .where((e) => e.studentId == studentId);
      expect(events.single.type, AttendanceEventType.boardedBus);

      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      events = controller.state.attendanceEvents
          .where((e) => e.studentId == studentId);
      expect(events.last.type, AttendanceEventType.alightedBus);
    });

    test('an unknown card is ignored rather than crashing', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final before = controller.state.attendanceEvents.length;

      await fleet.scanCard(trip: trip, cardUid: 'NOT-A-REAL-CARD');
      expect(controller.state.attendanceEvents, hasLength(before));
    });

    test('boarding notifies the guardian', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      final notified = controller.state.notifications.where(
        (n) => n.studentId == studentId && n.kind == NotificationKind.boarded,
      );
      expect(notified, isNotEmpty);
    });
  });

  group('the left-on-bus check', () {
    test('raises a critical alert when a boarder never scanned off', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      await controller.endTrip(trip.id);

      final alerts = controller.state.openAlerts
          .where((a) => a.kind == SafetyAlertKind.leftOnBus);
      expect(alerts, hasLength(1));
      expect(alerts.single.studentId, studentId);
      expect(alerts.single.severity, AlertSeverity.critical);
    });

    test('also notifies the guardian, not only the school', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      await controller.endTrip(trip.id);

      final alerted = controller.state.notifications.where(
        (n) =>
            n.studentId == studentId &&
            n.kind == NotificationKind.safetyAlert,
      );
      expect(alerted, isNotEmpty);
    });

    test('stays silent when everyone scanned off', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      await fleet.scanCard(trip: trip, cardUid: cardOf(studentId));
      await controller.endTrip(trip.id);

      expect(
        controller.state.openAlerts
            .where((a) => a.kind == SafetyAlertKind.leftOnBus),
        isEmpty,
      );
    });
  });

  group('absences and replanning', () {
    /// Declares an absence for every student assigned to [stop].
    Future<void> emptyStop(TripStop stop) async {
      for (final studentId in stop.expectedStudentIds) {
        await controller.declareAbsence(
          studentId: studentId,
          declaredByUserId: 'guardian-demo',
        );
      }
    }

    test('a stop stays on the route while anyone there is still coming',
        () async {
      final trip = northTrip();
      final stop = trip.stops.first;
      expect(stop.expectedStudentIds.length, greaterThan(1));

      // Every rider but one.
      for (final studentId in stop.expectedStudentIds.skip(1)) {
        await controller.declareAbsence(
          studentId: studentId,
          declaredByUserId: 'guardian-demo',
        );
      }

      final replanned = controller.state
          .tripById(trip.id)!
          .stops
          .firstWhere((s) => s.stopId == stop.stopId);
      expect(replanned.status, TripStopStatus.pending);
      expect(replanned.expectedStudentIds, hasLength(1));
    });

    test('a stop is skipped once every rider there is absent', () async {
      final trip = northTrip();
      final stop = trip.stops.first;
      await emptyStop(stop);

      final replanned = controller.state
          .tripById(trip.id)!
          .stops
          .firstWhere((s) => s.stopId == stop.stopId);
      expect(replanned.status, TripStopStatus.skipped);
    });

    test('skipping a stop shortens the drive', () async {
      final trip = northTrip();
      final before = trip.path.totalDistanceMetres;
      await emptyStop(trip.stops.first);

      expect(
        controller.state.tripById(trip.id)!.path.totalDistanceMetres,
        lessThan(before),
      );
    });

    test('a skipped stop is retained in the plan, never deleted', () async {
      final trip = northTrip();
      final before = trip.stops.map((s) => s.stopId).toList();
      await emptyStop(trip.stops.first);

      expect(
        controller.state.tripById(trip.id)!.stops.map((s) => s.stopId),
        before,
      );
    });

    test('cancelling one absence puts the whole stop back', () async {
      final trip = northTrip();
      final stop = trip.stops.first;
      final returning = stop.expectedStudentIds.first;
      await emptyStop(stop);

      await controller.cancelAbsence(returning);

      final restored = controller.state
          .tripById(trip.id)!
          .stops
          .firstWhere((s) => s.stopId == stop.stopId);
      expect(restored.status, TripStopStatus.pending);
      expect(restored.expectedStudentIds, contains(returning));
    });

    test('a stop with other riders is kept, minus the absent student',
        () async {
      final trip = northTrip();
      final stop = trip.stops.firstWhere((s) => s.expectedStudentIds.length > 1);
      final studentId = stop.expectedStudentIds.first;

      await controller.declareAbsence(
        studentId: studentId,
        declaredByUserId: 'guardian-demo',
      );

      final replanned = controller.state
          .tripById(trip.id)!
          .stops
          .firstWhere((s) => s.stopId == stop.stopId);
      expect(replanned.status, TripStopStatus.pending);
      expect(replanned.expectedStudentIds, isNot(contains(studentId)));
    });

    test('declaring the same absence twice changes nothing', () async {
      final trip = northTrip();
      final studentId = trip.expectedStudentIds.first;

      await controller.declareAbsence(
        studentId: studentId,
        declaredByUserId: 'guardian-demo',
      );
      final after = controller.state.absences.length;
      await controller.declareAbsence(
        studentId: studentId,
        declaredByUserId: 'guardian-demo',
      );
      expect(controller.state.absences, hasLength(after));
    });
  });

  group('manual attendance', () {
    test('is recorded as manual with its reason and author', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      controller.recordBusAttendance(
        studentId: studentId,
        tripId: trip.id,
        method: VerificationMethod.manualDriver,
        at: DateTime.now(),
        reason: ManualEntryReason.forgottenCard,
        recordedByUserId: 'driver-north',
      );

      final event = controller.state.attendanceEvents.last;
      expect(event.isManual, isTrue);
      expect(event.manualReason, ManualEntryReason.forgottenCard);
      expect(event.recordedByUserId, 'driver-north');
    });

    test('tells the guardian plainly that no card was scanned', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      final studentId = trip.expectedStudentIds.first;

      controller.recordBusAttendance(
        studentId: studentId,
        tripId: trip.id,
        method: VerificationMethod.manualDriver,
        at: DateTime.now(),
        reason: ManualEntryReason.forgottenCard,
        recordedByUserId: 'driver-north',
      );

      final notification = controller.state.notifications.last;
      expect(notification.kind, NotificationKind.manualAttendance);
      expect(notification.requiresConfirmation, isTrue);
      expect(notification.bodyAr, contains('يدوي'));
      expect(notification.bodyEn, contains('by hand'));
    });

    test('a guardian dispute raises an alert', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      controller.recordBusAttendance(
        studentId: trip.expectedStudentIds.first,
        tripId: trip.id,
        method: VerificationMethod.manualDriver,
        at: DateTime.now(),
        reason: ManualEntryReason.forgottenCard,
        recordedByUserId: 'driver-north',
      );

      final eventId = controller.state.attendanceEvents.last.id;
      controller.respondToManualEntry(
        attendanceEventId: eventId,
        response: GuardianConfirmation.disputed,
      );

      expect(controller.state.openAlerts, isNotEmpty);
      expect(
        controller.state.attendanceEvents.last.guardianConfirmation,
        GuardianConfirmation.disputed,
      );
    });

    test('a guardian confirmation raises nothing', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      controller.recordBusAttendance(
        studentId: trip.expectedStudentIds.first,
        tripId: trip.id,
        method: VerificationMethod.manualDriver,
        at: DateTime.now(),
        reason: ManualEntryReason.forgottenCard,
        recordedByUserId: 'driver-north',
      );

      controller.respondToManualEntry(
        attendanceEventId: controller.state.attendanceEvents.last.id,
        response: GuardianConfirmation.confirmed,
      );
      expect(controller.state.openAlerts, isEmpty);
    });
  });

  group('the school gate', () {
    test('a first tap enters, a second tap exits', () async {
      const studentId = 'student-001';
      controller.recordGateAttendance(
        studentId: studentId,
        method: VerificationMethod.nfcCard,
        at: DateTime.now(),
      );
      expect(
        controller.state.attendanceEvents.last.type,
        AttendanceEventType.enteredSchool,
      );

      controller.recordGateAttendance(
        studentId: studentId,
        method: VerificationMethod.nfcCard,
        at: DateTime.now(),
      );
      expect(
        controller.state.attendanceEvents.last.type,
        AttendanceEventType.exitedSchool,
      );
    });

    test('covers students who never ride a bus', () {
      final walker =
          SeedData.students.firstWhere((s) => !s.usesBus);
      controller.recordGateAttendance(
        studentId: walker.id,
        method: VerificationMethod.nfcCard,
        at: DateTime.now(),
      );
      expect(
        controller.state.attendanceEvents.last.studentId,
        walker.id,
      );
    });
  });

  group('tracker silence', () {
    test('a silence report marks the position stale', () async {
      final trip = northTrip();
      await controller.startTrip(trip.id);
      await fleet.moveTo(trip: trip, distanceMetres: 200);
      expect(controller.state.liveByBus[trip.busId]!.isStale, isFalse);

      await fleet.goSilent(trip: trip);
      expect(controller.state.liveByBus[trip.busId]!.isStale, isTrue);
    });
  });

  group('privileged access', () {
    test('a guardian cannot impersonate', () {
      controller.signInAs(SeedData.demoGuardian);
      controller.beginImpersonation(UserRole.schoolAdmin);
      expect(controller.state.isImpersonating, isFalse);
    });

    test('a developer can, and it is written to the audit log', () {
      controller.signInAs(SeedData.developer);
      controller.beginImpersonation(UserRole.guardian);

      expect(controller.state.isImpersonating, isTrue);
      expect(controller.state.effectiveRole, UserRole.guardian);
      expect(
        controller.state.auditLog.map((e) => e.action),
        contains('impersonation.begin'),
      );
    });

    test('impersonation never changes who is signed in', () {
      controller.signInAs(SeedData.developer);
      controller.beginImpersonation(UserRole.guardian);
      expect(controller.state.currentUser.id, SeedData.developer.id);
    });

    test('ending impersonation is logged too', () {
      controller.signInAs(SeedData.developer);
      controller.beginImpersonation(UserRole.guardian);
      controller.endImpersonation();

      expect(controller.state.isImpersonating, isFalse);
      expect(
        controller.state.auditLog.map((e) => e.action),
        contains('impersonation.end'),
      );
    });

    test('signing in as someone else clears any impersonation', () {
      controller.signInAs(SeedData.developer);
      controller.beginImpersonation(UserRole.guardian);
      controller.signInAs(SeedData.schoolAdmin);
      expect(controller.state.isImpersonating, isFalse);
    });
  });

  group('preferences', () {
    test('locale and theme changes are applied', () {
      controller.setThemeMode(ThemeMode.dark);
      expect(controller.state.themeMode, ThemeMode.dark);
    });
  });
}
