import 'package:http/http.dart' as http;
import 'package:safe_path/domain/services/location_link_parser.dart';

/// Expands a shortened map link by following its redirect.
///
/// Short links carry no coordinates of their own — the destination does — so a
/// pasted WhatsApp location is unusable until it is followed. One hop only,
/// with a short timeout: this runs while an administrator waits.
class HttpShortLinkResolver implements ShortLinkResolver {
  HttpShortLinkResolver({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  @override
  Future<String?> resolve(String shortUrl) async {
    final uri = Uri.tryParse(shortUrl);
    if (uri == null) return null;

    try {
      // followRedirects is off so the Location header can be read directly;
      // some shorteners answer a GET with an HTML page instead of a 30x.
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await _client.send(request).timeout(timeout);

      final location = response.headers['location'];
      if (location != null && location.isNotEmpty) {
        return uri.resolve(location).toString();
      }

      // No redirect header: fall back to the body, where the canonical URL is
      // usually present in a meta refresh or a link tag.
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString().timeout(timeout);
        final match = RegExp(
          r'https://www\.google\.com/maps[^"\s<]+',
        ).firstMatch(body);
        return match?.group(0)?.replaceAll('&amp;', '&');
      }
      return null;
    } on Exception {
      // A network failure is a normal outcome here, not an error to surface as
      // a crash: the UI simply reports that the link could not be read.
      return null;
    }
  }

  void close() => _client.close();
}
