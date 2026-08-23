import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';

/// Anything a vehicle reports.
///
/// Position reports and card scans arrive on one stream because that is how the
/// hardware actually behaves: the in-vehicle tracker reads the RFID module and
/// relays taps over the same link as GPS. Modelling them separately would
/// invent a split the real device does not have.
sealed class FleetEvent {
  const FleetEvent();

  String get busId;
  DateTime get occurredAt;
}

/// A GPS fix, already snapped to the trip's planned path.
class PositionReport extends FleetEvent {
  const PositionReport(this.ping);

  final BusPing ping;

  @override
  String get busId => ping.busId;

  @override
  DateTime get occurredAt => ping.recordedAt;
}

/// A card presented to the reader inside the bus.
///
/// The device reports a card UID and nothing more — resolving it to a student,
/// and deciding whether this tap means boarding or alighting, is the server's
/// job. Keeping that logic off the device is what lets a lost card be reissued
/// without touching hardware.
class CardScanReport extends FleetEvent {
  const CardScanReport({
    required this.busId,
    required this.tripId,
    required this.cardUid,
    required this.occurredAt,
    required this.location,
    this.stopId,
  });

  @override
  final String busId;

  final String tripId;
  final String cardUid;

  @override
  final DateTime occurredAt;

  final LatLngPoint location;
  final String? stopId;
}

/// The tracker has stopped reporting.
class TrackerSilentReport extends FleetEvent {
  const TrackerSilentReport({
    required this.busId,
    required this.tripId,
    required this.occurredAt,
    required this.lastKnownAt,
  });

  @override
  final String busId;

  final String tripId;

  @override
  final DateTime occurredAt;

  final DateTime lastKnownAt;
}

/// Where fleet telemetry comes from.
///
/// The simulator and the production ingest pipeline implement this identically,
/// so the entire app above this line is unaware of which one is running. That
/// is what makes the demo build the same code path as the pilot.
abstract class FleetEventSource {
  Stream<FleetEvent> get events;

  /// Begins reporting for the given trips.
  Future<void> start(List<Trip> trips);

  /// Stops reporting and releases resources.
  Future<void> stop();

  bool get isRunning;
}
