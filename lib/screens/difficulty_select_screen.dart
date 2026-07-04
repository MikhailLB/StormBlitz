import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/relic_data.dart';
import '../game/game_controller.dart';
import '../models/player_profile.dart';
import '../models/relic.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_transitions.dart';
import '../widgets/primary_button.dart';
import 'battle_screen.dart';
import 'campaign_screen.dart';

/// Full-screen battle setup: difficulty, equipped relic and campaign entry.
class DifficultySelectScreen extends StatelessWidget {
  const DifficultySelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();

    return AppScaffold(
      title: 'CHOOSE YOUR TRIAL',
      showBack: true,
      profile: profile,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _campaignCard(context, profile),
            const SizedBox(height: 18),
            Text('QUICK BATTLE',
                style: AppTheme.title(14, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            for (final d in Difficulty.values) ...[
              _DifficultyTile(
                difficulty: d,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).push(
                    AppTransitions.slideUp(
                      BattleScreen(
                        difficulty: d,
                        deckLevels: profile.deckLevels,
                        relic: RelicData.byId(profile.equippedRelicId),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text('RELIC',
                style: AppTheme.title(14, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            _relicPicker(context, profile),
          ],
        ),
      ),
    );
  }

  Widget _campaignCard(BuildContext context, PlayerProfile profile) {
    final cleared = profile.campaignClears.length;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        AppTransitions.slideUp(const CampaignScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.lightningDeep.withValues(alpha: 0.45),
              AppColors.epic.withValues(alpha: 0.35),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightning, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.lightning.withValues(alpha: 0.25),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.terrain, color: AppColors.lightning, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PANTHEON TRIALS', style: AppTheme.title(18)),
                  const SizedBox(height: 3),
                  Text(
                    'Campaign · $cleared / 9 trials conquered',
                    style: AppTheme.body(13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.lightning),
          ],
        ),
      ),
    );
  }

  Widget _relicPicker(BuildContext context, PlayerProfile profile) {
    if (profile.ownedRelics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.panelBorder),
        ),
        child: Text(
          'No relics yet. Find them in chests and achievements — each grants a passive power in battle.',
          style: AppTheme.body(13, color: AppColors.textMuted),
        ),
      );
    }

    final owned =
        RelicData.all.where((r) => profile.ownedRelics.contains(r.id)).toList();
    return Column(
      children: [
        for (final relic in owned) ...[
          _relicTile(context, profile, relic),
          const SizedBox(height: 8),
        ],
        if (profile.equippedRelicId != null)
          PrimaryButton(
            label: 'UNEQUIP RELIC',
            primary: false,
            height: 44,
            fontSize: 14,
            onTap: () => profile.equipRelic(null),
          ),
      ],
    );
  }

  Widget _relicTile(BuildContext context, PlayerProfile profile, Relic relic) {
    final equipped = profile.equippedRelicId == relic.id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        profile.equipRelic(equipped ? null : relic.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.panel
              .withValues(alpha: equipped ? 0.95 : 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: equipped ? relic.color : AppColors.panelBorder,
            width: equipped ? 2 : 1,
          ),
          boxShadow: [
            if (equipped)
              BoxShadow(
                color: relic.color.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: relic.color.withValues(alpha: 0.15),
                border: Border.all(color: relic.color, width: 1.5),
              ),
              child: Icon(relic.icon, color: relic.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(relic.name,
                      style: AppTheme.title(14, color: relic.color)),
                  const SizedBox(height: 2),
                  Text(relic.description,
                      style:
                          AppTheme.body(12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (equipped)
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 22),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.difficulty, required this.onTap});

  final Difficulty difficulty;
  final VoidCallback onTap;

  Color get _accent {
    switch (difficulty) {
      case Difficulty.easy:
        return AppColors.success;
      case Difficulty.normal:
        return AppColors.lightning;
      case Difficulty.hard:
        return AppColors.hpRed;
      case Difficulty.olympian:
        return AppColors.epic;
    }
  }

  IconData get _icon {
    switch (difficulty) {
      case Difficulty.easy:
        return Icons.shield_outlined;
      case Difficulty.normal:
        return Icons.balance;
      case Difficulty.hard:
        return Icons.local_fire_department;
      case Difficulty.olympian:
        return Icons.flash_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: _accent.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(difficulty.label.toUpperCase(),
                          style: AppTheme.title(17, color: _accent)),
                      const SizedBox(width: 8),
                      Icon(Icons.emoji_events,
                          size: 13, color: AppColors.gold),
                      Text(
                        ' +${difficulty.trophyWin}',
                        style: AppTheme.body(12,
                            color: AppColors.gold, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(difficulty.blurb,
                      style: AppTheme.body(13, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _accent),
          ],
        ),
      ),
    );
  }
}
