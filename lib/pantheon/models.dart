/// Persisted routing decision. The three states describe where the shell
/// should send the user on next launch.
enum LaunchLane {
  /// Server previously returned a URL — go straight into the shell.
  content,

  /// Server previously said "no" — go into the game.
  game,

  /// No decision yet — perform a full attribution round-trip.
  cold;

  String encode() {
    switch (this) {
      case LaunchLane.content: return 'content';
      case LaunchLane.game:    return 'game';
      case LaunchLane.cold:    return 'cold';
    }
  }

  static LaunchLane decode(String? raw) {
    switch (raw) {
      case 'content':
      case 'web':
      case 'browser':
        return LaunchLane.content;
      case 'game':
      case 'arcade':
        return LaunchLane.game;
      default:
        return LaunchLane.cold;
    }
  }
}

/// Reply from the dispatch endpoint. Encapsulates the routing decision +
/// destination URL + TTL. The fromMap constructor accepts several legacy
/// field names so backend variance doesn't break parsing.
class LaneVerdict {
  const LaneVerdict._({
    required this.approved,
    this.destination,
    this.reason,
    this.expiresAt,
  });

  final bool approved;
  final String? destination;
  final String? reason;
  final int? expiresAt;

  static bool _readBool(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is bool) return v;
    }
    return false;
  }

  static String? _readStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  factory LaneVerdict.fromMap(Map<String, dynamic> raw) {
    return LaneVerdict._(
      approved: _readBool(raw, const ['ok', 'granted', 'accepted']),
      destination:
          _readStr(raw, const ['url', 'link', 'target', 'destination']),
      reason: _readStr(raw, const ['message', 'note', 'reason']),
      expiresAt:
          _readInt(raw, const ['expires', 'expires_at', 'valid_until']),
    );
  }

  factory LaneVerdict.rejected(String reason) =>
      LaneVerdict._(approved: false, reason: reason);
}
