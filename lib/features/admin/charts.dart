import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:safe_path/core/theme/app_colors.dart';
import 'package:safe_path/core/theme/app_theme.dart';

/// One point on a trend line.
class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.value,
    this.caption,
  });

  /// Short axis label, e.g. a weekday.
  final String label;

  /// 0–1 for a rate, or any absolute number.
  final double value;

  /// Extra line for the tooltip, e.g. "24 of 28".
  final String? caption;
}

/// A single-series trend.
///
/// One series, so no legend: the title names it, and a legend box for one
/// colour is furniture. Values are labelled selectively — the latest point
/// always, the rest on touch — because a number on every point is noise a
/// reader has to filter before they can see the shape.
class TrendChart extends StatefulWidget {
  const TrendChart({
    required this.points,
    this.formatValue,
    this.height = 180,
    this.referenceValue,
    this.referenceLabel,
    super.key,
  });

  final List<TrendPoint> points;
  final String Function(double value)? formatValue;
  final double height;

  /// An optional target line, drawn recessive behind the data.
  final double? referenceValue;
  final String? referenceLabel;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  int? _touched;

  String _format(double v) =>
      widget.formatValue?.call(v) ?? v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    if (widget.points.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('—', style: text.bodySmall),
        ),
      );
    }

    return Semantics(
      // The series read out as values, so the chart is not a blank rectangle
      // to anyone using a screen reader. This is the table view the chart
      // itself cannot be.
      label:
          widget.points.map((p) => '${p.label} ${_format(p.value)}').join(', '),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _updateTouch(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) =>
                _updateTouch(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => setState(() => _touched = null),
            onTapUp: (_) => setState(() => _touched = null),
            onTapCancel: () => setState(() => _touched = null),
            child: SizedBox(
              height: widget.height,
              width: width,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TrendPainter(
                        points: widget.points,
                        accent: c.chartAccent,
                        grid: c.chartGrid,
                        surface: c.surface,
                        labelColor: c.inkMuted,
                        touched: _touched,
                        referenceValue: widget.referenceValue,
                        textStyle: text.labelSmall!.copyWith(color: c.inkMuted),
                        valueStyle: text.labelMedium!.copyWith(color: c.ink),
                        format: _format,
                      ),
                    ),
                  ),
                  if (_touched != null)
                    _Tooltip(
                      point: widget.points[_touched!],
                      value: _format(widget.points[_touched!].value),
                      alignment: _touched! > widget.points.length / 2
                          ? Alignment.topLeft
                          : Alignment.topRight,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _updateTouch(double dx, double width) {
    final span = width / (widget.points.length - 1);
    final index = (dx / span).round().clamp(0, widget.points.length - 1);
    if (index != _touched) setState(() => _touched = index);
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.accent,
    required this.grid,
    required this.surface,
    required this.labelColor,
    required this.touched,
    required this.referenceValue,
    required this.textStyle,
    required this.valueStyle,
    required this.format,
  });

  final List<TrendPoint> points;
  final Color accent;
  final Color grid;
  final Color surface;
  final Color labelColor;
  final int? touched;
  final double? referenceValue;
  final TextStyle textStyle;
  final TextStyle valueStyle;
  final String Function(double) format;

  static const _labelBand = 22.0;
  static const _topPadding = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plotHeight = size.height - _labelBand - _topPadding;
    if (plotHeight <= 0) return;

    final values = points.map((p) => p.value).toList();
    final maxValue = math.max(values.reduce(math.max), referenceValue ?? 0);
    final minValue = math.min(values.reduce(math.min), 0.0);
    final span = (maxValue - minValue) == 0 ? 1.0 : maxValue - minValue;

    double y(double value) =>
        _topPadding + plotHeight * (1 - (value - minValue) / span);
    double x(int i) => size.width * i / (points.length - 1);

    // Grid: three lines, recessive. Enough to read a level, not enough to
    // compete with the data.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final gy = _topPadding + plotHeight * i / 2;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
    }

    if (referenceValue != null) {
      final ry = y(referenceValue!);
      final dashPaint = Paint()
        ..color = labelColor.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, ry), Offset(dx + 4, ry), dashPaint);
      }
    }

    final linePath = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(x(i), y(values[i]));
    }

    final areaPath = Path.from(linePath)
      ..lineTo(x(points.length - 1), _topPadding + plotHeight)
      ..lineTo(x(0), _topPadding + plotHeight)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.02),
          ],
        ).createShader(
          Rect.fromLTWH(0, _topPadding, size.width, plotHeight),
        ),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );

    // The latest point is emphasised: it is the one an operator is looking
    // for, and it anchors the line to "now".
    final lastIndex = points.length - 1;
    _drawMarker(canvas, Offset(x(lastIndex), y(values[lastIndex])));

    if (touched != null) {
      final tx = x(touched!);
      canvas.drawLine(
        Offset(tx, _topPadding),
        Offset(tx, _topPadding + plotHeight),
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
      _drawMarker(canvas, Offset(tx, y(values[touched!])));
    }

    _drawAxisLabels(canvas, size, x);
    _drawLatestValue(canvas, size, x(lastIndex), y(values[lastIndex]));
  }

  /// A surface ring keeps the marker readable where it overlaps the line.
  void _drawMarker(Canvas canvas, Offset centre) {
    canvas.drawCircle(centre, 5.5, Paint()..color = surface);
    canvas.drawCircle(centre, 4, Paint()..color = accent);
  }

  void _drawAxisLabels(Canvas canvas, Size size, double Function(int) x) {
    // First, last, and the middle: more than three labels on a small chart
    // collide before they inform.
    final indices = {0, points.length ~/ 2, points.length - 1};
    for (final i in indices) {
      final painter = TextPainter(
        text: TextSpan(text: points[i].label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      var dx = x(i) - painter.width / 2;
      dx = dx.clamp(0, size.width - painter.width);
      painter.paint(canvas, Offset(dx, size.height - _labelBand + 4));
    }
  }

  void _drawLatestValue(Canvas canvas, Size size, double px, double py) {
    final painter = TextPainter(
      text: TextSpan(text: format(points.last.value), style: valueStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = (px - painter.width / 2).clamp(0, size.width - painter.width);
    painter.paint(canvas, Offset(dx.toDouble(), math.max(py - 22, 0)));
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.touched != touched || old.points != points || old.accent != accent;
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.point,
    required this.value,
    required this.alignment,
  });

  final TrendPoint point;
  final String value;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(Gap.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.sm,
          vertical: Gap.xs,
        ),
        decoration: BoxDecoration(
          color: c.ink,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${point.label} · $value',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.canvas,
                  ),
            ),
            if (point.caption != null)
              Text(
                point.caption!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: c.canvas.withValues(alpha: 0.75),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One row of a ranked bar chart.
class RankedBar {
  const RankedBar({
    required this.label,
    required this.value,
    required this.display,
    this.warn = false,
  });

  final String label;

  /// 0–1 of the chart's maximum.
  final double value;

  /// The number as the reader should see it.
  final String display;

  /// Draws this row in the warning colour and marks it — used where a value
  /// crosses a threshold that needs a human to look.
  final bool warn;
}

/// Horizontal bars, ranked, single hue.
///
/// Horizontal because the labels are names: vertical bars would either rotate
/// the text or truncate it, and a chart nobody can read the labels of is not a
/// chart. Ends are rounded and anchored to the baseline.
class RankedBarChart extends StatelessWidget {
  const RankedBarChart({
    required this.bars,
    this.thresholdLabel,
    super.key,
  });

  final List<RankedBar> bars;
  final String? thresholdLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    if (bars.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        child: Text('—', style: text.bodySmall),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bar in bars)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Semantics(
              label: '${bar.label}: ${bar.display}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          bar.label,
                          style: text.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bar.warn) ...[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: c.manual,
                        ),
                        const SizedBox(width: Gap.xs),
                      ],
                      Text(
                        bar.display,
                        // The value is a text token beside a coloured mark, not
                        // the series colour itself.
                        style: text.labelMedium?.copyWith(
                          color: bar.warn ? c.manual : c.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 8, color: c.sunken),
                        FractionallySizedBox(
                          widthFactor: bar.value.clamp(0.02, 1),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: bar.warn ? c.manual : c.chartAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (thresholdLabel != null)
          Text(
            thresholdLabel!,
            style: text.labelSmall?.copyWith(color: c.inkMuted),
          ),
      ],
    );
  }
}
