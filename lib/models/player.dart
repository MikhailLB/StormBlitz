import 'game_card.dart';

/// Holds the mutable battle state for one side (the human or the AI).
class Player {
  Player({
    required this.name,
    required this.isHuman,
    this.maxHp = 30,
  }) : hp = maxHp;

  final String name;
  final bool isHuman;
  final int maxHp;

  int hp;
  int mana = 0;
  int maxMana = 0;

  final List<GameCard> deck = [];
  final List<GameCard> hand = [];
  final List<GameCard> board = [];

  bool get isDead => hp <= 0;

  /// Clamp helper so HP never displays above the maximum or below zero.
  void changeHp(int delta) {
    hp = (hp + delta).clamp(0, maxHp);
  }

  void healHero(int amount) {
    hp = (hp + amount).clamp(0, maxHp);
  }
}
