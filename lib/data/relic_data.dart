import 'package:flutter/material.dart';

import '../models/relic.dart';
import '../theme/app_theme.dart';

/// The six relics of Olympus. Obtained from chests and achievements,
/// equipped one at a time before battle.
class RelicData {
  static const List<Relic> all = [
    Relic(
      id: 'aegis_of_athena',
      name: 'Aegis of Athena',
      description: 'Your Taunt gods enter the battlefield with +2 Health.',
      effect: RelicEffect.tauntBonusHp,
      value: 2,
      icon: Icons.shield,
      color: AppColors.rare,
    ),
    Relic(
      id: 'sandals_of_hermes',
      name: 'Sandals of Hermes',
      description: 'The first card you play each turn costs 1 less mana.',
      effect: RelicEffect.firstCardDiscount,
      value: 1,
      icon: Icons.directions_run,
      color: AppColors.lightning,
    ),
    Relic(
      id: 'ember_of_prometheus',
      name: 'Ember of Prometheus',
      description: 'Your damaging Battlecries deal +1 damage.',
      effect: RelicEffect.battlecryDamageUp,
      value: 1,
      icon: Icons.local_fire_department,
      color: AppColors.attackOrange,
    ),
    Relic(
      id: 'heart_of_gaia',
      name: 'Heart of Gaia',
      description: 'Your hero starts every battle with +5 max Health.',
      effect: RelicEffect.heroBonusHp,
      value: 5,
      icon: Icons.favorite,
      color: AppColors.hpRed,
    ),
    Relic(
      id: 'scroll_of_fate',
      name: 'Scroll of Fate',
      description: 'Begin each battle with 1 extra card in hand.',
      effect: RelicEffect.extraStartingCard,
      value: 1,
      icon: Icons.auto_stories,
      color: AppColors.gold,
    ),
    Relic(
      id: 'chalice_of_apollo',
      name: 'Chalice of Apollo',
      description: 'Your healing effects restore +2 Health.',
      effect: RelicEffect.healingBoost,
      value: 2,
      icon: Icons.wb_sunny,
      color: AppColors.goldLight,
    ),
  ];

  static Relic? byId(String? id) {
    if (id == null) return null;
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }
}
