import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'keeper.dart';
import 'push_channel.dart';

/// Async consent negotiator. Kept in its own file so the messaging class
/// stays focused on message-side lifecycle.
class PushConsent {
  PushConsent({required this.channel, required this.keeper});

  final PushChannel channel;
  final OracleKeeper keeper;

  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();

  Future<bool>? _inflight;

  /// Should the app show the in-house consent prompt? Returns false when
  /// the OS already granted or permanently denied permission.
  Future<bool> shouldOffer() async {
    final fcm = channel.raw;
    if (fcm == null) return false;
    try {
      if (Platform.isAndroid) {
        final impl = _tray.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (impl == null) return true;
        final enabled = await impl.areNotificationsEnabled();
        return enabled != true;
      }
      final s = await fcm.getNotificationSettings();
      final st = s.authorizationStatus;
      if (st == AuthorizationStatus.denied) {
        await _blockForYear();
        await keeper.markConsent(false);
      }
      return st == AuthorizationStatus.notDetermined ||
          st == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Asks the OS for permission. Multiple concurrent calls collapse into a
  /// single request via [_inflight].
  Future<bool> requestNow() async {
    if (channel.raw == null) return false;
    final pending = _inflight;
    if (pending != null) return pending;
    final job = _doRequest();
    _inflight = job;
    try {
      return await job;
    } finally {
      _inflight = null;
    }
  }

  Future<bool> _doRequest() async {
    final fcm = channel.raw!;
    try {
      if (Platform.isAndroid) {
        final impl = _tray.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (impl != null) {
          final already = await impl.areNotificationsEnabled();
          if (already == true) {
            await keeper.markConsent(true);
            return true;
          }
          final ok = (await impl.requestNotificationsPermission()) ?? false;
          await keeper.markConsent(ok);
          return ok;
        }
      }
      final settings = await fcm.getNotificationSettings();
      final st = settings.authorizationStatus;
      if (st == AuthorizationStatus.denied) {
        await _blockForYear();
        await keeper.markConsent(false);
        return false;
      }
      if (st == AuthorizationStatus.authorized) {
        await keeper.markConsent(true);
        return true;
      }
      final result = await fcm.requestPermission(
        alert: true, badge: true, sound: true, provisional: false,
      );
      final ok = result.authorizationStatus == AuthorizationStatus.authorized ||
          result.authorizationStatus == AuthorizationStatus.provisional;
      if (!ok && result.authorizationStatus == AuthorizationStatus.denied) {
        await _blockForYear();
      }
      await keeper.markConsent(ok);
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> _blockForYear() async {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        365 * 24 * 3600;
    await keeper.setConsentWait(until);
  }
}
