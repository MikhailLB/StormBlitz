import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/card_data.dart';
import '../models/game_card.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/card_view.dart';
import '../widgets/level_badge.dart';
import '../widgets/particle_burst.dart';
import '../widgets/primary_button.dart';

/// Collection tab: every god, its level, spare copies and upgrades.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();
    final roster = CardData.roster();

    return AppScaffold(
      title: 'COLLECTION',
      profile: profile,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.60,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        itemCount: roster.length,
        itemBuilder: (context, i) {
          final base = roster[i];
          final level = profile.cardLevel(base.id);
          final leveled = CardData.atLevel(base, level);
          return _CollectionTile(
            card: leveled,
            level: level,
            copies: profile.copiesOf(base.id),
            canUpgrade: profile.canUpgrade(base.id),
            onTap: () => _showUpgradeSheet(context, base),
          );
        },
      ),
    );
  }

  void _showUpgradeSheet(BuildContext context, GameCard base) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpgradeSheet(cardId: base.id),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.card,
    required this.level,
    required this.copies,
    required this.canUpgrade,
    required this.onTap,
  });

  final GameCard card;
  final int level;
  final int copies;
  final bool canUpgrade;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final needed = level < PlayerProfile.maxCardLevel
        ? PlayerProfile.upgradeCopies[level - 1]
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: LayoutBuilder(
                    builder: (context, c) => CardView(
                      card: card,
                      width: c.maxWidth,
                      showDescription: false,
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  left: 0,
                  child: LevelBadge(level: level),
                ),
                if (canUpgrade)
                  Positioned(
                    top: -2,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_upward,
                          size: 12, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Copies progress toward next level.
          if (level < PlayerProfile.maxCardLevel) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (copies / needed).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.background.withValues(alpha: 0.8),
                valueColor: AlwaysStoppedAnimation(
                  canUpgrade ? AppColors.success : AppColors.lightning,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text('$copies / $needed',
                style: AppTheme.body(10, color: AppColors.textMuted)),
          ] else
            Text('ASCENDED',
                style: AppTheme.body(10,
                    color: AppColors.legendary, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Bottom sheet with full card info + the upgrade action.
class _UpgradeSheet extends StatefulWidget {
  const _UpgradeSheet({required this.cardId});

  final String cardId;

  @override
  State<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<_UpgradeSheet> {
  int _burstTrigger = 0;
  bool _justUpgraded = false;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();
    final base =
        CardData.roster().firstWhere((c) => c.id == widget.cardId);
    final level = profile.cardLevel(base.id);
    final leveled = CardData.atLevel(base, level);
    final maxed = level >= PlayerProfile.maxCardLevel;
    final copies = profile.copiesOf(base.id);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 1.5)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 18,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(base.name, style: AppTheme.title(24)),
              Text(base.title,
                  style: AppTheme.body(13, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CardView(card: leveled, width: 120, showDescription: false),
                  const SizedBox(width: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelBadge(level: level),
                      const SizedBox(height: 8),
                      _statRow(Icons.bolt, AppColors.attackOrange,
                          'ATK ${leveled.attack}', _nextStat(base, level, true)),
                      const SizedBox(height: 4),
                      _statRow(Icons.favorite, AppColors.hpRed,
                          'HP ${leveled.health}', _nextStat(base, level, false)),
                      const SizedBox(height: 8),
                      if (leveled.frenzy)
                        _perk('FRENZY', AppColors.attackOrange),
                      if (leveled.lifesteal)
                        _perk('LIFESTEAL', AppColors.hpRed),
                      if (leveled.divineShield)
                        _perk('DIVINE SHIELD', AppColors.legendary),
                      if (!maxed && level + 1 >= 3 &&
                          (base.id == CardData.frenzyCardId ||
                              base.id == CardData.lifestealCardId) &&
                          level < 3)
                        _perk(
                            base.id == CardData.frenzyCardId
                                ? 'LV3: FRENZY'
                                : 'LV3: LIFESTEAL',
                            AppColors.textMuted),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                base.description,
                textAlign: TextAlign.center,
                style: AppTheme.body(13, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              if (maxed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.legendary),
                    color: AppColors.legendary.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    'ASCENDED — enters battle with a Divine Shield',
                    style: AppTheme.body(13,
                        color: AppColors.legendary, weight: FontWeight.w700),
                  ),
                )
              else ...[
                // Requirements, colored so it's obvious what's missing.
                Builder(builder: (context) {
                  final needCopies =
                      PlayerProfile.upgradeCopies[level - 1];
                  final needGold = PlayerProfile.upgradeGold[level - 1];
                  final copiesOk = copies >= needCopies;
                  final goldOk = profile.gold >= needGold;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _requirement(Icons.style, copiesOk,
                              '$copies / $needCopies copies'),
                          const SizedBox(width: 16),
                          _requirement(Icons.monetization_on, goldOk,
                              '$needGold gold'),
                        ],
                      ),
                      if (!goldOk) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Not enough gold — you have ${profile.gold}. Win battles or open chests!',
                          textAlign: TextAlign.center,
                          style: AppTheme.body(12, color: AppColors.hpRed),
                        ),
                      ] else if (!copiesOk) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Collect more copies of ${base.name} from chests and the shop.',
                          textAlign: TextAlign.center,
                          style: AppTheme.body(12, color: AppColors.hpRed),
                        ),
                      ],
                    ],
                  );
                }),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'UPGRADE TO LV ${level + 1}',
                  icon: Icons.arrow_upward,
                  height: 52,
                  enabled: profile.canUpgrade(base.id),
                  onTap: () {
                    if (profile.upgradeCard(base.id)) {
                      HapticFeedback.heavyImpact();
                      setState(() {
                        _burstTrigger++;
                        _justUpgraded = true;
                      });
                    }
                  },
                ),
              ],
            ],
          ),
          if (_justUpgraded)
            Positioned.fill(
              child: ParticleBurst(
                trigger: _burstTrigger,
                colors: const [
                  AppColors.goldLight,
                  AppColors.gold,
                  AppColors.lightning,
                ],
                particleCount: 34,
                spread: 170,
              ),
            ),
        ],
      ),
    );
  }

  String? _nextStat(GameCard base, int level, bool attack) {
    if (level >= PlayerProfile.maxCardLevel) return null;
    final now = attack
        ? CardData.scaledStat(base.attack, level)
        : CardData.scaledStat(base.health, level);
    final next = attack
        ? CardData.scaledStat(base.attack, level + 1)
        : CardData.scaledStat(base.health, level + 1);
    return next > now ? '→ $next' : null;
  }

  Widget _statRow(IconData icon, Color color, String text, String? next) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 5),
        Text(text, style: AppTheme.title(14, color: Colors.white)),
        if (next != null) ...[
          const SizedBox(width: 6),
          Text(next,
              style: AppTheme.body(13,
                  color: AppColors.success, weight: FontWeight.w700)),
        ],
      ],
    );
  }

  Widget _requirement(IconData icon, bool ok, String text) {
    final color = ok ? AppColors.success : AppColors.hpRed;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, color: color, size: 15),
        const SizedBox(width: 4),
        Icon(icon, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 3),
        Text(text,
            style: AppTheme.body(13, color: color, weight: FontWeight.w700)),
      ],
    );
  }

  Widget _perk(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Text(label,
            style: AppTheme.body(10, color: color, weight: FontWeight.w700)),
      ),
    );
  }
}
