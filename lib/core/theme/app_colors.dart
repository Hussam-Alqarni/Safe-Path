import 'package:flutter/material.dart';

/// The Safe Path palette.
///
/// Two families, kept deliberately separate:
///  * Brand colours identify the product.
///  * State colours carry meaning — a guardian must be able to read a student's
///    status from colour alone, before reading a word.
///
/// State colours are never reused for decoration, so amber always means
/// "a human entered this by hand" and red always means "act now".
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandMuted,
    required this.brandSurface,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.sunken,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.line,
    required this.lineStrong,
    required this.onBus,
    required this.onBusSurface,
    required this.atSchool,
    required this.atSchoolSurface,
    required this.delivered,
    required this.deliveredSurface,
    required this.absent,
    required this.absentSurface,
    required this.manual,
    required this.manualSurface,
    required this.critical,
    required this.criticalSurface,
    required this.routeLine,
    required this.routeLineDone,
    required this.chartAccent,
    required this.chartGrid,
  });

  final Color brand;
  final Color brandMuted;
  final Color brandSurface;

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color sunken;

  final Color ink;
  final Color inkSoft;
  final Color inkMuted;

  final Color line;
  final Color lineStrong;

  /// Student is aboard a bus.
  final Color onBus;
  final Color onBusSurface;

  /// Student is inside the school grounds.
  final Color atSchool;
  final Color atSchoolSurface;

  /// Student is home — the terminal, safe state.
  final Color delivered;
  final Color deliveredSurface;

  final Color absent;
  final Color absentSurface;

  /// Recorded by hand rather than scanned.
  final Color manual;
  final Color manualSurface;

  final Color critical;
  final Color criticalSurface;

  final Color routeLine;
  final Color routeLineDone;

  /// The single-series chart colour.
  ///
  /// A separate step from [brand] because a chart mark and a button have
  /// different jobs: each mode's value was checked against that mode's chart
  /// surface for lightness band and contrast, and the dark step is chosen,
  /// not derived by flipping the light one.
  final Color chartAccent;

  /// Grid and axis lines. Recessive by design — the data is the subject.
  final Color chartGrid;

  static const light = AppColors(
    brand: Color(0xFF0D6B75),
    brandMuted: Color(0xFF4C9199),
    brandSurface: Color(0xFFE1EDEE),
    canvas: Color(0xFFEDF1F0),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    sunken: Color(0xFFE3E9E8),
    ink: Color(0xFF0F2429),
    inkSoft: Color(0xFF4A6169),
    inkMuted: Color(0xFF7B8F95),
    line: Color(0xFFCFD9D8),
    lineStrong: Color(0xFFB4C3C2),
    onBus: Color(0xFF1F6FB2),
    onBusSurface: Color(0xFFE2EDF7),
    atSchool: Color(0xFF0D6B75),
    atSchoolSurface: Color(0xFFE1EDEE),
    delivered: Color(0xFF2C7A5B),
    deliveredSurface: Color(0xFFE2F0EA),
    absent: Color(0xFF6B7C82),
    absentSurface: Color(0xFFE8EDEE),
    manual: Color(0xFFB26512),
    manualSurface: Color(0xFFF7EBDB),
    critical: Color(0xFFA93E2F),
    criticalSurface: Color(0xFFF7E4E1),
    routeLine: Color(0xFF0D6B75),
    routeLineDone: Color(0xFFB4C3C2),
    chartAccent: Color(0xFF0D6B75),
    chartGrid: Color(0xFFE3E9E8),
  );

  static const dark = AppColors(
    brand: Color(0xFF4FB6BF),
    brandMuted: Color(0xFF357F87),
    brandSurface: Color(0xFF163336),
    canvas: Color(0xFF0D1A1D),
    surface: Color(0xFF14262A),
    surfaceRaised: Color(0xFF1A2F34),
    sunken: Color(0xFF101F23),
    ink: Color(0xFFE2EDEE),
    inkSoft: Color(0xFF9DB2B6),
    inkMuted: Color(0xFF6F868B),
    line: Color(0xFF233A3F),
    lineStrong: Color(0xFF315055),
    onBus: Color(0xFF62A8E0),
    onBusSurface: Color(0xFF14293A),
    atSchool: Color(0xFF4FB6BF),
    atSchoolSurface: Color(0xFF163336),
    delivered: Color(0xFF5FBF92),
    deliveredSurface: Color(0xFF143025),
    absent: Color(0xFF8B9DA3),
    absentSurface: Color(0xFF1B2B2F),
    manual: Color(0xFFE0A04B),
    manualSurface: Color(0xFF33280F),
    critical: Color(0xFFE08276),
    criticalSurface: Color(0xFF3A1E1A),
    routeLine: Color(0xFF4FB6BF),
    routeLineDone: Color(0xFF315055),
    chartAccent: Color(0xFF43A3AC),
    chartGrid: Color(0xFF233A3F),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// Reads the palette without repeating the lookup at every call site.
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
