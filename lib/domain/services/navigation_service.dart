import 'dart:math' as math;

import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// What the driver has to do next.
enum Maneuver {
  depart,
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,
  arriveStop,
  arriveDestination;

  bool get isArrival => this == arriveStop || this == arriveDestination;
}

/// One instruction on the way.
class NavigationStep {
  const NavigationStep({
    required this.maneuver,
    required this.distanceAlongRouteMetres,
    required this.location,
    this.streetAr,
    this.streetEn,
    this.stopId,
  });

  final Maneuver maneuver;

  /// Where along the trip path this instruction applies.
  final double distanceAlongRouteMetres;

  final LatLngPoint location;

  /// Street names come from a routing provider; the offline engine leaves them
  /// null rather than inventing a name, and the UI says "المحطة التالية"
  /// instead of guessing.
  final String? streetAr;
  final String? streetEn;

  /// Set on an arrival step so the driver screen can show who is due here.
  final String? stopId;
}

/// The instruction to show right now, with how far away it is.
class ActiveGuidance {
  const ActiveGuidance({
    required this.current,
    required this.metresToManeuver,
    this.next,
  });

  final NavigationStep current;
  final double metresToManeuver;

  /// The instruction after this one — shown small, the way a navigator does,
  /// so the driver can plan two moves ahead at a junction.
  final NavigationStep? next;

  /// Inside this range the instruction is imminent and the banner emphasises it.
  bool get isImminent => metresToManeuver < 120;
}

/// Produces turn-by-turn instructions for a trip.
///
/// Behind an interface so a real routing provider can supply street names and
/// live traffic later without the driver screen changing at all.
abstract class NavigationService {
  Future<List<NavigationStep>> stepsFor({
    required Trip trip,
    required Map<String, BusStop> stopsById,
  });
}

/// Derives instructions from the route geometry alone.
///
/// No key, no network, no cost — it reads the turns out of the line the bus is
/// already following. It cannot name a street, which is why the instruction
/// text stays about the turn itself; for a driver who knows the neighbourhood,
/// that is most of the value anyway.
class GeometryNavigationService implements NavigationService {
  const GeometryNavigationService({
    this.sampleMetres = 25,
    this.minimumTurnDegrees = 22,
    this.minimumGapMetres = 60,
  });

  /// How often the heading is measured along the path.
  final double sampleMetres;

  /// Below this, a bend is a curve in the road rather than a turn to announce.
  final double minimumTurnDegrees;

  /// Two turns closer together than this are one manoeuvre, not two.
  final double minimumGapMetres;

  @override
  Future<List<NavigationStep>> stepsFor({
    required Trip trip,
    required Map<String, BusStop> stopsById,
  }) async {
    final path = trip.path;
    final total = path.totalDistanceMetres;
    if (total <= 0) return const [];

    final steps = <NavigationStep>[
      NavigationStep(
        maneuver: Maneuver.depart,
        distanceAlongRouteMetres: 0,
        location: path.pointAtDistance(0),
      ),
    ];

    var lastAnnounced = 0.0;
    var previousBearing = path.bearingAtDistance(0);

    for (var d = sampleMetres; d < total; d += sampleMetres) {
      final bearing = path.bearingAtDistance(d);
      final delta = _signedTurn(previousBearing, bearing);
      previousBearing = bearing;

      if (delta.abs() < minimumTurnDegrees) continue;
      if (d - lastAnnounced < minimumGapMetres) continue;

      steps.add(
        NavigationStep(
          maneuver: _classify(delta),
          distanceAlongRouteMetres: d,
          location: path.pointAtDistance(d),
        ),
      );
      lastAnnounced = d;
    }

    // Stops are destinations, not turns: a driver needs to know where to pull
    // over even when the road runs straight through.
    for (final stop in trip.stops) {
      if (stop.status == TripStopStatus.skipped) continue;
      steps.add(
        NavigationStep(
          maneuver: Maneuver.arriveStop,
          distanceAlongRouteMetres: stop.distanceAlongRouteMetres,
          location: path.pointAtDistance(stop.distanceAlongRouteMetres),
          stopId: stop.stopId,
        ),
      );
    }

    steps.add(
      NavigationStep(
        maneuver: Maneuver.arriveDestination,
        distanceAlongRouteMetres: total,
        location: path.pointAtDistance(total),
      ),
    );

    steps.sort(
      (a, b) => a.distanceAlongRouteMetres.compareTo(b.distanceAlongRouteMetres),
    );
    return steps;
  }

  /// Turn angle in degrees; negative is left, positive is right.
  static double _signedTurn(double from, double to) {
    var delta = (to - from) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    return delta;
  }

  static Maneuver _classify(double degrees) {
    final magnitude = degrees.abs();
    final right = degrees > 0;

    if (magnitude >= 150) return Maneuver.uTurn;
    if (magnitude >= 100) {
      return right ? Maneuver.sharpRight : Maneuver.sharpLeft;
    }
    if (magnitude >= 45) return right ? Maneuver.right : Maneuver.left;
    return right ? Maneuver.slightRight : Maneuver.slightLeft;
  }
}

/// Picks the instruction that applies at a given point along the route.
///
/// Pure and separate from the service so it can run every frame without
/// recomputing the step list, which changes only when the plan does.
ActiveGuidance? guidanceAt({
  required List<NavigationStep> steps,
  required double distanceAlongRouteMetres,
  double passedToleranceMetres = 15,
}) {
  if (steps.isEmpty) return null;

  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final remaining =
        step.distanceAlongRouteMetres - distanceAlongRouteMetres;

    // A manoeuvre stays current until it is comfortably behind the bus, so the
    // banner does not flicker to the next instruction while turning.
    if (remaining < -passedToleranceMetres) continue;

    return ActiveGuidance(
      current: step,
      metresToManeuver: math.max(remaining, 0),
      next: i + 1 < steps.length ? steps[i + 1] : null,
    );
  }

  return ActiveGuidance(
    current: steps.last,
    metresToManeuver: 0,
  );
}
