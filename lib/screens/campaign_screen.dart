import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/campaign_data.dart';
import '../data/relic_data.dart';
import '../game/game_controller.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_transitions.dart';
import 'battle_screen.dart';

/// The "Pantheon Trials" campaign: nine nodes, unlocked in order,
/// first-clear rewards, boss finale.
class CampaignScreen extends StatelessWidget {
  const CampaignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();

    return AppScaffold(
      title: 'PANTHEON TRIALS',
      showBack: true,
      profile: profile,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: CampaignData.nodes.length,
        separatorBuilder: (_, _) => _connector(),
        itemBuilder: (context, i) {
          final node = CampaignData.nodes[i];
          final cleared = profile.campaignClears.contains(node.id);
          final unlocked = i == 0 ||
              profile.campaignClears
                  .contains(CampaignData.nodes[i - 1].id);
          return _NodeTile(
            node: node,
            index: i,
            cleared: cleared,
            unlocked: unlocked,
            onTap: unlocked
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      AppTransitions.slideUp(
                        BattleScreen(
                          difficulty: node.difficulty,
                          deckLevels: profile.deckLevels,
                          relic:
                              RelicData.byId(profile.equippedRelicId),
                          campaignNode: node,
                        ),
                      ),
                    );
                  }
                : null,
          );
        },
      ),
    );
  }

  Widget _connector() {
    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Container(
        width: 3,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.panelBorder,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.index,
    required this.cleared,
    required this.unlocked,
    required this.onTap,
  });

  final CampaignNode node;
  final int index;
  final bool cleared;
  final bool unlocked;
  final VoidCallback? onTap;

  Color get _accent {
    if (node.bossEnrage) return AppColors.hpRed;
    switch (node.difficulty) {
      case Difficulty.easy:
        return AppColors.success;
      case Difficulty.normal:
        return AppColors.lightning;
      case Difficulty.hard:
        return AppColors.attackOrange;
      case Difficulty.olympian:
        return AppColors.epic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBoss = node.bossEnrage;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: unlocked ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isBoss && unlocked
                ? LinearGradient(colors: [
                    AppColors.hpRed.withValues(alpha: 0.25),
                    AppColors.panel.withValues(alpha: 0.95),
                  ])
                : null,
            color: isBoss && unlocked
                ? null
                : AppColors.panel.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cleared
                  ? AppColors.success.withValues(alpha: 0.7)
                  : _accent.withValues(alpha: unlocked ? 0.8 : 0.4),
              width: isBoss ? 2 : 1.3,
            ),
            boxShadow: [
              if (isBoss && unlocked && !cleared)
                BoxShadow(
                  color: AppColors.hpRed.withValues(alpha: 0.3),
                  blurRadius: 14,
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background.withValues(alpha: 0.7),
                  border: Border.all(
                      color: cleared ? AppColors.success : _accent,
                      width: 1.6),
                ),
                child: cleared
                    ? const Icon(Icons.check,
                        color: AppColors.success, size: 24)
                    : unlocked
                        ? Icon(
                            isBoss ? Icons.whatshot : Icons.terrain,
                            color: _accent,
                            size: 24,
                          )
                        : const Icon(Icons.lock,
                            color: AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${node.name}'.toUpperCase(),
                      style: AppTheme.title(14,
                          color: isBoss ? AppColors.hpRed : null),
                    ),
                    const SizedBox(height: 2),
                    Text(node.subtitle,
                        style:
                            AppTheme.body(12, color: AppColors.textMuted)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _chip(node.difficulty.label.toUpperCase(), _accent),
                        const SizedBox(width: 8),
                        if (!cleared) ...[
                          Icon(Icons.monetization_on,
                              color: AppColors.gold, size: 13),
                          Text(' ${node.goldReward}',
                              style: AppTheme.body(12,
                                  color: AppColors.gold,
                                  weight: FontWeight.w700)),
                          if (node.ambrosiaReward > 0) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.local_drink,
                                color: AppColors.ambrosia, size: 13),
                            Text(' ${node.ambrosiaReward}',
                                style: AppTheme.body(12,
                                    color: AppColors.ambrosia,
                                    weight: FontWeight.w700)),
                          ],
                        ] else
                          Text('Cleared',
                              style: AppTheme.body(12,
                                  color: AppColors.success,
                                  weight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              if (unlocked && !cleared)
                Icon(Icons.chevron_right, color: _accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(text,
          style: AppTheme.body(10, color: color, weight: FontWeight.w700)),
    );
  }
}
