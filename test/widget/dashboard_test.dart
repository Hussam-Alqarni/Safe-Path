import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/app.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/repositories/safe_path_controller.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/features/admin/charts.dart';
import 'package:safe_path/features/admin/dashboard_screen.dart';

import '../data/fake_fleet_source.dart';

void main() {
  late FakeFleetSource fleet;
  late SafePathController controller;

  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
  }

  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
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
    await controller.bootstrap();
    controller.signInAs(SeedData.schoolAdmin);
    await settle(tester);
  }

  tearDown(() async {
    await fleet.dispose();
  });

  testWidgets('renders on a phone without overflowing', (tester) async {
    await pumpDashboard(tester, const Size(420, 900));

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders on a wide screen without overflowing', (tester) async {
    await pumpDashboard(tester, const Size(1400, 1000));

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the attendance trend', (tester) async {
    await pumpDashboard(tester, const Size(1400, 1000));
    expect(find.byType(TrendChart), findsOneWidget);
  });

  testWidgets('lists students with no home location as a data gap',
      (tester) async {
    await pumpDashboard(tester, const Size(1400, 1400));

    // The seed sets no home on anyone, so every rider is a gap — which is the
    // honest starting state for a school that has just signed up.
    final riders = SeedData.students.where((s) => s.usesBus).length;
    expect(riders, greaterThan(0));
    expect(find.textContaining('استكمال'), findsWidgets);
  });

  testWidgets('a recorded home closes the gap', (tester) async {
    await pumpDashboard(tester, const Size(1400, 1400));

    final rider = SeedData.students.firstWhere((s) => s.usesBus);
    controller.setStudentHome(
      studentId: rider.id,
      location: SeedData.school.location,
      linkSource: 'https://maps.google.com/?q=21.5433,39.1728',
    );
    await settle(tester);

    final student = controller.state.studentsById[rider.id]!;
    expect(student.hasHome, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('setting a home is written to the audit log', (tester) async {
    await pumpDashboard(tester, const Size(1400, 1000));

    controller.setStudentHome(
      studentId: SeedData.students.first.id,
      location: SeedData.school.location,
      linkSource: 'https://maps.app.goo.gl/abc',
    );

    final entry = controller.state.auditLog.last;
    expect(entry.action, 'student.home.set');
    expect(entry.subjectStudentId, SeedData.students.first.id);
    expect(entry.detail, contains('maps.app.goo.gl'));
  });
}
