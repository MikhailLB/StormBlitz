/// What kind of in-game action a quest counts.
enum QuestGoal {
  winBattles,
  playCards,
  dealHeroDamage,
  playLegendaries,
  destroyMinions,
  openChests,
}

/// Static template for a daily quest (see quest_data.dart for the pool).
class QuestTemplate {
  const QuestTemplate({
    required this.id,
    required this.goal,
    required this.title,
    required this.target,
    required this.goldReward,
    this.ambrosiaReward = 0,
  });

  final String id;
  final QuestGoal goal;
  final String title;
  final int target;
  final int goldReward;
  final int ambrosiaReward;
}

/// One of the player's active daily quests with live progress.
class QuestInstance {
  QuestInstance({
    required this.template,
    this.progress = 0,
    this.claimed = false,
  });

  final QuestTemplate template;
  int progress;
  bool claimed;

  bool get isComplete => progress >= template.target;
  double get fraction => (progress / template.target).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': template.id,
        'progress': progress,
        'claimed': claimed,
      };
}
