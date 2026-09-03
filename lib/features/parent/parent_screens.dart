import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/app_state.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/journey_engine.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/map_view.dart';
import 'package:safe_path/features/map/schematic_map.dart';
import 'package:safe_path/shared/widgets/common.dart';

/// The guardian's home screen: one card per child, status readable at arm's
/// length. This is the screen a parent opens at 6:40 in the morning, so it
/// answers the only question they have — where is my child right now — before
/// anything else.
class GuardianChildrenScreen extends ConsumerWidget {
  const GuardianChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final children = ref.watch(myChildrenProvider);

    if (children.isEmpty) {
      return EmptyState(
        message: s.guardianNoChildren,
        icon: Icons.family_restroom_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.lg),
      itemBuilder: (context, i) => _ChildCard(student: children[i]),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final snapshot = ref.watch(studentSnapshotProvider(student.id));
    final style = stageStyle(context, snapshot.stage);
    final absence = ref.watch(controllerProvider).absenceFor(student.id);

    return SectionCard(
      title: s.isArabic ? student.fullNameAr : student.fullNameEn,
      subtitle: '${s.grade} ${student.grade}${student.section} · '
          '${student.usesBus ? _stopName(context, student.stopId) : (s.isArabic ? 'بدون حافلة' : 'No bus')}',
      trailing: StatusPill(
        label: s.stageLabel(snapshot.stage),
        foreground: style.fg,
        background: style.bg,
        icon: style.icon,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (snapshot.hasCriticalAlert) ...[
            _CriticalStrip(alert: snapshot.openAlerts.first),
            const SizedBox(height: Gap.lg),
          ],
          _JourneyTimeline(snapshot: snapshot),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: absence == null
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.event_busy_rounded, size: 18),
                        label: Text(s.guardianDeclareAbsence),
                        onPressed: student.usesBus
                            ? () => _declareAbsence(context, ref)
                            : null,
                      )
                    : FilledButton.tonalIcon(
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: Text(s.guardianCancelAbsence),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.absentSurface,
                          foregroundColor: c.absent,
                        ),
                        onPressed: () => ref
                            .read(controllerProvider.notifier)
                            .cancelAbsence(student.id),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _declareAbsence(BuildContext context, WidgetRef ref) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await ref.read(controllerProvider.notifier).declareAbsence(
          studentId: student.id,
          declaredByUserId: ref.read(controllerProvider).currentUser.id,
        );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          s.isArabic
              ? 'سُجّل الغياب وأُبلغ السائق. سيُعاد رسم المسار.'
              : 'Absence recorded and the driver notified. The route is being redrawn.',
        ),
      ),
    );
  }

  String _stopName(BuildContext context, String? stopId) {
    if (stopId == null) return '';
    final stop = SeedData.stopsById[stopId];
    if (stop == null) return '';
    return AppStrings.of(context).isArabic ? stop.nameAr : stop.nameEn;
  }
}

/// The day as a vertical sequence. Four fixed moments, so a parent can see at a
/// glance which ones have happened and which have not.
class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({required this.snapshot});

  final StudentDaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final events = snapshot.events;

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        alignment: Alignment.center,
        child: Text(
          s.stageLabel(snapshot.stage),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.guardianTodayTimeline,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: Gap.sm),
        for (var i = 0; i < events.length; i++)
          _TimelineRow(
            event: events[i],
            isLast: i == events.length - 1,
            lineColor: c.line,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.lineColor,
  });

  final AttendanceEvent event;
  final bool isLast;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final tint = event.isManual ? c.manual : c.brand;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 9,
                height: 9,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: lineColor)),
            ],
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.eventLabel(event.type),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        formatClock(event.occurredAt),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: c.inkSoft,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Manual records are labelled in place, not only in the
                  // notification: the parent must be able to see later which
                  // records were scanned and which were typed.
                  if (event.isManual)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: StatusPill(
                        label: s.methodLabel(event.method),
                        foreground: c.manual,
                        background: c.manualSurface,
                        icon: Icons.edit_note_rounded,
                        dense: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriticalStrip extends StatelessWidget {
  const _CriticalStrip({required this.alert});

  final SafetyAlert alert;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.criticalSurface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border(right: BorderSide(color: c.critical, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_rounded, size: 18, color: c.critical),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.isArabic ? alert.titleAr : alert.titleEn,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: c.critical),
                ),
                Text(
                  s.isArabic ? alert.detailAr : alert.detailEn,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Live map for the child currently travelling.
class GuardianLiveScreen extends ConsumerWidget {
  const GuardianLiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);
    final children = ref.watch(myChildrenProvider);

    // Show the bus the child is actually on; failing that, any run that will
    // carry one of them today.
    Trip? trip;
    for (final child in children) {
      trip = state.activeTripForStudent(child.id);
      if (trip != null) break;
    }
    trip ??= state.trips
        .where(
          (t) => children.any((c) => t.expectedStudentIds.contains(c.id)),
        )
        .firstOrNull;

    if (trip == null) {
      return EmptyState(message: s.tripNotStarted, icon: Icons.map_rounded);
    }

    return _LiveTripView(trip: trip);
  }
}

class _LiveTripView extends ConsumerWidget {
  const _LiveTripView({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);
    final live = state.liveByBus[trip.busId];

    return ListView(
      padding: const EdgeInsets.all(Gap.lg),
      children: [
        if (live == null)
          TripMapView(
            renderer: state.config.mapRenderer,
            trip: trip,
            stopsById: SeedData.stopsById,
            school: state.school.location,
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
            ),
          ),
        const SizedBox(height: Gap.md),
        const MapLegend(),
        const SizedBox(height: Gap.lg),
        if (live?.isStale ?? false) ...[
          _StaleWarning(lastSeen: live!.updatedAt),
          const SizedBox(height: Gap.lg),
        ],
        _TripSummary(trip: trip, live: live),
        const SizedBox(height: Gap.lg),
        SectionCard(
          title: s.navRoutes,
          padded: false,
          child: Column(
            children: [
              for (final stop in trip.stops)
                _StopRow(
                  stop: stop,
                  isNext: trip.nextStop?.stopId == stop.stopId,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown the moment a tracker goes quiet. The app says so rather than letting
/// a frozen marker imply the bus has stopped moving.
class _StaleWarning extends StatelessWidget {
  const _StaleWarning({required this.lastSeen});

  final DateTime lastSeen;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: c.manualSurface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.manual.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.signal_wifi_statusbar_null_rounded,
            size: 18,
            color: c.manual,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.signalLost,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: c.manual),
                ),
                Text(
                  '${s.lastSeen} ${formatClock(lastSeen)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.trip, required this.live});

  final Trip trip;
  final BusLiveState? live;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    final remaining =
        trip.stops.where((st) => st.status == TripStopStatus.pending).length;
    final metresLeft =
        (trip.path.totalDistanceMetres - (live?.distanceAlongRouteMetres ?? 0))
            .clamp(0, double.infinity)
            .round();
    final nextStop = trip.nextStop;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: s.nextStop,
            value: nextStop == null
                ? '—'
                : (s.isArabic
                    ? SeedData.stopsById[nextStop.stopId]?.nameAr ?? '—'
                    : SeedData.stopsById[nextStop.stopId]?.nameEn ?? '—'),
            icon: Icons.place_rounded,
            accent: c.brand,
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: StatTile(
            label: s.stopsRemaining,
            value: '$remaining',
            icon: Icons.linear_scale_rounded,
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: StatTile(
            label: s.distanceRemaining,
            value: s.metres(metresLeft),
            icon: Icons.route_rounded,
          ),
        ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.isNext});

  final TripStop stop;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final busStop = SeedData.stopsById[stop.stopId];
    final skipped = stop.status == TripStopStatus.skipped;

    final (icon, tint) = switch (stop.status) {
      TripStopStatus.departed => (Icons.check_circle_rounded, c.delivered),
      TripStopStatus.arrived => (Icons.trip_origin_rounded, c.onBus),
      TripStopStatus.skipped => (Icons.cancel_rounded, c.absent),
      TripStopStatus.pending => (
          Icons.radio_button_unchecked_rounded,
          c.inkMuted
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        color: isNext ? c.brandSurface : null,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Text(
              s.isArabic
                  ? busStop?.nameAr ?? stop.stopId
                  : busStop?.nameEn ?? stop.stopId,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    decoration: skipped ? TextDecoration.lineThrough : null,
                    color: skipped ? c.inkMuted : null,
                  ),
            ),
          ),
          if (skipped)
            StatusPill(
              label: s.legendSkipped,
              foreground: c.absent,
              background: c.absentSurface,
              dense: true,
            )
          else
            Text(
              s.countStudents(stop.expectedStudentIds.length),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.inkSoft,
                  ),
            ),
        ],
      ),
    );
  }
}

/// The notification feed, including the confirm/dispute action that turns a
/// guardian into a second verification layer for hand-entered records.
class GuardianNotificationsScreen extends ConsumerStatefulWidget {
  const GuardianNotificationsScreen({super.key});

  @override
  ConsumerState<GuardianNotificationsScreen> createState() =>
      _GuardianNotificationsScreenState();
}

class _GuardianNotificationsScreenState
    extends ConsumerState<GuardianNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Reading the feed is what marks it read, which is what everyone expects
    // and what keeps the badge meaningful.
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  void _markAllRead() {
    if (!mounted) return;
    final controller = ref.read(controllerProvider.notifier);
    for (final notification in ref.read(myNotificationsProvider)) {
      if (notification.isUnread) {
        controller.markNotificationRead(notification.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final notifications = ref.watch(myNotificationsProvider);

    if (notifications.isEmpty) {
      return EmptyState(
        message: s.noData,
        icon: Icons.notifications_off_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(Gap.lg),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
      itemBuilder: (context, i) =>
          _NotificationCard(notification: notifications[i]),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final state = ref.watch(controllerProvider);

    final event = notification.attendanceEventId == null
        ? null
        : state.attendanceEvents
            .where((e) => e.id == notification.attendanceEventId)
            .firstOrNull;

    final isCritical = notification.kind == NotificationKind.safetyAlert ||
        notification.kind == NotificationKind.emergency;
    final isManual = notification.kind == NotificationKind.manualAttendance;
    final tint = isCritical
        ? c.critical
        : isManual
            ? c.manual
            : c.brand;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(
          color: isCritical ? c.critical.withValues(alpha: 0.5) : c.line,
        ),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(notification.kind), size: 18, color: tint),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  s.isArabic ? notification.titleAr : notification.titleEn,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                formatClock(notification.sentAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.inkMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            s.isArabic ? notification.bodyAr : notification.bodyEn,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (notification.requiresConfirmation && event != null) ...[
            const SizedBox(height: Gap.lg),
            if (event.guardianConfirmation == GuardianConfirmation.pending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond(
                        ref,
                        event.id,
                        GuardianConfirmation.confirmed,
                      ),
                      child: Text(s.guardianConfirmManual),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: c.critical),
                      onPressed: () => _respond(
                        ref,
                        event.id,
                        GuardianConfirmation.disputed,
                      ),
                      child: Text(s.guardianDisputeManual),
                    ),
                  ),
                ],
              )
            else
              StatusPill(
                label:
                    event.guardianConfirmation == GuardianConfirmation.confirmed
                        ? s.guardianConfirmed
                        : s.guardianDisputed,
                foreground:
                    event.guardianConfirmation == GuardianConfirmation.confirmed
                        ? c.delivered
                        : c.critical,
                background:
                    event.guardianConfirmation == GuardianConfirmation.confirmed
                        ? c.deliveredSurface
                        : c.criticalSurface,
                icon:
                    event.guardianConfirmation == GuardianConfirmation.confirmed
                        ? Icons.check_rounded
                        : Icons.flag_rounded,
              ),
          ],
        ],
      ),
    );
  }

  void _respond(WidgetRef ref, String eventId, GuardianConfirmation response) {
    ref.read(controllerProvider.notifier).respondToManualEntry(
          attendanceEventId: eventId,
          response: response,
        );
  }

  static IconData _iconFor(NotificationKind kind) => switch (kind) {
        NotificationKind.emergency => Icons.sos_rounded,
        NotificationKind.boarded => Icons.login_rounded,
        NotificationKind.alighted => Icons.logout_rounded,
        NotificationKind.enteredSchool => Icons.school_rounded,
        NotificationKind.exitedSchool => Icons.door_front_door_rounded,
        NotificationKind.busApproaching => Icons.near_me_rounded,
        NotificationKind.busArrived => Icons.place_rounded,
        NotificationKind.manualAttendance => Icons.edit_note_rounded,
        NotificationKind.absenceRecorded => Icons.event_busy_rounded,
        NotificationKind.noShow => Icons.person_off_rounded,
        NotificationKind.safetyAlert => Icons.error_rounded,
        NotificationKind.tripStarted => Icons.play_circle_rounded,
        NotificationKind.tripCompleted => Icons.flag_rounded,
      };
}
