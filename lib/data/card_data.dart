import 'dart:math';

import '../models/game_card.dart';

/// The full roster of 10 Olympian gods. Each side's deck is built from two
/// copies of every card (20 cards total), giving a focused, replayable pool.
class CardData {
  static const String _assetDir = 'assets/';

  /// Cards that unlock a bonus combat keyword at collection level 3+.
  static const String frenzyCardId = 'ares';
  static const String lifestealCardId = 'hades';

  static List<GameCard> roster() => [
        GameCard(
          id: 'zeus',
          name: 'Zeus',
          title: 'King of Olympus',
          asset: '${_assetDir}Zeus.webp',
          cost: 7,
          attack: 7,
          health: 7,
          rarity: Rarity.legendary,
          battlecry: Battlecry.stormStrike,
          battlecryValue: 3,
          description: 'Battlecry: Deal 3 damage to all enemy minions and 1 to the enemy hero.',
        ),
        GameCard(
          id: 'poseidon',
          name: 'Poseidon',
          title: 'Lord of the Seas',
          asset: '${_assetDir}Poseidon.webp',
          cost: 6,
          attack: 6,
          health: 6,
          rarity: Rarity.legendary,
          battlecry: Battlecry.tidalWave,
          battlecryValue: 4,
          description: 'Battlecry: Deal 4 damage to the enemy hero.',
        ),
        GameCard(
          id: 'hera',
          name: 'Hera',
          title: 'Queen of Gods',
          asset: '${_assetDir}Hera.webp',
          cost: 6,
          attack: 5,
          health: 7,
          rarity: Rarity.rare,
          battlecry: Battlecry.royalDecree,
          description: 'Battlecry: Give all your minions +1/+1.',
        ),
        GameCard(
          id: 'hades',
          name: 'Hades',
          title: 'God of the Underworld',
          asset: '${_assetDir}Hades.webp',
          cost: 5,
          attack: 5,
          health: 6,
          rarity: Rarity.rare,
          keyword: Keyword.taunt,
          description: 'Taunt. A grim wall the enemy must break through.',
        ),
        GameCard(
          id: 'prometheus',
          name: 'Prometheus',
          title: 'Bringer of Fire',
          asset: '${_assetDir}Prometheus.webp',
          cost: 5,
          attack: 4,
          health: 4,
          rarity: Rarity.rare,
          battlecry: Battlecry.sacredFire,
          description: 'Battlecry: Give your other minions +1/+1.',
        ),
        GameCard(
          id: 'athena',
          name: 'Athena',
          title: 'Goddess of Wisdom',
          asset: '${_assetDir}Athena.webp',
          cost: 4,
          attack: 3,
          health: 7,
          rarity: Rarity.rare,
          keyword: Keyword.taunt,
          description: 'Taunt. Her aegis shields your forces.',
        ),
        GameCard(
          id: 'ares',
          name: 'Ares',
          title: 'God of War',
          asset: '${_assetDir}Ares.webp',
          cost: 4,
          attack: 5,
          health: 4,
          rarity: Rarity.common,
          keyword: Keyword.charge,
          description: 'Charge. Strikes the moment he enters the battle.',
        ),
        GameCard(
          id: 'apollo',
          name: 'Apollo',
          title: 'God of the Sun',
          asset: '${_assetDir}Apollo.webp',
          cost: 3,
          attack: 2,
          health: 4,
          rarity: Rarity.common,
          battlecry: Battlecry.sunBlessing,
          battlecryValue: 5,
          description: 'Battlecry: Restore 5 health to your hero.',
        ),
        GameCard(
          id: 'artemis',
          name: 'Artemis',
          title: 'Goddess of the Hunt',
          asset: '${_assetDir}Artemis.webp',
          cost: 3,
          attack: 4,
          health: 3,
          rarity: Rarity.common,
          battlecry: Battlecry.huntersArrow,
          battlecryValue: 3,
          description: 'Battlecry: Deal 3 damage to a random enemy minion.',
        ),
        GameCard(
          id: 'hermes',
          name: 'Hermes',
          title: 'The Messenger',
          asset: '${_assetDir}Hermes.webp',
          cost: 2,
          attack: 2,
          health: 3,
          rarity: Rarity.common,
          keyword: Keyword.charge,
          battlecry: Battlecry.swiftMessage,
          description: 'Charge. Battlecry: Draw a card.',
        ),
      ];

  /// Scales a base stat by collection level: +6% per level above 1, but
  /// never less than +1 per two levels so cheap cards still progress.
  static int scaledStat(int base, int level) {
    if (level <= 1) return base;
    final pct = (base * 0.06 * (level - 1)).round();
    final floor = (level - 1) ~/ 2;
    return base + max(pct, floor);
  }

  /// Builds a level-adjusted copy of [card]:
  ///  - stats scaled by [scaledStat]
  ///  - level 3+: Ares gains Frenzy, Hades gains Lifesteal
  ///  - level 5 (Ascension): starts with a Divine Shield
  static GameCard atLevel(GameCard card, int level) {
    final lvl = level.clamp(1, 5);
    return GameCard(
      id: card.id,
      name: card.name,
      title: card.title,
      asset: card.asset,
      cost: card.cost,
      attack: scaledStat(card.attack, lvl),
      health: scaledStat(card.health, lvl),
      rarity: card.rarity,
      keyword: card.keyword,
      battlecry: card.battlecry,
      battlecryValue: card.battlecryValue,
      description: card.description,
      level: lvl,
      frenzy: card.id == frenzyCardId && lvl >= 3,
      lifesteal: card.id == lifestealCardId && lvl >= 3,
      divineShield: lvl >= 5,
    );
  }

  /// Builds a 20-card deck (2 copies of each god) of fresh, playable clones.
  /// [levels] applies the player's collection levels (AI decks pass null).
  static List<GameCard> buildDeck({Map<String, int>? levels}) {
    final deck = <GameCard>[];
    for (final card in roster()) {
      final lvl = levels?[card.id] ?? 1;
      final template = lvl > 1 ? atLevel(card, lvl) : card;
      deck.add(template.clone());
      deck.add(template.clone());
    }
    return deck;
  }
}
