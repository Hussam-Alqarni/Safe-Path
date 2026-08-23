import 'dart:async';
import 'dart:math' as math;

import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/services/fleet_event_source.dart';

/// Deterministic fleet simulator.
///
/// Drives each trip along its planned path at a speed that varies the way city
/// traffic does, dwells at stops, and emits card scans as students board. Seeded
/// so a demo repeats identically — a pitch that behaves differently on the
/// second run is worse than no pitch.
class SimulatedFleet implements FleetEventSource {
  SimulatedFleet({
    required this.tickInterval,
    this.timeScale = 12,
    int seed = 20260901,
  }) : _random = math.Random(seed);

  /// Wall-clock interval between position reports.
  final Duration tickInterval;

  /// How many simulated seconds pass per real second. A morning run covering
  /// 12 km is a 25-minute drive; at 12x it demonstrates in about two minutes.
  final double timeScale;

  final math.Random _random;
  final _controller = StreamController<FleetEvent>.broadcast();
  final _vehicles = <String, _SimulatedVehicle>{};

  Timer? _timer;
  bool _running = false;

  /// When set, this bus stops reporting — used to demonstrate how the app
  /// behaves when a tracker goes quiet rather than claiming it is still moving.
  String? _silencedBusId;

  /// Students the simulator will deliberately not scan off, to demonstrate
  /// left-on-bus detection.
  final _studentsToLeaveOnBoard = <String>{};

  /// Students the simulator will not board at all.
  final _studentsToSkipBoarding = <String>{};

  @override
  Stream<FleetEvent> get events => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(List<Trip> trips) async {
    await stop();
    _vehicles.clear();
    for (final trip in trips) {
      if (trip.status == TripStatus.completed) continue;
      _vehicles[trip.busId] = _SimulatedVehicle(trip: trip);
    }
    _running = true;
    _timer = Timer.periodic(tickInterval, (_) => _tick());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  /// Replaces a vehicle's plan after the trip has been replanned mid-run,
  /// preserving how far the bus has already travelled.
  void updateTrip(Trip trip) {
    final vehicle = _vehicles[trip.busId];
    if (vehicle == null) {
      _vehicles[trip.busId] = _SimulatedVehicle(trip: trip);
      return;
    }
    vehicle.trip = trip;
    vehicle.distance = math.min(
      vehicle.distance,
      trip.path.totalDistanceMetres,
    );
  }

  void silenceTracker(String busId) => _silencedBusId = busId;
  void restoreTracker() => _silencedBusId = null;

  void leaveStudentOnBoard(String studentId) =>
      _studentsToLeaveOnBoard.add(studentId);

  void skipBoardingFor(String studentId) =>
      _studentsToSkipBoarding.add(studentId);

  void clearScenarios() {
    _studentsToLeaveOnBoard.clear();
    _studentsToSkipBoarding.clear();
    _silencedBusId = null;
  }

  bool willLeaveOnBoard(String studentId) =>
      _studentsToLeaveOnBoard.contains(studentId);

  bool willSkipBoarding(String studentId) =>
      _studentsToSkipBoarding.contains(studentId);

  void _tick() {
    final now = DateTime.now();
    final elapsedSeconds = tickInterval.inMilliseconds / 1000 * timeScale;

    for (final vehicle in _vehicles.values) {
      if (vehicle.trip.status != TripStatus.inProgress) continue;

      if (vehicle.trip.busId == _silencedBusId) {
        _controller.add(
          TrackerSilentReport(
            busId: vehicle.trip.busId,
            tripId: vehicle.trip.id,
            occurredAt: now,
            lastKnownAt: vehicle.lastReportedAt ?? now,
          ),
        );
        continue;
      }

      _advance(vehicle, elapsedSeconds, now);
    }
  }

  void _advance(
    _SimulatedVehicle vehicle,
    double elapsedSeconds,
    DateTime now,
  ) {
    final trip = vehicle.trip;
    final path = trip.path;

    if (vehicle.dwellRemaining > 0) {
      vehicle.dwellRemaining -= elapsedSeconds;
      vehicle.speedKmh = 0;
      _emitPosition(vehicle, now);
      return;
    }

    // Traffic model: a base speed modulated by a slow wave plus a little
    // noise, so the marker never moves at an implausibly constant rate.
    final wave = math.sin(vehicle.distance / 420);
    final noise = (_random.nextDouble() - 0.5) * 6;
    vehicle.speedKmh = (30 + wave * 9 + noise).clamp(9.0, 52.0);

    final metresPerSecond = vehicle.speedKmh * 1000 / 3600;
    final nextDistance = math.min(
      vehicle.distance + metresPerSecond * elapsedSeconds,
      path.totalDistanceMetres,
    );

    _checkStopsCrossed(vehicle, vehicle.distance, nextDistance, now);
    vehicle.distance = nextDistance;
    _emitPosition(vehicle, now);
  }

  /// Fires a dwell and the matching card scans for any stop the bus passed
  /// during this tick. Checking the interval rather than the instant means a
  /// long tick can never skip a stop.
  void _checkStopsCrossed(
    _SimulatedVehicle vehicle,
    double from,
    double to,
    DateTime now,
  ) {
    for (final stop in vehicle.trip.stops) {
      if (stop.status == TripStopStatus.skipped) continue;
      if (vehicle.servedStopIds.contains(stop.stopId)) continue;

      final target = stop.distanceAlongRouteMetres;
      final crossed = target >= from && target <= to;
      final startingOnIt = from == 0 && target <= 1;
      if (!crossed && !startingOnIt) continue;

      vehicle.servedStopIds.add(stop.stopId);
      vehicle.dwellRemaining = 40;
      vehicle.pendingScans.addAll(
        stop.expectedStudentIds.map(
          (studentId) => _PendingScan(studentId, stop.stopId),
        ),
      );
      _flushScans(vehicle, now);
      return;
    }
  }

  void _flushScans(_SimulatedVehicle vehicle, DateTime now) {
    final position = vehicle.trip.path.pointAtDistance(vehicle.distance);
    for (final scan in vehicle.pendingScans) {
      if (_studentsToSkipBoarding.contains(scan.studentId)) continue;
      _controller.add(
        CardScanReport(
          busId: vehicle.trip.busId,
          tripId: vehicle.trip.id,
          // The device reports a card, not a student. Resolution happens above.
          cardUid: _cardUidFor(scan.studentId),
          occurredAt: now,
          location: position,
          stopId: scan.stopId,
        ),
      );
    }
    vehicle.pendingScans.clear();
  }

  /// Mirrors the UID scheme in the seed data.
  String _cardUidFor(String studentId) {
    final digits = studentId.replaceAll(RegExp('[^0-9]'), '');
    return 'SA${digits.padLeft(6, '0')}';
  }

  void _emitPosition(_SimulatedVehicle vehicle, DateTime now) {
    final path = vehicle.trip.path;
    final position = path.pointAtDistance(vehicle.distance);
    vehicle.lastReportedAt = now;

    _controller.add(
      PositionReport(
        BusPing(
          busId: vehicle.trip.busId,
          tripId: vehicle.trip.id,
          position: position,
          speedKmh: vehicle.speedKmh,
          heading: path.bearingAtDistance(vehicle.distance),
          recordedAt: now,
          distanceAlongRouteMetres: vehicle.distance,
        ),
      ),
    );
  }
}

class _SimulatedVehicle {
  _SimulatedVehicle({required this.trip});

  Trip trip;
  double distance = 0;
  double speedKmh = 0;
  double dwellRemaining = 0;
  DateTime? lastReportedAt;
  final Set<String> servedStopIds = {};
  final List<_PendingScan> pendingScans = [];
}

class _PendingScan {
  const _PendingScan(this.studentId, this.stopId);
  final String studentId;
  final String stopId;
}
