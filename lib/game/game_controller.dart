import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/card_data.dart';
import '../models/game_card.dart';
import '../models/player.dart';
import '../models/relic.dart';
import 'ai_strategy.dart';

enum GamePhase { playing, victory, defeat }

enum Difficulty { easy, normal, hard, olympian }

extension DifficultyInfo on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.normal:
        return 'Normal';
      case Difficulty.hard:
        return 'Hard';
      case Difficulty.olympian:
        return 'Olympian';
    }
  }

  String get blurb {
    switch (this) {
      case Difficulty.easy:
        return 'The AI is forgiving and often hesitates.';
      case Difficulty.normal:
        return 'A balanced, fair opponent.';
      case Difficulty.hard:
        return 'A ruthless tactician that hunts for lethal.';
      case Difficulty.olympian:
        return 'A divine mind that weighs every possible move.';
    }
  }

  /// Opening hand size for the AI.
  int get aiOpeningHand {
    switch (this) {
      case Difficulty.easy:
        return 3;
      case Difficulty.normal:
        return 4;
      case Difficulty.hard:
        return 5;
      case Difficulty.olympian:
        return 5;
    }
  }

  /// Enemy hero starting HP.
  int get aiHp {
    switch (this) {
      case Difficulty.easy:
        return 24;
      case Difficulty.normal:
        return 30;
      case Difficulty.hard:
        return 30;
      case Difficulty.olympian:
        return 32;
    }
  }

  /// Trophy stakes: gained on victory / lost on defeat.
  int get trophyWin {
    switch (this) {
      case Difficulty.easy:
        return 15;
      case Difficulty.normal:
        return 25;
      case Difficulty.hard:
        return 35;
      case Difficulty.olympian:
        return 50;
    }
  }

  int get trophyLoss {
    switch (this) {
      case Difficulty.easy:
        return -5;
      case Difficulty.normal:
        return -10;
      case Difficulty.hard:
        return -10;
      case Difficulty.olympian:
        return -15;
    }
  }
}

/// Aggregated per-battle counters, fed into quests/achievements afterwards.
class BattleStats {
  int cardsPlayed = 0;
  int legendariesPlayed = 0;
  int heroDamage = 0;
  int minionsDestroyed = 0;
  int attacksMade = 0;
}

/// A single attack that just resolved, so the UI can play a lunge/impact
/// animation. [attackerId]/[targetId] are GameCard.instanceId values;
/// targetId is null when a hero was hit.
class AttackEvent {
  AttackEvent({
    required this.attackerId,
    required this.targetId,
    required this.byEnemy,
  });

  final int attackerId;
  final int? targetId;
  final bool byEnemy;

  /// Monotonic id so identical attacks still trigger fresh animations.
  final int serial = _serial++;
  static int _serial = 0;
}

/// Drives the entire "Council of Olympus" battle: turns, mana, drawing,
/// playing minions, battlecries, combat and a difficulty-aware AI.
///
/// Extends [ChangeNotifier] so the battle screen rebuilds reactively.
class GameController extends ChangeNotifier {
  GameController({
    this.difficulty = Difficulty.normal,
    this.humanDeckLevels,
    this.relic,
    this.aiHpOverride,
    this.bossEnrage = false,
  }) {
    _strategy = AiStrategy(difficulty, _rng);
    _startGame();
  }

  final Difficulty difficulty;

  /// Collection levels applied to the human deck (null = everything level 1).
  final Map<String, int>? humanDeckLevels;

  /// Passive artifact equipped by the human for this battle.
  final Relic? relic;

  /// Campaign overrides.
  final int? aiHpOverride;
  final bool bossEnrage;

  static const int boardLimit = 5;
  static const int handLimit = 10;
  static const int maxManaCap = 10;

  /// Both heroes act on turn one with this much mana, so there are no
  /// "dead" opening turns where you can do nothing.
  static const int startingMana = 3;

  final Random _rng = Random();
  late final AiStrategy _strategy;

  late Player human;
  late Player ai;

  GamePhase phase = GamePhase.playing;
  bool isPlayerTurn = true;
  bool aiThinking = false;
  int turnNumber = 0;

  /// Boss mechanic: once turn 6 arrives, all AI minions rage with +2 Attack.
  bool aiEnraged = false;

  /// Sandals of Hermes: whether the per-turn discount is still available.
  bool _firstCardDiscountAvailable = false;

  /// Per-battle counters for the meta layer.
  final BattleStats stats = BattleStats();

  /// The friendly minion the human has tapped and is about to attack with.
  GameCard? selectedAttacker;

  /// Hero power "Thunderbolt": once per turn, pay mana to zap any enemy.
  static const int heroPowerCost = 2;
  static const int heroPowerDamage = 1;
  bool heroPowerUsed = false;

  /// True while the player has tapped the hero power and is picking a target.
  bool heroPowerArmed = false;

  /// The most recent attack, so the UI can animate a lunge + impact.
  AttackEvent? lastAttack;

  /// Rolling combat log shown to the player (most recent first).
  final List<String> log = [];

  void _log(String message) {
    log.insert(0, message);
    if (log.length > 30) log.removeLast();
  }

  void _startGame() {
    final humanBonusHp =
        relic?.effect == RelicEffect.heroBonusHp ? relic!.value : 0;
    human = Player(name: 'You', isHuman: true, maxHp: 30 + humanBonusHp);
    ai = Player(
      name: 'Olympus AI',
      isHuman: false,
      maxHp: aiHpOverride ?? difficulty.aiHp,
    );

    human.deck.addAll(CardData.buildDeck(levels: humanDeckLevels)
      ..shuffle(_rng));
    ai.deck.addAll(CardData.buildDeck()..shuffle(_rng));

    // Seed mana so the very first increment lands on [startingMana].
    human.maxMana = startingMana - 1;
    ai.maxMana = startingMana - 1;

    phase = GamePhase.playing;
    isPlayerTurn = true;
    selectedAttacker = null;
    turnNumber = 0;
    aiEnraged = false;
    log.clear();

    final humanOpeningHand =
        3 + (relic?.effect == RelicEffect.extraStartingCard ? relic!.value : 0);
    for (var i = 0; i < humanOpeningHand; i++) {
      _draw(human);
    }
    for (var i = 0; i < difficulty.aiOpeningHand; i++) {
      _draw(ai);
    }

    _log('The Council of Olympus begins! (${difficulty.label})');
    if (relic != null) _log('Relic equipped: ${relic!.name}.');
    if (bossEnrage) {
      _log('The Titan stirs... it will ENRAGE after turn 6!');
    }
    _beginTurn(human);
  }

  void restart() {
    _startGame();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Turn handling
  // ---------------------------------------------------------------------------

  void _beginTurn(Player p) {
    if (p.maxMana < maxManaCap) p.maxMana++;
    p.mana = p.maxMana;

    _draw(p);
    for (final m in p.board) {
      m.canAttack = true;
    }

    if (p.isHuman) {
      isPlayerTurn = true;
      turnNumber++;
      heroPowerUsed = false;
      heroPowerArmed = false;
      _firstCardDiscountAvailable =
          relic?.effect == RelicEffect.firstCardDiscount;
      _log('Your turn ($turnNumber). ${p.mana} mana.');
    } else {
      isPlayerTurn = false;
      _log("Olympus AI's turn.");
      _maybeEnrage();
    }
  }

  void _maybeEnrage() {
    if (!bossEnrage || aiEnraged || turnNumber < 6) return;
    aiEnraged = true;
    for (final m in ai.board) {
      m.attack += 2;
    }
    _log('THE TITAN ENRAGES! All enemy gods gain +2 Attack!');
  }

  void _draw(Player p) {
    if (p.deck.isEmpty) return; // No fatigue damage in this build.
    if (p.hand.length >= handLimit) {
      p.deck.removeAt(0); // Overdraw is burned.
      return;
    }
    p.hand.add(p.deck.removeAt(0));
  }

  /// Human ends their turn -> hand control to the AI.
  Future<void> endTurn() async {
    if (!isPlayerTurn || phase != GamePhase.playing) return;
    selectedAttacker = null;
    heroPowerArmed = false;
    isPlayerTurn = false;
    notifyListeners();
    await _runAiTurn();
  }

  // ---------------------------------------------------------------------------
  // Playing cards (human)
  // ---------------------------------------------------------------------------

  /// Actual mana cost after the Sandals of Hermes discount.
  int effectiveCost(GameCard card) {
    if (_firstCardDiscountAvailable && isPlayerTurn) {
      return max(0, card.cost - relic!.value);
    }
    return card.cost;
  }

  bool canPlay(GameCard card) =>
      isPlayerTurn &&
      !aiThinking &&
      phase == GamePhase.playing &&
      effectiveCost(card) <= human.mana &&
      human.board.length < boardLimit;

  void playCard(GameCard card) {
    if (!canPlay(card)) return;
    heroPowerArmed = false;
    human.hand.remove(card);
    human.mana -= effectiveCost(card);
    _firstCardDiscountAvailable = false;
    human.board.add(card);

    // Aegis of Athena: taunts arrive sturdier.
    if (card.hasTaunt && relic?.effect == RelicEffect.tauntBonusHp) {
      card.health += relic!.value;
      card.currentHealth += relic!.value;
    }

    stats.cardsPlayed++;
    if (card.rarity == Rarity.legendary) stats.legendariesPlayed++;

    _log('You summon ${card.name}.');
    _resolveBattlecry(card, human, ai);
    _cleanupDead();
    _checkWin();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Combat (human initiated)
  // ---------------------------------------------------------------------------

  void selectAttacker(GameCard card) {
    if (!isPlayerTurn || aiThinking || phase != GamePhase.playing) return;
    if (!human.board.contains(card) || !card.canAttack || card.attack <= 0) {
      return;
    }
    heroPowerArmed = false;
    selectedAttacker = (selectedAttacker == card) ? null : card;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Hero power (Thunderbolt)
  // ---------------------------------------------------------------------------

  bool get canUseHeroPower =>
      isPlayerTurn &&
      !aiThinking &&
      phase == GamePhase.playing &&
      !heroPowerUsed &&
      human.mana >= heroPowerCost;

  /// Arms (or disarms) the hero power; the next enemy tap resolves it.
  void toggleHeroPower() {
    if (!canUseHeroPower) return;
    selectedAttacker = null;
    heroPowerArmed = !heroPowerArmed;
    notifyListeners();
  }

  void _spendHeroPower() {
    human.mana -= heroPowerCost;
    heroPowerUsed = true;
    heroPowerArmed = false;
  }

  void heroPowerOnMinion(GameCard target) {
    if (!heroPowerArmed || !ai.board.contains(target)) return;
    _spendHeroPower();
    _damageMinion(target, heroPowerDamage);
    _log('Thunderbolt strikes ${target.name}!');
    _cleanupDead();
    _checkWin();
    notifyListeners();
  }

  void heroPowerOnHero() {
    if (!heroPowerArmed) return;
    if (!canStrikeEnemyHero()) {
      _log('Destroy all enemy gods first!');
      return;
    }
    _spendHeroPower();
    _damageEnemyHero(heroPowerDamage, source: human);
    _log('Thunderbolt strikes the enemy hero!');
    _checkWin();
    notifyListeners();
  }

  bool enemyHasTaunt() => ai.board.any((m) => m.hasTaunt);

  /// House rule: a hero can only be attacked once their battlefield is empty.
  bool canStrikeEnemyHero() => ai.board.isEmpty;

  void attackMinion(GameCard target) {
    if (heroPowerArmed) {
      heroPowerOnMinion(target);
      return;
    }
    final attacker = selectedAttacker;
    if (attacker == null || !isPlayerTurn || phase != GamePhase.playing) return;
    if (!ai.board.contains(target)) return;
    if (enemyHasTaunt() && !target.hasTaunt) {
      _log('A Taunt guardian blocks the way!');
      return;
    }
    lastAttack = AttackEvent(
        attackerId: attacker.instanceId,
        targetId: target.instanceId,
        byEnemy: false);
    stats.attacksMade++;
    _resolveCombat(attacker, target,
        attackerOwner: human, defenderOwner: ai);
    _log('${attacker.name} clashes with ${target.name}.');
    selectedAttacker = null;
    _cleanupDead();
    _checkWin();
    notifyListeners();
  }

  void attackHero() {
    if (heroPowerArmed) {
      heroPowerOnHero();
      return;
    }
    final attacker = selectedAttacker;
    if (attacker == null || !isPlayerTurn || phase != GamePhase.playing) return;
    if (!canStrikeEnemyHero()) {
      _log('Destroy all enemy gods first!');
      return;
    }
    lastAttack = AttackEvent(
        attackerId: attacker.instanceId, targetId: null, byEnemy: false);
    stats.attacksMade++;
    _damageEnemyHero(attacker.attack, source: human);
    if (attacker.lifesteal) _heal(human, attacker.attack);
    attacker.canAttack = false;
    _log('${attacker.name} strikes the enemy hero for ${attacker.attack}.');
    selectedAttacker = null;
    _checkWin();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Damage pipeline (divine shield / frenzy / lifesteal aware)
  // ---------------------------------------------------------------------------

  /// Applies [amount] damage to [target]; returns the damage actually dealt
  /// (0 when a Divine Shield absorbs the hit).
  int _damageMinion(GameCard target, int amount) {
    if (amount <= 0) return 0;
    if (target.divineShield) {
      target.divineShield = false;
      _log("${target.name}'s Divine Shield shatters!");
      return 0;
    }
    target.currentHealth -= amount;
    if (!target.isDead && target.frenzy && !target.frenzyTriggered) {
      target.frenzyTriggered = true;
      target.attack += 2;
      _log('${target.name} enters a FRENZY (+2 Attack)!');
    }
    return amount;
  }

  /// Hero damage helper that also tracks the human's quest counters.
  void _damageEnemyHero(int amount, {required Player source}) {
    if (amount <= 0) return;
    final target = source.isHuman ? ai : human;
    target.changeHp(-amount);
    if (source.isHuman) stats.heroDamage += amount;
  }

  void _heal(Player p, int amount) {
    var value = amount;
    if (p.isHuman && relic?.effect == RelicEffect.healingBoost) {
      value += relic!.value;
    }
    p.healHero(value);
  }

  void _resolveCombat(
    GameCard attacker,
    GameCard defender, {
    required Player attackerOwner,
    required Player defenderOwner,
  }) {
    final dealt = _damageMinion(defender, attacker.attack);
    final received = _damageMinion(attacker, defender.attack);
    if (attacker.lifesteal && dealt > 0) _heal(attackerOwner, dealt);
    if (defender.lifesteal && received > 0) _heal(defenderOwner, received);
    attacker.canAttack = false;
  }

  // ---------------------------------------------------------------------------
  // Battlecries (auto-resolved, no manual targeting)
  // ---------------------------------------------------------------------------

  /// Ember of Prometheus: the human's damaging battlecries hit harder.
  int _battlecryDamage(GameCard card, Player owner) {
    var value = card.battlecryValue;
    if (owner.isHuman && relic?.effect == RelicEffect.battlecryDamageUp) {
      value += relic!.value;
    }
    return value;
  }

  void _resolveBattlecry(GameCard card, Player owner, Player opponent) {
    switch (card.battlecry) {
      case Battlecry.none:
        break;
      case Battlecry.stormStrike:
        final dmg = _battlecryDamage(card, owner);
        for (final m in opponent.board) {
          _damageMinion(m, dmg);
        }
        _damageEnemyHero(1, source: owner);
        _log('${card.name} calls down a storm!');
        break;
      case Battlecry.tidalWave:
        final dmg = _battlecryDamage(card, owner);
        _damageEnemyHero(dmg, source: owner);
        _log('${card.name} crashes a tidal wave for $dmg.');
        break;
      case Battlecry.sunBlessing:
        _heal(owner, card.battlecryValue);
        _log('${card.name} restores health.');
        break;
      case Battlecry.huntersArrow:
        if (opponent.board.isNotEmpty) {
          final t = opponent.board[_rng.nextInt(opponent.board.length)];
          final dmg = _battlecryDamage(card, owner);
          _damageMinion(t, dmg);
          _log('${card.name} pierces ${t.name}.');
        }
        break;
      case Battlecry.sacredFire:
        for (final m in owner.board) {
          if (m != card) {
            m.attack += 1;
            m.health += 1;
            m.currentHealth += 1;
          }
        }
        _log('${card.name} empowers your minions (+1/+1).');
        break;
      case Battlecry.royalDecree:
        for (final m in owner.board) {
          m.attack += 1;
          m.health += 1;
          m.currentHealth += 1;
        }
        _log('${card.name} decrees +1/+1 to all your minions.');
        break;
      case Battlecry.swiftMessage:
        _draw(owner);
        _log('${card.name} delivers a card.');
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  void _cleanupDead() {
    for (final m in [...human.board, ...ai.board]) {
      if (m.isDead) _log('${m.name} falls.');
    }
    stats.minionsDestroyed += ai.board.where((m) => m.isDead).length;
    human.board.removeWhere((m) => m.isDead);
    ai.board.removeWhere((m) => m.isDead);
  }

  void _checkWin() {
    if (ai.isDead) {
      phase = GamePhase.victory;
      _log('Olympus is yours. Victory!');
    } else if (human.isDead) {
      phase = GamePhase.defeat;
      _log('You have fallen. Defeat.');
    }
  }

  // ---------------------------------------------------------------------------
  // AI turn
  // ---------------------------------------------------------------------------

  Future<void> _runAiTurn() async {
    if (phase != GamePhase.playing) return;
    aiThinking = true;
    _beginTurn(ai);
    notifyListeners();
    await _pause(700);

    await _aiPlayCards();
    if (phase == GamePhase.playing) await _aiAttack();

    aiThinking = false;
    if (phase == GamePhase.playing) {
      _beginTurn(human);
    }
    notifyListeners();
  }

  Future<void> _aiPlayCards() async {
    while (phase == GamePhase.playing) {
      final affordable = ai.hand
          .where((c) => c.cost <= ai.mana && ai.board.length < boardLimit)
          .toList();
      if (affordable.isEmpty) break;
      if (_strategy.hesitates()) break;

      final card = _strategy.chooseCardToPlay(
        ai: ai,
        human: human,
        affordable: affordable,
      );
      if (card == null) break;

      ai.hand.remove(card);
      ai.mana -= card.cost;
      ai.board.add(card);
      if (aiEnraged) card.attack += 2; // Titan's fury applies to newcomers.
      _log('Olympus AI summons ${card.name}.');
      _resolveBattlecry(card, ai, human);
      _cleanupDead();
      _checkWin();
      notifyListeners();
      await _pause(600);
    }
  }

  Future<void> _aiAttack() async {
    // Hard/Olympian: if lethal is on the table, take it. The hero is only
    // reachable once the player's battlefield is completely empty.
    final goForLethal = (difficulty == Difficulty.hard ||
            difficulty == Difficulty.olympian) &&
        human.board.isEmpty &&
        _strategy.hasLethal(ai: ai, human: human);
    if (goForLethal) {
      for (final attacker
          in ai.board.where((m) => m.canAttack && m.attack > 0).toList()) {
        if (phase != GamePhase.playing) break;
        lastAttack = AttackEvent(
            attackerId: attacker.instanceId, targetId: null, byEnemy: true);
        _damageEnemyHero(attacker.attack, source: ai);
        if (attacker.lifesteal) _heal(ai, attacker.attack);
        attacker.canAttack = false;
        _log('Olympus AI: ${attacker.name} goes for lethal!');
        _checkWin();
        notifyListeners();
        await _pause(450);
      }
      if (phase != GamePhase.playing) return;
    }

    final attackers =
        ai.board.where((m) => m.canAttack && m.attack > 0).toList();
    for (final attacker in attackers) {
      if (phase != GamePhase.playing) break;
      if (!ai.board.contains(attacker)) continue;
      if (_strategy.skipsAttack()) continue;

      final taunts = _humanTaunts();
      if (taunts.isNotEmpty) {
        final target = taunts.first;
        lastAttack = AttackEvent(
            attackerId: attacker.instanceId,
            targetId: target.instanceId,
            byEnemy: true);
        _resolveCombat(attacker, target,
            attackerOwner: ai, defenderOwner: human);
        _log('Olympus AI: ${attacker.name} hits ${target.name}.');
      } else {
        var target = _strategy.chooseAttackTarget(
          attacker: attacker,
          ai: ai,
          human: human,
        );
        // Same rule as for the player: while the human has minions on the
        // board, the AI must fight them and cannot go face.
        if (target == null && human.board.isNotEmpty) {
          final sorted = [...human.board]
            ..sort((a, b) => a.currentHealth.compareTo(b.currentHealth));
          target = sorted.first;
        }
        if (target != null && human.board.contains(target)) {
          lastAttack = AttackEvent(
              attackerId: attacker.instanceId,
              targetId: target.instanceId,
              byEnemy: true);
          _resolveCombat(attacker, target,
              attackerOwner: ai, defenderOwner: human);
          _log('Olympus AI: ${attacker.name} strikes ${target.name}.');
        } else {
          lastAttack = AttackEvent(
              attackerId: attacker.instanceId, targetId: null, byEnemy: true);
          _damageEnemyHero(attacker.attack, source: ai);
          if (attacker.lifesteal) _heal(ai, attacker.attack);
          attacker.canAttack = false;
          _log(
              'Olympus AI: ${attacker.name} strikes you for ${attacker.attack}.');
        }
      }
      _cleanupDead();
      _checkWin();
      notifyListeners();
      await _pause(520);
    }
  }

  List<GameCard> _humanTaunts() =>
      human.board.where((m) => m.hasTaunt).toList();

  Future<void> _pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
}
