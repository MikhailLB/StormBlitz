import 'dart:math';

import '../models/quest.dart';

/// Pool of daily quest templates; three are active at any time and the set
/// re-rolls every 24 hours.
class QuestData {
  static const List<QuestTemplate> pool = [
    QuestTemplate(
      id: 'win_2',
      goal: QuestGoal.winBattles,
      title: 'Win 2 battles',
      target: 2,
      goldReward: 80,
    ),
    QuestTemplate(
      id: 'win_3',
      goal: QuestGoal.winBattles,
      title: 'Win 3 battles',
      target: 3,
      goldReward: 120,
      ambrosiaReward: 3,
    ),
    QuestTemplate(
      id: 'play_12_cards',
      goal: QuestGoal.playCards,
      title: 'Summon 12 gods',
      target: 12,
      goldReward: 70,
    ),
    QuestTemplate(
      id: 'hero_damage_25',
      goal: QuestGoal.dealHeroDamage,
      title: 'Deal 25 damage to enemy heroes',
      target: 25,
      goldReward: 90,
    ),
    QuestTemplate(
      id: 'play_2_legendaries',
      goal: QuestGoal.playLegendaries,
      title: 'Summon 2 Legendary gods',
      target: 2,
      goldReward: 100,
      ambrosiaReward: 2,
    ),
    QuestTemplate(
      id: 'destroy_8_minions',
      goal: QuestGoal.destroyMinions,
      title: 'Destroy 8 enemy gods',
      target: 8,
      goldReward: 90,
    ),
    QuestTemplate(
      id: 'open_2_chests',
      goal: QuestGoal.openChests,
      title: 'Open 2 chests',
      target: 2,
      goldReward: 60,
    ),
  ];

  static QuestTemplate? byId(String id) {
    for (final t in pool) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Picks [count] distinct random templates for a fresh daily set.
  static List<QuestInstance> rollDaily(Random rng, {int count = 3}) {
    final shuffled = [...pool]..shuffle(rng);
    return shuffled.take(count).map((t) => QuestInstance(template: t)).toList();
  }
}
