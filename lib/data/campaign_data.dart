import '../game/game_controller.dart';

/// A single node of the "Pantheon Trials" campaign.
class CampaignNode {
  const CampaignNode({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.difficulty,
    required this.goldReward,
    this.ambrosiaReward = 0,
    this.aiHpOverride,
    this.bossEnrage = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final Difficulty difficulty;

  /// First-clear rewards.
  final int goldReward;
  final int ambrosiaReward;

  /// Some trials pit you against a beefier hero.
  final int? aiHpOverride;

  /// Boss mechanic: from turn 6 onward all enemy minions gain +2 attack.
  final bool bossEnrage;
}

class CampaignData {
  static const List<CampaignNode> nodes = [
    CampaignNode(
      id: 'trial_1',
      name: 'Foothills of Olympus',
      subtitle: 'A gentle climb begins.',
      difficulty: Difficulty.easy,
      goldReward: 80,
    ),
    CampaignNode(
      id: 'trial_2',
      name: 'Grove of Artemis',
      subtitle: 'Arrows whistle between the trees.',
      difficulty: Difficulty.easy,
      goldReward: 100,
    ),
    CampaignNode(
      id: 'trial_3',
      name: 'Forge of Hephaestus',
      subtitle: 'The heat tempers your resolve.',
      difficulty: Difficulty.normal,
      goldReward: 130,
      ambrosiaReward: 3,
    ),
    CampaignNode(
      id: 'trial_4',
      name: 'Agora of Athens',
      subtitle: 'Wisdom cuts deeper than blades.',
      difficulty: Difficulty.normal,
      goldReward: 150,
    ),
    CampaignNode(
      id: 'trial_5',
      name: 'Halls of the Underworld',
      subtitle: 'Hades bars every door.',
      difficulty: Difficulty.normal,
      goldReward: 180,
      ambrosiaReward: 5,
      aiHpOverride: 34,
    ),
    CampaignNode(
      id: 'trial_6',
      name: 'Poseidon\'s Deep',
      subtitle: 'The sea itself fights back.',
      difficulty: Difficulty.hard,
      goldReward: 220,
    ),
    CampaignNode(
      id: 'trial_7',
      name: 'Peak of Storms',
      subtitle: 'Zeus watches. Zeus judges.',
      difficulty: Difficulty.hard,
      goldReward: 260,
      ambrosiaReward: 8,
      aiHpOverride: 36,
    ),
    CampaignNode(
      id: 'trial_8',
      name: 'Council Chamber',
      subtitle: 'All of Olympus stands against you.',
      difficulty: Difficulty.olympian,
      goldReward: 320,
      ambrosiaReward: 10,
    ),
    CampaignNode(
      id: 'trial_9',
      name: 'Wrath of the Titan',
      subtitle: 'Enrages after turn 6. Survive the fury.',
      difficulty: Difficulty.olympian,
      goldReward: 500,
      ambrosiaReward: 25,
      aiHpOverride: 40,
      bossEnrage: true,
    ),
  ];

  static CampaignNode? byId(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  static int indexOf(String id) => nodes.indexWhere((n) => n.id == id);
}
