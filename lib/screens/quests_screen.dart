import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/player_profile.dart';
import '../models/quest.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';

/// Quests tab: the daily login bonus + three rotating daily quests.
class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();

    return AppScaffold(
      title: 'DAILY QUESTS',
      profile: profile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _loginBonus(context, profile),
          const SizedBox(height: 18),
          Text('QUESTS',
              style: AppTheme.title(14, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          if (profile.quests.isEmpty)
            Text('New quests arrive soon...',
                style: AppTheme.body(14, color: AppColors.textMuted)),
          for (final q in profile.quests) ...[
            _QuestTile(quest: q, profile: profile),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text(
            'Quests re-roll every 24 hours.',
            textAlign: TextAlign.center,
            style: AppTheme.body(12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _loginBonus(BuildContext context, PlayerProfile profile) {
    final claimed = profile.dailyBonusClaimed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: claimed ? 0.10 : 0.25),
            AppColors.panel.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: claimed
              ? AppColors.panelBorder
              : AppColors.gold.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month,
              color: claimed ? AppColors.textMuted : AppColors.gold, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY BONUS', style: AppTheme.title(15)),
                const SizedBox(height: 2),
                Text(
                  'Login streak: ${profile.loginStreak} day${profile.loginStreak == 1 ? '' : 's'}',
                  style: AppTheme.body(12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 110,
            child: PrimaryButton(
              label: claimed ? 'CLAIMED' : '+${profile.dailyBonusGold}',
              icon: claimed ? Icons.check : Icons.monetization_on,
              height: 42,
              fontSize: 13,
              enabled: !claimed,
              onTap: () {
                HapticFeedback.mediumImpact();
                profile.claimDailyBonus();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.profile});

  final QuestInstance quest;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = quest.template;
    final claimable = quest.isComplete && !quest.claimed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: claimable
              ? AppColors.success
              : quest.claimed
                  ? AppColors.panelBorder.withValues(alpha: 0.5)
                  : AppColors.panelBorder,
          width: claimable ? 1.8 : 1,
        ),
        boxShadow: [
          if (claimable)
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
        ],
      ),
      child: Opacity(
        opacity: quest.claimed ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.title, style: AppTheme.title(15)),
                ),
                Icon(Icons.monetization_on,
                    color: AppColors.gold, size: 15),
                Text(' ${t.goldReward}',
                    style: AppTheme.body(13,
                        color: AppColors.gold, weight: FontWeight.w700)),
                if (t.ambrosiaReward > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.local_drink,
                      color: AppColors.ambrosia, size: 15),
                  Text(' ${t.ambrosiaReward}',
                      style: AppTheme.body(13,
                          color: AppColors.ambrosia,
                          weight: FontWeight.w700)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: quest.fraction),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 9,
                        backgroundColor:
                            AppColors.background.withValues(alpha: 0.8),
                        valueColor: AlwaysStoppedAnimation(
                          quest.isComplete
                              ? AppColors.success
                              : AppColors.lightning,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${quest.progress}/${t.target}',
                    style: AppTheme.body(12, color: AppColors.textMuted)),
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
                  profile.claimQuest(quest);
                },
              ),
            ],
            if (quest.claimed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 16),
                    const SizedBox(width: 6),
                    Text('Completed',
                        style: AppTheme.body(12, color: AppColors.success)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
