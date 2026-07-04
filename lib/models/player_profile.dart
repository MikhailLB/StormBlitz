import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/achievement_data.dart';
import '../data/card_data.dart';
import '../data/quest_data.dart';
import '../models/achievement.dart';
import 'chest.dart';
import 'quest.dart';

/// League tiers derived from trophies (visual only).
enum League { bronze, silver, gold, olympian }

extension LeagueInfo on League {
  String get label {
    switch (this) {
      case League.bronze:
        return 'Bronze League';
      case League.silver:
        return 'Silver League';
      case League.gold:
        return 'Gold League';
      case League.olympian:
        return 'Olympian League';
    }
  }

  int get threshold {
    switch (this) {
      case League.bronze:
        return 0;
      case League.silver:
        return 300;
      case League.gold:
        return 800;
      case League.olympian:
        return 1500;
    }
  }
}

/// The player's persistent meta-progression: currencies, card collection,
/// chest slots, quests, achievements, campaign clears, relics and stats.
///
/// Every mutation calls [_mutate], which notifies listeners and fires the
/// [onMutated] persistence hook (wired to ProfileRepository.save in main).
class PlayerProfile extends ChangeNotifier {
  PlayerProfile();

  /// Persistence hook; assigned once at startup.
  void Function()? onMutated;

  static const int chestSlotCount = 4;

  // --- Currencies ---
  int gold = 150;
  int ambrosia = 10;

  // --- Progression ---
  int trophies = 0;
  int xp = 0;
  int level = 1;
  int wins = 0;
  int losses = 0;

  // --- Collection ---
  /// Spare copies waiting to be spent on upgrades (cardId -> count).
  final Map<String, int> cardCopies = {};

  /// Current level of each card (default 1, max [maxCardLevel]).
  final Map<String, int> cardLevels = {};

  static const int maxCardLevel = 5;

  /// Copies required to go from level N to N+1 (index = current level - 1).
  static const List<int> upgradeCopies = [2, 4, 8, 12];

  /// Gold required to go from level N to N+1.
  static const List<int> upgradeGold = [50, 200, 450, 900];

  // --- Chests ---
  final List<ChestInstance?> chestSlots =
      List<ChestInstance?>.filled(chestSlotCount, null, growable: false);
  int chestsOpened = 0;

  // --- Quests ---
  List<QuestInstance> quests = [];
  DateTime? questRollDate;

  // --- Daily login ---
  DateTime? lastLoginDate;
  int loginStreak = 0;
  bool dailyBonusClaimed = false;

  // --- Achievements / titles / relics ---
  final Set<String> claimedAchievements = {};
  final Set<String> unlockedTitles = {};
  String? activeTitle;
  final Set<String> ownedRelics = {};
  String? equippedRelicId;

  // --- Campaign ---
  final Set<String> campaignClears = {};

  // --- Tutorial ---
  bool tutorialDone = false;

  // --- Lifetime counters (feed quests + achievements) ---
  int totalCardsPlayed = 0;
  int totalLegendariesPlayed = 0;
  int totalHeroDamage = 0;
  int totalMinionsDestroyed = 0;

  // ---------------------------------------------------------------------
  // Derived
  // ---------------------------------------------------------------------

  int cardLevel(String cardId) => cardLevels[cardId] ?? 1;
  int copiesOf(String cardId) => cardCopies[cardId] ?? 0;

  Map<String, int> get deckLevels =>
      {for (final c in CardData.roster()) c.id: cardLevel(c.id)};

  int get xpForNextLevel => 100 + (level - 1) * 50;

  League get league {
    var result = League.bronze;
    for (final l in League.values) {
      if (trophies >= l.threshold) result = l;
    }
    return result;
  }

  bool canUpgrade(String cardId) {
    final lvl = cardLevel(cardId);
    if (lvl >= maxCardLevel) return false;
    return copiesOf(cardId) >= upgradeCopies[lvl - 1] &&
        gold >= upgradeGold[lvl - 1];
  }

  int achievementProgress(Achievement a) {
    switch (a.goal) {
      case QuestGoal.winBattles:
        return wins;
      case QuestGoal.playCards:
        return totalCardsPlayed;
      case QuestGoal.dealHeroDamage:
        return totalHeroDamage;
      case QuestGoal.playLegendaries:
        return totalLegendariesPlayed;
      case QuestGoal.destroyMinions:
        return totalMinionsDestroyed;
      case QuestGoal.openChests:
        return chestsOpened;
    }
  }

  bool isAchievementComplete(Achievement a) =>
      achievementProgress(a) >= a.target;

  // ---------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------

  void _mutate() {
    notifyListeners();
    onMutated?.call();
  }

  void addGold(int amount) {
    gold += amount;
    _mutate();
  }

  void addAmbrosia(int amount) {
    ambrosia += amount;
    _mutate();
  }

  bool spendGold(int amount) {
    if (gold < amount) return false;
    gold -= amount;
    _mutate();
    return true;
  }

  bool spendAmbrosia(int amount) {
    if (ambrosia < amount) return false;
    ambrosia -= amount;
    _mutate();
    return true;
  }

  void addCardCopies(String cardId, int count) {
    cardCopies[cardId] = copiesOf(cardId) + count;
    _mutate();
  }

  /// Consumes copies + gold, raises the card's level by one.
  bool upgradeCard(String cardId) {
    if (!canUpgrade(cardId)) return false;
    final lvl = cardLevel(cardId);
    cardCopies[cardId] = copiesOf(cardId) - upgradeCopies[lvl - 1];
    gold -= upgradeGold[lvl - 1];
    cardLevels[cardId] = lvl + 1;
    _mutate();
    return true;
  }

  void addXp(int amount) {
    xp += amount;
    while (xp >= xpForNextLevel) {
      xp -= xpForNextLevel;
      level++;
    }
    _mutate();
  }

  /// Records the outcome of a battle and returns whether a chest was granted
  /// (chest may be lost if all slots are full).
  void recordBattleResult({required bool victory, required int trophyDelta}) {
    if (victory) {
      wins++;
    } else {
      losses++;
    }
    trophies = max(0, trophies + trophyDelta);
    _mutate();
  }

  // --- Chests ---

  int? freeChestSlot() {
    for (var i = 0; i < chestSlots.length; i++) {
      if (chestSlots[i] == null) return i;
    }
    return null;
  }

  bool get anyChestUnlocking => chestSlots.any((c) => c?.isUnlocking ?? false);

  /// Puts a chest into the first free slot. Returns the slot or null if full.
  int? grantChest(ChestTier tier) {
    final slot = freeChestSlot();
    if (slot == null) return null;
    chestSlots[slot] = ChestInstance(tier: tier);
    _mutate();
    return slot;
  }

  bool startUnlocking(int slot) {
    final chest = chestSlots[slot];
    if (chest == null || chest.unlockStart != null || anyChestUnlocking) {
      return false;
    }
    chest.unlockStart = DateTime.now();
    _mutate();
    return true;
  }

  /// Instantly finishes an unlocking chest for ambrosia.
  bool rushChest(int slot, int ambrosiaCost) {
    final chest = chestSlots[slot];
    if (chest == null || chest.unlockStart == null || chest.isReady) {
      return false;
    }
    if (!spendAmbrosia(ambrosiaCost)) return false;
    chest.unlockStart =
        DateTime.now().subtract(chest.tier.unlockDuration);
    _mutate();
    return true;
  }

  /// Applies chest contents to the profile and clears the slot.
  void applyChestContents(int slot, ChestContents contents) {
    chestSlots[slot] = null;
    chestsOpened++;
    gold += contents.gold;
    ambrosia += contents.ambrosia;
    contents.cardCopies.forEach((id, n) {
      cardCopies[id] = copiesOf(id) + n;
    });
    if (contents.relicId != null) ownedRelics.add(contents.relicId!);
    addQuestProgress(QuestGoal.openChests, 1);
    _mutate();
  }

  // --- Quests ---

  /// Rolls a fresh daily set if 24h passed (or none exist yet).
  void refreshDailyQuests(Random rng) {
    final now = DateTime.now();
    final needsRoll = questRollDate == null ||
        now.difference(questRollDate!).inHours >= 24;
    if (needsRoll) {
      quests = QuestData.rollDaily(rng);
      questRollDate = now;
    }

    // Daily login streak.
    final today = DateTime(now.year, now.month, now.day);
    if (lastLoginDate == null) {
      loginStreak = 1;
      dailyBonusClaimed = false;
      lastLoginDate = today;
    } else {
      final last = DateTime(
          lastLoginDate!.year, lastLoginDate!.month, lastLoginDate!.day);
      final gap = today.difference(last).inDays;
      if (gap == 1) {
        loginStreak++;
        dailyBonusClaimed = false;
        lastLoginDate = today;
      } else if (gap > 1) {
        loginStreak = 1;
        dailyBonusClaimed = false;
        lastLoginDate = today;
      }
    }
    _mutate();
  }

  int get dailyBonusGold => 40 + 10 * min(loginStreak - 1, 6);

  bool claimDailyBonus() {
    if (dailyBonusClaimed) return false;
    dailyBonusClaimed = true;
    gold += dailyBonusGold;
    _mutate();
    return true;
  }

  void addQuestProgress(QuestGoal goal, int amount) {
    var changed = false;
    for (final q in quests) {
      if (q.template.goal == goal && !q.claimed && !q.isComplete) {
        q.progress = min(q.progress + amount, q.template.target);
        changed = true;
      }
    }
    if (changed) _mutate();
  }

  bool claimQuest(QuestInstance quest) {
    if (!quest.isComplete || quest.claimed) return false;
    quest.claimed = true;
    gold += quest.template.goldReward;
    ambrosia += quest.template.ambrosiaReward;
    _mutate();
    return true;
  }

  // --- Achievements ---

  bool claimAchievement(Achievement a) {
    if (claimedAchievements.contains(a.id) || !isAchievementComplete(a)) {
      return false;
    }
    claimedAchievements.add(a.id);
    gold += a.goldReward;
    ambrosia += a.ambrosiaReward;
    if (a.titleReward != null) unlockedTitles.add(a.titleReward!);
    if (a.relicReward != null) ownedRelics.add(a.relicReward!);
    _mutate();
    return true;
  }

  void setActiveTitle(String? title) {
    activeTitle = title;
    _mutate();
  }

  void equipRelic(String? relicId) {
    equippedRelicId = relicId;
    _mutate();
  }

  // --- Campaign ---

  bool markCampaignClear(String nodeId) {
    final first = campaignClears.add(nodeId);
    if (first) _mutate();
    return first;
  }

  void markTutorialDone() {
    if (tutorialDone) return;
    tutorialDone = true;
    _mutate();
  }

  // --- Battle counters ---

  void recordBattleStats({
    required int cardsPlayed,
    required int legendariesPlayed,
    required int heroDamage,
    required int minionsDestroyed,
  }) {
    totalCardsPlayed += cardsPlayed;
    totalLegendariesPlayed += legendariesPlayed;
    totalHeroDamage += heroDamage;
    totalMinionsDestroyed += minionsDestroyed;
    addQuestProgress(QuestGoal.playCards, cardsPlayed);
    addQuestProgress(QuestGoal.playLegendaries, legendariesPlayed);
    addQuestProgress(QuestGoal.dealHeroDamage, heroDamage);
    addQuestProgress(QuestGoal.destroyMinions, minionsDestroyed);
    _mutate();
  }

  void resetAll() {
    gold = 150;
    ambrosia = 10;
    trophies = 0;
    xp = 0;
    level = 1;
    wins = 0;
    losses = 0;
    cardCopies.clear();
    cardLevels.clear();
    for (var i = 0; i < chestSlots.length; i++) {
      chestSlots[i] = null;
    }
    chestsOpened = 0;
    quests = [];
    questRollDate = null;
    lastLoginDate = null;
    loginStreak = 0;
    dailyBonusClaimed = false;
    claimedAchievements.clear();
    unlockedTitles.clear();
    activeTitle = null;
    ownedRelics.clear();
    equippedRelicId = null;
    campaignClears.clear();
    tutorialDone = false;
    totalCardsPlayed = 0;
    totalLegendariesPlayed = 0;
    totalHeroDamage = 0;
    totalMinionsDestroyed = 0;
    _mutate();
  }

  // ---------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'gold': gold,
        'ambrosia': ambrosia,
        'trophies': trophies,
        'xp': xp,
        'level': level,
        'wins': wins,
        'losses': losses,
        'cardCopies': cardCopies,
        'cardLevels': cardLevels,
        'chestSlots': [for (final c in chestSlots) c?.toJson()],
        'chestsOpened': chestsOpened,
        'quests': [for (final q in quests) q.toJson()],
        'questRollDate': questRollDate?.toIso8601String(),
        'lastLoginDate': lastLoginDate?.toIso8601String(),
        'loginStreak': loginStreak,
        'dailyBonusClaimed': dailyBonusClaimed,
        'claimedAchievements': claimedAchievements.toList(),
        'unlockedTitles': unlockedTitles.toList(),
        'activeTitle': activeTitle,
        'ownedRelics': ownedRelics.toList(),
        'equippedRelicId': equippedRelicId,
        'campaignClears': campaignClears.toList(),
        'tutorialDone': tutorialDone,
        'totalCardsPlayed': totalCardsPlayed,
        'totalLegendariesPlayed': totalLegendariesPlayed,
        'totalHeroDamage': totalHeroDamage,
        'totalMinionsDestroyed': totalMinionsDestroyed,
      };

  static PlayerProfile fromJson(Map<String, dynamic> json) {
    final p = PlayerProfile();
    p.gold = json['gold'] as int? ?? 150;
    p.ambrosia = json['ambrosia'] as int? ?? 10;
    p.trophies = json['trophies'] as int? ?? 0;
    p.xp = json['xp'] as int? ?? 0;
    p.level = json['level'] as int? ?? 1;
    p.wins = json['wins'] as int? ?? 0;
    p.losses = json['losses'] as int? ?? 0;

    (json['cardCopies'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => p.cardCopies[k] = v as int);
    (json['cardLevels'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => p.cardLevels[k] = v as int);

    final slots = json['chestSlots'] as List<dynamic>? ?? [];
    for (var i = 0; i < p.chestSlots.length && i < slots.length; i++) {
      final s = slots[i];
      if (s != null) {
        p.chestSlots[i] = ChestInstance.fromJson(s as Map<String, dynamic>);
      }
    }
    p.chestsOpened = json['chestsOpened'] as int? ?? 0;

    for (final q in json['quests'] as List<dynamic>? ?? []) {
      final map = q as Map<String, dynamic>;
      final template = QuestData.byId(map['id'] as String? ?? '');
      if (template != null) {
        p.quests.add(QuestInstance(
          template: template,
          progress: map['progress'] as int? ?? 0,
          claimed: map['claimed'] as bool? ?? false,
        ));
      }
    }
    p.questRollDate = json['questRollDate'] == null
        ? null
        : DateTime.tryParse(json['questRollDate'] as String);
    p.lastLoginDate = json['lastLoginDate'] == null
        ? null
        : DateTime.tryParse(json['lastLoginDate'] as String);
    p.loginStreak = json['loginStreak'] as int? ?? 0;
    p.dailyBonusClaimed = json['dailyBonusClaimed'] as bool? ?? false;

    for (final id in json['claimedAchievements'] as List<dynamic>? ?? []) {
      if (AchievementData.byId(id as String) != null) {
        p.claimedAchievements.add(id);
      }
    }
    for (final t in json['unlockedTitles'] as List<dynamic>? ?? []) {
      p.unlockedTitles.add(t as String);
    }
    p.activeTitle = json['activeTitle'] as String?;
    for (final r in json['ownedRelics'] as List<dynamic>? ?? []) {
      p.ownedRelics.add(r as String);
    }
    p.equippedRelicId = json['equippedRelicId'] as String?;
    for (final c in json['campaignClears'] as List<dynamic>? ?? []) {
      p.campaignClears.add(c as String);
    }
    p.tutorialDone = json['tutorialDone'] as bool? ?? false;
    p.totalCardsPlayed = json['totalCardsPlayed'] as int? ?? 0;
    p.totalLegendariesPlayed = json['totalLegendariesPlayed'] as int? ?? 0;
    p.totalHeroDamage = json['totalHeroDamage'] as int? ?? 0;
    p.totalMinionsDestroyed = json['totalMinionsDestroyed'] as int? ?? 0;
    return p;
  }
}
