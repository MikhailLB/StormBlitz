import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chest.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_counter.dart';
import '../widgets/chest_widget.dart';
import '../widgets/particle_burst.dart';
import '../widgets/primary_button.dart';
import '../widgets/storm_background.dart';

/// Post-battle rewards ceremony: counters tick up, the chest (if any)
/// drops in, and campaign first-clear bonuses are called out.
class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({
    super.key,
    required this.victory,
    required this.rewards,
    required this.chestGranted,
    this.firstClearGold = 0,
    this.firstClearAmbrosia = 0,
    this.onPlayAgain,
  });

  final bool victory;
  final BattleRewards rewards;

  /// False when the chest was rolled but all slots were full.
  final bool chestGranted;

  final int firstClearGold;
  final int firstClearAmbrosia;

  /// When set, shows a PLAY AGAIN button that restarts the same battle.
  final VoidCallback? onPlayAgain;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.victory) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final victory = widget.victory;
    final r = widget.rewards;
    final accent = victory ? AppColors.goldLight : AppColors.hpRed;

    return Scaffold(
      body: StormBackground(
        darken: 0.78,
        showFlash: victory,
        intensity: victory ? 0.6 : 0.0,
        child: Stack(
          children: [
            if (victory)
              const Positioned.fill(
                child: ParticleBurst(
                  colors: [
                    AppColors.goldLight,
                    AppColors.gold,
                    AppColors.lightning,
                  ],
                  particleCount: 44,
                  spread: 230,
                  duration: Duration(milliseconds: 1400),
                ),
              )
            else
              // Defeat: red vignette pulse.
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 0.0),
                    duration: const Duration(milliseconds: 1200),
                    builder: (_, v, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          radius: 1.1,
                          colors: [
                            Colors.transparent,
                            AppColors.hpRed.withValues(alpha: v),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 550),
                      curve: Curves.easeOutBack,
                      builder: (_, t, child) => Transform.scale(
                        scale: 0.6 + 0.4 * t,
                        child:
                            Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            victory ? Icons.emoji_events : Icons.dangerous,
                            size: 84,
                            color: victory ? AppColors.gold : AppColors.hpRed,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            victory ? 'VICTORY' : 'DEFEAT',
                            style: AppTheme.title(46, color: accent),
                          ),
                          Text(
                            victory
                                ? 'Olympus bows before you.'
                                : 'The heavens have forsaken you.',
                            style: AppTheme.body(15,
                                color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    _rewardsPanel(r),
                    if (r.chestTier != null) ...[
                      const SizedBox(height: 14),
                      _chestPanel(r.chestTier!),
                    ],
                    const Spacer(flex: 3),
                    if (widget.onPlayAgain != null) ...[
                      PrimaryButton(
                        label: 'PLAY AGAIN',
                        icon: Icons.refresh,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onPlayAgain!();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    PrimaryButton(
                      label: 'CONTINUE',
                      icon: Icons.home,
                      primary: widget.onPlayAgain == null,
                      onTap: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardsPanel(BattleRewards r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _counter(Icons.monetization_on, AppColors.gold,
                  r.gold + widget.firstClearGold, 'GOLD'),
              _counter(Icons.auto_awesome, AppColors.lightning, r.xp, 'XP'),
              _counter(
                Icons.emoji_events,
                r.trophyDelta >= 0 ? AppColors.goldLight : AppColors.hpRed,
                r.trophyDelta,
                'TROPHIES',
                signed: true,
              ),
            ],
          ),
          if (widget.firstClearGold > 0 || widget.firstClearAmbrosia > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.epic.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.epic.withValues(alpha: 0.7)),
              ),
              child: Text(
                'FIRST CLEAR BONUS!'
                '${widget.firstClearAmbrosia > 0 ? ' +${widget.firstClearAmbrosia} ambrosia' : ''}',
                style: AppTheme.body(13,
                    color: AppColors.epic, weight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _counter(IconData icon, Color color, int value, String label,
      {bool signed = false}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        AnimatedCounter(
          value: value,
          prefix: signed && value > 0 ? '+' : '',
          duration: const Duration(milliseconds: 1100),
          style: AppTheme.title(22, color: color),
        ),
        Text(label, style: AppTheme.body(11, color: AppColors.textMuted)),
      ],
    );
  }

  Widget _chestPanel(ChestTier tier) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.bounceOut,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(0, -30 * (1 - t)),
        child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tier.color.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
                color: tier.color.withValues(alpha: 0.3), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChestWidget(tier: tier, size: 46, glowing: widget.chestGranted),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.label,
                    style: AppTheme.title(15, color: tier.color)),
                Text(
                  widget.chestGranted
                      ? 'Added to your chest slots!'
                      : 'Chest slots full — reward lost!',
                  style: AppTheme.body(12,
                      color: widget.chestGranted
                          ? AppColors.textMuted
                          : AppColors.hpRed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
