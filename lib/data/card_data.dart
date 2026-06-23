import '../models/game_card.dart';

/// The full roster of 10 Olympian gods. Each side's deck is built from two
/// copies of every card (20 cards total), giving a focused, replayable pool.
class CardData {
  static const String _assetDir = 'assets/';

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

  /// Builds a 20-card deck (2 copies of each god) of fresh, playable clones.
  static List<GameCard> buildDeck() {
    final deck = <GameCard>[];
    for (final card in roster()) {
      deck.add(card.clone());
      deck.add(card.clone());
    }
    return deck;
  }
}
