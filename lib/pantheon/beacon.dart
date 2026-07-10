import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'settings.dart';

/// Combined outbound-request client and connectivity probe. The two responsi-
/// bilities were split into separate classes in earlier builds; consolidating
/// them here reduces surface area and keeps the mobile-browser UA close to
/// where it's actually used.
class SkyBeacon {
  SkyBeacon._();
  static final SkyBeacon instance = SkyBeacon._();

  final http.Client _client = http.Client();
  String _mobileUa = '';

  // -----------------------------------------------------------------
  // User-Agent
  // -----------------------------------------------------------------

  String _iosUa(String version) {
    final dotless = version.replaceAll('.', '_');
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS $dotless like Mac OS X) '
        'AppleWebKit/${uaWebkitVersion()} (KHTML, like Gecko) '
        'Version/$version Mobile/15E148 Safari/${uaWebkitVersion()}';
  }

  String _androidUa(String major) =>
      'Mozilla/5.0 (Linux; Android $major; Pixel 8 Build/UD1A.230803.041) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/${uaChromeVersion()} Mobile Safari/537.36';

  String _fallbackUa() =>
      Platform.isAndroid ? _androidUa('14') : _iosUa('17.5');

  Future<void> heatUa() async {
    try {
      final ver = Platform.operatingSystemVersion;
      if (Platform.isIOS) {
        final m = RegExp(r'(\d+\.\d+(?:\.\d+)?)').firstMatch(ver);
        _mobileUa = _iosUa(m?.group(1) ?? '17.5');
      } else if (Platform.isAndroid) {
        final m = RegExp(r'(\d+)').firstMatch(ver);
        _mobileUa = _androidUa(m?.group(1) ?? '14');
      } else {
        _mobileUa = _fallbackUa();
      }
    } catch (_) {
      _mobileUa = _fallbackUa();
    }
  }

  String get userAgent => _mobileUa.isNotEmpty ? _mobileUa : _fallbackUa();

  // -----------------------------------------------------------------
  // HTTP passthrough
  // -----------------------------------------------------------------

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) {
    final merged = <String, String>{'User-Agent': userAgent, ...?headers};
    return _client.get(uri, headers: merged);
  }

  Future<http.Response> post(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
  }) {
    final merged = <String, String>{'User-Agent': userAgent, ...headers};
    return _client.post(uri, headers: merged, body: body);
  }

  // -----------------------------------------------------------------
  // Connectivity probe
  // -----------------------------------------------------------------

  /// Cheap DNS-based reachability check. Avoids captive-portal false-
  /// positives that plague pure socket-connect probes.
  Future<bool> reachable() async {
    try {
      final rec = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 4));
      return rec.isNotEmpty && rec.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Emits reachability status every 9s. Used for background watch by the
  /// web shell.
  Stream<bool> watch() =>
      Stream.periodic(const Duration(seconds: 9)).asyncMap((_) => reachable());
}

/// Convenience singleton alias for existing call sites.
final SkyBeacon skyBeacon = SkyBeacon.instance;
