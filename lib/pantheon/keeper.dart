import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Persistence facade. Splits durable state between `SharedPreferences`
/// (non-secret enums / cooldowns) and `FlutterSecureStorage` (URLs, which
/// may be personal to the install).
class OracleKeeper {
  // Keys are deliberately terse and app-local — no shared prefix with
  // sibling builds.
  static const _kLane        = 'ob.lane';
  static const _kSavedUrl    = 'ob.savedUrl';
  static const _kSavedTtl    = 'ob.savedUrl.ttl';
  static const _kOneShotUrl  = 'ob.oneShot';
  static const _kConsentOk   = 'ob.consent';
  static const _kConsentWait = 'ob.consent.wait';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _safe = const FlutterSecureStorage();

  bool _ready = false;

  Future<void> bringUp() async {
    if (_ready) return;
    _prefs = await SharedPreferences.getInstance();
    _ready = true;
  }

  // ----- Lane -----

  LaunchLane currentLane() => LaunchLane.decode(_prefs.getString(_kLane));

  Future<void> commitLane(LaunchLane lane) =>
      _prefs.setString(_kLane, lane.encode());

  // ----- Saved URL -----

  Future<String?> loadSavedUrl() async {
    try { return await _safe.read(key: _kSavedUrl); } catch (_) { return null; }
  }

  Future<void> saveUrl(String url) async {
    try { await _safe.write(key: _kSavedUrl, value: url); } catch (_) {}
  }

  Future<void> saveTtl(int epochSeconds) =>
      _prefs.setInt(_kSavedTtl, epochSeconds);

  bool savedUrlExpired() {
    final ttl = _prefs.getInt(_kSavedTtl);
    if (ttl == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= ttl;
  }

  // ----- One-shot URL (from push tap) -----

  Future<void> stashOneShot(String url) async {
    if (url.trim().isEmpty) return;
    try { await _safe.write(key: _kOneShotUrl, value: url); } catch (_) {}
  }

  Future<String?> takeOneShot() async {
    try {
      final v = await _safe.read(key: _kOneShotUrl);
      if (v != null) await _safe.delete(key: _kOneShotUrl);
      return v;
    } catch (_) {
      return null;
    }
  }

  // ----- Push consent state -----

  bool hasConsent() => _prefs.getBool(_kConsentOk) ?? false;

  Future<void> markConsent(bool ok) => _prefs.setBool(_kConsentOk, ok);

  int? consentWaitUntil() => _prefs.getInt(_kConsentWait);

  Future<void> setConsentWait(int epochSeconds) =>
      _prefs.setInt(_kConsentWait, epochSeconds);

  bool needsConsentPrompt() {
    final consent = hasConsent();
    final until  = consentWaitUntil();
    final now    = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (kDebugMode) {
      debugPrint('[oracle] needsConsentPrompt:'
          ' hasConsent=$consent until=$until now=$now'
          ' diff=${until != null ? now - until : "n/a"}');
    }
    if (consent) return false;
    if (until == null) return true;
    return now >= until;
  }
}
