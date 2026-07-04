import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chest.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_transitions.dart';
import '../widgets/chest_widget.dart';
import '../widgets/primary_button.dart';
import 'chest_opening_screen.dart';
import 'difficulty_select_screen.dart';
import 'how_to_play_screen.dart';

/// Home tab: hero banner, event strip, chest slots and the PLAY button.
class BattleHubScreen extends StatefulWidget {
  const BattleHubScreen({super.key});

  /// Toggle for the (static) weekend event banner.
  static const bool eventBannerEnabled = true;

  @override
  State<BattleHubScreen> createState() => _BattleHubScreenState();
}

class _BattleHubScreenState extends State<BattleHubScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh chest countdowns every second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();

    return AppScaffold(
      profile: profile,
      showFlash: true,
      darken: 0.5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Image.asset(
              'assets/logo.webp',
              height: 110,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Text('STORM BLITZ', style: AppTheme.title(36)),
            ),
            const SizedBox(height: 4),
            Text(
              'COUNCIL OF OLYMPUS',
              style: AppTheme.body(14,
                      color: AppColors.gold, weight: FontWeight.w700)
                  .copyWith(letterSpacing: 4),
            ),
            const SizedBox(height: 14),
            _leagueStrip(profile),
            if (BattleHubScreen.eventBannerEnabled) ...[
              const SizedBox(height: 12),
              _eventBanner(),
            ],
            const SizedBox(height: 16),
            _chestRow(profile),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'PLAY',
              icon: Icons.bolt,
              height: 64,
              fontSize: 22,
              onTap: () => Navigator.of(context).push(
                AppTransitions.slideUp(const DifficultySelectScreen()),
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'HOW TO PLAY',
              icon: Icons.menu_book,
              primary: false,
              height: 52,
              fontSize: 16,
              onTap: () => Navigator.of(context).push(
                AppTransitions.slideUp(const HowToPlayScreen()),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _leagueStrip(PlayerProfile profile) {
    final league = profile.league;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.military_tech, color: _leagueColor(league), size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(league.label.toUpperCase(),
                    style: AppTheme.title(14, color: _leagueColor(league))),
                Text(
                  '${profile.trophies} trophies · Level ${profile.level}',
                  style: AppTheme.body(12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.emoji_events, color: AppColors.gold, size: 20),
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

  Widget _eventBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.epic.withValues(alpha: 0.35),
            AppColors.lightningDeep.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.epic.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: AppColors.epic, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'WEEKEND EVENT: chest luck is blessed by the gods!',
              style: AppTheme.body(13,
                  color: AppColors.textPrimary, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Chest slots
  // -------------------------------------------------------------------

  Widget _chestRow(PlayerProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CHESTS', style: AppTheme.title(14, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < profile.chestSlots.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _chestSlot(profile, i)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chestSlot(PlayerProfile profile, int slot) {
    final chest = profile.chestSlots[slot];

    if (chest == null) {
      return AspectRatio(
        aspectRatio: 0.78,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.panelBorder.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add,
                  color: AppColors.textMuted.withValues(alpha: 0.5), size: 22),
              const SizedBox(height: 4),
              Text('Win battles',
                  textAlign: TextAlign.center,
                  style: AppTheme.body(9.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }

    final String statusText;
    final Color statusColor;
    if (chest.isReady) {
      statusText = 'OPEN!';
      statusColor = AppColors.success;
    } else if (chest.isUnlocking) {
      statusText = formatChestDuration(chest.remaining);
      statusColor = AppColors.lightning;
    } else {
      statusText = formatChestDuration(chest.tier.unlockDuration);
      statusColor = AppColors.textMuted;
    }

    return GestureDetector(
      onTap: () => _onChestTap(profile, slot, chest),
      child: AspectRatio(
        aspectRatio: 0.78,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: chest.isReady
                  ? AppColors.success
                  : chest.tier.color.withValues(alpha: 0.6),
              width: chest.isReady ? 2 : 1.2,
            ),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ChestWidget(
                  tier: chest.tier,
                  glowing: chest.isReady,
                  wobbling: chest.isUnlocking,
                ),
              ),
              Text(
                statusText,
                style: AppTheme.body(11,
                    color: statusColor, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onChestTap(PlayerProfile profile, int slot, ChestInstance chest) {
    HapticFeedback.lightImpact();
    if (chest.isReady) {
      Navigator.of(context).push(
        AppTransitions.scaleIn(ChestOpeningScreen(slot: slot)),
      );
      return;
    }
    if (chest.unlockStart == null) {
      if (profile.anyChestUnlocking) {
        _showRushSheet(profile, slot, chest, startInstead: true);
      } else {
        profile.startUnlocking(slot);
      }
      return;
    }
    // Currently unlocking -> offer to rush with ambrosia.
    _showRushSheet(profile, slot, chest);
  }

  /// 1 ambrosia per 10 minutes of remaining unlock time.
  int _rushCost(ChestInstance chest) =>
      max(1, (chest.remaining.inSeconds / 600).ceil());

  void _showRushSheet(
    PlayerProfile profile,
    int slot,
    ChestInstance chest, {
    bool startInstead = false,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final cost = _rushCost(chest);
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            border:
                Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChestWidget(tier: chest.tier, size: 72),
              const SizedBox(height: 8),
              Text(chest.tier.label, style: AppTheme.title(20)),
              const SizedBox(height: 4),
              Text(
                startInstead
                    ? 'Another chest is already unlocking.'
                    : 'Unlocks in ${formatChestDuration(chest.remaining)}',
                style: AppTheme.body(14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'OPEN NOW · $cost',
                icon: Icons.local_drink,
                height: 54,
                enabled: profile.ambrosia >= cost,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  if (chest.unlockStart == null) {
                    // Rushing a chest that hasn't started: pay & open.
                    if (profile.spendAmbrosia(cost)) {
                      chest.unlockStart = DateTime.now()
                          .subtract(chest.tier.unlockDuration);
                      Navigator.of(context).push(
                        AppTransitions.scaleIn(
                            ChestOpeningScreen(slot: slot)),
                      );
                    }
                  } else if (profile.rushChest(slot, cost)) {
                    Navigator.of(context).push(
                      AppTransitions.scaleIn(ChestOpeningScreen(slot: slot)),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
