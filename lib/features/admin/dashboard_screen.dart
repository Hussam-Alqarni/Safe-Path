import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/analytics.dart';
import 'package:safe_path/features/admin/charts.dart';
import 'package:safe_path/features/students/student_detail_sheet.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// The administrator's dashboard.
///
/// Ordered by urgency, not by category: anything needing action is above
/// anything merely informative, and the figures at the top are the ones
/// someone would act on within the hour. Everything below them explains why
/// those numbers are what they are.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  /// Below this the layout is one column; above it, two. Chosen from content
  /// width rather than a device category — the same tablet in landscape has
  /// room for two columns and in portrait does not.
  static const _twoColumnBreakpoint = 880.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(openAlertsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumn = constraints.maxWidth >= _twoColumnBreakpoint;
        final panels = <Widget>[
          const _AttendanceTrendPanel(),
          const _DriverReliabilityPanel(),
          const _PunctualityPanel(),
          const _DataGapsPanel(),
          const _FleetPanel(),
        ];

        return ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            if (alerts.isNotEmpty) ...[
              _AlertStrip(count: alerts.length),
              const SizedBox(height: Gap.lg),
            ],
            const _KpiRow(),
            const SizedBox(height: Gap.lg),
            if (twoColumn)
              _TwoColumn(panels: panels)
            else
              for (final panel in panels)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gap.lg),
                  child: panel,
                ),
          ],
        );
      },
    );
  }
}

/// Balances panels across two columns by count, so neither runs far longer
/// than the other and the page has no long empty gutter.
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.panels});

  final List<Widget> panels;

  @override
  Widget build(BuildContext context) {
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < panels.length; i++) {
      (i.isEven ? left : right).add(panels[i]);
    }

    Widget column(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.lg),
                child: child,
              ),
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: Gap.lg),
        Expanded(child: column(right)),
      ],
    );
  }
}

/// The four counts that answer "is everyone accounted for right now".
///
/// Deliberately four separate tiles rather than one stacked bar: the question
/// is how many are in each state, read individually, not how the states divide
/// a whole. Each keeps its own state colour, and none is ever adjacent to
/// another as a fill, so meaning survives without a legend.
class _KpiRow extends ConsumerWidget {
  const _KpiRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final tally = ref.watch(schoolTallyProvider);

    final tiles = <Widget>[
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
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: Gap.md,
          mainAxisSpacing: Gap.md,
          childAspectRatio: columns == 4 ? 1.5 : 1.55,
          children: tiles,
        );
      },
    );
  }
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.count});

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

class _AttendanceTrendPanel extends ConsumerWidget {
  const _AttendanceTrendPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);

    final today = Analytics.today(
      trips: state.trips,
      events: state.attendanceEvents,
      students: state.students,
      date: DateTime.now(),
    );

    // Seed history is a demo prop. Drawing it beside a real measurement in a
    // live deployment would be the app inventing a fortnight of attendance.
    final history = state.usesSimulatedData
        ? SeedData.demoAttendanceHistory
        : const <({DateTime date, int expected, int present, int manual})>[];

    final points = <TrendPoint>[
      for (final day in history)
        TrendPoint(
          label: _weekday(context, day.date),
          value: day.present / day.expected,
          caption: '${day.present} / ${day.expected}',
        ),
      TrendPoint(
        label: s.today,
        value: today.rate,
        caption: '${today.present} / ${today.expected}',
      ),
    ];

    return SectionCard(
      title: s.dashAttendanceTrend,
      subtitle: s.dashAttendanceTrendNote,
      child: TrendChart(
        points: points,
        referenceValue: 0.95,
        formatValue: (v) => '${(v * 100).round()}%',
      ),
    );
  }

  static String _weekday(BuildContext context, DateTime date) {
    const ar = ['اث', 'ث', 'أر', 'خ', 'ج', 'س', 'أح'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final index = (date.weekday - 1) % 7;
    return AppStrings.of(context).isArabic ? ar[index] : en[index];
  }
}

class _DriverReliabilityPanel extends ConsumerWidget {
  const _DriverReliabilityPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);

    final rows = Analytics.driverReliability(
      events: state.attendanceEvents,
      trips: state.trips,
    );

    return SectionCard(
      title: s.dashDriverReliability,
      subtitle: s.dashDriverReliabilityNote,
      child: RankedBarChart(
        bars: [
          for (final row in rows)
            RankedBar(
              label: s.isArabic
                  ? SeedData.usersById[row.driverId]?.fullNameAr ?? row.driverId
                  : SeedData.usersById[row.driverId]?.fullNameEn ??
                      row.driverId,
              value: row.manualRate,
              display: '${(row.manualRate * 100).round()}%',
              // Above a fifth, a human should look at the reader before the
              // driver.
              warn: row.manualRate > 0.2,
            ),
        ],
      ),
    );
  }
}

class _PunctualityPanel extends ConsumerWidget {
  const _PunctualityPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);
    final rows = Analytics.punctuality(state.trips);

    return SectionCard(
      title: s.dashPunctuality,
      subtitle: s.dashPunctualityNote,
      child: RankedBarChart(
        bars: [
          for (final row in rows)
            RankedBar(
              label: SeedData.busesById[row.busId]?.plateNumber ?? row.busId,
              // Scaled against a ten-minute window: beyond that the exact
              // number matters less than the fact that it is far outside plan.
              value: (row.averageDelaySeconds.abs() / 600).clamp(0.0, 1.0),
              display: _delayLabel(s, row),
              warn: row.averageDelaySeconds.abs() > 300,
            ),
        ],
      ),
    );
  }

  static String _delayLabel(AppStrings s, RoutePunctuality row) {
    final minutes = row.averageDelayMinutes;
    if (minutes == 0) return s.dashOnTime;
    // Early is reported as plainly as late: a bus that beats its timetable
    // leaves a child standing on a pavement.
    return minutes > 0
        ? '${s.minutes(minutes)} ${s.dashLate}'
        : '${s.minutes(minutes.abs())} ${s.dashEarly}';
  }
}

/// Students whose home has never been recorded.
///
/// Not a vanity metric: each row is a pickup point nobody has confirmed, and
/// the panel exists because the fix is one tap away from the number.
class _DataGapsPanel extends ConsumerWidget {
  const _DataGapsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final missing = Analytics.missingHomeLocation(ref.watch(studentsProvider));

    return SectionCard(
      title: s.dashDataGaps,
      subtitle: s.dashDataGapsNote,
      trailing: missing.isEmpty
          ? Icon(Icons.check_circle_rounded, size: 18, color: c.delivered)
          : StatusPill(
              label: '${missing.length}',
              foreground: c.manual,
              background: c.manualSurface,
              dense: true,
            ),
      padded: missing.isEmpty,
      child: missing.isEmpty
          ? Text(
              s.dashNoGaps,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.inkSoft),
            )
          : Column(
              children: [
                for (final student in missing.take(6))
                  _GapRow(student: student),
              ],
            ),
    );
  }
}

/// Every run today and where it stands.
class _FleetPanel extends ConsumerWidget {
  const _FleetPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);

    return SectionCard(
      title: s.navFleet,
      subtitle: s.countStops(
        state.trips.fold(0, (sum, t) => sum + t.activeStops.length),
      ),
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

class _GapRow extends ConsumerWidget {
  const _GapRow({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final stop =
        student.stopId == null ? null : SeedData.stopsById[student.stopId];

    return InkWell(
      onTap: () => showStudentDetail(context, ref, student.id),
      child: Container(
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
              size: 32,
              color: c.manual,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.isArabic ? student.fullNameAr : student.fullNameEn,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (stop != null)
                    Text(
                      s.isArabic ? stop.nameAr : stop.nameEn,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Text(
              s.dashFixNow,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.brand),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMuted),
          ],
        ),
      ),
    );
  }
}
