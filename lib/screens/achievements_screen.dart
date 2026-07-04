import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/achievement_data.dart';
import '../data/relic_data.dart';
import '../models/achievement.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();
    final sorted = [...AchievementData.all]..sort((a, b) {
        int rank(Achievement x) {
          final claimed = profile.claimedAchievements.contains(x.id);
          if (claimed) return 2;
          return profile.isAchievementComplete(x) ? 0 : 1;
        }

        return rank(a).compareTo(rank(b));
      });

    return AppScaffold(
      title: 'ACHIEVEMENTS',
      showBack: true,
      profile: profile,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) =>
            _AchievementTile(achievement: sorted[i], profile: profile),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.profile});

  final Achievement achievement;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final claimed = profile.claimedAchievements.contains(a.id);
    final complete = profile.isAchievementComplete(a);
    final claimable = complete && !claimed;
    final progress = profile.achievementProgress(a);
    final relic = RelicData.byId(a.relicReward);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimable
              ? AppColors.gold
              : claimed
                  ? AppColors.panelBorder.withValues(alpha: 0.5)
                  : AppColors.panelBorder,
          width: claimable ? 1.8 : 1,
        ),
        boxShadow: [
          if (claimable)
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.25),
                blurRadius: 12),
        ],
      ),
      child: Opacity(
        opacity: claimed ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  claimed ? Icons.check_circle : Icons.emoji_events,
                  color: claimed ? AppColors.success : AppColors.gold,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: AppTheme.title(15)),
                      Text(a.description,
                          style: AppTheme.body(12,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (progress / a.target).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor:
                          AppColors.background.withValues(alpha: 0.8),
                      valueColor: AlwaysStoppedAnimation(
                        complete ? AppColors.success : AppColors.lightning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${progress.clamp(0, a.target)}/${a.target}',
                  style: AppTheme.body(12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _rewardChip(Icons.monetization_on, AppColors.gold,
                    '${a.goldReward}'),
                if (a.ambrosiaReward > 0)
                  _rewardChip(Icons.local_drink, AppColors.ambrosia,
                      '${a.ambrosiaReward}'),
                if (a.titleReward != null)
                  _rewardChip(Icons.badge, AppColors.goldLight,
                      '«${a.titleReward}»'),
                if (relic != null)
                  _rewardChip(relic.icon, relic.color, relic.name),
              ],
            ),
            if (claimable) ...[
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'CLAIM',
                icon: Icons.redeem,
                height: 42,
                fontSize: 14,
                onTap: () {
                  HapticFeedback.heavyImpact();
                  profile.claimAchievement(a);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rewardChip(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 3),
        Text(text,
            style:
                AppTheme.body(12, color: color, weight: FontWeight.w700)),
      ],
    );
  }
}
