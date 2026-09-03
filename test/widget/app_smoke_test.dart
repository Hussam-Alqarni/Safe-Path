import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/app.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/repositories/safe_path_controller.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/features/map/schematic_map.dart';

import '../data/fake_fleet_source.dart';

/// Boots the real widget tree against a fleet the test drives.
///
/// The demo profile draws its map with the built-in renderer, so these tests
/// exercise the actual screens without stubbing a platform channel or holding
/// a Google Maps key.
void main() {
  late FakeFleetSource fleet;
  late SafePathController controller;

  /// Advances a bounded number of frames.
  ///
  /// [WidgetTester.pumpAndSettle] waits for the frame queue to empty, which
  /// never happens on a screen with live tracking. Bounded pumps assert on a
  /// settled-enough tree without depending on animation ever stopping.
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fleet = FakeFleetSource();
    controller = SafePathController(
      config: AppConfig.demo(),
      eventSource: fleet,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(AppConfig.demo()),
          controllerProvider.overrideWith((ref) => controller),
        ],
        child: const SafePathApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // The ProviderScope owns the controller and disposes it on teardown; doing
  // it here as well would dispose twice.
  tearDown(() async {
    await fleet.dispose();
  });

  testWidgets('boots to the guardian view without throwing', (tester) async {
    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    // The demo banner must be impossible to miss: nothing on screen is a
    // real bus.
    expect(find.textContaining('محاكاة'), findsWidgets);
  });

  testWidgets('shows the signed-in guardian their own children only',
      (tester) async {
    await pumpApp(tester);

    final mine = SeedData.demoGuardian.linkedStudentIds;
    for (final id in mine) {
      final student = SeedData.studentsById[id]!;
      expect(
        find.text(student.fullNameAr),
        findsOneWidget,
        reason: 'guardian should see ${student.fullNameAr}',
      );
    }

    // A child belonging to someone else must not appear.
    final other = SeedData.students.firstWhere((s) => !mine.contains(s.id));
    expect(find.text(other.fullNameAr), findsNothing);
  });

  testWidgets('renders the built-in map when no Maps key is configured',
      (tester) async {
    await pumpApp(tester);
    await controller.bootstrap();
    await settle(tester);

    await tester.tap(find.byIcon(Icons.map_outlined));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(SchematicMap), findsWidgets);
  });

  testWidgets('switching language flips the interface to English',
      (tester) async {
    await pumpApp(tester);

    controller.setLocale(const Locale('en'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Simulated data'), findsWidgets);
  });

  testWidgets('each role renders its own screens without throwing',
      (tester) async {
    await pumpApp(tester);
    await controller.bootstrap();
    await settle(tester);

    for (final user in [
      SeedData.drivers.first,
      SeedData.schoolAdmin,
      SeedData.schoolStaff,
      SeedData.developer,
    ]) {
      controller.signInAs(user);
      await settle(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: 'role ${user.role.name} failed to render',
      );
    }
  });

  testWidgets('opening the notification feed clears the unread badge',
      (tester) async {
    await pumpApp(tester);
    await controller.bootstrap();
    await settle(tester);

    final trip = controller.state.trips.firstWhere(
      (t) => t.expectedStudentIds.any(
        SeedData.demoGuardian.linkedStudentIds.contains,
      ),
    );
    await controller.startTrip(trip.id);
    await settle(tester);

    expect(
      controller.state
          .notificationsFor(SeedData.demoGuardian.id)
          .where((n) => n.isUnread),
      isNotEmpty,
    );

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await settle(tester);

    expect(
      controller.state
          .notificationsFor(SeedData.demoGuardian.id)
          .where((n) => n.isUnread),
      isEmpty,
      reason: 'a badge that never clears trains people to ignore it',
    );
  });

  testWidgets('a left-on-bus alert reaches the guardian screen',
      (tester) async {
    await pumpApp(tester);
    await controller.bootstrap();
    await settle(tester);

    // Board a child of the demo guardian, then close the trip without them
    // ever scanning off.
    final trip = controller.state.trips.firstWhere(
      (t) => t.expectedStudentIds.any(
        SeedData.demoGuardian.linkedStudentIds.contains,
      ),
    );
    final studentId = trip.expectedStudentIds.firstWhere(
      SeedData.demoGuardian.linkedStudentIds.contains,
    );

    await controller.startTrip(trip.id);
    await fleet.scanCard(
      trip: trip,
      cardUid: SeedData.studentsById[studentId]!.cardUid,
    );
    await controller.endTrip(trip.id);
    await settle(tester);

    expect(
      controller.state.openAlerts
          .where((a) => a.kind == SafetyAlertKind.leftOnBus),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('لم يسجّل نزوله'), findsWidgets);
  });
}
