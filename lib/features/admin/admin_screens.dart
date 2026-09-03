import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/map_view.dart';
import 'package:safe_path/features/students/student_detail_sheet.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// The administrator's landing screen.
///
/// Summary before detail: the counts that need attention are readable without
/// scrolling, and anything requiring action is above anything merely
/// informative.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final tally = ref.watch(schoolTallyProvider);
    final alerts = ref.watch(openAlertsProvider);

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        if (alerts.isNotEmpty) ...[
          _AlertSummaryBanner(count: alerts.length),
          const SizedBox(height: Gap.lg),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: Gap.md,
          mainAxisSpacing: Gap.md,
          childAspectRatio: 1.55,
          children: [
            StatTile(
              label: s.adminTotalStudents,
              value: '${tally.total}',
              icon: Icons.groups_rounded,
            ),
            StatTile(
              label: s.adminOnBus,
              value: '${tally.onBus}',
              icon: Icons.directions_bus_rounded,
              accent: c.onBus,
            ),
            StatTile(
              label: s.adminAtSchool,
              value: '${tally.atSchool}',
              icon: Icons.school_rounded,
              accent: c.atSchool,
            ),
            StatTile(
              label: s.adminAbsent,
              value: '${tally.absent}',
              icon: Icons.event_busy_rounded,
              accent: c.absent,
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: s.adminActiveTrips,
                value: '${tally.activeTrips}',
                icon: Icons.route_rounded,
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              // A rising manual-entry rate is the earliest signal that a reader
              // has failed, long before anyone reports it.
              child: StatTile(
                label: s.adminManualRate,
                value: '${(tally.manualRate * 100).round()}%',
                icon: Icons.edit_note_rounded,
                accent: tally.manualRate > 0.2 ? c.manual : null,
                caption: tally.manualRate > 0.2
                    ? (s.isArabic
                        ? 'مرتفعة — افحص القارئ'
                        : 'High — check the reader')
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        _ActiveTripsCard(),
      ],
    );
  }
}

class _AlertSummaryBanner extends StatelessWidget {
  const _AlertSummaryBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.criticalSurface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.critical.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_rounded, color: c.critical),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              '$count ${s.alertsOpenCount}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: c.critical),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTripsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);

    return SectionCard(
      title: s.navFleet,
      padded: false,
      child: Column(
        children: [
          for (final trip in state.trips)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.lg,
                vertical: Gap.md,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bus_rounded,
                    size: 18,
                    color: trip.status == TripStatus.inProgress
                        ? c.onBus
                        : c.inkMuted,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SeedData.busesById[trip.busId]?.plateNumber ??
                              trip.busId,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          s.countStops(trip.activeStops.length),
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
                    foreground: trip.status == TripStatus.inProgress
                        ? c.onBus
                        : c.inkSoft,
                    background: trip.status == TripStatus.inProgress
                        ? c.onBusSurface
                        : c.sunken,
                    dense: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Every bus on one screen.
class AdminFleetScreen extends ConsumerWidget {
  const AdminFleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);

    if (state.trips.isEmpty) {
      return EmptyState(message: s.noData, icon: Icons.map_rounded);
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        for (final trip in state.trips)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: _FleetTripCard(trip: trip),
          ),
      ],
    );
  }
}

class _FleetTripCard extends ConsumerWidget {
  const _FleetTripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);
    final live = state.liveByBus[trip.busId];
    final bus = SeedData.busesById[trip.busId];

    return SectionCard(
      title: bus?.plateNumber ?? trip.busId,
      subtitle: s.countStops(trip.activeStops.length),
      child: live == null
          ? TripMapView(
              renderer: state.config.mapRenderer,
              trip: trip,
              stopsById: SeedData.stopsById,
              school: state.school.location,
              height: 200,
            )
          : BusPositionAnimator(
              live: live,
              path: trip.path,
              builder: (context, position) => TripMapView(
                renderer: state.config.mapRenderer,
                trip: trip,
                stopsById: SeedData.stopsById,
                school: state.school.location,
                live: position,
                height: 200,
              ),
            ),
    );
  }
}

/// The full student roster with search.
///
/// Covers the whole school, not only bus riders: the gate readers record
/// everyone, so attendance here is school-wide.
class AdminRosterScreen extends ConsumerStatefulWidget {
  const AdminRosterScreen({super.key});

  @override
  ConsumerState<AdminRosterScreen> createState() => _AdminRosterScreenState();
}

class _AdminRosterScreenState extends ConsumerState<AdminRosterScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final matches = ref.watch(studentsProvider).where((student) {
      if (_query.isEmpty) return true;
      final needle = _query.toLowerCase();
      return student.fullNameAr.contains(_query) ||
          student.fullNameEn.toLowerCase().contains(needle) ||
          '${student.grade}${student.section}'.contains(needle);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: TextField(
            controller: _controller,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: s.adminSearchStudents,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? EmptyState(
                  message: s.adminNoResults,
                  icon: Icons.search_off_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
                  itemCount: matches.length,
                  itemBuilder: (context, i) =>
                      StudentRosterRow(student: matches[i]),
                ),
        ),
      ],
    );
  }
}

/// One roster row. Shared with the staff screens so a student looks identical
/// wherever they are listed.
class StudentRosterRow extends ConsumerWidget {
  const StudentRosterRow({required this.student, super.key});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final snapshot = ref.watch(studentSnapshotProvider(student.id));
    final style = stageStyle(context, snapshot.stage);
    final stop =
        student.stopId == null ? null : SeedData.stopsById[student.stopId];

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showStudentDetail(context, ref, student.id),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
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
                      [
                        '${s.grade} ${student.grade}${student.section}',
                        if (stop != null)
                          s.isArabic ? stop.nameAr : stop.nameEn,
                        if (!student.usesBus)
                          s.isArabic ? 'بدون حافلة' : 'No bus',
                        if (!student.hasHome && student.usesBus)
                          s.isArabic ? 'بلا موقع منزل' : 'no home set',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: s.stageLabel(snapshot.stage),
                foreground: style.fg,
                background: style.bg,
                icon: style.icon,
                dense: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Open safety alerts, most severe first.
class AdminAlertsScreen extends ConsumerWidget {
  const AdminAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final alerts = ref.watch(openAlertsProvider);

    if (alerts.isEmpty) {
      return EmptyState(
        message: s.alertsNone,
        icon: Icons.verified_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) => _AlertCard(alert: alerts[i]),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  const _AlertCard({required this.alert});

  final SafetyAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final style = severityStyle(context, alert.severity);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: style.fg.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Gap.md),
            color: style.bg,
            child: Row(
              children: [
                Icon(Icons.error_rounded, size: 18, color: style.fg),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    s.alertKindLabel(alert.kind),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: style.fg),
                  ),
                ),
                Text(
                  formatClock(alert.raisedAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: style.fg,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.isArabic ? alert.detailAr : alert.detailEn,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: Gap.lg),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(s.alertAcknowledge),
                  onPressed: () => ref
                      .read(controllerProvider.notifier)
                      .acknowledgeAlert(alert.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
