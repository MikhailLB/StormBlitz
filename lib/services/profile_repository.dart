import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_profile.dart';

/// Persists the whole [PlayerProfile] as a single JSON blob.
class ProfileRepository {
  static const String _key = 'storm_blitz_profile_v1';

  Future<PlayerProfile> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        return PlayerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ProfileRepository.load failed: $e');
    }
    return PlayerProfile();
  }

  Future<void> save(PlayerProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(profile.toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('ProfileRepository.save failed: $e');
    }
  }
}
