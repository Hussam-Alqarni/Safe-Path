import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_path/data/repositories/app_state.dart';
import 'package:safe_path/domain/models/geo.dart';

/// Where the bus should be drawn *this frame*.
class InterpolatedPosition {
  const InterpolatedPosition({
    required this.point,
    required this.bearing,
    required this.distanceAlongRoute,
    required this.isStale,
  });

  final LatLngPoint point;
  final double bearing;
  final double distanceAlongRoute;
  final bool isStale;
}

/// Turns ten-second position reports into sixty-frames-a-second motion.
///
/// A tracker reports every few seconds. Drawing each fix as it lands makes the
/// bus teleport, which reads as a broken app long before anyone questions the
/// data. Three things fix that, and all three matter:
///
///  * The marker advances **along the route geometry**, not in a straight line
///    between fixes, so it follows every bend of the street.
///  * Between fixes it keeps moving at the last reported speed, so motion is
///    continuous rather than a stutter every reporting interval.
///  * Once a tracker goes quiet past the stale threshold it **stops**. Dead
///    reckoning is a smoothing trick, not a source of truth, and a guardian
///    must never be shown a guess presented as a live position.
class BusPositionAnimator extends StatefulWidget {
  const BusPositionAnimator({
    required this.live,
    required this.path,
    required this.builder,
    this.maxExtrapolation = const Duration(seconds: 12),
    super.key,
  });

  final BusLiveState live;
  final RoutePath path;
  final Widget Function(BuildContext context, InterpolatedPosition position)
      builder;

  /// How far ahead of the last fix the marker may be projected. Beyond this the
  /// marker holds position even before the stale flag is set.
  final Duration maxExtrapolation;

  @override
  State<BusPositionAnimator> createState() => _BusPositionAnimatorState();
}

class _BusPositionAnimatorState extends State<BusPositionAnimator>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Where the marker is drawn now. Distinct from the reported distance so a
  /// new fix is eased into rather than snapped to.
  double _renderedDistance = 0;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    _renderedDistance = widget.live.distanceAlongRouteMetres;
    _initialised = true;
    _ticker = createTicker(_onTick);
    _syncTicker();
  }

  @override
  void didUpdateWidget(BusPositionAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A replanned route changes the distance scale entirely, so the rendered
    // position must be reclamped rather than carried across.
    if (widget.path != oldWidget.path) {
      _renderedDistance =
          _renderedDistance.clamp(0.0, widget.path.totalDistanceMetres);
    }
    _syncTicker();
  }

  /// Runs the ticker only while there is motion to draw.
  ///
  /// A sixty-frames-a-second ticker that never stops is a battery drain on the
  /// phone of a parent who leaves the screen open, and it keeps the framework
  /// scheduling frames forever — which also makes the screen untestable.
  void _syncTicker() {
    final shouldRun = !widget.live.isStale &&
        (widget.live.speedKmh > 0.5 ||
            (_projectedDistance() - _renderedDistance).abs() > 0.2);

    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (!mounted || !_initialised) return;
    setState(() {});
    _syncTicker();
  }

  /// The distance the bus has most likely reached by now.
  double _projectedDistance() {
    final live = widget.live;
    if (live.isStale) return live.distanceAlongRouteMetres;

    final sinceFix = DateTime.now().difference(live.updatedAt);
    final cappedSeconds = sinceFix.inMilliseconds
            .clamp(0, widget.maxExtrapolation.inMilliseconds) /
        1000;

    final metresPerSecond = live.speedKmh * 1000 / 3600;
    return (live.distanceAlongRouteMetres + metresPerSecond * cappedSeconds)
        .clamp(0.0, widget.path.totalDistanceMetres);
  }

  @override
  Widget build(BuildContext context) {
    final target = _projectedDistance();

    // Ease toward the target instead of jumping to it. When a fix lands a few
    // metres behind the projection, the marker settles rather than snapping
    // backwards — which is far more jarring than being slightly ahead.
    final delta = target - _renderedDistance;
    _renderedDistance += delta * 0.18;
    if (delta.abs() < 0.2) _renderedDistance = target;
    _renderedDistance =
        _renderedDistance.clamp(0.0, widget.path.totalDistanceMetres);

    return widget.builder(
      context,
      InterpolatedPosition(
        point: widget.path.pointAtDistance(_renderedDistance),
        bearing: widget.path.bearingAtDistance(_renderedDistance),
        distanceAlongRoute: _renderedDistance,
        isStale: widget.live.isStale,
      ),
    );
  }
}
