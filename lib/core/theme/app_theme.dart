import 'package:flutter/material.dart';
import 'package:safe_path/core/theme/app_colors.dart';

/// Spacing scale. Every gap in the app comes from here, so rhythm stays even.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Radii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;
}

/// Builds the Material theme from the Safe Path palette.
///
/// Two families do the work: ReadexPro for headings, where its wider Arabic
/// forms give titles presence, and IBM Plex Sans Arabic for body and data,
/// where readability at small sizes matters more than character.
abstract final class AppTheme {
  static const _display = 'ReadexPro';
  static const _body = 'PlexArabic';

  /// Latin glyphs are missing from the Arabic face and vice versa, so each
  /// family names the other as its fallback. Without this, a mixed string like
  /// "الحافلة ABC-1234" renders half in a system default.
  static const _fallback = [_body, _display];

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors palette, Brightness brightness) {
    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.canvas,
      canvasColor: palette.canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.brand,
        onPrimary: brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : const Color(0xFF08211F),
        secondary: palette.brandMuted,
        onSecondary: const Color(0xFFFFFFFF),
        error: palette.critical,
        onError: const Color(0xFFFFFFFF),
        surface: palette.surface,
        onSurface: palette.ink,
        surfaceContainerHighest: palette.sunken,
        outline: palette.line,
        outlineVariant: palette.lineStrong,
      ),
      textTheme: textTheme,
      fontFamily: _body,
      fontFamilyFallback: _fallback,
      extensions: [palette],
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: palette.line)),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          side: BorderSide(color: palette.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.brand,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: palette.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brand,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.sunken,
        side: BorderSide(color: palette.line),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: palette.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: palette.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
          borderSide: BorderSide(color: palette.brand, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.brandSurface,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: palette.canvas,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.inkSoft,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brand,
        linearTrackColor: palette.sunken,
      ),
    );
  }

  static TextTheme _textTheme(AppColors palette) {
    TextStyle display(double size, FontWeight weight, {double height = 1.3}) =>
        TextStyle(
          fontFamily: _display,
          fontFamilyFallback: _fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: palette.ink,
        );

    TextStyle body(
      double size,
      FontWeight weight, {
      Color? color,
      double height = 1.55,
      double? spacing,
    }) =>
        TextStyle(
          fontFamily: _body,
          fontFamilyFallback: _fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          letterSpacing: spacing,
          color: color ?? palette.ink,
        );

    return TextTheme(
      displaySmall: display(30, FontWeight.w500, height: 1.22),
      headlineMedium: display(24, FontWeight.w500, height: 1.25),
      headlineSmall: display(20, FontWeight.w500),
      titleLarge: display(18, FontWeight.w500),
      titleMedium: body(16, FontWeight.w600, height: 1.4),
      titleSmall: body(14, FontWeight.w600, height: 1.4),
      bodyLarge: body(15, FontWeight.w400),
      bodyMedium: body(14, FontWeight.w400),
      bodySmall: body(12.5, FontWeight.w400, color: palette.inkSoft),
      labelLarge: body(14, FontWeight.w600, height: 1.2),
      labelMedium: body(12.5, FontWeight.w500, height: 1.2),
      labelSmall: body(11.5, FontWeight.w500, height: 1.2, spacing: 0.2),
    );
  }
}
