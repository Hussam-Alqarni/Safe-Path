import 'package:url_launcher/url_launcher.dart';

/// Places a phone call.
///
/// Behind an interface for the same reason the fleet feed and the router are:
/// an emergency screen must be testable without a SIM card, and a school that
/// routes calls through its own switchboard should be a swapped implementation
/// rather than an edit to every button that dials.
abstract class Dialer {
  /// Returns false when the device could not open the dialler — a tablet with
  /// no telephony, most often. Callers must say so rather than fail silently:
  /// a call button that does nothing is worse than no call button.
  Future<bool> call(String phoneNumber);
}

class UrlLauncherDialer implements Dialer {
  const UrlLauncherDialer();

  @override
  Future<bool> call(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: _dialable(phoneNumber));
    try {
      return await launchUrl(uri);
    } on Object {
      // Platform channels throw on a device with no dialler at all.
      return false;
    }
  }

  /// Keeps digits, a leading +, and the pause characters diallers understand.
  static String _dialable(String raw) {
    final trimmed = raw.trim();
    final plus = trimmed.startsWith('+') ? '+' : '';
    final rest = trimmed.replaceAll(RegExp(r'[^0-9,;*#]'), '');
    return '$plus$rest';
  }
}
