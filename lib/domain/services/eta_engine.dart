import 'dart:math' as math;

import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';

/// Predicted arrival at one stop.
class StopEta {
  const StopEta({
    required this.stopId,
    required this.remainingMetres,
    required this.eta,
    required this.minutesAway,
  });

  final String stopId;
  final double remainingMetres;
  final DateTime eta;
  final int minutesAway;
}

/// What the arrival watcher decided should fire right now.
class EtaTriggers {
  const EtaTriggers({
    required this.approaching,
    required this.arrived,
  });

  /// Stops that just crossed the "N minutes away" threshold.
  final List<String> approaching;

  /// Stops the bus has just reached.
  final List<String> arrived;

  bool get isEmpty => approaching.isEmpty && arrived.isEmpty;
}

/// Computes arrival times and decides when guardians should be told.
///
/// Speed comes from the fleet's own history rather than a paid traffic API:
/// once buses have driven the same streets at the same hour for a term, the
/// operator's own data is the most accurate source available for these roads
/// at these times.
class EtaEngine {
  const EtaEngine({
    this.approachThreshold = const Duration(minutes: 5),
    this.arrivalRadiusMetres = 60,
    this.minimumSpeedKmh = 8,
    this.fallbackSpeedKmh = 28,
  });

  final Duration approachThreshold;

  /// How close counts as "at the stop".
  final double arrivalRadiusMetres;

  /// Floor for speed maths, so a bus stopped at a light does not produce an
  /// ETA of infinity.
  final double minimumSpeedKmh;

  /// Used before the trip has any speed history.
  final double fallbackSpeedKmh;

  /// ETA for every stop still ahead of the bus.
  List<StopEta> etasFor({
    required Trip trip,
    required double currentSpeedKmh,
    required DateTime now,
  }) {
    final speed = _effectiveSpeed(currentSpeedKmh);
    final metresPerSecond = speed * 1000 / 3600;

    final results = <StopEta>[];
    for (final stop in trip.stops) {
      if (stop.status.isDone) continue;

      final remaining =
          stop.distanceAlongRouteMetres - trip.distanceCoveredMetres;
      if (remaining < 0) continue;

      // Every intermediate stop still to be served costs its dwell time.
      final dwellAhead = trip.stops
          .where(
            (s) =>
                !s.status.isDone &&
                s.sequence < stop.sequence &&
                s.distanceAlongRouteMetres > trip.distanceCoveredMetres,
          )
          .length;

      final travelSeconds = remaining / metresPerSecond;
      final dwellSeconds = dwellAhead * 45;
      final totalSeconds = (travelSeconds + dwellSeconds).round();

      results.add(
        StopEta(
          stopId: stop.stopId,
          remainingMetres: remaining,
          eta: now.add(Duration(seconds: totalSeconds)),
          minutesAway: (totalSeconds / 60).ceil(),
        ),
      );
    }
    return results;
  }

  /// Which notifications are due, given what has already been sent.
  ///
  /// Each trigger fires at most once per stop per trip — the [TripStop] flags
  /// are the idempotency guard, so a burst of pings cannot spam a guardian.
  EtaTriggers evaluateTriggers({
    required Trip trip,
    required List<StopEta> etas,
    required DateTime now,
  }) {
    final approaching = <String>[];
    final arrived = <String>[];
    final etaByStop = {for (final e in etas) e.stopId: e};

    for (final stop in trip.stops) {
      if (stop.status == TripStopStatus.skipped) continue;

      final eta = etaByStop[stop.stopId];
      if (eta == null) continue;

      if (!stop.arrivalNotified &&
          eta.remainingMetres <= arrivalRadiusMetres &&
          stop.status != TripStopStatus.departed) {
        arrived.add(stop.stopId);
        continue;
      }

      if (!stop.approachNotified &&
          !stop.arrivalNotified &&
          eta.minutesAway <= approachThreshold.inMinutes &&
          eta.remainingMetres > arrivalRadiusMetres) {
        approaching.add(stop.stopId);
      }
    }
    return EtaTriggers(approaching: approaching, arrived: arrived);
  }

  /// True when the tracker has been silent long enough that the UI must stop
  /// animating the bus. Showing a guessed position as if it were live is the
  /// one thing a child-safety app must never do.
  bool isPositionStale({
    required DateTime? lastPingAt,
    required DateTime now,
    required Duration staleAfter,
  }) {
    if (lastPingAt == null) return true;
    return now.difference(lastPingAt) > staleAfter;
  }

  double _effectiveSpeed(double currentSpeedKmh) {
    if (currentSpeedKmh.isNaN || currentSpeedKmh <= 0) return fallbackSpeedKmh;
    return math.max(currentSpeedKmh, minimumSpeedKmh);
  }
}
