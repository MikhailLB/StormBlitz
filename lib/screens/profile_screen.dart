import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_transitions.dart';
import 'achievements_screen.dart';
import 'settings_screen.dart';

/// Profile tab: league banner, stats, title picker, links to achievements
/// and settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();

    return AppScaffold(
      title: 'PROFILE',
      profile: profile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _leagueBanner(profile),
          const SizedBox(height: 16),
          _statsGrid(profile),
          const SizedBox(height: 16),
          if (profile.unlockedTitles.isNotEmpty) ...[
            Text('TITLE',
                style: AppTheme.title(14, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            _titlePicker(profile),
            const SizedBox(height: 16),
          ],
          _navTile(
            context,
            icon: Icons.emoji_events,
            color: AppColors.gold,
            label: 'Achievements',
            subtitle:
                '${profile.claimedAchievements.length} claimed',
            screen: const AchievementsScreen(),
          ),
          const SizedBox(height: 10),
          _navTile(
            context,
            icon: Icons.settings,
            color: AppColors.lightning,
            label: 'Settings',
            subtitle: 'Privacy, support, reset',
            screen: const SettingsScreen(),
          ),
        ],
      ),
    );
  }

  Widget _leagueBanner(PlayerProfile profile) {
    final league = profile.league;
    final color = _leagueColor(league);
    final next = League.values
        .where((l) => l.threshold > profile.trophies)
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.30),
            AppColors.panel.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 16),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.military_tech, color: color, size: 52),
          const SizedBox(height: 6),
          Text(league.label.toUpperCase(),
              style: AppTheme.title(22, color: color)),
          if (profile.activeTitle != null) ...[
            const SizedBox(height: 2),
            Text('«${profile.activeTitle}»',
                style: AppTheme.body(14,
                    color: AppColors.goldLight, weight: FontWeight.w700)),
          ],
          const SizedBox(height: 8),
          Text(
            '${profile.trophies} trophies',
            style: AppTheme.body(15, color: AppColors.textPrimary),
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: (profile.trophies / next.first.threshold)
                    .clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.background.withValues(alpha: 0.7),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${next.first.threshold - profile.trophies} trophies to ${next.first.label}',
              style: AppTheme.body(12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Color _leagueColor(League league) {
    switch (league) {
      case League.bronze:
        return const Color(0xFFCD8A54);
      case League.silver:
        return AppColors.common;
      case League.gold:
        return AppColors.gold;
      case League.olympian:
        return AppColors.lightning;
    }
  }

  Widget _statsGrid(PlayerProfile profile) {
    final total = profile.wins + profile.losses;
    final winRate =
        total == 0 ? '—' : '${(profile.wins / total * 100).round()}%';
    final items = [
      ('Level', '${profile.level}', Icons.star),
      ('Wins', '${profile.wins}', Icons.emoji_events),
      ('Losses', '${profile.losses}', Icons.dangerous),
      ('Win rate', winRate, Icons.percent),
      ('Gods summoned', '${profile.totalCardsPlayed}', Icons.style),
      ('Chests opened', '${profile.chestsOpened}', Icons.inventory_2),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final (label, value, icon) in items)
          Container(
            decoration: BoxDecoration(
              color: AppColors.panel.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.panelBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.lightning, size: 20),
                const SizedBox(height: 4),
                Text(value, style: AppTheme.title(17)),
                Text(label,
                    style: AppTheme.body(11, color: AppColors.textMuted)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _titlePicker(PlayerProfile profile) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final title in profile.unlockedTitles)
          GestureDetector(
            onTap: () => profile.setActiveTitle(
                profile.activeTitle == title ? null : title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: profile.activeTitle == title
                    ? AppColors.gold.withValues(alpha: 0.22)
                    : AppColors.panel.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: profile.activeTitle == title
                      ? AppColors.gold
                      : AppColors.panelBorder,
                ),
              ),
              child: Text(
                title,
                style: AppTheme.body(13,
                    color: profile.activeTitle == title
                        ? AppColors.goldLight
                        : AppColors.textPrimary,
                    weight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(AppTransitions.slideUp(screen)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panel.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.panelBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTheme.title(15)),
                  Text(subtitle,
                      style: AppTheme.body(12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
