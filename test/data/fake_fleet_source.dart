import 'dart:async';

import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/domain/services/fleet_event_source.dart';

/// A fleet whose every event the test decides.
///
/// The real simulator runs on a timer, which makes assertions racy. This one
/// implements the same interface with no clock at all, so a test can place a
/// bus at an exact point on a route and assert on precisely what follows.
class FakeFleetSource implements FleetEventSource {
  final _controller = StreamController<FleetEvent>.broadcast();
  final startedTrips = <Trip>[];
  bool _running = false;

  @override
  Stream<FleetEvent> get events => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  bool get isSimulated => true;

  @override
  Future<void> start(List<Trip> trips) async {
    startedTrips
      ..clear()
      ..addAll(trips);
    _running = true;
  }

  @override
  Future<void> stop() async => _running = false;

  Future<void> dispose() async => _controller.close();

  /// Places the bus a given distance along its planned path.
  Future<void> moveTo({
    required Trip trip,
    required double distanceMetres,
    double speedKmh = 30,
    DateTime? at,
  }) async {
    final point = trip.path.pointAtDistance(distanceMetres);
    _controller.add(
      PositionReport(
        BusPing(
          busId: trip.busId,
          tripId: trip.id,
          position: point,
          speedKmh: speedKmh,
          heading: trip.path.bearingAtDistance(distanceMetres),
          recordedAt: at ?? DateTime.now(),
          distanceAlongRouteMetres: distanceMetres,
        ),
      ),
    );
    await _settle();
  }

  /// Presents a card to the in-vehicle reader.
  Future<void> scanCard({
    required Trip trip,
    required String cardUid,
    String? stopId,
    DateTime? at,
  }) async {
    _controller.add(
      CardScanReport(
        busId: trip.busId,
        tripId: trip.id,
        cardUid: cardUid,
        occurredAt: at ?? DateTime.now(),
        location: const LatLngPoint(21.54, 39.17),
        stopId: stopId,
      ),
    );
    await _settle();
  }

  Future<void> goSilent({required Trip trip, DateTime? at}) async {
    _controller.add(
      TrackerSilentReport(
        busId: trip.busId,
        tripId: trip.id,
        occurredAt: at ?? DateTime.now(),
        lastKnownAt: at ?? DateTime.now(),
      ),
    );
    await _settle();
  }

  /// Lets the broadcast stream deliver before the test asserts.
  ///
  /// A microtask, not a delayed future: widget tests run on a fake clock where
  /// `Future.delayed` never completes unless the test pumps, which would
  /// deadlock any caller that simply awaits an event.
  Future<void> _settle() => Future<void>.microtask(() {});
}
