import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/campaign_data.dart';
import '../game/game_controller.dart';
import '../models/game_card.dart';
import '../models/player.dart';
import '../models/player_profile.dart';
import '../models/quest.dart';
import '../models/relic.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_transitions.dart';
import '../widgets/card_detail_dialog.dart';
import '../widgets/card_view.dart';
import '../widgets/storm_background.dart';
import '../widgets/value_change_effect.dart';
import 'battle_result_screen.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    this.difficulty = Difficulty.normal,
    this.deckLevels,
    this.relic,
    this.campaignNode,
  });

  final Difficulty difficulty;
  final Map<String, int>? deckLevels;
  final Relic? relic;
  final CampaignNode? campaignNode;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

// ---------------------------------------------------------------------------
// Tutorial
// ---------------------------------------------------------------------------

enum _TutorialStep {
  welcome,
  playCard,
  endTurn,
  attack,
  heroPower,
  finish,
  done,
}

extension _TutorialText on _TutorialStep {
  String get text {
    switch (this) {
      case _TutorialStep.welcome:
        return 'Welcome to Olympus! Your goal: bring the enemy hero (top) to 0 HP. The cards below are your HAND.';
      case _TutorialStep.playCard:
        return 'Summon a god: tap any GLOWING card in your hand. The blue drop is its mana cost — you have limited mana each turn.';
      case _TutorialStep.endTurn:
        return 'Great! New gods need a turn to prepare before attacking. Tap END TURN and let the enemy move.';
      case _TutorialStep.attack:
        return 'Time to strike! Tap your god (green glow), then tap an enemy god. The enemy HERO can only be attacked once their battlefield is empty!';
      case _TutorialStep.heroPower:
        return 'You also command THUNDERBOLT — the bolt button near your hero. For 2 mana it zaps any enemy for 1 damage, once per turn. Try it, or skip.';
      case _TutorialStep.finish:
        return 'You know everything you need. Win battles to earn gold, chests and trophies. May the storm favor you!';
      case _TutorialStep.done:
        return '';
    }
  }

  /// Where the helper card sits so it never covers what the player must tap.
  bool get anchorTop =>
      this == _TutorialStep.playCard ||
      this == _TutorialStep.endTurn ||
      this == _TutorialStep.heroPower;
}

class _BattleScreenState extends State<BattleScreen> {
  late final GameController game;
  bool _resultShown = false;

  // Attack lunge animation state.
  int? _lungeAttackerId;
  bool _lungeDown = false;
  int _lastAttackSerial = -1;

  // Tutorial state.
  _TutorialStep _tutorial = _TutorialStep.done;

  @override
  void initState() {
    super.initState();
    game = GameController(
      difficulty: widget.difficulty,
      humanDeckLevels: widget.deckLevels,
      relic: widget.relic,
      aiHpOverride: widget.campaignNode?.aiHpOverride,
      bossEnrage: widget.campaignNode?.bossEnrage ?? false,
    );
    game.addListener(_onGameChanged);

    final profile = context.read<PlayerProfile>();
    if (!profile.tutorialDone && widget.campaignNode == null) {
      _tutorial = _TutorialStep.welcome;
    }
  }

  @override
  void dispose() {
    game.removeListener(_onGameChanged);
    game.dispose();
    super.dispose();
  }

  void _onGameChanged() {
    _maybeAnimateAttack();
    _advanceTutorial();
    if (game.phase != GamePhase.playing && !_resultShown) {
      _resultShown = true;
      // Let the final blow land visually before the ceremony.
      Future.delayed(const Duration(milliseconds: 1300), _finishBattle);
    }
  }

  void _maybeAnimateAttack() {
    final attack = game.lastAttack;
    if (attack == null || attack.serial == _lastAttackSerial) return;
    _lastAttackSerial = attack.serial;
    setState(() {
      _lungeAttackerId = attack.attackerId;
      // Enemy minions lunge downward (toward the player), yours lunge up.
      _lungeDown = attack.byEnemy;
    });
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted && _lungeAttackerId == attack.attackerId) {
        setState(() => _lungeAttackerId = null);
      }
    });
  }

  // -------------------------------------------------------------------
  // Tutorial flow
  // -------------------------------------------------------------------

  void _advanceTutorial() {
    if (_tutorial == _TutorialStep.done) return;
    switch (_tutorial) {
      case _TutorialStep.playCard:
        if (game.stats.cardsPlayed >= 1) {
          setState(() => _tutorial = _TutorialStep.endTurn);
        } else if (!game.isPlayerTurn) {
          // Player ended the turn without a playable card — move on.
          setState(() => _tutorial = _TutorialStep.attack);
        }
        break;
      case _TutorialStep.endTurn:
        if (!game.isPlayerTurn || game.turnNumber >= 2) {
          setState(() => _tutorial = _TutorialStep.attack);
        }
        break;
      case _TutorialStep.attack:
        if (game.stats.attacksMade >= 1) {
          setState(() => _tutorial = _TutorialStep.heroPower);
        }
        break;
      case _TutorialStep.heroPower:
        if (game.heroPowerUsed) {
          setState(() => _tutorial = _TutorialStep.finish);
        }
        break;
      default:
        break;
    }
  }

  void _tutorialNext() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_tutorial) {
        case _TutorialStep.welcome:
          _tutorial = _TutorialStep.playCard;
          break;
        case _TutorialStep.heroPower:
          _tutorial = _TutorialStep.finish;
          break;
        case _TutorialStep.finish:
          _tutorial = _TutorialStep.done;
          context.read<PlayerProfile>().markTutorialDone();
          break;
        default:
          break;
      }
    });
  }

  void _tutorialSkip() {
    setState(() => _tutorial = _TutorialStep.done);
    context.read<PlayerProfile>().markTutorialDone();
  }

  // -------------------------------------------------------------------
  // Battle end
  // -------------------------------------------------------------------

  void _finishBattle() {
    if (!mounted) return;
    final profile = context.read<PlayerProfile>();
    final victory = game.phase == GamePhase.victory;
    final rewards = RewardService().battleRewards(
      difficulty: widget.difficulty,
      victory: victory,
    );

    // Campaign first-clear bonus.
    var firstClearGold = 0;
    var firstClearAmbrosia = 0;
    final node = widget.campaignNode;
    if (victory &&
        node != null &&
        !profile.campaignClears.contains(node.id)) {
      profile.markCampaignClear(node.id);
      firstClearGold = node.goldReward;
      firstClearAmbrosia = node.ambrosiaReward;
    }

    profile.recordBattleResult(
        victory: victory, trophyDelta: rewards.trophyDelta);
    profile.addGold(rewards.gold + firstClearGold);
    if (firstClearAmbrosia > 0) profile.addAmbrosia(firstClearAmbrosia);
    profile.addXp(rewards.xp);
    profile.recordBattleStats(
      cardsPlayed: game.stats.cardsPlayed,
      legendariesPlayed: game.stats.legendariesPlayed,
      heroDamage: game.stats.heroDamage,
      minionsDestroyed: game.stats.minionsDestroyed,
    );
    if (victory) profile.addQuestProgress(QuestGoal.winBattles, 1);
    profile.markTutorialDone();

    var chestGranted = false;
    if (victory && rewards.chestTier != null) {
      chestGranted = profile.grantChest(rewards.chestTier!) != null;
    }

    Navigator.of(context).pushReplacement(
      AppTransitions.scaleIn(
        BattleResultScreen(
          victory: victory,
          rewards: rewards,
          chestGranted: chestGranted,
          firstClearGold: firstClearGold,
          firstClearAmbrosia: firstClearAmbrosia,
          onPlayAgain: widget.campaignNode == null
              ? () {
                  Navigator.of(context).push(
                    AppTransitions.slideUp(
                      BattleScreen(
                        difficulty: widget.difficulty,
                        deckLevels: widget.deckLevels,
                        relic: widget.relic,
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
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

  // Emote speech bubble above the human hero.
  static const List<String> _emotes = [
    'Well played!',
    'Ha!',
    'Feel the thunder!',
    'Once more?',
  ];
  String? _emoteText;

  void _showEmotePicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final e in _emotes)
              GestureDetector(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() => _emoteText = e);
                  Future.delayed(const Duration(milliseconds: 1900), () {
                    if (mounted && _emoteText == e) {
                      setState(() => _emoteText = null);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold),
                  ),
                  child: Text(e,
                      style: AppTheme.body(15,
                          color: AppColors.goldLight,
                          weight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: game,
        builder: (context, _) {
          _maybeBanner();
          return StormBackground(
            darken: 0.62,
            intensity: min(1.0, game.turnNumber / 12),
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      _topBar(context),
                      _HeroPanel(
                        player: game.ai,
                        isEnemy: true,
                        enraged: game.aiEnraged,
                        targetable: (game.selectedAttacker != null ||
                                game.heroPowerArmed) &&
                            game.canStrikeEnemyHero(),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          game.attackHero();
                        },
                      ),
                      _board(game.ai, isEnemy: true),
                      _centerStrip(),
                      _board(game.human, isEnemy: false),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _HeroPanel(
                            player: game.human,
                            isEnemy: false,
                            relic: widget.relic,
                            onTap: _showEmotePicker,
                            alwaysTappable: true,
                            heroPower: _HeroPowerState(
                              visible: true,
                              enabled: game.canUseHeroPower,
                              armed: game.heroPowerArmed,
                              used: game.heroPowerUsed,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                game.toggleHeroPower();
                              },
                            ),
                          ),
                          if (_emoteText != null)
                            Positioned(
                              top: -34,
                              left: 24,
                              child: _emoteBubble(_emoteText!),
                            ),
                        ],
                      ),
                      _hand(),
                      _endTurnBar(),
                    ],
                  ),
                  if (_showBanner) _turnBanner(),
                  if (_tutorial != _TutorialStep.done) _tutorialOverlay(),
                  if (game.phase != GamePhase.playing) _gameOverFlash(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // Tutorial overlay
  // -------------------------------------------------------------------

  Widget _tutorialOverlay() {
    final step = _tutorial;
    final showNext = step == _TutorialStep.welcome ||
        step == _TutorialStep.heroPower ||
        step == _TutorialStep.finish;

    return Align(
      alignment:
          step.anchorTop ? Alignment.topCenter : Alignment.bottomCenter,
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(
              16, step.anchorTop ? 64 : 0, 16, step.anchorTop ? 0 : 178),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(step),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, t, child) => Transform.scale(
              scale: 0.9 + 0.1 * t,
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.gold),
                        ),
                        child: const Icon(Icons.school,
                            color: AppColors.goldLight, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.text,
                          style: AppTheme.body(14,
                              color: AppColors.textPrimary,
                              weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _tutorialSkip,
                        child: Text('Skip tutorial',
                            style: AppTheme.body(13,
                                color: AppColors.textMuted)),
                      ),
                      if (showNext)
                        TextButton(
                          onPressed: _tutorialNext,
                          child: Text(
                            step == _TutorialStep.finish
                                ? 'FIGHT!'
                                : step == _TutorialStep.heroPower
                                    ? 'GOT IT'
                                    : 'NEXT',
                            style: AppTheme.title(15,
                                color: AppColors.goldLight),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('your move...',
                                  style: AppTheme.body(12,
                                      color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emoteBubble(String text) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutBack,
      builder: (_, t, child) =>
          Transform.scale(scale: t.clamp(0.0, 1.0), child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.goldLight,
          borderRadius: BorderRadius.circular(14).copyWith(
            bottomLeft: const Radius.circular(2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(text,
            style: AppTheme.body(14,
                color: Colors.black, weight: FontWeight.w700)),
      ),
    );
  }

  /// Quick flash while the result screen is being prepared.
  Widget _gameOverFlash() {
    final victory = game.phase == GamePhase.victory;
    return Positioned.fill(
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (_, t, _) => Container(
            color: (victory ? AppColors.gold : AppColors.hpRed)
                .withValues(alpha: 0.28 * t),
            alignment: Alignment.center,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Text(
                victory ? 'VICTORY' : 'DEFEAT',
                style: AppTheme.title(44,
                    color:
                        victory ? AppColors.goldLight : AppColors.hpRed),
              ),
            ),
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
    final node = widget.campaignNode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 22),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                node != null ? node.name.toUpperCase() : 'TURN ${game.turnNumber}',
                style: AppTheme.title(13, color: AppColors.gold),
              ),
              if (node?.bossEnrage ?? false)
                Text(
                  game.aiEnraged ? 'ENRAGED!' : 'Enrages after turn 6',
                  style: AppTheme.body(11,
                      color: game.aiEnraged
                          ? AppColors.hpRed
                          : AppColors.textMuted,
                      weight: FontWeight.w700),
                ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: game.phase == GamePhase.playing ? game.restart : null,
            icon: const Icon(Icons.refresh,
                color: AppColors.textMuted, size: 22),
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
        ((game.selectedAttacker != null &&
                (!game.enemyHasTaunt() || m.hasTaunt)) ||
            game.heroPowerArmed);
    final lunging = _lungeAttackerId == m.instanceId;

    // Scale-in entrance + attack lunge.
    return TweenAnimationBuilder<double>(
      key: ValueKey('board_${m.instanceId}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: 0.55 + 0.45 * t.clamp(0.0, 1.0),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
            0, lunging ? (_lungeDown ? 16 : -16) : 0, 0),
        child: CardView(
          card: m,
          width: 62,
          showDescription: false,
          selected: game.selectedAttacker == m,
          readyToAttack: selectable,
          targetable: targetable,
          onTap: () {
            if (isEnemy) {
              HapticFeedback.mediumImpact();
              game.attackMinion(m);
            } else {
              HapticFeedback.selectionClick();
              game.selectAttacker(m);
            }
          },
          onLongPress: () => showCardDetail(context, m),
        ),
      ),
    );
  }

  Widget _centerStrip() {
    final hasAttacker = game.selectedAttacker != null;
    final latest = game.log.isNotEmpty ? game.log.first : '';
    final message = game.heroPowerArmed
        ? 'Tap any enemy to strike with Thunderbolt'
        : hasAttacker
            ? 'Tap an enemy to attack'
            : latest;
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
                  color: (hasAttacker || game.heroPowerArmed)
                      ? AppColors.goldLight
                      : AppColors.textMuted,
                  weight: (hasAttacker || game.heroPowerArmed)
                      ? FontWeight.w700
                      : FontWeight.w600),
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
                // Playable cards float slightly upward, begging to be played.
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(
                      0, playable ? -6 : 0, 0),
                  child: Center(
                    child: CardView(
                      key: ValueKey('hand_${card.instanceId}'),
                      card: card,
                      width: 96,
                      playable: playable,
                      onTap: playable
                          ? () {
                              HapticFeedback.mediumImpact();
                              game.playCard(card);
                            }
                          : null,
                      onLongPress: () => showCardDetail(context, card),
                    ),
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
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                game.endTurn();
              }
            : null,
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
}

// ---------------------------------------------------------------------------
// Hero panel
// ---------------------------------------------------------------------------

class _HeroPowerState {
  const _HeroPowerState({
    required this.visible,
    required this.enabled,
    required this.armed,
    required this.used,
    required this.onTap,
  });

  final bool visible;
  final bool enabled;
  final bool armed;
  final bool used;
  final VoidCallback onTap;
}

/// Hero portrait + HP bar + mana crystals for one side.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.player,
    required this.isEnemy,
    this.targetable = false,
    this.enraged = false,
    this.relic,
    this.onTap,
    this.alwaysTappable = false,
    this.heroPower,
  });

  final Player player;
  final bool isEnemy;
  final bool targetable;
  final bool enraged;
  final Relic? relic;
  final VoidCallback? onTap;
  final bool alwaysTappable;
  final _HeroPowerState? heroPower;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (targetable || alwaysTappable) ? onTap : null,
      child: ValueChangeEffect(
        value: player.hp,
        borderRadius: 14,
        numberFontSize: 30,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.panel.withValues(alpha: 0.95),
                AppColors.backgroundLight.withValues(alpha: 0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: targetable
                  ? AppColors.hpRed
                  : enraged
                      ? AppColors.hpRed.withValues(alpha: 0.8)
                      : AppColors.panelBorder.withValues(alpha: 0.7),
              width: targetable ? 2.5 : (enraged ? 1.8 : 1),
            ),
            boxShadow: [
              if (targetable || enraged)
                BoxShadow(
                    color: AppColors.hpRed.withValues(alpha: 0.6),
                    blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              // Portrait.
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isEnemy
                        ? [AppColors.hpRed, const Color(0xFF7A1F1A)]
                        : [AppColors.lightningDeep, AppColors.lightning],
                  ),
                  border: Border.all(color: AppColors.goldLight, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isEnemy
                              ? AppColors.hpRed
                              : AppColors.lightning)
                          .withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  isEnemy
                      ? (enraged ? Icons.whatshot : Icons.shield_moon)
                      : Icons.person,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(player.name,
                            style: AppTheme.body(13.5,
                                weight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Icon(Icons.layers,
                            size: 12, color: AppColors.textMuted),
                        Text(' ${player.deck.length}',
                            style: AppTheme.body(11,
                                color: AppColors.textMuted)),
                        if (relic != null) ...[
                          const SizedBox(width: 6),
                          Icon(relic!.icon, size: 13, color: relic!.color),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _hpBar(),
                    const SizedBox(height: 4),
                    _ManaCrystals(mana: player.mana, maxMana: player.maxMana),
                  ],
                ),
              ),
              if (heroPower != null && heroPower!.visible) ...[
                const SizedBox(width: 8),
                _HeroPowerButton(state: heroPower!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hpBar() {
    final fraction = (player.hp / player.maxHp).clamp(0.0, 1.0);
    final low = fraction <= 0.3;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: AppColors.background.withValues(alpha: 0.8),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  widthFactor: fraction,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: low
                            ? [const Color(0xFF8E1F18), AppColors.hpRed]
                            : [AppColors.hpRed, const Color(0xFFFF7A6B)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${player.hp}/${player.maxHp}',
          style: AppTheme.title(12,
              color: low ? AppColors.hpRed : Colors.white),
        ),
      ],
    );
  }
}

/// The circular Thunderbolt hero-power button.
class _HeroPowerButton extends StatelessWidget {
  const _HeroPowerButton({required this.state});

  final _HeroPowerState state;

  @override
  Widget build(BuildContext context) {
    final color = state.armed
        ? AppColors.lightning
        : state.enabled
            ? AppColors.gold
            : AppColors.panelBorder;
    return GestureDetector(
      onTap: state.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.background.withValues(alpha: 0.85),
          border: Border.all(color: color, width: state.armed ? 2.5 : 1.6),
          boxShadow: [
            if (state.armed || state.enabled)
              BoxShadow(
                color: color.withValues(alpha: 0.55),
                blurRadius: state.armed ? 14 : 8,
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              state.used ? Icons.flash_off : Icons.flash_on,
              color: state.used ? AppColors.textMuted : color,
              size: 20,
            ),
            Text(
              '${GameController.heroPowerCost}',
              style: AppTheme.body(9,
                  color: AppColors.manaBlue, weight: FontWeight.w700),
            ),
          ],
        ),
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
