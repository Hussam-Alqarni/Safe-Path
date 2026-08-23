/// Application-wide configuration.
///
/// Everything that differs between a demo run, a pilot deployment, and
/// production lives here — never hard-coded deeper in the tree.
library;

/// How the app sources bus positions.
enum LocationSourceMode {
  /// Deterministic in-app fleet simulator. No backend, no hardware.
  /// Used for demos and for widget/integration tests.
  simulated,

  /// Live positions relayed from in-vehicle Teltonika trackers.
  live,
}

/// Which renderer draws the map.
enum MapRenderer {
  /// Google Maps. Requires a platform API key (see docs/SETUP.md).
  google,

  /// Built-in canvas renderer. Needs no key, no network, never fails.
  /// Used automatically when no Google Maps key is configured.
  schematic,
}

class AppConfig {
  const AppConfig({
    required this.locationSourceMode,
    required this.googleMapsApiKey,
    required this.pingIntervalSeconds,
    required this.approachNotificationMinutes,
    required this.staleLocationSeconds,
    required this.gateEntryGraceMinutes,
    required this.schoolId,
  });

  /// Demo profile: simulated fleet, schematic map, accelerated timings.
  ///
  /// Runs with zero setup — this is what `flutter run` gives you out of the box.
  factory AppConfig.demo() => const AppConfig(
        locationSourceMode: LocationSourceMode.simulated,
        googleMapsApiKey: '',
        pingIntervalSeconds: 3,
        approachNotificationMinutes: 5,
        staleLocationSeconds: 30,
        gateEntryGraceMinutes: 10,
        schoolId: 'school-001',
      );

  /// Production profile. Supply the key at build time:
  ///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=...
  factory AppConfig.production() => const AppConfig(
        locationSourceMode: LocationSourceMode.live,
        googleMapsApiKey: String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
        pingIntervalSeconds: 10,
        approachNotificationMinutes: 5,
        staleLocationSeconds: 30,
        gateEntryGraceMinutes: 10,
        schoolId: String.fromEnvironment(
          'SCHOOL_ID',
          defaultValue: 'school-001',
        ),
      );

  final LocationSourceMode locationSourceMode;
  final String googleMapsApiKey;

  /// How often a tracker reports its position while the bus is moving.
  final int pingIntervalSeconds;

  /// Guardians are warned this many minutes before the bus reaches their stop.
  final int approachNotificationMinutes;

  /// After this much silence from a tracker the UI stops animating the bus and
  /// shows a "last seen" timestamp instead. Never guess a child's location.
  final int staleLocationSeconds;

  /// A student who alights at school but does not tap the gate reader within
  /// this window raises a gap alert.
  final int gateEntryGraceMinutes;

  final String schoolId;

  /// Falls back to the schematic renderer when no key is present, so the app
  /// is never a grey rectangle.
  MapRenderer get mapRenderer =>
      googleMapsApiKey.isEmpty ? MapRenderer.schematic : MapRenderer.google;

  bool get isDemo => locationSourceMode == LocationSourceMode.simulated;

  Duration get pingInterval => Duration(seconds: pingIntervalSeconds);
  Duration get staleAfter => Duration(seconds: staleLocationSeconds);
}
