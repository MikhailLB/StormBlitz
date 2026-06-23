import 'package:flutter/foundation.dart';

/// Rarity tiers drive the visual frame of a card.
enum Rarity { common, rare, legendary }

/// Keyword abilities a god card can carry.
enum Keyword {
  none,

  /// Can attack the turn it is played.
  charge,

  /// Enemies must attack this minion first.
  taunt,
}

/// Battlecry effects trigger automatically when the card is played.
/// They are auto-resolved so the player never has to manually pick a target,
/// which keeps the touch UX simple on mobile.
enum Battlecry {
  none,

  /// Deal [value] damage to every enemy minion + 1 to the enemy hero.
  stormStrike,

  /// Deal [value] damage to the enemy hero.
  tidalWave,

  /// Restore [value] health to your own hero.
  sunBlessing,

  /// Deal [value] damage to a random enemy minion.
  huntersArrow,

  /// Give your OTHER minions +1/+1.
  sacredFire,

  /// Give ALL your minions +1/+1.
  royalDecree,

  /// Draw a card.
  swiftMessage,
}

/// A single god card. Instances on the board are mutable (health changes,
/// summoning sickness, buffs), so each played card is a fresh clone.
class GameCard {
  GameCard({
    required this.id,
    required this.name,
    required this.title,
    required this.asset,
    required this.cost,
    required this.attack,
    required this.health,
    required this.rarity,
    this.keyword = Keyword.none,
    this.battlecry = Battlecry.none,
    this.battlecryValue = 0,
    required this.description,
    int? currentHealth,
    this.canAttack = false,
  }) : currentHealth = currentHealth ?? health;

  final String id;
  final String name;
  final String title;
  final String asset;
  final int cost;

  int attack;
  int health;
  int currentHealth;

  final Rarity rarity;
  final Keyword keyword;
  final Battlecry battlecry;
  final int battlecryValue;
  final String description;

  /// False right after being summoned (summoning sickness), unless it has Charge.
  bool canAttack;

  /// Unique per-instance handle so the UI can key/animate individual minions.
  final int instanceId = _instanceCounter++;
  static int _instanceCounter = 0;

  bool get isDead => currentHealth <= 0;
  bool get hasTaunt => keyword == Keyword.taunt;

  /// Returns a fresh playable copy (used when moving from deck -> hand -> board).
  GameCard clone() {
    return GameCard(
      id: id,
      name: name,
      title: title,
      asset: asset,
      cost: cost,
      attack: attack,
      health: health,
      rarity: rarity,
      keyword: keyword,
      battlecry: battlecry,
      battlecryValue: battlecryValue,
      description: description,
      currentHealth: health,
      canAttack: keyword == Keyword.charge,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameCard && other.instanceId == instanceId;

  @override
  int get hashCode => instanceId;
}

@immutable
class GameCardLog {
  const GameCardLog(this.message);
  final String message;
}
