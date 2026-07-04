import '../models/achievement.dart';
import '../models/quest.dart';

/// Permanent milestones. Progress is computed from PlayerProfile counters.
class AchievementData {
  static const List<Achievement> all = [
    Achievement(
      id: 'first_win',
      title: 'First Spark',
      description: 'Win your first battle.',
      goal: QuestGoal.winBattles,
      target: 1,
      goldReward: 100,
      titleReward: 'Sparkbearer',
    ),
    Achievement(
      id: 'win_10',
      title: 'Storm Adept',
      description: 'Win 10 battles.',
      goal: QuestGoal.winBattles,
      target: 10,
      goldReward: 250,
      ambrosiaReward: 10,
      titleReward: 'Storm Adept',
    ),
    Achievement(
      id: 'win_25',
      title: 'Lord of Storms',
      description: 'Win 25 battles.',
      goal: QuestGoal.winBattles,
      target: 25,
      goldReward: 500,
      ambrosiaReward: 20,
      titleReward: 'Lord of Storms',
      relicReward: 'heart_of_gaia',
    ),
    Achievement(
      id: 'play_100_cards',
      title: 'Divine Summoner',
      description: 'Summon 100 gods across all battles.',
      goal: QuestGoal.playCards,
      target: 100,
      goldReward: 300,
      titleReward: 'Divine Summoner',
    ),
    Achievement(
      id: 'open_5_chests',
      title: 'Treasure Seeker',
      description: 'Open 5 chests.',
      goal: QuestGoal.openChests,
      target: 5,
      goldReward: 150,
      relicReward: 'scroll_of_fate',
    ),
    Achievement(
      id: 'open_15_chests',
      title: 'Vault of Olympus',
      description: 'Open 15 chests.',
      goal: QuestGoal.openChests,
      target: 15,
      goldReward: 400,
      ambrosiaReward: 15,
      titleReward: 'Keeper of Vaults',
    ),
    Achievement(
      id: 'destroy_50_minions',
      title: 'Godslayer',
      description: 'Destroy 50 enemy gods.',
      goal: QuestGoal.destroyMinions,
      target: 50,
      goldReward: 350,
      titleReward: 'Godslayer',
      relicReward: 'ember_of_prometheus',
    ),
    Achievement(
      id: 'hero_damage_500',
      title: 'Heavensbreaker',
      description: 'Deal 500 total damage to enemy heroes.',
      goal: QuestGoal.dealHeroDamage,
      target: 500,
      goldReward: 400,
      ambrosiaReward: 10,
      titleReward: 'Heavensbreaker',
    ),
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
