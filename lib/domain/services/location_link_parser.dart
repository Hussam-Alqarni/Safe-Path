import 'package:safe_path/domain/models/geo.dart';

/// What a pasted location link turned out to be.
sealed class LinkParseResult {
  const LinkParseResult();
}

/// Coordinates were read successfully.
class LinkParsed extends LinkParseResult {
  const LinkParsed({
    required this.point,
    required this.source,
    this.label,
    this.outsideExpectedArea = false,
  });

  final LatLngPoint point;

  /// Which URL shape it matched — shown in diagnostics, not to guardians.
  final String source;

  /// Place name, when the link carried one.
  final String? label;

  /// True when the point is far from the school. Almost always a swapped
  /// latitude and longitude, which otherwise silently plants a home in the
  /// wrong hemisphere.
  final bool outsideExpectedArea;
}

/// The link is a short one and must be expanded over the network first.
class LinkNeedsResolving extends LinkParseResult {
  const LinkNeedsResolving(this.url);
  final String url;
}

/// Nothing usable in the text.
class LinkUnrecognised extends LinkParseResult {
  const LinkUnrecognised(this.reason);

  /// A machine-readable reason so the UI can phrase it in either language.
  final LinkFailure reason;
}

enum LinkFailure {
  empty,
  noCoordinates,
  outOfRange,
}

/// Expands a shortened link to the URL it points at.
///
/// Behind an interface because the app must stay testable without a network,
/// and because short-link hosts change more often than this parser does.
abstract class ShortLinkResolver {
  Future<String?> resolve(String shortUrl);
}

/// Reads coordinates out of a pasted map link.
///
/// Guardians in Saudi Arabia share their address as a WhatsApp location, which
/// arrives as a Google Maps link — so accepting a pasted link is the shortest
/// path from "where do you live" to a usable pickup point. Typing coordinates
/// is not a realistic alternative for a parent.
class LocationLinkParser {
  const LocationLinkParser({
    this.expectedCentre,
    this.expectedRadiusKm = 150,
  });

  /// Used only to flag an implausible result; parsing never depends on it.
  final LatLngPoint? expectedCentre;
  final double expectedRadiusKm;

  static final _shortHosts = {
    'maps.app.goo.gl',
    'goo.gl',
    'g.co',
    'maps.google.com.sa',
  };

  // 21.5433,39.1728 — with or without a space, and with an optional sign.
  static final _bareCoords = RegExp(
    r'(-?\d{1,3}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})',
  );

  // The @lat,lng,zoom form inside a /maps/place/ or /maps/@ path.
  static final _atCoords = RegExp(
    r'@(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)',
  );

  // Google embeds the true pin as !3d<lat>!4d<lng> in the data= blob. It is
  // more precise than the @ coordinates, which describe the camera rather
  // than the place, so it wins when both are present.
  static final _dataPin = RegExp(r'!3d(-?\d{1,3}\.\d+)!4d(-?\d{1,3}\.\d+)');

  LinkParseResult parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const LinkUnrecognised(LinkFailure.empty);

    final uri = Uri.tryParse(text);
    if (uri != null && _shortHosts.contains(uri.host.toLowerCase())) {
      return LinkNeedsResolving(text);
    }

    // Ordered most precise first.
    final attempts = <({String source, RegExpMatch? match})>[
      (source: 'data-pin', match: _dataPin.firstMatch(text)),
      (source: 'query', match: _fromQuery(uri)),
      (source: 'at-coords', match: _atCoords.firstMatch(text)),
      (source: 'bare', match: _bareCoords.firstMatch(text)),
    ];

    for (final attempt in attempts) {
      final match = attempt.match;
      if (match == null) continue;

      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat == null || lng == null) continue;
      if (lat.abs() > 90 || lng.abs() > 180) {
        return const LinkUnrecognised(LinkFailure.outOfRange);
      }

      final point = LatLngPoint(lat, lng);
      return LinkParsed(
        point: point,
        source: attempt.source,
        label: _labelFrom(uri),
        outsideExpectedArea: _isImplausible(point),
      );
    }
    return const LinkUnrecognised(LinkFailure.noCoordinates);
  }

  /// Handles ?q=, ?query=, ?ll= and ?destination= — the shapes produced by
  /// share sheets, the Maps URL API, and Apple Maps.
  RegExpMatch? _fromQuery(Uri? uri) {
    if (uri == null) return null;
    for (final key in const ['q', 'query', 'll', 'destination', 'daddr']) {
      final value = uri.queryParameters[key];
      if (value == null) continue;
      final match = _bareCoords.firstMatch(value);
      if (match != null) return match;
    }
    return null;
  }

  /// Pulls the place name out of a `/maps/place/<name>/` path.
  String? _labelFrom(Uri? uri) {
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final index = segments.indexOf('place');
    if (index == -1 || index + 1 >= segments.length) return null;

    final name = Uri.decodeComponent(segments[index + 1]).replaceAll('+', ' ');
    // A place segment that is itself coordinates is not a name.
    if (_bareCoords.hasMatch(name)) return null;
    return name.trim().isEmpty ? null : name.trim();
  }

  bool _isImplausible(LatLngPoint point) {
    final centre = expectedCentre;
    if (centre == null) return false;
    return centre.distanceTo(point) > expectedRadiusKm * 1000;
  }

  /// Expands a short link, then parses whatever it points at.
  Future<LinkParseResult> parseResolving(
    String raw,
    ShortLinkResolver resolver,
  ) async {
    final first = parse(raw);
    if (first is! LinkNeedsResolving) return first;

    final expanded = await resolver.resolve(first.url);
    if (expanded == null) {
      return const LinkUnrecognised(LinkFailure.noCoordinates);
    }
    // Resolve once only: a short link that expands to another short link is a
    // redirect loop, not a location.
    final second = parse(expanded);
    return second is LinkNeedsResolving
        ? const LinkUnrecognised(LinkFailure.noCoordinates)
        : second;
  }
}
