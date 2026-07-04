import 'package:flutter/material.dart';

/// Passive battle modifier. The player equips at most one relic per battle.
enum RelicEffect {
  /// Taunt minions enter play with bonus health.
  tauntBonusHp,

  /// The first card played each turn costs 1 less (min 0).
  firstCardDiscount,

  /// Battlecry damage values are increased by 1.
  battlecryDamageUp,

  /// Your hero starts the battle with bonus max HP.
  heroBonusHp,

  /// Start the battle with one extra card in hand.
  extraStartingCard,

  /// Healing effects restore 2 more health.
  healingBoost,
}

class Relic {
  const Relic({
    required this.id,
    required this.name,
    required this.description,
    required this.effect,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String description;
  final RelicEffect effect;
  final int value;
  final IconData icon;
  final Color color;
}
