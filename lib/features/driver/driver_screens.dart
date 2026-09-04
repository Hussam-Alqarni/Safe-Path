import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/features/driver/emergency_button.dart';
import 'package:safe_path/features/driver/navigation_screen.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/map_view.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// Finds the trip the signed-in driver is running today.
/// The run this driver is on, or the next one they are due to start.
///
/// A bus does two runs a day. Ordering the scheduled ones by departure keeps
/// the morning route in front of the driver at 6am and the afternoon route at
/// 1pm, rather than whichever happened to be built first.
Trip? _driverTrip(WidgetRef ref) {
  final state = ref.watch(controllerProvider);
  final busId = state.currentUser.assignedBusId ?? SeedData.buses.first.id;
  final candidates = state.trips.where((t) => t.busId == busId).toList();

  for (final trip in candidates) {
    if (trip.status == TripStatus.inProgress) return trip;
  }

  final scheduled = candidates
      .where((t) => t.status == TripStatus.scheduled)
      .toList()
    ..sort((a, b) => _departure(a).compareTo(_departure(b)));
  if (scheduled.isNotEmpty) return scheduled.first;

  return candidates.firstOrNull;
}

DateTime _departure(Trip trip) {
  final route = SeedData.routes.where((r) => r.id == trip.routeId).firstOrNull;
  return route?.departureTime.onDate(trip.serviceDate) ?? trip.serviceDate;
}

/// The driver's main screen.
///
/// Designed for a tablet clamped to a dashboard: large targets, one decision
/// visible at a time, and no gesture that needs two hands.
class DriverTripScreen extends ConsumerWidget {
  const DriverTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);
    final trip = _driverTrip(ref);

    if (trip == null) {
      return EmptyState(message: s.noData, icon: Icons.directions_bus_rounded);
    }

    final live = state.liveByBus[trip.busId];

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        _TripControlBar(trip: trip),
        const SizedBox(height: Gap.lg),
        if (live == null)
          TripMapView(
            renderer: state.config.mapRenderer,
            trip: trip,
            stopsById: SeedData.stopsById,
            school: state.school.location,
            height: 220,
          )
        else
          BusPositionAnimator(
            live: live,
            path: trip.path,
            builder: (context, position) => TripMapView(
              renderer: state.config.mapRenderer,
              trip: trip,
              stopsById: SeedData.stopsById,
              school: state.school.location,
              live: position,
              height: 220,
              followBus: true,
              showTraffic: true,
            ),
          ),
        if (trip.status == TripStatus.inProgress) ...[
          const SizedBox(height: Gap.md),
          // Full-screen guidance is a deliberate mode switch, not the default:
          // the trip screen is for managing students, the driving view is for
          // driving, and mixing them serves neither.
          FilledButton.icon(
            icon: const Icon(Icons.navigation_rounded),
            label: Text(AppStrings.of(context).navigate),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DriverNavigationScreen(tripId: trip.id),
              ),
            ),
          ),
        ],
        if (trip.status == TripStatus.inProgress) ...[
          const SizedBox(height: Gap.md),
          EmergencyButton(tripId: trip.id),
        ],
        const SizedBox(height: Gap.lg),
        _CurrentStopPanel(trip: trip),
      ],
    );
  }
}

class _TripControlBar extends ConsumerWidget {
  const _TripControlBar({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final controller = ref.read(controllerProvider.notifier);
    final onBoard = _countOnBoard(ref, trip);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus_rounded, color: c.brand),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      SeedData.busesById[trip.busId]?.plateNumber ?? trip.busId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$onBoard ${s.studentsOnBoard}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: switch (trip.status) {
                  TripStatus.inProgress => s.onTheWay,
                  TripStatus.completed => s.tripCompleted,
                  _ => s.tripNotStarted,
                },
                foreground:
                    trip.status == TripStatus.inProgress ? c.onBus : c.inkSoft,
                background: trip.status == TripStatus.inProgress
                    ? c.onBusSurface
                    : c.sunken,
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          SizedBox(
            width: double.infinity,
            child: switch (trip.status) {
              TripStatus.scheduled => FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(s.driverStartTrip),
                  onPressed: () => controller.startTrip(trip.id),
                ),
              TripStatus.inProgress => FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: c.critical),
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(s.driverEndTrip),
                  onPressed: () => _confirmEnd(context, ref, trip),
                ),
              _ => OutlinedButton(
                  onPressed: null,
                  child: Text(s.tripCompleted),
                ),
            },
          ),
        ],
      ),
    );
  }

  int _countOnBoard(WidgetRef ref, Trip trip) {
    final events = ref.watch(controllerProvider).attendanceEvents;
    final onBoard = <String>{};
    for (final event in events) {
      if (event.tripId != trip.id) continue;
      if (event.type == AttendanceEventType.boardedBus) {
        onBoard.add(event.studentId);
      } else if (event.type == AttendanceEventType.alightedBus) {
        onBoard.remove(event.studentId);
      }
    }
    return onBoard.length;
  }

  /// Ending a trip is the moment the safety check runs, so the driver is told
  /// plainly what is about to happen rather than being asked "are you sure?".
  Future<void> _confirmEnd(
    BuildContext context,
    WidgetRef ref,
    Trip trip,
  ) async {
    final s = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: s.direction,
        child: AlertDialog(
          title: Text(s.driverEndTripConfirm),
          content: Text(s.driverEndTripWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.confirm),
            ),
          ],
        ),
      ),
    );
    if (confirmed ?? false) {
      await ref.read(controllerProvider.notifier).endTrip(trip.id);
    }
  }
}

/// The stop the bus is at or heading to, with its expected students.
class _CurrentStopPanel extends ConsumerWidget {
  const _CurrentStopPanel({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final stop = trip.nextStop;

    if (stop == null) {
      return SectionCard(
        title: s.nextStop,
        child: EmptyState(
          message: s.tripCompleted,
          icon: Icons.check_circle_rounded,
        ),
      );
    }

    final busStop = SeedData.stopsById[stop.stopId];
    return SectionCard(
      title: s.isArabic ? busStop?.nameAr ?? '' : busStop?.nameEn ?? '',
      subtitle: s.driverExpectedHere,
      padded: false,
      child: stop.expectedStudentIds.isEmpty
          ? EmptyState(
              message: s.driverNobodyHere,
              icon: Icons.person_off_rounded,
            )
          : Column(
              children: [
                for (final studentId in stop.expectedStudentIds)
                  _StudentActionRow(
                    studentId: studentId,
                    trip: trip,
                    stopId: stop.stopId,
                  ),
              ],
            ),
    );
  }
}

/// One student, with the two actions a driver ever needs: record them, or
/// record that they were not there.
class _StudentActionRow extends ConsumerWidget {
  const _StudentActionRow({
    required this.studentId,
    required this.trip,
    required this.stopId,
  });

  final String studentId;
  final Trip trip;
  final String stopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final student = ref.watch(controllerProvider).studentsById[studentId];
    final snapshot = ref.watch(studentSnapshotProvider(studentId));
    if (student == null) return const SizedBox.shrink();

    final recorded = snapshot.events.any((e) => e.tripId == trip.id);
    final style = stageStyle(context, snapshot.stage);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          InitialsAvatar(initials: student.photoInitials, color: style.fg),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.isArabic ? student.fullNameAr : student.fullNameEn,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${s.grade} ${student.grade}${student.section}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (recorded)
            StatusPill(
              label: s.stageLabel(snapshot.stage),
              foreground: style.fg,
              background: style.bg,
              icon: style.icon,
              dense: true,
            )
          else ...[
            IconButton(
              tooltip: s.driverManualEntry,
              icon: const Icon(Icons.edit_note_rounded),
              color: c.manual,
              onPressed: () => _manualEntry(context, ref, student),
            ),
            IconButton(
              tooltip: s.driverMarkNoShow,
              icon: const Icon(Icons.person_off_rounded),
              color: c.inkSoft,
              onPressed: () => _markNoShow(context, ref, student),
            ),
          ],
        ],
      ),
    );
  }

  /// The fallback for a forgotten card.
  ///
  /// A reason is mandatory — not bureaucracy, but the diagnostic that tells an
  /// administrator whether one child is careless or one reader is broken.
  Future<void> _manualEntry(
    BuildContext context,
    WidgetRef ref,
    Student student,
  ) async {
    final s = AppStrings.of(context);
    final reason = await showModalBottomSheet<ManualEntryReason>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: s.direction,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.driverManualEntryTitle,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  s.driverManualEntryExplain,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.lg),
                for (final reason in ManualEntryReason.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(reason),
                      child: Text(s.manualReasonLabel(reason)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reason == null) return;
    ref.read(controllerProvider.notifier).recordBusAttendance(
          studentId: student.id,
          tripId: trip.id,
          stopId: stopId,
          method: VerificationMethod.manualDriver,
          at: DateTime.now(),
          reason: reason,
          recordedByUserId: ref.read(controllerProvider).currentUser.id,
        );
  }

  void _markNoShow(BuildContext context, WidgetRef ref, Student student) {
    ref.read(controllerProvider.notifier).markNoShow(
          studentId: student.id,
          tripId: trip.id,
          recordedByUserId: ref.read(controllerProvider).currentUser.id,
        );
  }
}

/// Everyone the bus is responsible for today, in one list.
class DriverManifestScreen extends ConsumerWidget {
  const DriverManifestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final trip = _driverTrip(ref);

    if (trip == null) {
      return EmptyState(message: s.noData, icon: Icons.groups_rounded);
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        for (final stop in trip.stops)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: _ManifestStopCard(stop: stop, trip: trip),
          ),
      ],
    );
  }
}

class _ManifestStopCard extends ConsumerWidget {
  const _ManifestStopCard({required this.stop, required this.trip});

  final TripStop stop;
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final busStop = SeedData.stopsById[stop.stopId];
    final skipped = stop.status == TripStopStatus.skipped;

    return SectionCard(
      title: s.isArabic ? busStop?.nameAr ?? '' : busStop?.nameEn ?? '',
      subtitle: s.countStudents(stop.expectedStudentIds.length),
      trailing: skipped
          ? StatusPill(
              label: s.legendSkipped,
              foreground: c.absent,
              background: c.absentSurface,
              icon: Icons.cancel_rounded,
              dense: true,
            )
          : null,
      padded: false,
      child: stop.expectedStudentIds.isEmpty
          ? EmptyState(
              message: s.driverNobodyHere,
              icon: Icons.person_off_rounded,
            )
          : Column(
              children: [
                for (final id in stop.expectedStudentIds)
                  _ManifestRow(studentId: id),
              ],
            ),
    );
  }
}

class _ManifestRow extends ConsumerWidget {
  const _ManifestRow({required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final student = ref.watch(controllerProvider).studentsById[studentId];
    final snapshot = ref.watch(studentSnapshotProvider(studentId));
    if (student == null) return const SizedBox.shrink();

    final style = stageStyle(context, snapshot.stage);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            initials: student.photoInitials,
            size: 34,
            color: style.fg,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              s.isArabic ? student.fullNameAr : student.fullNameEn,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          StatusPill(
            label: s.stageLabel(snapshot.stage),
            foreground: style.fg,
            background: style.bg,
            dense: true,
          ),
        ],
      ),
    );
  }
}
