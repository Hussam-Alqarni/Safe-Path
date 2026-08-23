import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// Produces a road-following path through an ordered list of coordinates.
///
/// Kept behind an interface so the engine can be swapped — a bundled
/// approximation for demos and tests, a self-hosted OSRM instance or a
/// commercial routing API in production — without touching any caller.
abstract class RoutingService {
  Future<RoutePath> buildPath(List<LatLngPoint> waypoints);
}

/// Deterministic offline router.
///
/// Interpolates between waypoints with a slight lateral offset so the drawn
/// line reads as a street rather than a ruler. Good enough to demonstrate and
/// to test against; replaced wholesale in production.
class LocalGeometryRoutingService implements RoutingService {
  const LocalGeometryRoutingService({this.pointsPerLeg = 14});

  final int pointsPerLeg;

  @override
  Future<RoutePath> buildPath(List<LatLngPoint> waypoints) async {
    if (waypoints.length < 2) {
      throw ArgumentError('A path needs at least two waypoints');
    }

    final points = <LatLngPoint>[waypoints.first];
    for (var leg = 0; leg < waypoints.length - 1; leg++) {
      final from = waypoints[leg];
      final to = waypoints[leg + 1];

      // A dog-leg through an intermediate corner approximates a grid of
      // streets far better than a straight diagonal.
      final corner = LatLngPoint(from.latitude, to.longitude);
      _appendLeg(points, from, corner, pointsPerLeg ~/ 2);
      _appendLeg(points, corner, to, pointsPerLeg ~/ 2);
    }
    return RoutePath(points);
  }

  void _appendLeg(
    List<LatLngPoint> into,
    LatLngPoint from,
    LatLngPoint to,
    int steps,
  ) {
    for (var i = 1; i <= steps; i++) {
      into.add(from.lerp(to, i / steps));
    }
  }
}

/// Builds trips and rebuilds them when the plan changes mid-run.
class RoutePlanner {
  const RoutePlanner(this.routingService);

  final RoutingService routingService;

  /// Builds today's trip from a route, dropping stops where every assigned
  /// student is absent.
  ///
  /// This runs before departure, not in the middle of a drive: guardians
  /// declare absences the night before or early morning, so the optimisation
  /// is a scheduled job, never a real-time scramble.
  Future<Trip> buildTrip({
    required String tripId,
    required BusRoute route,
    required Map<String, BusStop> stopsById,
    required List<Student> students,
    required List<AbsenceRecord> absences,
    required LatLngPoint schoolLocation,
    required DateTime serviceDate,
  }) async {
    final absentStudentIds = absences
        .where((a) => a.appliesTo(route.direction))
        .map((a) => a.studentId)
        .toSet();

    final studentsByStop = <String, List<String>>{};
    for (final student in students) {
      final stopId = student.stopId;
      if (stopId == null || !student.usesBus) continue;
      if (absentStudentIds.contains(student.id)) continue;
      studentsByStop.putIfAbsent(stopId, () => []).add(student.id);
    }

    final tripStops = <TripStop>[];
    for (var i = 0; i < route.orderedStopIds.length; i++) {
      final stopId = route.orderedStopIds[i];
      final expected = studentsByStop[stopId] ?? const <String>[];
      final skipped = expected.isEmpty;

      tripStops.add(
        TripStop(
          stopId: stopId,
          sequence: i,
          status: skipped ? TripStopStatus.skipped : TripStopStatus.pending,
          expectedStudentIds: expected,
          skipReason: skipped ? 'allStudentsAbsent' : null,
        ),
      );
    }

    final path = await _buildPathFor(
      tripStops: tripStops,
      stopsById: stopsById,
      schoolLocation: schoolLocation,
      direction: route.direction,
    );

    return Trip(
      id: tripId,
      schoolId: route.schoolId,
      routeId: route.id,
      busId: route.busId,
      driverId: route.driverId,
      direction: route.direction,
      serviceDate: serviceDate,
      status: TripStatus.scheduled,
      stops: _withDistances(tripStops, stopsById, path),
      path: path,
    );
  }

  /// Skips a stop on a trip already under way and redraws what remains.
  ///
  /// Only the remaining geometry is recomputed — for a dozen stops that is a
  /// few milliseconds locally, so there is no reason to batch or defer it.
  Future<Trip> skipStop({
    required Trip trip,
    required String stopId,
    required Map<String, BusStop> stopsById,
    required LatLngPoint schoolLocation,
    required String reason,
  }) async {
    final updatedStops = trip.stops.map((stop) {
      if (stop.stopId != stopId) return stop;
      if (stop.status.isDone) return stop;
      // The stop is marked, never removed: the record must still show that it
      // was planned, and why it was dropped.
      return stop.copyWith(
        status: TripStopStatus.skipped,
        skipReason: reason,
      );
    }).toList();

    final path = await _buildPathFor(
      tripStops: updatedStops,
      stopsById: stopsById,
      schoolLocation: schoolLocation,
      direction: trip.direction,
    );

    return trip.copyWith(
      stops: _withDistances(updatedStops, stopsById, path),
      path: path,
    );
  }

  /// Re-includes a stop that was skipped — a guardian cancelling an absence.
  Future<Trip> restoreStop({
    required Trip trip,
    required String stopId,
    required List<String> studentIds,
    required Map<String, BusStop> stopsById,
    required LatLngPoint schoolLocation,
  }) async {
    final updatedStops = trip.stops.map((stop) {
      if (stop.stopId != stopId) return stop;
      return TripStop(
        stopId: stop.stopId,
        sequence: stop.sequence,
        status: TripStopStatus.pending,
        expectedStudentIds: studentIds,
        distanceAlongRouteMetres: stop.distanceAlongRouteMetres,
      );
    }).toList();

    final path = await _buildPathFor(
      tripStops: updatedStops,
      stopsById: stopsById,
      schoolLocation: schoolLocation,
      direction: trip.direction,
    );

    return trip.copyWith(
      stops: _withDistances(updatedStops, stopsById, path),
      path: path,
    );
  }

  Future<RoutePath> _buildPathFor({
    required List<TripStop> tripStops,
    required Map<String, BusStop> stopsById,
    required LatLngPoint schoolLocation,
    required TripDirection direction,
  }) {
    final servedPoints = tripStops
        .where((s) => s.status != TripStopStatus.skipped)
        .map((s) => stopsById[s.stopId]?.location)
        .whereType<LatLngPoint>()
        .toList();

    final waypoints = direction == TripDirection.toSchool
        ? [...servedPoints, schoolLocation]
        : [schoolLocation, ...servedPoints];

    if (waypoints.length < 2) {
      // Every stop skipped: a degenerate but legal plan — the bus still drives
      // to school so the trip can be closed out cleanly.
      return routingService.buildPath([schoolLocation, schoolLocation]);
    }
    return routingService.buildPath(waypoints);
  }

  /// Pins each served stop to its distance along the freshly drawn path, which
  /// is what ETA and the approach trigger measure against.
  List<TripStop> _withDistances(
    List<TripStop> tripStops,
    Map<String, BusStop> stopsById,
    RoutePath path,
  ) {
    return tripStops.map((stop) {
      if (stop.status == TripStopStatus.skipped) return stop;
      final location = stopsById[stop.stopId]?.location;
      if (location == null) return stop;
      return stop.copyWith(
        distanceAlongRouteMetres: path.distanceAlongForNearest(location),
      );
    }).toList();
  }
}
