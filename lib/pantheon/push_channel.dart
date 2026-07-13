import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'beacon.dart';
import 'keeper.dart';

const _kAndroidChannelId    = 'sb_push_main';
const _kAndroidChannelName  = 'Storm Blitz Updates';
const _kAndroidChannelDesc  = 'Storm Blitz real-time updates';
const _kAndroidIconResource = '@mipmap/ic_launcher';

const List<String> _urlKeys = <String>[
  'url', 'link', 'target', 'deeplink', 'deep_link',
];

String? _pickUrl(Map<Object?, Object?> map) {
  for (final k in _urlKeys) {
    final v = map[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

String? _extractRemoteUrl(RemoteMessage msg) {
  final direct = _pickUrl(msg.data);
  if (direct != null) return direct;
  final nested = msg.data['payload'];
  if (nested is Map) return _pickUrl(nested);
  return null;
}

@pragma('vm:entry-point')
Future<void> _backgroundRemoteHandler(RemoteMessage _) async {}

@pragma('vm:entry-point')
Future<void> heraldBackgroundTapHandler(NotificationResponse resp) async {
  final payload = resp.payload;
  if (payload == null || payload.isEmpty) return;
  try {
    final d = jsonDecode(payload);
    if (d is Map && d['url'] is String && (d['url'] as String).isNotEmpty) {
      await OracleKeeper().stashOneShot(d['url'] as String);
    }
  } catch (_) {}
}

/// FCM lifecycle + local tray + cold-start capture.
///
/// Consent asking is intentionally handled in a separate file so this
/// class stays focused on message-side concerns.
class PushChannel {
  PushChannel(this._keeper);

  final OracleKeeper _keeper;
  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();
  final Completer<void> _coldReady = Completer<void>();

  FirebaseMessaging? _fcm;
  String? _token;
  bool _armed = false;
  Future<void>? _bootFuture;

  void Function(String url)? onIncomingUrl;
  void Function(String token)? onTokenRotated;

  String? get token => _token;
  bool get armed => _armed;
  FirebaseMessaging? get raw => _fcm;

  Future<void> get coldReady => _coldReady.future;

  Future<void> arm() => _bootFuture ??= _doArm();

  Future<void> _doArm() async {
    try {
      _fcm = FirebaseMessaging.instance;
      await _captureColdStart();
      FirebaseMessaging.onBackgroundMessage(_backgroundRemoteHandler);
      await _prepareTray();
      try {
        await _fcm!.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true,
        );
      } catch (_) {}
      _fcm!.onTokenRefresh.listen((t) {
        _token = t;
        onTokenRotated?.call(t);
      });
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onTapped);
      if (Platform.isIOS) {
        try {
          final s = await _fcm!.getNotificationSettings();
          if (s.authorizationStatus == AuthorizationStatus.notDetermined) {
            await _fcm!.requestPermission(
              alert: false, badge: false, sound: false, provisional: true,
            );
          }
        } catch (_) {}
        await pollApns();
      }
      _token = await _fcm!.getToken();
      if (kDebugMode) debugPrint('[oracle] FCM token: $_token');
      _armed = true;
    } catch (_) {
    } finally {
      if (!_coldReady.isCompleted) _coldReady.complete();
    }
  }

  Future<void> _captureColdStart() async {
    try {
      final msg = await _fcm!.getInitialMessage().timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
      if (msg != null) {
        final url = _extractRemoteUrl(msg);
        if (url != null) await _keeper.stashOneShot(url);
      }
    } catch (_) {}
    finally {
      if (!_coldReady.isCompleted) _coldReady.complete();
    }
  }

  Future<void> pollApns({int retries = 5}) async {
    for (var i = 0; i < retries; i++) {
      try {
        final t = await _fcm!.getAPNSToken();
        if (t != null && t.isNotEmpty) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _prepareTray() async {
    await _tray.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings(_kAndroidIconResource),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null) return;
        try {
          final d = jsonDecode(payload);
          if (d is Map && d['url'] is String) {
            _routeUrl(d['url'] as String);
          }
        } catch (_) {}
      },
      onDidReceiveBackgroundNotificationResponse: heraldBackgroundTapHandler,
    );
    if (Platform.isAndroid) {
      final impl = _tray.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await impl?.createNotificationChannel(const AndroidNotificationChannel(
        _kAndroidChannelId, _kAndroidChannelName,
        description: _kAndroidChannelDesc,
        importance: Importance.high,
      ));
    }
  }

  Future<String?> refreshToken() async {
    final m = _fcm;
    if (m == null) return null;
    try {
      if (Platform.isIOS) await pollApns(retries: 14);
      _token = await m.getToken().timeout(const Duration(seconds: 10));
      final t = _token;
      if (t != null && t.isNotEmpty) onTokenRotated?.call(t);
      return t;
    } catch (_) {
      return null;
    }
  }

  void _onForeground(RemoteMessage msg) async {
    if (Platform.isIOS) return;
    final notif = msg.notification;
    if (notif == null) {
      final url = _extractRemoteUrl(msg);
      if (url != null) _routeUrl(url);
      return;
    }
    final imageUrl = msg.notification?.android?.imageUrl;
    AndroidNotificationDetails? androidDetails;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final bytes = await _downloadImage(imageUrl);
      if (bytes != null) {
        androidDetails = AndroidNotificationDetails(
          _kAndroidChannelId, _kAndroidChannelName,
          importance: Importance.high, priority: Priority.high,
          icon: _kAndroidIconResource,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }
    androidDetails ??= const AndroidNotificationDetails(
      _kAndroidChannelId, _kAndroidChannelName,
      importance: Importance.high, priority: Priority.high,
      icon: _kAndroidIconResource,
    );
    await _tray.show(
      notif.hashCode, notif.title, notif.body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true,
          presentSound: true, presentBanner: true, presentList: true,
        ),
      ),
      payload: msg.data.isNotEmpty ? jsonEncode(msg.data) : null,
    );
  }

  void _onTapped(RemoteMessage msg) {
    final url = _extractRemoteUrl(msg);
    if (url != null) _routeUrl(url);
  }

  void _routeUrl(String url) {
    final cb = onIncomingUrl;
    if (cb != null) {
      cb(url);
    } else {
      _keeper.stashOneShot(url);
    }
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final r = await skyBeacon
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }
}
