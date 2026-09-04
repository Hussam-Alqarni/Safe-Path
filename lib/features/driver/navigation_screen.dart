import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_path/core/i18n/strings.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';
import 'package:safe_path/data/repositories/providers.dart';
import 'package:safe_path/data/seed/seed_data.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/navigation_service.dart';
import 'package:safe_path/features/driver/emergency_button.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/map_view.dart';

/// Full-screen driving view.
///
/// Built for a tablet clamped to a dashboard: the map fills the screen, the
/// next manoeuvre is the largest thing on it, and every control is a target a
/// driver can hit without looking. Nothing here needs two hands.
class DriverNavigationScreen extends ConsumerStatefulWidget {
  const DriverNavigationScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<DriverNavigationScreen> createState() =>
      _DriverNavigationScreenState();
}

class _DriverNavigationScreenState
    extends ConsumerState<DriverNavigationScreen> {
  bool _traffic = true;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final state = ref.watch(controllerProvider);
    final trip = state.tripById(widget.tripId);
    if (trip == null) return const SizedBox.shrink();

    final steps =
        ref.watch(navigationStepsProvider(widget.tripId)).valueOrNull ??
            const <NavigationStep>[];
    final live = state.liveByBus[trip.busId];

    return Directionality(
      textDirection: s.direction,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: live == null
                  ? TripMapView(
                      renderer: state.config.mapRenderer,
                      trip: trip,
                      stopsById: SeedData.stopsById,
                      school: state.school.location,
                      height: double.infinity,
                      showTraffic: _traffic,
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
                        height: double.infinity,
                        followBus: true,
                        tiltedFollow: true,
                        showTraffic: _traffic,
                      ),
                    ),
            ),

            // Guidance sits at the top, where a windscreen-mounted tablet puts
            // it closest to the road.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: _GuidanceBanner(
                    steps: steps,
                    distanceAlongRoute: live?.distanceAlongRouteMetres ?? 0,
                    stale: live?.isStale ?? true,
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: _NavigationControls(
                    trip: trip,
                    trafficOn: _traffic,
                    onToggleTraffic: () => setState(() => _traffic = !_traffic),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({
    required this.steps,
    required this.distanceAlongRoute,
    required this.stale,
  });

  final List<NavigationStep> steps;
  final double distanceAlongRoute;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final c = context.colors;

    final guidance = guidanceAt(
      steps: steps,
      distanceAlongRouteMetres: distanceAlongRoute,
    );
    if (guidance == null) return const SizedBox.shrink();

    final stopName = guidance.current.stopId == null
        ? null
        : (s.isArabic
            ? SeedData.stopsById[guidance.current.stopId]?.nameAr
            : SeedData.stopsById[guidance.current.stopId]?.nameEn);

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(Radii.md),
      color: guidance.isImminent ? c.brand : c.surface,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _ManeuverIcon(
                  maneuver: guidance.current.maneuver,
                  color: guidance.isImminent ? Colors.white : c.brand,
                  size: 46,
                ),
                const SizedBox(width: Gap.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Distance first, the way a driver reads it: how far,
                        // then what to do.
                        s.metres(guidance.metresToManeuver.round()),
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: guidance.isImminent ? Colors.white : c.ink,
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      Text(
                        stopName ?? s.maneuverLabel(guidance.current.maneuver),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: guidance.isImminent
                                      ? Colors.white
                                      : c.inkSoft,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (guidance.next != null) ...[
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Text(
                    s.thenNext,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              guidance.isImminent ? Colors.white70 : c.inkMuted,
                        ),
                  ),
                  const SizedBox(width: Gap.sm),
                  _ManeuverIcon(
                    maneuver: guidance.next!.maneuver,
                    color: guidance.isImminent ? Colors.white70 : c.inkSoft,
                    size: 18,
                  ),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      s.maneuverLabel(guidance.next!.maneuver),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: guidance.isImminent
                                ? Colors.white70
                                : c.inkSoft,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (stale) ...[
              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  Icon(
                    Icons.signal_wifi_statusbar_null_rounded,
                    size: 14,
                    color: guidance.isImminent ? Colors.white70 : c.manual,
                  ),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      s.signalLost,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                guidance.isImminent ? Colors.white70 : c.manual,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Arrow glyphs for each manoeuvre.
///
/// Material has no complete turn set, so left and right share one icon,
/// mirrored — which also guarantees the pair always reads as opposites.
class _ManeuverIcon extends StatelessWidget {
  const _ManeuverIcon({
    required this.maneuver,
    required this.color,
    required this.size,
  });

  final Maneuver maneuver;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = switch (maneuver) {
      Maneuver.depart => Icons.navigation_rounded,
      Maneuver.straight => Icons.straight_rounded,
      Maneuver.slightLeft => Icons.turn_slight_left_rounded,
      Maneuver.left => Icons.turn_left_rounded,
      Maneuver.sharpLeft => Icons.turn_sharp_left_rounded,
      Maneuver.slightRight => Icons.turn_slight_right_rounded,
      Maneuver.right => Icons.turn_right_rounded,
      Maneuver.sharpRight => Icons.turn_sharp_right_rounded,
      Maneuver.uTurn => Icons.u_turn_left_rounded,
      Maneuver.arriveStop => Icons.place_rounded,
      Maneuver.arriveDestination => Icons.school_rounded,
    };
    return Icon(icon, size: size, color: color);
  }
}

class _NavigationControls extends ConsumerWidget {
  const _NavigationControls({
    required this.trip,
    required this.trafficOn,
    required this.onToggleTraffic,
  });

  final Trip trip;
  final bool trafficOn;
  final VoidCallback onToggleTraffic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final c = context.colors;
    final nextStop = trip.nextStop;
    final stop = nextStop == null ? null : SeedData.stopsById[nextStop.stopId];

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(Radii.md),
      color: c.surface,
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (stop != null)
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 18, color: c.brand),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      s.isArabic ? stop.nameAr : stop.nameEn,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    s.countStudents(nextStop!.expectedStudentIds.length),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: c.inkSoft,
                        ),
                  ),
                ],
              ),
            const SizedBox(height: Gap.md),
            EmergencyButton(tripId: trip.id, compact: true),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(
                      trafficOn
                          ? Icons.traffic_rounded
                          : Icons.traffic_outlined,
                      size: 18,
                      color: trafficOn ? c.brand : c.inkSoft,
                    ),
                    label: Text(s.showTraffic),
                    onPressed: onToggleTraffic,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: c.critical),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(s.exitNavigation),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
