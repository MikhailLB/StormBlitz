/// Chest tiers dropped after battles and bought in the shop.
///
/// A chest occupies one of the profile's slots; the player starts its unlock
/// timer manually (only one chest can be unlocking at a time), then opens it
/// once the timer expires.
enum ChestTier {
  common(
    label: 'Storm Chest',
    unlockMinutes: 15,
    minGold: 30,
    maxGold: 60,
    ambrosiaChance: 0.10,
    cardCopies: 2,
    rareUpChance: 0.15,
  ),
  rare(
    label: 'Thunder Chest',
    unlockMinutes: 60,
    minGold: 70,
    maxGold: 130,
    ambrosiaChance: 0.35,
    cardCopies: 4,
    rareUpChance: 0.45,
  ),
  epic(
    label: 'Tempest Chest',
    unlockMinutes: 240,
    minGold: 160,
    maxGold: 260,
    ambrosiaChance: 0.75,
    cardCopies: 6,
    rareUpChance: 0.75,
  ),
  olympian(
    label: 'Olympian Chest',
    unlockMinutes: 480,
    minGold: 300,
    maxGold: 480,
    ambrosiaChance: 1.0,
    cardCopies: 9,
    rareUpChance: 1.0,
  );

  const ChestTier({
    required this.label,
    required this.unlockMinutes,
    required this.minGold,
    required this.maxGold,
    required this.ambrosiaChance,
    required this.cardCopies,
    required this.rareUpChance,
  });

  final String label;
  final int unlockMinutes;
  final int minGold;
  final int maxGold;

  /// Probability that the chest also contains ambrosia.
  final double ambrosiaChance;

  /// Total card copies rolled from the chest.
  final int cardCopies;

  /// Probability that at least one copy is guaranteed rare-or-better.
  final double rareUpChance;

  Duration get unlockDuration => Duration(minutes: unlockMinutes);

  /// Shop price in gold (olympian is ambrosia-only).
  int get shopGoldPrice {
    switch (this) {
      case ChestTier.common:
        return 120;
      case ChestTier.rare:
        return 320;
      case ChestTier.epic:
        return 750;
      case ChestTier.olympian:
        return 0; // not sold for gold
    }
  }

  int get shopAmbrosiaPrice {
    switch (this) {
      case ChestTier.common:
        return 0;
      case ChestTier.rare:
        return 0;
      case ChestTier.epic:
        return 25;
      case ChestTier.olympian:
        return 60;
    }
  }
}

/// A chest sitting in one of the player's slots.
class ChestInstance {
  ChestInstance({required this.tier, this.unlockStart});

  final ChestTier tier;

  /// Null until the player taps "start unlocking".
  DateTime? unlockStart;

  bool get isUnlocking => unlockStart != null && !isReady;

  bool get isReady =>
      unlockStart != null &&
      DateTime.now().isAfter(unlockStart!.add(tier.unlockDuration));

  Duration get remaining {
    if (unlockStart == null) return tier.unlockDuration;
    final end = unlockStart!.add(tier.unlockDuration);
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'unlockStart': unlockStart?.toIso8601String(),
      };

  static ChestInstance fromJson(Map<String, dynamic> json) => ChestInstance(
        tier: ChestTier.values.firstWhere(
          (t) => t.name == json['tier'],
          orElse: () => ChestTier.common,
        ),
        unlockStart: json['unlockStart'] == null
            ? null
            : DateTime.tryParse(json['unlockStart'] as String),
      );
}

/// Everything found inside an opened chest.
class ChestContents {
  const ChestContents({
    required this.gold,
    required this.ambrosia,
    required this.cardCopies,
    this.relicId,
  });

  final int gold;
  final int ambrosia;

  /// cardId -> number of copies.
  final Map<String, int> cardCopies;

  /// Rarely a chest contains a relic the player doesn't own yet.
  final String? relicId;
}
