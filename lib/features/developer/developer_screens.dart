import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/data/simulation/simulated_fleet.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// Scenario controls.
///
/// Every failure this product is built to catch can be triggered here on
/// demand. A safety feature nobody can watch working is a claim, not a
/// demonstration — and these are the buttons that turn the claim into one.
class DeveloperControlsScreen extends ConsumerWidget {
  const DeveloperControlsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final source = controller.eventSource;

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        SectionCard(
          title: s.devDiagnostics,
          child: Column(
            children: [
              _DiagnosticRow(
                label: s.isArabic ? 'مصدر البيانات' : 'Data source',
                value: state.config.isDemo
                    ? (s.isArabic ? 'محاكاة' : 'Simulated')
                    : (s.isArabic ? 'أجهزة حقيقية' : 'Live trackers'),
              ),
              _DiagnosticRow(
                label: s.isArabic ? 'محرّك الخريطة' : 'Map renderer',
                value: state.config.mapRenderer.name,
              ),
              _DiagnosticRow(
                label: s.isArabic ? 'رحلات جارية' : 'Active trips',
                value: '${state.activeTrips.length}',
              ),
              _DiagnosticRow(
                label: s.isArabic ? 'أحداث الحضور' : 'Attendance events',
                value: '${state.attendanceEvents.length}',
              ),
              _DiagnosticRow(
                label: s.isArabic ? 'الإشعارات المرسلة' : 'Notifications sent',
                value: '${state.notifications.length}',
              ),
              _DiagnosticRow(
                label: s.alertsOpenCount,
                value: '${state.openAlerts.length}',
                accent: state.openAlerts.isEmpty ? null : c.critical,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: s.devScenario,
          subtitle: s.isArabic
              ? 'شغّل رحلة ثم أطلق سيناريو لترى النظام يكتشفه'
              : 'Start a trip, then fire a scenario and watch it get caught',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final trip in state.trips)
                if (trip.status == TripStatus.scheduled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.sm),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        '${s.driverStartTrip} — '
                        '${SeedData.busesById[trip.busId]?.plateNumber ?? trip.busId}',
                      ),
                      onPressed: () => controller.startTrip(trip.id),
                    ),
                  ),
              const SizedBox(height: Gap.sm),
              OutlinedButton.icon(
                icon: Icon(Icons.person_off_rounded, color: c.critical),
                label: Text(s.devTriggerLeftOnBus),
                onPressed: source is SimulatedFleet
                    ? () => _leaveOnBoard(context, ref, source)
                    : null,
              ),
              const SizedBox(height: Gap.sm),
              OutlinedButton.icon(
                icon: Icon(Icons.signal_wifi_off_rounded, color: c.manual),
                label: Text(
                  s.isArabic ? 'محاكاة انقطاع الإشارة' : 'Simulate signal loss',
                ),
                onPressed: source is SimulatedFleet
                    ? () => _silence(context, ref, source, state.activeTrips)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: s.devReset,
          subtitle: s.devClearStoredNote,
          child: OutlinedButton.icon(
            icon: Icon(Icons.delete_sweep_rounded, color: c.critical),
            label: Text(s.devClearStored),
            onPressed: () => _clearStored(context, ref),
          ),
        ),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: s.devImpersonate,
          subtitle: s.devImpersonationLogged,
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final role in UserRole.values)
                if (role != UserRole.developer)
                  OutlinedButton(
                    onPressed: () => controller.beginImpersonation(role),
                    child: Text(s.roleName(role)),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  /// Wipes the device's copy of the day.
  ///
  /// Deliberately does not clear what is already in memory: the running app
  /// is mid-day and mid-trip, and silently emptying a driver's manifest is a
  /// far worse outcome than a reset that takes effect on the next launch.
  Future<void> _clearStored(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await ref.read(controllerProvider.notifier).clearPersistence();
    messenger.showSnackBar(SnackBar(content: Text(s.devClearStoredDone)));
  }

  /// Marks a boarded student so the simulator never scans them off — the exact
  /// shape of a child left asleep in a seat.
  Future<void> _leaveOnBoard(
    BuildContext context,
    WidgetRef ref,
    SimulatedFleet fleet,
  ) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(controllerProvider);

    final onBoard = <String>{};
    for (final event in state.attendanceEvents) {
      if (event.type == AttendanceEventType.boardedBus) {
        onBoard.add(event.studentId);
      } else if (event.type == AttendanceEventType.alightedBus) {
        onBoard.remove(event.studentId);
      }
    }

    if (onBoard.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            s.isArabic
                ? 'ابدأ رحلة أولاً وانتظر صعود الطلاب'
                : 'Start a trip first and wait for students to board',
          ),
        ),
      );
      return;
    }

    final studentId = onBoard.first;
    fleet.leaveStudentOnBoard(studentId);
    final name = state.studentsById[studentId];

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          s.isArabic
              ? '${name?.fullNameAr} لن يسجّل نزوله. أنهِ الرحلة لترى التنبيه.'
              : '${name?.fullNameEn} will not scan off. End the trip to see the alert.',
        ),
      ),
    );
  }

  void _silence(
    BuildContext context,
    WidgetRef ref,
    SimulatedFleet fleet,
    List<Trip> activeTrips,
  ) {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (activeTrips.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.tripNotStarted)),
      );
      return;
    }
    fleet.silenceTracker(activeTrips.first.busId);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          s.isArabic
              ? 'أُسكِت جهاز التتبع. الخريطة ستتوقف عن الحركة وتوضّح أن الموقع غير محدّث.'
              : 'Tracker silenced. The map stops animating and says the position is not current.',
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent ?? c.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The raw attendance log, newest first.
class DeveloperEventLogScreen extends ConsumerWidget {
  const DeveloperEventLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);
    final students = state.studentsById;
    final events = state.attendanceEvents.reversed.toList();

    if (events.isEmpty) {
      return EmptyState(message: s.noData, icon: Icons.receipt_long_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final event = events[i];
        final student = students[event.studentId];
        return Container(
          margin: const EdgeInsets.only(bottom: Gap.sm),
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(
              color: event.isManual ? c.manual.withValues(alpha: 0.5) : c.line,
            ),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Row(
            children: [
              Text(
                formatClock(event.occurredAt),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: c.inkSoft,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.isArabic ? student?.fullNameAr ?? '' : student?.fullNameEn ?? ''} — '
                      '${s.eventLabel(event.type)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      s.methodLabel(event.method),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: event.isManual ? c.manual : c.inkMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Privileged-access history.
///
/// The reason the developer role is defensible: nothing it does is invisible.
class DeveloperAuditScreen extends ConsumerWidget {
  const DeveloperAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final entries = ref.watch(controllerProvider).auditLog.reversed.toList();

    if (entries.isEmpty) {
      return EmptyState(
        message: s.isArabic
            ? 'لا يوجد وصول مميّز مسجّل بعد'
            : 'No privileged access recorded yet',
        icon: Icons.policy_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        return Container(
          margin: const EdgeInsets.only(bottom: Gap.sm),
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: c.inkSoft),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.action,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      // Naming the person is the point of the log; a role
                      // alone cannot be held to anything.
                      '${SeedData.usersById[entry.actorUserId]?.fullNameAr ?? entry.actorUserId}'
                      ' · ${s.roleName(entry.actorRole)}'
                      '${entry.detail == null ? '' : ' → ${entry.detail}'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                formatClock(entry.occurredAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
