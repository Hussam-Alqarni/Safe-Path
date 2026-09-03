import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/map_markers.dart';

/// Google Maps rendering of a trip.
///
/// The bus is positioned from the interpolated value rather than the raw fix,
/// so it glides here exactly as it does in the built-in renderer — the
/// smoothing belongs to the app, not to whichever map is drawing.
class GoogleTripMap extends StatefulWidget {
  const GoogleTripMap({
    required this.trip,
    required this.stopsById,
    required this.school,
    this.live,
    this.homes = const [],
    this.followBus = false,
    this.showTraffic = false,
    this.tiltedFollow = false,
    super.key,
  });

  final Trip trip;
  final Map<String, BusStop> stopsById;
  final LatLngPoint school;
  final InterpolatedPosition? live;

  /// Student homes to plot, so an administrator can see how a stop relates to
  /// the doors it serves.
  final List<LatLngPoint> homes;

  /// Keeps the camera on the bus. Used by the driver, never forced on a
  /// guardian who may be panning around.
  final bool followBus;

  final bool showTraffic;

  /// Driving view: tilted and rotated to the direction of travel.
  final bool tiltedFollow;

  @override
  State<GoogleTripMap> createState() => _GoogleTripMapState();
}

class _GoogleTripMapState extends State<GoogleTripMap> {
  gmaps.GoogleMapController? _controller;
  MapMarkerFactory? _markers;
  Map<String, gmaps.BitmapDescriptor> _icons = {};
  bool _iconsReady = false;

  /// True once the user has moved the camera themselves. Auto-follow yields to
  /// it — a map that fights the person holding it is worse than one that
  /// never moved.
  bool _userMovedCamera = false;
  DateTime _lastFollow = DateTime.fromMillisecondsSinceEpoch(0);

  static gmaps.LatLng _toGoogle(LatLngPoint p) =>
      gmaps.LatLng(p.latitude, p.longitude);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIcons();
  }

  @override
  void didUpdateWidget(GoogleTripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followBus && !oldWidget.followBus) _userMovedCamera = false;
    unawaited(_followBusIfNeeded());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    final media = MediaQuery.maybeOf(context);
    final ratio = media?.devicePixelRatio ?? 2.0;
    final palette = context.colors;

    final factory = _markers ??= MapMarkerFactory(devicePixelRatio: ratio);

    final icons = <String, gmaps.BitmapDescriptor>{
      'bus': await factory.bus(color: palette.onBus, stale: false),
      'bus-stale': await factory.bus(color: palette.absent, stale: true),
      'school': await factory.school(color: palette.atSchool),
      'home': await factory.home(color: palette.brandMuted),
      'stop-pending':
          await factory.stop(color: palette.brand, filled: false, struck: false),
      'stop-done':
          await factory.stop(color: palette.delivered, filled: true, struck: false),
      'stop-skipped':
          await factory.stop(color: palette.absent, filled: false, struck: true),
    };

    if (!mounted) return;
    setState(() {
      _icons = icons;
      _iconsReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final travelled = widget.live?.distanceAlongRoute ?? 0;
    final full = widget.trip.path.points.map(_toGoogle).toList();
    final remaining =
        widget.trip.path.sliceFrom(travelled).points.map(_toGoogle).toList();

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _toGoogle(widget.live?.point ?? widget.school),
        zoom: 13,
      ),
      style: isDark ? darkMapStyle : lightMapStyle,
      onMapCreated: (controller) {
        _controller = controller;
        unawaited(_fitToRoute(full));
      },
      onCameraMoveStarted: () => _userMovedCamera = true,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      trafficEnabled: widget.showTraffic,
      polylines: {
        // The whole plan in a muted colour, with the part still to drive laid
        // over it — so progress reads without a legend.
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route-plan'),
          points: full,
          width: 7,
          color: palette.routeLineDone,
          startCap: gmaps.Cap.roundCap,
          endCap: gmaps.Cap.roundCap,
          jointType: gmaps.JointType.round,
        ),
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route-remaining'),
          points: remaining,
          width: 7,
          color: palette.routeLine,
          startCap: gmaps.Cap.roundCap,
          endCap: gmaps.Cap.roundCap,
          jointType: gmaps.JointType.round,
        ),
      },
      markers: _iconsReady ? _buildMarkers() : const {},
    );
  }

  Set<gmaps.Marker> _buildMarkers() {
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('school'),
        position: _toGoogle(widget.school),
        icon: _icons['school']!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      ),
    };

    for (var i = 0; i < widget.homes.length; i++) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('home-$i'),
          position: _toGoogle(widget.homes[i]),
          icon: _icons['home']!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
        ),
      );
    }

    for (final stop in widget.trip.stops) {
      final location = widget.stopsById[stop.stopId]?.location;
      if (location == null) continue;

      final key = switch (stop.status) {
        TripStopStatus.skipped => 'stop-skipped',
        TripStopStatus.departed => 'stop-done',
        _ => 'stop-pending',
      };
      final busStop = widget.stopsById[stop.stopId];

      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('stop-${stop.stopId}'),
          position: _toGoogle(location),
          icon: _icons[key]!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 3,
          infoWindow: gmaps.InfoWindow(
            title: busStop?.nameAr ?? stop.stopId,
            snippet: '${stop.expectedStudentIds.length}',
          ),
        ),
      );
    }

    final live = widget.live;
    if (live != null) {
      markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('bus'),
          position: _toGoogle(live.point),
          // Google rotates the bitmap, so one cached icon serves every
          // heading. In the driving view the camera turns instead, and the
          // marker stays pointing up the screen.
          rotation: widget.tiltedFollow ? 0 : live.bearing,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
          icon: live.isStale ? _icons['bus-stale']! : _icons['bus']!,
        ),
      );
    }
    return markers;
  }

  /// Keeps the bus in view without stealing the map from the person holding it.
  Future<void> _followBusIfNeeded() async {
    if (!widget.followBus || _userMovedCamera) return;
    final live = widget.live;
    final controller = _controller;
    if (live == null || controller == null) return;

    // The animator ticks every frame; moving the camera that often would fight
    // Google's own easing and burn battery for no visible gain.
    final now = DateTime.now();
    if (now.difference(_lastFollow) < const Duration(milliseconds: 700)) return;
    _lastFollow = now;

    await controller.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: _toGoogle(live.point),
          zoom: widget.tiltedFollow ? 17.5 : 15.5,
          tilt: widget.tiltedFollow ? 55 : 0,
          bearing: widget.tiltedFollow ? live.bearing : 0,
        ),
      ),
    );
  }

  Future<void> _fitToRoute(List<gmaps.LatLng> points) async {
    final controller = _controller;
    if (controller == null || points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    await controller.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(
        gmaps.LatLngBounds(
          southwest: gmaps.LatLng(minLat, minLng),
          northeast: gmaps.LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }
}
