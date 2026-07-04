import 'quest.dart';

/// A permanent milestone. Progress is derived from PlayerProfile counters,
/// so only the "claimed" flag needs to be persisted.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.target,
    required this.goldReward,
    this.ambrosiaReward = 0,
    this.titleReward,
    this.relicReward,
  });

  final String id;
  final String title;
  final String description;

  /// Reuses QuestGoal kinds plus profile-level counters resolved in
  /// PlayerProfile.achievementProgress().
  final QuestGoal goal;
  final int target;
  final int goldReward;
  final int ambrosiaReward;

  /// Player title unlocked by this achievement (shown on the profile).
  final String? titleReward;

  /// Relic id granted by this achievement.
  final String? relicReward;
}
