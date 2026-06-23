import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/card_data.dart';
import '../models/game_card.dart';
import '../models/player.dart';

enum GamePhase { playing, victory, defeat }

enum Difficulty { easy, normal, hard }

extension DifficultyInfo on Difficulty {
  String get label {
    switch (this) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.normal:
        return 'Normal';
      case Difficulty.hard:
        return 'Hard';
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
    }
  }
}

/// Drives the entire "Council of Olympus" battle: turns, mana, drawing,
/// playing minions, battlecries, combat and a difficulty-aware AI.
///
/// Extends [ChangeNotifier] so the battle screen rebuilds reactively.
class GameController extends ChangeNotifier {
  GameController({this.difficulty = Difficulty.normal}) {
    _startGame();
  }

  final Difficulty difficulty;

  static const int boardLimit = 5;
  static const int handLimit = 10;
  static const int maxManaCap = 10;

  /// Both heroes act on turn one with this much mana, so there are no
  /// "dead" opening turns where you can do nothing.
  static const int startingMana = 3;

  final Random _rng = Random();

  late Player human;
  late Player ai;

  GamePhase phase = GamePhase.playing;
  bool isPlayerTurn = true;
  bool aiThinking = false;
  int turnNumber = 0;

  /// The friendly minion the human has tapped and is about to attack with.
  GameCard? selectedAttacker;

  /// Rolling combat log shown to the player (most recent first).
  final List<String> log = [];

  void _log(String message) {
    log.insert(0, message);
    if (log.length > 30) log.removeLast();
  }

  void _startGame() {
    human = Player(name: 'You', isHuman: true);
    ai = Player(name: 'Olympus AI', isHuman: false, maxHp: difficulty.aiHp);

    human.deck.addAll(CardData.buildDeck()..shuffle(_rng));
    ai.deck.addAll(CardData.buildDeck()..shuffle(_rng));

    // Seed mana so the very first increment lands on [startingMana].
    human.maxMana = startingMana - 1;
    ai.maxMana = startingMana - 1;

    phase = GamePhase.playing;
    isPlayerTurn = true;
    selectedAttacker = null;
    turnNumber = 0;
    log.clear();

    for (var i = 0; i < 3; i++) {
      _draw(human);
    }
    for (var i = 0; i < difficulty.aiOpeningHand; i++) {
      _draw(ai);
    }

    _log('The Council of Olympus begins! (${difficulty.label})');
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
      _log('Your turn ($turnNumber). ${p.mana} mana.');
    } else {
      isPlayerTurn = false;
      _log("Olympus AI's turn.");
    }
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
    isPlayerTurn = false;
    notifyListeners();
    await _runAiTurn();
  }

  // ---------------------------------------------------------------------------
  // Playing cards (human)
  // ---------------------------------------------------------------------------

  bool canPlay(GameCard card) =>
      isPlayerTurn &&
      !aiThinking &&
      phase == GamePhase.playing &&
      card.cost <= human.mana &&
      human.board.length < boardLimit;

  void playCard(GameCard card) {
    if (!canPlay(card)) return;
    human.hand.remove(card);
    human.mana -= card.cost;
    human.board.add(card);
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
    selectedAttacker = (selectedAttacker == card) ? null : card;
    notifyListeners();
  }

  bool enemyHasTaunt() => ai.board.any((m) => m.hasTaunt);

  void attackMinion(GameCard target) {
    final attacker = selectedAttacker;
    if (attacker == null || !isPlayerTurn || phase != GamePhase.playing) return;
    if (!ai.board.contains(target)) return;
    if (enemyHasTaunt() && !target.hasTaunt) {
      _log('A Taunt guardian blocks the way!');
      return;
    }
    _resolveCombat(attacker, target);
    selectedAttacker = null;
    _cleanupDead();
    _checkWin();
    notifyListeners();
  }

  void attackHero() {
    final attacker = selectedAttacker;
    if (attacker == null || !isPlayerTurn || phase != GamePhase.playing) return;
    if (enemyHasTaunt()) {
      _log('A Taunt guardian blocks the way!');
      return;
    }
    ai.changeHp(-attacker.attack);
    attacker.canAttack = false;
    _log('${attacker.name} strikes the enemy hero for ${attacker.attack}.');
    selectedAttacker = null;
    _checkWin();
    notifyListeners();
  }

  void _resolveCombat(GameCard attacker, GameCard defender) {
    defender.currentHealth -= attacker.attack;
    attacker.currentHealth -= defender.attack;
    attacker.canAttack = false;
    _log('${attacker.name} clashes with ${defender.name}.');
  }

  // ---------------------------------------------------------------------------
  // Battlecries (auto-resolved, no manual targeting)
  // ---------------------------------------------------------------------------

  void _resolveBattlecry(GameCard card, Player owner, Player opponent) {
    switch (card.battlecry) {
      case Battlecry.none:
        break;
      case Battlecry.stormStrike:
        for (final m in opponent.board) {
          m.currentHealth -= card.battlecryValue;
        }
        opponent.changeHp(-1);
        _log('${card.name} calls down a storm!');
        break;
      case Battlecry.tidalWave:
        opponent.changeHp(-card.battlecryValue);
        _log('${card.name} crashes a tidal wave for ${card.battlecryValue}.');
        break;
      case Battlecry.sunBlessing:
        owner.healHero(card.battlecryValue);
        _log('${card.name} restores ${card.battlecryValue} health.');
        break;
      case Battlecry.huntersArrow:
        if (opponent.board.isNotEmpty) {
          final t = opponent.board[_rng.nextInt(opponent.board.length)];
          t.currentHealth -= card.battlecryValue;
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
    bool playedSomething = true;
    while (playedSomething && phase == GamePhase.playing) {
      playedSomething = false;
      final affordable = ai.hand
          .where((c) => c.cost <= ai.mana && ai.board.length < boardLimit)
          .toList();
      if (affordable.isEmpty) break;

      // Easy: random pick (and a chance to just stop early).
      // Normal/Hard: spend the most mana possible (biggest threat first).
      GameCard card;
      if (difficulty == Difficulty.easy) {
        if (_rng.nextDouble() < 0.30) break; // hesitates
        card = affordable[_rng.nextInt(affordable.length)];
      } else {
        affordable.sort((a, b) => b.cost.compareTo(a.cost));
        card = affordable.first;
      }

      ai.hand.remove(card);
      ai.mana -= card.cost;
      ai.board.add(card);
      _log('Olympus AI summons ${card.name}.');
      _resolveBattlecry(card, ai, human);
      _cleanupDead();
      _checkWin();
      notifyListeners();
      playedSomething = true;
      await _pause(600);
    }
  }

  Future<void> _aiAttack() async {
    // Hard AI: if it can kill the player this turn with an open board, go face.
    if (difficulty == Difficulty.hard && _humanTaunts().isEmpty) {
      final totalAttack = ai.board
          .where((m) => m.canAttack && m.attack > 0)
          .fold<int>(0, (s, m) => s + m.attack);
      if (totalAttack >= human.hp) {
        for (final attacker
            in ai.board.where((m) => m.canAttack && m.attack > 0).toList()) {
          if (phase != GamePhase.playing) break;
          human.changeHp(-attacker.attack);
          attacker.canAttack = false;
          _log('Olympus AI: ${attacker.name} goes for lethal!');
          _checkWin();
          notifyListeners();
          await _pause(450);
        }
        return;
      }
    }

    final attackers =
        ai.board.where((m) => m.canAttack && m.attack > 0).toList();
    for (final attacker in attackers) {
      if (phase != GamePhase.playing) break;
      if (!ai.board.contains(attacker)) continue;

      // Easy AI sometimes just doesn't bother attacking.
      if (difficulty == Difficulty.easy && _rng.nextDouble() < 0.30) {
        continue;
      }

      final taunts = _humanTaunts();
      if (taunts.isNotEmpty) {
        final target = taunts.first;
        _aiTrade(attacker, target);
        _log('Olympus AI: ${attacker.name} hits ${target.name}.');
      } else {
        final target = _chooseAttackTarget(attacker);
        if (target != null) {
          _aiTrade(attacker, target);
          _log('Olympus AI: ${attacker.name} slays ${target.name}.');
        } else {
          human.changeHp(-attacker.attack);
          attacker.canAttack = false;
          _log('Olympus AI: ${attacker.name} strikes you for ${attacker.attack}.');
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

  /// Picks a minion worth trading into, else null (= go face).
  GameCard? _chooseAttackTarget(GameCard attacker) {
    if (difficulty == Difficulty.easy) {
      // Easy mostly ignores trades and swings face.
      return _rng.nextDouble() < 0.25 && human.board.isNotEmpty
          ? human.board[_rng.nextInt(human.board.length)]
          : null;
    }

    // Favourable trades: kill something without dying.
    final goodTrades = human.board
        .where((m) =>
            m.currentHealth <= attacker.attack &&
            m.attack < attacker.currentHealth)
        .toList()
      ..sort((a, b) => b.attack.compareTo(a.attack));
    if (goodTrades.isNotEmpty) return goodTrades.first;

    if (difficulty == Difficulty.hard) {
      // Hard will also remove a big threat even at the cost of dying.
      final bigThreats = human.board
          .where((m) => m.attack >= 5 && m.currentHealth <= attacker.attack)
          .toList()
        ..sort((a, b) => b.attack.compareTo(a.attack));
      if (bigThreats.isNotEmpty) return bigThreats.first;
    }
    return null; // go face
  }

  void _aiTrade(GameCard attacker, GameCard defender) {
    attacker.currentHealth -= defender.attack;
    defender.currentHealth -= attacker.attack;
    attacker.canAttack = false;
  }

  Future<void> _pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
}
