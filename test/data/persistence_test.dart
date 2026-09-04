import 'dart:convert';

import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/data/persistence/local_store.dart';
import 'package:safe_path/data/persistence/persisted_snapshot.dart';
import 'package:safe_path/data/repositories/safe_path_controller.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

import 'fake_fleet_source.dart';

void main() {
  late InMemoryLocalStore store;
  final open = <SafePathController>[];
  final fleets = <FakeFleetSource>[];

  setUp(() => store = InMemoryLocalStore());

  tearDown(() async {
    for (final controller in open) {
      controller.dispose();
    }
    open.clear();
    for (final fleet in fleets) {
      await fleet.dispose();
    }
    fleets.clear();
  });

  /// Boots an app against the shared store — the second call is a restart.
  Future<SafePathController> boot() async {
    final fleet = FakeFleetSource();
    final controller = SafePathController(
      config: AppConfig.demo(),
      eventSource: fleet,
      store: store,
    );
    fleets.add(fleet);
    open.add(controller);
    await controller.bootstrap();
    return controller;
  }

  Trip morningNorth(SafePathController c) => c.state.trips.firstWhere(
        (t) => t.busId == 'bus-north' && t.direction == TripDirection.toSchool,
      );

  group('across a restart', () {
    test('today\'s attendance log comes back', () async {
      final first = await boot();
      final trip = morningNorth(first);
      await first.startTrip(trip.id);

      final studentId = trip.expectedStudentIds.first;
      first.recordBusAttendance(
        studentId: studentId,
        tripId: trip.id,
        stopId: trip.stops.first.stopId,
        method: VerificationMethod.nfcCard,
        at: DateTime.now(),
        recordedByUserId: 'driver-north',
      );
      await first.flushPersistence();

      final second = await boot();
      expect(
        second.state.attendanceEvents.map((e) => e.studentId),
        contains(studentId),
      );
    });

    test('a run in progress is still in progress', () async {
      // A driver whose tablet dies halfway through a route must not come back
      // to a trip that never started — the whole safety chain hangs off it.
      final first = await boot();
      final trip = morningNorth(first);
      await first.startTrip(trip.id);
      await first.flushPersistence();

      final second = await boot();
      expect(morningNorth(second).status, TripStatus.inProgress);
      expect(morningNorth(second).startedAt, isNotNull);
    });

    test('a skipped stop is still skipped, and still present', () async {
      final first = await boot();
      final trip = morningNorth(first);
      final studentIds = trip.stops.first.expectedStudentIds;
      for (final id in studentIds) {
        await first.declareAbsence(
          studentId: id,
          declaredByUserId: 'guardian-demo',
        );
      }
      final skippedId = trip.stops.first.stopId;
      expect(
        morningNorth(first)
            .stops
            .firstWhere((s) => s.stopId == skippedId)
            .status,
        TripStopStatus.skipped,
      );
      await first.flushPersistence();

      final second = await boot();
      final restored =
          morningNorth(second).stops.where((s) => s.stopId == skippedId);
      expect(restored, hasLength(1), reason: 'a skipped stop is never removed');
      expect(restored.single.status, TripStopStatus.skipped);
    });

    test('a home location set by a guardian survives', () async {
      final first = await boot();
      const home = LatLngPoint(21.5602, 39.1553);
      first.setStudentHome(
        studentId: 'student-001',
        location: home,
        label: 'البيت',
        linkSource: 'https://maps.app.goo.gl/example',
      );
      await first.flushPersistence();

      final second = await boot();
      final student = second.state.studentsById['student-001']!;
      expect(student.homeLocation?.latitude, closeTo(home.latitude, 1e-9));
      expect(
        student.homeLinkSource,
        'https://maps.app.goo.gl/example',
        reason: 'a wrong pin has to be traceable to what was actually shared',
      );
    });

    test('language and theme come back', () async {
      final first = await boot();
      first.setLocale(const Locale('en'));
      first.setThemeMode(ThemeMode.dark);
      await first.flushPersistence();

      final second = await boot();
      expect(second.state.locale.languageCode, 'en');
      expect(second.state.themeMode, ThemeMode.dark);
    });

    test('no bus position is restored', () async {
      // A stored position is a position from the past. Redrawing it on a cold
      // start would present an invented location as live, which is the one
      // failure this product cannot afford.
      final first = await boot();
      final trip = morningNorth(first);
      await first.startTrip(trip.id);
      await fleets.first.moveTo(trip: trip, distanceMetres: 300);
      expect(first.state.liveByBus, isNotEmpty);
      await first.flushPersistence();

      final second = await boot();
      expect(second.state.liveByBus, isEmpty);
    });

    test('an impersonation session is not restored', () async {
      final first = await boot();
      first.signInAs(SeedData.developer);
      first.beginImpersonation(UserRole.guardian);
      expect(first.state.isImpersonating, isTrue);
      await first.flushPersistence();

      final second = await boot();
      expect(second.state.currentUser.id, SeedData.developer.id);
      expect(
        second.state.isImpersonating,
        isFalse,
        reason: 'privileged access is time-boxed; a restart is not a renewal',
      );
    });
  });

  group('a new day', () {
    /// Writes a snapshot that looks like it was saved yesterday.
    Future<void> seedYesterday() async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await store.save(
        PersistedSnapshot(
          savedAt: yesterday,
          attendanceEvents: [
            AttendanceEvent(
              id: 'event-old',
              schoolId: SeedData.schoolId,
              studentId: 'student-001',
              type: AttendanceEventType.boardedBus,
              method: VerificationMethod.nfcCard,
              occurredAt: yesterday,
            ),
          ],
          studentOverrides: const [
            StudentOverride(
              studentId: 'student-001',
              homeLocation: LatLngPoint(21.56, 39.15),
            ),
          ],
          localeCode: 'en',
        ),
      );
    }

    test('yesterday\'s boardings do not become today\'s', () async {
      // The journey engine reads the log it is given. Replaying yesterday
      // would show every guardian their child safely at school before the bus
      // had left the depot.
      await seedYesterday();
      final controller = await boot();
      expect(controller.state.attendanceEvents, isEmpty);
    });

    test('but the home pin and the language do', () async {
      await seedYesterday();
      final controller = await boot();
      expect(controller.state.studentsById['student-001']?.hasHome, isTrue);
      expect(controller.state.locale.languageCode, 'en');
    });
  });

  group('the disk is not written for nothing', () {
    test('an unchanged state is not rewritten', () async {
      final controller = await boot();
      await controller.flushPersistence();

      final before = store.saveCount;
      await controller.flushPersistence();
      expect(store.saveCount, before);
    });

    test('a bus simply moving is not a fact worth writing down', () async {
      // Positions arrive several times a second and none of them are kept.
      // Without a guard the app would rewrite the whole day's log on every
      // ping, for a snapshot that comes out byte-identical.
      final controller = await boot();
      final trip = morningNorth(controller);
      await controller.startTrip(trip.id);
      await fleets.first.moveTo(trip: trip, distanceMetres: 500);
      await controller.flushPersistence();

      final before = store.saveCount;
      await fleets.first.moveTo(trip: trip, distanceMetres: 505);
      await controller.flushPersistence();

      expect(store.saveCount, before);
    });
  });

  group('the developer reset', () {
    test('wipes the device copy and stays wiped until restart', () async {
      // A wipe that the next state change silently undoes is not a wipe.
      final controller = await boot();
      final trip = morningNorth(controller);
      await controller.startTrip(trip.id);
      await controller.flushPersistence();
      expect(await store.load(), isNotNull);

      await controller.clearPersistence();
      expect(await store.load(), isNull);

      controller.setThemeMode(ThemeMode.dark);
      await controller.flushPersistence();
      expect(await store.load(), isNull);
    });

    test('leaves the running app alone', () async {
      // Emptying a driver's manifest mid-route is a far worse outcome than a
      // reset that waits for the next launch.
      final controller = await boot();
      final trip = morningNorth(controller);
      await controller.startTrip(trip.id);

      await controller.clearPersistence();

      expect(morningNorth(controller).status, TripStatus.inProgress);
      expect(controller.state.notifications, isNotEmpty);
    });
  });

  group('a file this build cannot read', () {
    test('a newer schema is discarded rather than half-understood', () {
      final json = PersistedSnapshot(savedAt: DateTime.now()).toJson()
        ..['schemaVersion'] = 999;
      expect(PersistedSnapshot.fromJson(json), isNull);
    });

    test('one unreadable record costs that record, not the log', () {
      final good = AttendanceEvent(
        id: 'event-good',
        schoolId: SeedData.schoolId,
        studentId: 'student-001',
        type: AttendanceEventType.boardedBus,
        method: VerificationMethod.nfcCard,
        occurredAt: DateTime.now(),
      );
      final json = PersistedSnapshot(
        savedAt: DateTime.now(),
        attendanceEvents: [good],
      ).toJson();

      // A value written by a newer build. Guessing at it would silently
      // reclassify a child's movement.
      (json['attendanceEvents'] as List).add({
        'id': 'event-future',
        'schoolId': SeedData.schoolId,
        'studentId': 'student-001',
        'type': 'teleportedIntoSchool',
        'method': 'nfcCard',
        'occurredAt': DateTime.now().toUtc().toIso8601String(),
      });

      final restored = PersistedSnapshot.fromJson(
        jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
      );
      expect(restored!.attendanceEvents, hasLength(1));
      expect(restored.attendanceEvents.single.id, 'event-good');
    });

    test('a round trip keeps enum values by name, not position', () {
      final json = PersistedSnapshot(
        savedAt: DateTime.now(),
        alerts: [
          SafetyAlert(
            id: 'alert-1',
            schoolId: SeedData.schoolId,
            kind: SafetyAlertKind.leftOnBus,
            raisedAt: DateTime.now(),
            titleAr: 'ع',
            titleEn: 'e',
            detailAr: 'ع',
            detailEn: 'e',
          ),
        ],
      ).toJson();

      expect((json['alerts'] as List).first, containsPair('kind', 'leftOnBus'));
      final restored = PersistedSnapshot.fromJson(json);
      expect(restored!.alerts.single.kind, SafetyAlertKind.leftOnBus);
    });
  });
}
