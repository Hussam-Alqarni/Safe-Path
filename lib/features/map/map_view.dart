import 'package:flutter/material.dart';
import 'package:safe_path/core/config/app_config.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/domain/models/entities.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/features/map/bus_position_animator.dart';
import 'package:safe_path/features/map/google_trip_map.dart';
import 'package:safe_path/features/map/schematic_map.dart';

/// The one place the app talks to a map.
///
/// Every screen renders through this widget, so swapping providers — or
/// falling back to the built-in renderer when no key is configured — is a
/// change here and nowhere else.
class TripMapView extends StatelessWidget {
  const TripMapView({
    required this.renderer,
    required this.trip,
    required this.stopsById,
    required this.school,
    this.live,
    this.homes = const [],
    this.height = 280,
    this.followBus = false,
    this.showTraffic = false,
    this.tiltedFollow = false,
    super.key,
  });

  final MapRenderer renderer;
  final Trip trip;
  final Map<String, BusStop> stopsById;
  final LatLngPoint school;

  /// Null before the trip starts — the route is drawn, but no bus.
  final InterpolatedPosition? live;

  final List<LatLngPoint> homes;
  final double height;
  final bool followBus;
  final bool showTraffic;
  final bool tiltedFollow;

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
            MapRenderer.google => GoogleTripMap(
                trip: trip,
                stopsById: stopsById,
                school: school,
                live: live,
                homes: homes,
                followBus: followBus,
                showTraffic: showTraffic,
                tiltedFollow: tiltedFollow,
              ),
            MapRenderer.schematic => SchematicMap(
                path: trip.path,
                stops: trip.stops,
                stopsById: stopsById,
                school: school,
                busPosition: live,
                homes: homes,
              ),
          },
        ),
      ),
    );
  }
}
