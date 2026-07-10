import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Bridge between the native scene delegate and Dart. When the app is
/// killed and a push notification is tapped, iOS routes through
/// `SceneDelegate` before Flutter is alive. The delegate persists the
/// destination URL under a UserDefaults key with the `flutter.` prefix so
/// that `SharedPreferences` can read it back here.
class NativeColdTap {
  static const String _key = 'sb_tap_return';

  /// Reads and clears the persisted URL. Only meaningful on iOS.
  static Future<String?> pull() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      await prefs.remove(_key);
      return trimmed;
    } catch (_) {
      return null;
    }
  }
}
