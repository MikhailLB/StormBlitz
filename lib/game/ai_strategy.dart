import 'dart:math';

import '../models/game_card.dart';
import '../models/player.dart';
import 'game_controller.dart';

/// Difficulty-aware decision making for the AI side.
///
/// Easy / Normal / Hard keep their original personalities (hesitant, greedy,
/// ruthless). Olympian layers a positional evaluation on top: every candidate
/// play and every attack target is scored, and the best-scoring option wins.
class AiStrategy {
  AiStrategy(this.difficulty, this._rng);

  final Difficulty difficulty;
  final Random _rng;

  // -------------------------------------------------------------------
  // Position evaluation (Olympian)
  // -------------------------------------------------------------------

  /// Scores the battle from the AI's perspective. Higher = better for AI.
  double evaluate({required Player ai, required Player human}) {
    if (human.hp <= 0) return 10000;
    if (ai.hp <= 0) return -10000;

    double score = 0;
    for (final m in ai.board) {
      score += _minionValue(m);
    }
    for (final m in human.board) {
      score -= _minionValue(m);
    }
    score += (ai.hp - human.hp) * 0.9;
    // Pressure bonus: the lower the human hero, the more each point matters.
    score += (30 - human.hp) * 0.35;
    score += ai.hand.length * 0.4;
    return score;
  }

  double _minionValue(GameCard m) {
    var v = m.attack * 1.0 + m.currentHealth * 0.85;
    if (m.hasTaunt) v += 1.5;
    if (m.divineShield) v += 2.0;
    if (m.lifesteal) v += 1.0;
    return v;
  }

  // -------------------------------------------------------------------
  // Lethal detection
  // -------------------------------------------------------------------

  /// True if the AI can kill the human hero this turn: ready attackers
  /// (with no taunts in the way) plus direct battlecry damage it can afford.
  bool hasLethal({required Player ai, required Player human}) {
    final humanTaunts = human.board.where((m) => m.hasTaunt);
    if (humanTaunts.isNotEmpty) return false;

    final attackDamage = ai.board
        .where((m) => m.canAttack && m.attack > 0)
        .fold<int>(0, (s, m) => s + m.attack);

    // Direct hero damage from affordable battlecries (greedy mana spend,
    // cheapest damage first so more spells fit).
    var mana = ai.mana;
    var spellDamage = 0;
    final burn = ai.hand
        .where((c) =>
            c.battlecry == Battlecry.tidalWave ||
            c.battlecry == Battlecry.stormStrike)
        .toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    var boardRoom = GameController.boardLimit - ai.board.length;
    for (final c in burn) {
      if (c.cost <= mana && boardRoom > 0) {
        mana -= c.cost;
        boardRoom--;
        spellDamage += c.battlecry == Battlecry.tidalWave
            ? c.battlecryValue
            : 1; // stormStrike hits the hero for 1
        // Charge minions also add their attack after being played.
        if (c.keyword == Keyword.charge) spellDamage += c.attack;
      }
    }

    return attackDamage + spellDamage >= human.hp;
  }

  // -------------------------------------------------------------------
  // Card selection
  // -------------------------------------------------------------------

  /// True when the Easy AI decides to stop playing cards early.
  bool hesitates() =>
      difficulty == Difficulty.easy && _rng.nextDouble() < 0.30;

  /// Picks the next card to play from [affordable], or null to stop.
  GameCard? chooseCardToPlay({
    required Player ai,
    required Player human,
    required List<GameCard> affordable,
  }) {
    if (affordable.isEmpty) return null;

    switch (difficulty) {
      case Difficulty.easy:
        return affordable[_rng.nextInt(affordable.length)];
      case Difficulty.normal:
      case Difficulty.hard:
        // Greedy: biggest threat (highest cost) first.
        final sorted = [...affordable]
          ..sort((a, b) => b.cost.compareTo(a.cost));
        return sorted.first;
      case Difficulty.olympian:
        GameCard? best;
        var bestScore = double.negativeInfinity;
        for (final c in affordable) {
          final s = _playScore(c, ai: ai, human: human);
          if (s > bestScore) {
            bestScore = s;
            best = c;
          }
        }
        return best;
    }
  }

  /// Heuristic value of playing [card] right now (Olympian).
  double _playScore(GameCard card, {required Player ai, required Player human}) {
    var score = card.attack * 1.0 + card.health * 0.85;
    if (card.hasTaunt) {
      score += 1.5;
      // Taunts get much more valuable when the AI is under pressure.
      final humanBoardAttack =
          human.board.fold<int>(0, (s, m) => s + m.attack);
      if (humanBoardAttack >= ai.hp - 8) score += 4;
    }
    if (card.divineShield) score += 2;

    switch (card.battlecry) {
      case Battlecry.stormStrike:
        var dmg = 0.0;
        var kills = 0;
        for (final m in human.board) {
          dmg += min(card.battlecryValue, m.currentHealth);
          if (m.currentHealth <= card.battlecryValue && !m.divineShield) {
            kills++;
          }
        }
        score += dmg * 0.9 + kills * 2.5 + 1;
        break;
      case Battlecry.tidalWave:
        score += card.battlecryValue * 1.1;
        if (human.hp <= card.battlecryValue) score += 1000; // lethal
        break;
      case Battlecry.sunBlessing:
        final missing = ai.maxHp - ai.hp;
        score += min(card.battlecryValue, missing) * 0.7;
        break;
      case Battlecry.huntersArrow:
        if (human.board.isNotEmpty) {
          score += card.battlecryValue * 0.8;
        }
        break;
      case Battlecry.sacredFire:
        score += (ai.board.length) * 1.8;
        break;
      case Battlecry.royalDecree:
        score += (ai.board.length + 1) * 1.8;
        break;
      case Battlecry.swiftMessage:
        score += 1.5;
        break;
      case Battlecry.none:
        break;
    }

    // Slight preference for spending more mana (tempo).
    score += card.cost * 0.15;
    return score;
  }

  // -------------------------------------------------------------------
  // Attack targeting
  // -------------------------------------------------------------------

  /// Picks a target for [attacker]: a human minion, or null to go face.
  /// Taunts are enforced by the controller before this is consulted.
  GameCard? chooseAttackTarget({
    required GameCard attacker,
    required Player ai,
    required Player human,
  }) {
    switch (difficulty) {
      case Difficulty.easy:
        // Easy mostly ignores trades and swings face.
        return _rng.nextDouble() < 0.25 && human.board.isNotEmpty
            ? human.board[_rng.nextInt(human.board.length)]
            : null;

      case Difficulty.normal:
        return _bestFavourableTrade(attacker, human) ;

      case Difficulty.hard:
        final trade = _bestFavourableTrade(attacker, human);
        if (trade != null) return trade;
        // Remove a big threat even at the cost of dying, unless this
        // attacker is the AI's last Taunt while the player threatens lethal.
        if (_isLastTauntUnderLethal(attacker, ai, human)) return null;
        final bigThreats = human.board
            .where((m) =>
                m.attack >= 5 &&
                m.currentHealth <= attacker.attack &&
                !m.divineShield)
            .toList()
          ..sort((a, b) => b.attack.compareTo(a.attack));
        if (bigThreats.isNotEmpty) return bigThreats.first;
        return null;

      case Difficulty.olympian:
        return _olympianTarget(attacker, ai, human);
    }
  }

  /// Kill something without dying; prefer the highest-attack victim.
  GameCard? _bestFavourableTrade(GameCard attacker, Player human) {
    final goodTrades = human.board
        .where((m) =>
            m.currentHealth <= attacker.attack &&
            !m.divineShield &&
            m.attack < attacker.currentHealth)
        .toList()
      ..sort((a, b) => b.attack.compareTo(a.attack));
    return goodTrades.isEmpty ? null : goodTrades.first;
  }

  bool _isLastTauntUnderLethal(GameCard attacker, Player ai, Player human) {
    if (!attacker.hasTaunt) return false;
    final otherTaunts = ai.board.where((m) => m.hasTaunt && m != attacker);
    if (otherTaunts.isNotEmpty) return false;
    final humanDamage = human.board.fold<int>(0, (s, m) => s + m.attack);
    return humanDamage >= ai.hp;
  }

  /// Olympian: score every option (each enemy minion + face) by the
  /// evaluation delta it produces and pick the best.
  GameCard? _olympianTarget(GameCard attacker, Player ai, Player human) {
    // Guaranteed lethal reachable by going face? Always face.
    if (attacker.attack >= human.hp) return null;

    GameCard? best;
    // Baseline: going face.
    var bestScore = attacker.attack * 1.0 +
        (30 - human.hp - attacker.attack) * 0.35;

    for (final target in human.board) {
      var score = 0.0;
      final kills =
          !target.divineShield && target.currentHealth <= attacker.attack;
      final dies =
          !attacker.divineShield && attacker.currentHealth <= target.attack;

      if (kills) {
        score += _minionValue(target) + 1.0;
      } else if (target.divineShield) {
        score += 1.5; // popping a shield has value
      } else {
        score += min(attacker.attack, target.currentHealth) * 0.6;
      }
      if (dies) score -= _minionValue(attacker) * 0.9;
      // Frenzy targets get angrier when poked but not killed.
      if (!kills && target.frenzy && !target.frenzyTriggered) score -= 1.5;

      if (score > bestScore) {
        bestScore = score;
        best = target;
      }
    }
    return best;
  }

  /// True when the Easy AI skips an attack entirely.
  bool skipsAttack() =>
      difficulty == Difficulty.easy && _rng.nextDouble() < 0.30;
}
