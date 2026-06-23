import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../models/game_card.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import '../widgets/card_detail_dialog.dart';
import '../widgets/card_view.dart';
import '../widgets/storm_background.dart';
import '../widgets/value_change_effect.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key, this.difficulty = Difficulty.normal});

  final Difficulty difficulty;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late final GameController game;

  @override
  void initState() {
    super.initState();
    game = GameController(difficulty: widget.difficulty);
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  // Tracks turn changes so we can flash a "YOUR TURN" / "ENEMY TURN" banner.
  bool? _prevPlayerTurn;
  bool _showBanner = false;

  void _maybeBanner() {
    final current = game.isPlayerTurn && !game.aiThinking;
    if (_prevPlayerTurn != null && _prevPlayerTurn != current) {
      _showBanner = true;
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showBanner = false);
      });
    }
    _prevPlayerTurn = current;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StormBackground(
        darken: 0.62,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: game,
            builder: (context, _) {
              _maybeBanner();
              return Stack(
                children: [
                  Column(
                    children: [
                      _topBar(context),
                      _HeroPanel(
                        player: game.ai,
                        isEnemy: true,
                        targetable: game.selectedAttacker != null &&
                            !game.enemyHasTaunt(),
                        onTap: game.attackHero,
                      ),
                      _board(game.ai, isEnemy: true),
                      _centerStrip(),
                      _board(game.human, isEnemy: false),
                      _HeroPanel(player: game.human, isEnemy: false),
                      _hand(),
                      _endTurnBar(),
                    ],
                  ),
                  if (_showBanner) _turnBanner(),
                  if (game.phase != GamePhase.playing) _gameOverOverlay(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _turnBanner() {
    final yourTurn = game.isPlayerTurn && !game.aiThinking;
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: yourTurn ? AppColors.gold : AppColors.lightning,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (yourTurn ? AppColors.gold : AppColors.lightning)
                      .withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Text(
              yourTurn ? 'YOUR TURN' : 'ENEMY TURN',
              style: AppTheme.title(28,
                  color: yourTurn ? AppColors.goldLight : AppColors.lightning),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
          ),
          const Spacer(),
          Text('COUNCIL OF OLYMPUS',
              style: AppTheme.title(15, color: AppColors.gold)),
          const Spacer(),
          IconButton(
            onPressed: game.restart,
            icon: const Icon(Icons.refresh, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _board(Player player, {required bool isEnemy}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (!isEnemy && game.isPlayerTurn)
                ? AppColors.gold.withValues(alpha: 0.35)
                : AppColors.panelBorder.withValues(alpha: 0.4),
          ),
        ),
        child: player.board.isEmpty
            ? Center(
                child: Text(
                  isEnemy ? 'Enemy battlefield' : 'Your battlefield',
                  style: AppTheme.body(13, color: AppColors.textMuted),
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final m in player.board)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _boardMinion(m, isEnemy: isEnemy),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _boardMinion(GameCard m, {required bool isEnemy}) {
    final selectable = !isEnemy && game.isPlayerTurn && m.canAttack;
    final targetable = isEnemy &&
        game.selectedAttacker != null &&
        (!game.enemyHasTaunt() || m.hasTaunt);

    return CardView(
      key: ValueKey('board_${m.instanceId}'),
      card: m,
      width: 62,
      showDescription: false,
      selected: game.selectedAttacker == m,
      readyToAttack: selectable,
      targetable: targetable,
      onTap: () {
        if (isEnemy) {
          game.attackMinion(m);
        } else {
          game.selectAttacker(m);
        }
      },
      onLongPress: () => showCardDetail(context, m),
    );
  }

  Widget _centerStrip() {
    final hasAttacker = game.selectedAttacker != null;
    final latest = game.log.isNotEmpty ? game.log.first : '';
    final message = hasAttacker ? 'Tap an enemy to attack' : latest;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _turnChip(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(13,
                  color: hasAttacker ? AppColors.goldLight : AppColors.textMuted,
                  weight: hasAttacker ? FontWeight.w700 : FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _turnChip() {
    final yourTurn = game.isPlayerTurn && !game.aiThinking;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (yourTurn ? AppColors.gold : AppColors.lightningDeep)
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        yourTurn ? 'YOUR TURN' : 'ENEMY TURN',
        style: AppTheme.body(12,
            color: yourTurn ? Colors.black : Colors.white,
            weight: FontWeight.w700),
      ),
    );
  }

  Widget _hand() {
    final hand = game.human.hand;
    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: hand.isEmpty
          ? Center(
              child: Text('No cards in hand',
                  style: AppTheme.body(13, color: AppColors.textMuted)),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: hand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final card = hand[i];
                final playable = game.canPlay(card);
                return Center(
                  child: CardView(
                    key: ValueKey('hand_${card.instanceId}'),
                    card: card,
                    width: 96,
                    playable: playable,
                    onTap: playable ? () => game.playCard(card) : null,
                    onLongPress: () => showCardDetail(context, card),
                  ),
                );
              },
            ),
    );
  }

  Widget _endTurnBar() {
    final enabled = game.isPlayerTurn && !game.aiThinking;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: GestureDetector(
        onTap: enabled ? game.endTurn : null,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? [AppColors.gold, AppColors.goldLight]
                  : [AppColors.panel, AppColors.backgroundLight],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              if (enabled)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Center(
            child: Text(
              game.aiThinking ? 'ENEMY IS THINKING...' : 'END TURN',
              style: AppTheme.title(18,
                  color: enabled ? Colors.black : AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameOverOverlay(BuildContext context) {
    final victory = game.phase == GamePhase.victory;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                victory ? Icons.emoji_events : Icons.dangerous,
                size: 90,
                color: victory ? AppColors.gold : AppColors.hpRed,
              ),
              const SizedBox(height: 12),
              Text(
                victory ? 'VICTORY' : 'DEFEAT',
                style: AppTheme.title(48,
                    color: victory ? AppColors.goldLight : AppColors.hpRed),
              ),
              const SizedBox(height: 8),
              Text(
                victory
                    ? 'Olympus bows before you.'
                    : 'The heavens have forsaken you.',
                style: AppTheme.body(16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: game.restart,
                icon: const Icon(Icons.refresh),
                label: const Text('PLAY AGAIN'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  textStyle: AppTheme.title(18, color: Colors.black),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('BACK TO MENU',
                    style: AppTheme.body(16, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero portrait + HP + mana crystals for one side.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.player,
    required this.isEnemy,
    this.targetable = false,
    this.onTap,
  });

  final Player player;
  final bool isEnemy;
  final bool targetable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: targetable ? onTap : null,
      child: ValueChangeEffect(
        value: player.hp,
        borderRadius: 14,
        numberFontSize: 30,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: targetable
                  ? AppColors.hpRed
                  : AppColors.panelBorder.withValues(alpha: 0.7),
              width: targetable ? 2.5 : 1,
            ),
            boxShadow: [
              if (targetable)
                BoxShadow(
                    color: AppColors.hpRed.withValues(alpha: 0.6),
                    blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isEnemy
                        ? [AppColors.hpRed, const Color(0xFF7A1F1A)]
                        : [AppColors.lightningDeep, AppColors.lightning],
                  ),
                  border: Border.all(color: AppColors.goldLight, width: 1.5),
                ),
                child: Icon(
                  isEnemy ? Icons.shield_moon : Icons.person,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(player.name, style: AppTheme.body(14)),
                        const SizedBox(width: 8),
                        Text('Deck ${player.deck.length}',
                            style: AppTheme.body(11,
                                color: AppColors.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _ManaCrystals(mana: player.mana, maxMana: player.maxMana),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statPill(
                icon: Icons.favorite,
                color: AppColors.hpRed,
                value: '${player.hp}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statPill({
    required IconData icon,
    required Color color,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(value, style: AppTheme.title(15, color: Colors.white)),
        ],
      ),
    );
  }
}

/// A row of mana crystal pips (filled = available, dim = spent/locked).
class _ManaCrystals extends StatelessWidget {
  const _ManaCrystals({required this.mana, required this.maxMana});

  final int mana;
  final int maxMana;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < maxMana; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < mana
                    ? AppColors.manaBlue
                    : AppColors.manaBlue.withValues(alpha: 0.18),
                border: Border.all(
                  color: i < mana
                      ? AppColors.lightning
                      : AppColors.panelBorder,
                  width: 1,
                ),
                boxShadow: [
                  if (i < mana)
                    BoxShadow(
                      color: AppColors.lightning.withValues(alpha: 0.6),
                      blurRadius: 4,
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text('$mana/$maxMana',
            style: AppTheme.body(11, color: AppColors.textMuted)),
      ],
    );
  }
}
