import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/core/platform/dialer.dart';
import 'package:safe_path/data/persistence/local_store.dart';
import 'package:safe_path/data/repositories/app_state.dart';
import 'package:safe_path/data/repositories/safe_path_controller.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/data/services/http_short_link_resolver.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/journey_engine.dart';
import 'package:safe_path/domain/services/location_link_parser.dart';
import 'package:safe_path/domain/services/navigation_service.dart';

/// Overridden in main() so the same widget tree can run against a demo
/// configuration or a live one without any screen knowing the difference.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

/// Where the app remembers today.
///
/// Defaults to keeping nothing, so a test or a throwaway build never writes to
/// a device it does not own. `main()` overrides it with the real store.
final localStoreProvider = Provider<LocalStore>((ref) => InMemoryLocalStore());

// StateNotifierProvider disposes the notifier it creates, so registering an
// extra onDispose here would call dispose twice and throw.
final controllerProvider = StateNotifierProvider<SafePathController, AppState>(
  (ref) => SafePathController(
    config: ref.watch(appConfigProvider),
    store: ref.watch(localStoreProvider),
  ),
);

/// The role whose screens are showing — impersonation aware.
final effectiveRoleProvider = Provider<UserRole>(
  (ref) => ref.watch(controllerProvider).effectiveRole,
);

/// Configured with the school's position so an implausible pin is flagged
/// rather than silently accepted.
final linkParserProvider = Provider<LocationLinkParser>((ref) {
  final school = ref.watch(controllerProvider).school;
  return LocationLinkParser(expectedCentre: school.location);
});

/// Overridden in tests, and by any deployment that routes calls through a
/// switchboard rather than the device dialler.
final dialerProvider = Provider<Dialer>((ref) => const UrlLauncherDialer());

final shortLinkResolverProvider = Provider<ShortLinkResolver>((ref) {
  final resolver = HttpShortLinkResolver();
  ref.onDispose(resolver.close);
  return resolver;
});

final studentsProvider = Provider<List<Student>>(
  (ref) => ref.watch(controllerProvider).students,
);

/// A fingerprint of a trip's *plan*, ignoring its position.
///
/// Instructions must be rebuilt when a stop is skipped and the route redrawn,
/// but not on every position report — and a report arrives every few seconds.
/// Riverpod only notifies when a value changes, so depending on this instead
/// of the trip means the expensive work runs when the plan does.
final tripPlanSignatureProvider =
    Provider.family<String, String>((ref, tripId) {
  final trip = ref.watch(controllerProvider).tripById(tripId);
  if (trip == null) return 'none';
  final served = trip.stops.where((s) => s.status != TripStopStatus.skipped);
  return '${trip.id}|${trip.path.totalDistanceMetres.round()}|'
      '${served.map((s) => s.stopId).join(',')}';
});

final navigationStepsProvider =
    FutureProvider.family<List<NavigationStep>, String>((ref, tripId) async {
  ref.watch(tripPlanSignatureProvider(tripId));
  final trip = ref.read(controllerProvider).tripById(tripId);
  if (trip == null) return const [];
  return const GeometryNavigationService().stepsFor(
    trip: trip,
    stopsById: SeedData.stopsById,
  );
});

final openAlertsProvider = Provider<List<SafetyAlert>>(
  (ref) => ref.watch(controllerProvider).openAlerts,
);

final activeTripsProvider = Provider<List<Trip>>(
  (ref) => ref.watch(controllerProvider).activeTrips,
);

/// Today's snapshot for one student, derived from the event log on demand.
final studentSnapshotProvider =
    Provider.family<StudentDaySnapshot, String>((ref, studentId) {
  final state = ref.watch(controllerProvider);
  return const JourneyEngine().snapshotFor(
    studentId: studentId,
    allEvents: state.attendanceEvents,
    allAlerts: state.alerts,
    absence: state.absenceFor(studentId),
  );
});

/// Live snapshots for every child linked to the signed-in guardian.
final myChildrenProvider = Provider<List<Student>>((ref) {
  final state = ref.watch(controllerProvider);
  final ids = state.currentUser.linkedStudentIds;
  return state.students.where((s) => ids.contains(s.id)).toList();
});

final myNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final state = ref.watch(controllerProvider);
  return state.notificationsFor(state.currentUser.id);
});

final unreadCountProvider = Provider<int>(
  (ref) => ref.watch(myNotificationsProvider).where((n) => n.isUnread).length,
);

/// School-wide counts for the admin overview.
final schoolTallyProvider = Provider<SchoolTally>((ref) {
  final state = ref.watch(controllerProvider);
  const engine = JourneyEngine();

  var onBus = 0;
  var atSchool = 0;
  var absent = 0;
  var home = 0;

  for (final student in state.students) {
    final snapshot = engine.snapshotFor(
      studentId: student.id,
      allEvents: state.attendanceEvents,
      allAlerts: state.alerts,
      absence: state.absenceFor(student.id),
    );
    switch (snapshot.stage) {
      case JourneyStage.onMorningBus:
      case JourneyStage.onAfternoonBus:
        onBus++;
      case JourneyStage.insideSchool:
      case JourneyStage.arrivedAtSchool:
        atSchool++;
      case JourneyStage.absent:
      case JourneyStage.noShow:
        absent++;
      case JourneyStage.deliveredHome:
        home++;
      case JourneyStage.notStarted:
      case JourneyStage.leftSchoolGrounds:
        break;
    }
  }

  return SchoolTally(
    total: state.students.length,
    onBus: onBus,
    atSchool: atSchool,
    absent: absent,
    home: home,
    manualRate: engine.manualEntryRate(state.attendanceEvents),
    activeTrips: state.activeTrips.length,
    openAlerts: state.openAlerts.length,
  );
});

class SchoolTally {
  const SchoolTally({
    required this.total,
    required this.onBus,
    required this.atSchool,
    required this.absent,
    required this.home,
    required this.manualRate,
    required this.activeTrips,
    required this.openAlerts,
  });

  final int total;
  final int onBus;
  final int atSchool;
  final int absent;
  final int home;
  final double manualRate;
  final int activeTrips;
  final int openAlerts;
}
