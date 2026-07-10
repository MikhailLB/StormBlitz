import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'beacon.dart';
import 'settings.dart';

/// Attribution collector. Warms up AppsFlyer, listens for conversion +
/// deep-link + reopen callbacks, and exposes the accumulated data to
/// the payload builder.
///
/// Responsibility split from [PayloadForge]: this file only *collects*,
/// while payload composition + dispatch live elsewhere.
class OmenSignal {
  OmenSignal();

  AppsflyerSdk? _sdk;

  Map<String, dynamic> _conversion = const {};
  Map<String, dynamic> _deepLink   = const {};
  Map<String, dynamic> _reopen     = const {};

  final Completer<void> _conversionReady = Completer<void>();
  final Completer<void> _deepLinkReady   = Completer<void>();

  bool _kickedOff = false;
  Future<void>? _bootFuture;

  bool get running => _kickedOff;

  Map<String, dynamic> get conversion => Map.unmodifiable(_conversion);
  Map<String, dynamic> get deepLink   => Map.unmodifiable(_deepLink);
  Map<String, dynamic> get reopen     => Map.unmodifiable(_reopen);

  Future<void> spinUp() => _bootFuture ??= _doSpinUp();

  Future<void> _doSpinUp() async {
    if (_kickedOff) return;
    final devKey = OracleSettings.afInstallKey;
    if (devKey.isEmpty) {
      _kickedOff = true;
      _completeAll();
      return;
    }
    _kickedOff = true;
    try {
      if (Platform.isIOS) await _requestAtt();
      final opts = AppsFlyerOptions(
        afDevKey: devKey,
        appId: OracleSettings.analyticsAppId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 4,
      );
      _sdk = AppsflyerSdk(opts);
      _sdk!.onInstallConversionData(_onConversion);
      _sdk!.onAppOpenAttribution(_onReopen);
      _sdk!.onDeepLinking(_onDeepLink);
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _completeAll();
    }
  }

  void _completeAll() {
    if (!_conversionReady.isCompleted) _conversionReady.complete();
    if (!_deepLinkReady.isCompleted)   _deepLinkReady.complete();
  }

  Future<void> _requestAtt() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 300));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (_) {}
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is! Map) return const {};
    final m = Map<String, dynamic>.from(raw);
    final inner = m['payload'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return m;
  }

  void _onConversion(dynamic raw) async {
    final data = _unwrap(raw);
    if (data['af_status'] == 'Organic') {
      await Future.delayed(
        Duration(seconds: OracleSettings.organicRetrySeconds),
      );
      final retry = await _refreshFromGcd();
      _conversion = retry ?? data;
    } else {
      _conversion = data;
    }
    if (!_conversionReady.isCompleted) _conversionReady.complete();
  }

  void _onReopen(dynamic raw) {
    _reopen = _unwrap(raw);
  }

  void _onDeepLink(DeepLinkResult r) {
    final ev = r.deepLink?.clickEvent;
    if (ev != null) {
      _deepLink = Map<String, dynamic>.from(ev);
    }
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  Future<Map<String, dynamic>?> _refreshFromGcd() async {
    try {
      final uid = await installUid();
      if (uid == null) return null;
      final appId = Platform.isIOS
          ? OracleSettings.analyticsAppId
          : OracleSettings.bundleId;
      final url = resolveGcdEndpoint(appId, uid);
      if (url.isEmpty) return null;
      final resp = await skyBeacon.get(
        Uri.parse(url),
        headers: {'authorization': 'Bearer ${OracleSettings.afInstallKey}'},
      ).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return null;
  }

  Future<void> awaitConversion({
    Duration timeout = const Duration(seconds: 7),
  }) =>
      _conversionReady.future.timeout(timeout, onTimeout: () {});

  Future<void> awaitDeepLink({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _deepLinkReady.future.timeout(timeout, onTimeout: () {});

  Future<String?> installUid() async {
    final s = _sdk;
    if (s == null) return null;
    try { return await s.getAppsFlyerUID(); } catch (_) { return null; }
  }
}
