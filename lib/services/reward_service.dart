import 'dart:math';

import '../data/card_data.dart';
import '../data/relic_data.dart';
import '../game/game_controller.dart';
import '../models/chest.dart';
import '../models/game_card.dart';

/// Everything the player takes home from one battle.
class BattleRewards {
  const BattleRewards({
    required this.gold,
    required this.xp,
    required this.trophyDelta,
    this.chestTier,
  });

  final int gold;
  final int xp;
  final int trophyDelta;

  /// Victory drop; null on defeat (or when a campaign node was re-cleared).
  final ChestTier? chestTier;
}

/// Pure reward math: battle payouts and chest content rolls.
class RewardService {
  RewardService({Random? rng}) : _rng = rng ?? Random();

  final Random _rng;

  // -------------------------------------------------------------------
  // Battle payouts
  // -------------------------------------------------------------------

  BattleRewards battleRewards({
    required Difficulty difficulty,
    required bool victory,
  }) {
    if (!victory) {
      return BattleRewards(
        gold: 10,
        xp: 15,
        trophyDelta: difficulty.trophyLoss,
      );
    }
    final baseGold = switch (difficulty) {
      Difficulty.easy => 35,
      Difficulty.normal => 55,
      Difficulty.hard => 80,
      Difficulty.olympian => 120,
    };
    return BattleRewards(
      gold: baseGold + _rng.nextInt(16),
      xp: switch (difficulty) {
        Difficulty.easy => 40,
        Difficulty.normal => 60,
        Difficulty.hard => 85,
        Difficulty.olympian => 120,
      },
      trophyDelta: difficulty.trophyWin,
      chestTier: _rollChestTier(difficulty),
    );
  }

  ChestTier _rollChestTier(Difficulty difficulty) {
    final roll = _rng.nextDouble();
    switch (difficulty) {
      case Difficulty.easy:
        return roll < 0.75 ? ChestTier.common : ChestTier.rare;
      case Difficulty.normal:
        if (roll < 0.50) return ChestTier.common;
        if (roll < 0.90) return ChestTier.rare;
        return ChestTier.epic;
      case Difficulty.hard:
        if (roll < 0.30) return ChestTier.common;
        if (roll < 0.75) return ChestTier.rare;
        if (roll < 0.95) return ChestTier.epic;
        return ChestTier.olympian;
      case Difficulty.olympian:
        if (roll < 0.15) return ChestTier.rare;
        if (roll < 0.60) return ChestTier.epic;
        return ChestTier.olympian;
    }
  }

  // -------------------------------------------------------------------
  // Chest contents
  // -------------------------------------------------------------------

  /// Rolls what's inside a chest of [tier]. [ownedRelicIds] lets epic+
  /// chests occasionally drop a relic the player doesn't own yet.
  ChestContents rollChestContents(
    ChestTier tier, {
    Set<String> ownedRelicIds = const {},
  }) {
    final gold =
        tier.minGold + _rng.nextInt(tier.maxGold - tier.minGold + 1);

    var ambrosia = 0;
    if (_rng.nextDouble() < tier.ambrosiaChance) {
      ambrosia = switch (tier) {
        ChestTier.common => 2 + _rng.nextInt(3),
        ChestTier.rare => 4 + _rng.nextInt(5),
        ChestTier.epic => 8 + _rng.nextInt(8),
        ChestTier.olympian => 18 + _rng.nextInt(13),
      };
    }

    final copies = <String, int>{};
    final roster = CardData.roster();
    var guaranteedRareUp = _rng.nextDouble() < tier.rareUpChance;
    for (var i = 0; i < tier.cardCopies; i++) {
      GameCard picked;
      if (guaranteedRareUp) {
        final rareUp =
            roster.where((c) => c.rarity != Rarity.common).toList();
        picked = rareUp[_rng.nextInt(rareUp.length)];
        guaranteedRareUp = false;
      } else {
        picked = _weightedPick(roster);
      }
      copies[picked.id] = (copies[picked.id] ?? 0) + 1;
    }

    String? relicId;
    final relicChance = switch (tier) {
      ChestTier.common => 0.0,
      ChestTier.rare => 0.05,
      ChestTier.epic => 0.15,
      ChestTier.olympian => 0.35,
    };
    if (_rng.nextDouble() < relicChance) {
      final unowned =
          RelicData.all.where((r) => !ownedRelicIds.contains(r.id)).toList();
      if (unowned.isNotEmpty) {
        relicId = unowned[_rng.nextInt(unowned.length)].id;
      }
    }

    return ChestContents(
      gold: gold,
      ambrosia: ambrosia,
      cardCopies: copies,
      relicId: relicId,
    );
  }

  /// Common cards drop far more often than legendaries.
  GameCard _weightedPick(List<GameCard> roster) {
    final weights = roster
        .map((c) => switch (c.rarity) {
              Rarity.common => 10,
              Rarity.rare => 5,
              Rarity.legendary => 2,
            })
        .toList();
    final total = weights.fold<int>(0, (s, w) => s + w);
    var roll = _rng.nextInt(total);
    for (var i = 0; i < roster.length; i++) {
      roll -= weights[i];
      if (roll < 0) return roster[i];
    }
    return roster.last;
  }
}
