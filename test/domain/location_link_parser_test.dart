import 'package:flutter_test/flutter_test.dart';
import 'package:safe_path/domain/models/geo.dart';
import 'package:safe_path/domain/services/location_link_parser.dart';

/// A resolver that returns whatever the test tells it to.
class _StubResolver implements ShortLinkResolver {
  _StubResolver(this.expansion);
  final String? expansion;
  int calls = 0;

  @override
  Future<String?> resolve(String shortUrl) async {
    calls++;
    return expansion;
  }
}

void main() {
  const jeddah = LatLngPoint(21.5433, 39.1728);
  const parser = LocationLinkParser(expectedCentre: jeddah);

  LinkParsed parsed(String input) {
    final result = parser.parse(input);
    expect(result, isA<LinkParsed>(), reason: 'failed to parse: $input');
    return result as LinkParsed;
  }

  group('Google Maps link shapes', () {
    test('reads the ?q= share form', () {
      final r = parsed('https://www.google.com/maps?q=21.5433,39.1728');
      expect(r.point.latitude, closeTo(21.5433, 1e-6));
      expect(r.point.longitude, closeTo(39.1728, 1e-6));
    });

    test('reads the /maps/@lat,lng,zoom camera form', () {
      final r = parsed('https://www.google.com/maps/@21.5602,39.1553,16z');
      expect(r.point.latitude, closeTo(21.5602, 1e-6));
      expect(r.point.longitude, closeTo(39.1553, 1e-6));
    });

    test('reads a place link and keeps its name', () {
      final r = parsed(
        'https://www.google.com/maps/place/Al+Rawdah+District/'
        '@21.5602,39.1553,17z/data=!3m1!4b1',
      );
      expect(r.point.latitude, closeTo(21.5602, 1e-6));
      expect(r.label, 'Al Rawdah District');
    });

    test('prefers the pin in data= over the camera position', () {
      // Google puts the camera in @ and the actual pin in !3d!4d. Using the
      // camera would drop the pickup point a block away from the house.
      final r = parsed(
        'https://www.google.com/maps/place/Home/'
        '@21.5000,39.1000,17z/data=!4m6!3m5!1s0x0!8m2!3d21.5602!4d39.1553',
      );
      expect(r.source, 'data-pin');
      expect(r.point.latitude, closeTo(21.5602, 1e-6));
      expect(r.point.longitude, closeTo(39.1553, 1e-6));
    });

    test('reads the Maps URL API search form', () {
      final r = parsed(
        'https://www.google.com/maps/search/?api=1&query=21.5433,39.1728',
      );
      expect(r.point.latitude, closeTo(21.5433, 1e-6));
    });

    test('reads a directions destination', () {
      final r = parsed(
        'https://www.google.com/maps/dir/?api=1&destination=21.5433,39.1728',
      );
      expect(r.point.latitude, closeTo(21.5433, 1e-6));
    });

    test('reads an Apple Maps ll parameter', () {
      final r = parsed('https://maps.apple.com/?ll=21.5433,39.1728&z=16');
      expect(r.point.longitude, closeTo(39.1728, 1e-6));
    });

    test('reads a geo: URI', () {
      final r = parsed('geo:21.5433,39.1728');
      expect(r.point.latitude, closeTo(21.5433, 1e-6));
    });

    test('reads bare coordinates a parent typed or pasted', () {
      final r = parsed('21.5433, 39.1728');
      expect(r.point.latitude, closeTo(21.5433, 1e-6));
      expect(r.source, 'bare');
    });

    test('tolerates surrounding chatter from a pasted message', () {
      final r = parsed(
        'موقع البيت: https://www.google.com/maps?q=21.5433,39.1728 شكراً',
      );
      expect(r.point.latitude, closeTo(21.5433, 1e-6));
    });
  });

  group('short links', () {
    test('a maps.app.goo.gl link asks to be resolved', () {
      final result = parser.parse('https://maps.app.goo.gl/aBcD1234');
      expect(result, isA<LinkNeedsResolving>());
    });

    test('a goo.gl/maps link asks to be resolved', () {
      expect(
        parser.parse('https://goo.gl/maps/aBcD1234'),
        isA<LinkNeedsResolving>(),
      );
    });

    test('resolving expands then parses', () async {
      final resolver = _StubResolver(
        'https://www.google.com/maps/place/X/@21.5602,39.1553,17z',
      );
      final result = await parser.parseResolving(
        'https://maps.app.goo.gl/aBcD1234',
        resolver,
      );

      expect(result, isA<LinkParsed>());
      expect((result as LinkParsed).point.latitude, closeTo(21.5602, 1e-6));
      expect(resolver.calls, 1);
    });

    test('a resolver that fails yields an unrecognised result, not a crash',
        () async {
      final result = await parser.parseResolving(
        'https://maps.app.goo.gl/aBcD1234',
        _StubResolver(null),
      );
      expect(result, isA<LinkUnrecognised>());
    });

    test('a short link expanding to another short link is refused', () async {
      // A redirect loop must terminate rather than recurse.
      final result = await parser.parseResolving(
        'https://maps.app.goo.gl/one',
        _StubResolver('https://maps.app.goo.gl/two'),
      );
      expect(result, isA<LinkUnrecognised>());
    });

    test('a full link is parsed without touching the network', () async {
      final resolver = _StubResolver('unused');
      await parser.parseResolving(
        'https://www.google.com/maps?q=21.5433,39.1728',
        resolver,
      );
      expect(resolver.calls, 0);
    });
  });

  group('rejects what it should', () {
    test('empty text', () {
      final r = parser.parse('   ');
      expect(r, isA<LinkUnrecognised>());
      expect((r as LinkUnrecognised).reason, LinkFailure.empty);
    });

    test('a link with no coordinates at all', () {
      final r = parser.parse('https://www.google.com/maps/place/Some+Mall');
      expect((r as LinkUnrecognised).reason, LinkFailure.noCoordinates);
    });

    test('coordinates outside the valid range', () {
      final r = parser.parse('99.9999,200.0000');
      expect((r as LinkUnrecognised).reason, LinkFailure.outOfRange);
    });
  });

  group('implausible location warning', () {
    test('flags a point far from the school', () {
      // Latitude and longitude swapped — the single most common paste error,
      // and one that silently plants a home in the wrong country.
      final r = parsed('39.1728,21.5433');
      expect(r.outsideExpectedArea, isTrue);
    });

    test('does not flag a nearby point', () {
      final r = parsed('21.5602,39.1553');
      expect(r.outsideExpectedArea, isFalse);
    });

    test('never flags when no centre is configured', () {
      const noCentre = LocationLinkParser();
      final r = noCentre.parse('39.1728,21.5433');
      expect((r as LinkParsed).outsideExpectedArea, isFalse);
    });
  });
}
