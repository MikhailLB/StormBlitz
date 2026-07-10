import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

import 'beacon.dart';
import 'keeper.dart';
import 'models.dart';
import 'omen_signal.dart';
import 'settings.dart';

/// Builds the launch payload from an [OmenSignal] snapshot and dispatches
/// it to the remote endpoint. Split from [OmenSignal] to keep collection
/// separate from transport.
class PayloadForge {
  PayloadForge({required this.signal, required this.keeper});

  final OmenSignal signal;
  final OracleKeeper keeper;

  /// Composes the outbound JSON body. Field names remain compatible with
  /// the shared backend contract.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    body.addAll(signal.conversion);
    signal.deepLink.forEach((k, v) => body.putIfAbsent(k, () => v));
    signal.reopen.forEach((k, v) => body.putIfAbsent(k, () => v));

    final uid = await signal.installUid();
    body['af_id'] = uid ?? '';

    if (Platform.isIOS) {
      final idfa = await _readIdfa();
      if (idfa != null) body.putIfAbsent('sub_id_10', () => idfa);
    }

    body['bundle_id'] = OracleSettings.bundleId;
    body['store_id']  = OracleSettings.storeIdentifier;
    body['os']        = Platform.isAndroid ? 'Android' : 'iOS';
    body['locale']    = locale;
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (OracleSettings.firebaseProjectId.isNotEmpty) {
      body['firebase_project_id'] = OracleSettings.firebaseProjectId;
    }

    return body;
  }

  Future<String?> _readIdfa() async {
    try {
      final s = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (s != TrackingStatus.authorized) return null;
      final id = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (id.isEmpty || id.startsWith('00000000-')) return null;
      return id;
    } catch (_) {
      return null;
    }
  }

  /// POSTs the payload and stores the returned URL on success.
  Future<LaneVerdict> dispatch(Map<String, dynamic> body) async {
    final endpoint = OracleSettings.dispatchEndpoint;
    if (endpoint.isEmpty) {
      if (kDebugMode) debugPrint('[oracle] dispatch: endpoint missing');
      return LaneVerdict.rejected('endpoint_missing');
    }
    try {
      if (kDebugMode) {
        debugPrint('[oracle] POST $endpoint');
        debugPrint('[oracle] body keys: ${body.keys.toList()}');
      }
      final resp = await skyBeacon
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
      if (kDebugMode) {
        debugPrint('[oracle] response ${resp.statusCode}: ${resp.body}');
      }
      if (resp.statusCode != 200) {
        return LaneVerdict.rejected('http_${resp.statusCode}');
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return LaneVerdict.rejected('bad_json');
      }
      final verdict = LaneVerdict.fromMap(decoded);
      if (kDebugMode) {
        debugPrint('[oracle] verdict approved=${verdict.approved} '
            'destination=${verdict.destination} reason=${verdict.reason}');
      }
      if (verdict.approved && verdict.destination != null) {
        await keeper.saveUrl(verdict.destination!);
        if (verdict.expiresAt != null) {
          await keeper.saveTtl(verdict.expiresAt!);
        }
      }
      return verdict;
    } catch (err) {
      if (kDebugMode) debugPrint('[oracle] dispatch error: $err');
      return LaneVerdict.rejected(err.runtimeType.toString());
    }
  }
}
