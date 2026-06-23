import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/storm_background.dart';
import 'battle_screen.dart';
import 'web_view_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  static const String privacyUrl = 'https://storrmblitz.com/privacy-policy.html';
  static const String supportUrl = 'https://storrmblitz.com/support.html';

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StormBackground(
        darken: 0.45,
        showFlash: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                Image.asset(
                  'assets/logo.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Text(
                    'STORM BLITZ',
                    style: AppTheme.title(40),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'COUNCIL OF OLYMPUS',
                  style: AppTheme.body(16,
                      color: AppColors.gold, weight: FontWeight.w700)
                      .copyWith(letterSpacing: 4),
                ),
                const Spacer(flex: 3),
                _MenuButton(
                  label: 'PLAY',
                  icon: Icons.bolt,
                  primary: true,
                  onTap: () => _selectDifficulty(context),
                ),
                const SizedBox(height: 16),
                _MenuButton(
                  label: 'HOW TO PLAY',
                  icon: Icons.menu_book,
                  onTap: () => _showHowToPlay(context),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MenuButton(
                        label: 'PRIVACY',
                        icon: Icons.privacy_tip_outlined,
                        compact: true,
                        onTap: () => _open(
                          context,
                          const WebViewScreen(
                            title: 'Privacy Policy',
                            url: privacyUrl,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _MenuButton(
                        label: 'SUPPORT',
                        icon: Icons.support_agent,
                        compact: true,
                        onTap: () => _open(
                          context,
                          const WebViewScreen(
                            title: 'Support',
                            url: supportUrl,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                Text(
                  'v1.0.0',
                  style: AppTheme.body(12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectDifficulty(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.panelBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text('CHOOSE YOUR TRIAL', style: AppTheme.title(22)),
            const SizedBox(height: 16),
            for (final d in Difficulty.values) ...[
              _DifficultyTile(
                difficulty: d,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _open(context, BattleScreen(difficulty: d));
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _showHowToPlay(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to Play', style: AppTheme.title(24)),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._rules.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.bolt,
                                  color: AppColors.lightning, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(r,
                                    style: AppTheme.body(15,
                                        color: AppColors.textPrimary)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('GOT IT',
                      style: AppTheme.body(16, color: AppColors.gold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<String> _rules = [
    'Reduce the enemy hero to 0 HP to win.',
    'Each card shows three numbers: the BLUE drop (top-left) is its mana cost, the ORANGE bolt (bottom-left) is its attack, and the RED heart (bottom-right) is its current health.',
    'Each turn you gain a mana crystal (max 10). Spend mana to summon gods.',
    'Tap a card in your hand to summon it onto the battlefield.',
    'Tap your god, then tap a target to attack. Gods can attack once per turn.',
    'TAUNT gods must be destroyed first. CHARGE gods attack immediately.',
    'Battlecries trigger automatically when a god is summoned.',
    'Press and hold any card to open it full-size and read all of its stats and its special ability.',
  ];
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.difficulty, required this.onTap});

  final Difficulty difficulty;
  final VoidCallback onTap;

  Color get _accent {
    switch (difficulty) {
      case Difficulty.easy:
        return const Color(0xFF4CD964);
      case Difficulty.normal:
        return AppColors.lightning;
      case Difficulty.hard:
        return AppColors.hpRed;
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
          border: Border.all(color: _accent.withValues(alpha: 0.7), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _accent, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(difficulty.label.toUpperCase(),
                      style: AppTheme.title(18, color: _accent)),
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

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gradient = primary
        ? const LinearGradient(
            colors: [AppColors.gold, AppColors.goldLight],
          )
        : LinearGradient(
            colors: [
              AppColors.panel.withValues(alpha: 0.95),
              AppColors.backgroundLight.withValues(alpha: 0.95),
            ],
          );
    final fg = primary ? Colors.black : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: compact ? 54 : 64,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primary ? AppColors.goldLight : AppColors.panelBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (primary ? AppColors.gold : Colors.black)
                  .withValues(alpha: 0.45),
              blurRadius: primary ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: compact ? 20 : 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTheme.title(compact ? 16 : 20, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
