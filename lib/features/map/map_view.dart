import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/domain/enums.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/schematic_map.dart';

/// The one place the app talks to a map.
///
/// Every screen renders through this widget, so swapping Google Maps for
/// another provider — or for the built-in renderer when no key is configured —
/// is a change here and nowhere else.
class TripMapView extends StatelessWidget {
  const TripMapView({
    required this.renderer,
    required this.trip,
    required this.stopsById,
    required this.school,
    this.live,
    this.height = 280,
    super.key,
  });

  final MapRenderer renderer;
  final Trip trip;
  final Map<String, BusStop> stopsById;
  final LatLngPoint school;

  /// Null before the trip starts — the route is drawn, but no bus.
  final InterpolatedPosition? live;

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: c.line)),
          child: switch (renderer) {
            MapRenderer.google => _GoogleTripMap(
                trip: trip,
                stopsById: stopsById,
                school: school,
                live: live,
              ),
            MapRenderer.schematic => SchematicMap(
                path: trip.path,
                stops: trip.stops,
                stopsById: stopsById,
                school: school,
                busPosition: live,
              ),
          },
        ),
      ),
    );
  }
}

/// Google Maps rendering of the same trip.
///
/// The bus marker is positioned from the interpolated value rather than the
/// raw fix, so it glides here exactly as it does in the built-in renderer.
class _GoogleTripMap extends StatefulWidget {
  const _GoogleTripMap({
    required this.trip,
    required this.stopsById,
    required this.school,
    required this.live,
  });

  final Trip trip;
  final Map<String, BusStop> stopsById;
  final LatLngPoint school;
  final InterpolatedPosition? live;

  @override
  State<_GoogleTripMap> createState() => _GoogleTripMapState();
}

class _GoogleTripMapState extends State<_GoogleTripMap> {
  gmaps.GoogleMapController? _controller;

  static gmaps.LatLng _toGoogle(LatLngPoint p) =>
      gmaps.LatLng(p.latitude, p.longitude);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final points = widget.trip.path.points.map(_toGoogle).toList();

    final travelled = widget.live?.distanceAlongRoute ?? 0;
    final remaining = widget.trip.path.sliceFrom(travelled);

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _toGoogle(widget.school),
        zoom: 12.5,
      ),
      onMapCreated: (controller) {
        _controller = controller;
        _fitToRoute(points);
      },
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      polylines: {
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route-done'),
          points: points,
          width: 5,
          color: c.routeLineDone,
        ),
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route-remaining'),
          points: remaining.points.map(_toGoogle).toList(),
          width: 6,
          color: c.routeLine,
        ),
      },
      markers: _buildMarkers(),
    );
  }

  Set<gmaps.Marker> _buildMarkers() {
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('school'),
        position: _toGoogle(widget.school),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueCyan,
        ),
      ),
    };

    for (final stop in widget.trip.stops) {
      final location = widget.stopsById[stop.stopId]?.location;
      if (location == null) continue;
      // A skipped stop keeps its marker, greyed: the plan must still show it
      // was scheduled and dropped.
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('stop-${stop.stopId}'),
          position: _toGoogle(location),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            switch (stop.status) {
              TripStopStatus.skipped => gmaps.BitmapDescriptor.hueViolet,
              TripStopStatus.departed => gmaps.BitmapDescriptor.hueGreen,
              _ => gmaps.BitmapDescriptor.hueAzure,
            },
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
          rotation: live.bearing,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          alpha: live.isStale ? 0.45 : 1,
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }
    return markers;
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
