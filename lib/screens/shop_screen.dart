import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/card_data.dart';
import '../models/chest.dart';
import '../models/game_card.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/chest_widget.dart';
import '../widgets/currency_pill.dart';
import '../widgets/primary_button.dart';

/// Shop tab: chests for gold/ambrosia + a rotating daily card offer.
/// Soft currency only — no real-money purchases.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  /// Today's featured card (rotates daily, same for everyone).
  static GameCard dailyCard() {
    final roster = CardData.roster();
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    return roster[day % roster.length];
  }

  static int dailyCardPrice(GameCard c) => switch (c.rarity) {
        Rarity.common => 90,
        Rarity.rare => 160,
        Rarity.legendary => 320,
      };

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();

    return AppScaffold(
      title: 'SHOP',
      profile: profile,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DAILY OFFER',
                style: AppTheme.title(14, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            _dailyOffer(context, profile),
            const SizedBox(height: 20),
            Text('CHESTS',
                style: AppTheme.title(14, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            _chestOffer(context, profile, ChestTier.common),
            const SizedBox(height: 10),
            _chestOffer(context, profile, ChestTier.rare),
            const SizedBox(height: 10),
            _chestOffer(context, profile, ChestTier.epic),
            const SizedBox(height: 10),
            _chestOffer(context, profile, ChestTier.olympian),
            const SizedBox(height: 20),
            Text('EXCHANGE',
                style: AppTheme.title(14, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            _exchangeTile(context, profile),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------

  Widget _dailyOffer(BuildContext context, PlayerProfile profile) {
    final card = dailyCard();
    final price = dailyCardPrice(card);
    final color = AppTheme.rarityColor(card.rarity.index);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            AppColors.panel.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              card.asset,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 64,
                height: 64,
                color: AppColors.backgroundLight,
                child: const Icon(Icons.bolt, color: AppColors.lightning),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${card.name} · 2 copies',
                    style: AppTheme.title(16, color: color)),
                const SizedBox(height: 2),
                Text('Rotates daily',
                    style: AppTheme.body(12, color: AppColors.textMuted)),
              ],
            ),
          ),
          _buyButton(
            context,
            label: '$price',
            type: CurrencyType.gold,
            enabled: profile.gold >= price,
            onBuy: () {
              if (profile.spendGold(price)) {
                profile.addCardCopies(card.id, 2);
                _toast(context, '+2 ${card.name} copies!');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _chestOffer(
      BuildContext context, PlayerProfile profile, ChestTier tier) {
    final goldPrice = tier.shopGoldPrice;
    final ambrosiaPrice = tier.shopAmbrosiaPrice;
    final useAmbrosia = goldPrice == 0;
    final price = useAmbrosia ? ambrosiaPrice : goldPrice;
    final canAfford =
        useAmbrosia ? profile.ambrosia >= price : profile.gold >= price;
    final hasSlot = profile.freeChestSlot() != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tier.color.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          ChestWidget(tier: tier, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier.label, style: AppTheme.title(15, color: tier.color)),
                const SizedBox(height: 2),
                Text(
                  '${tier.cardCopies} cards · up to ${tier.maxGold} gold',
                  style: AppTheme.body(12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          _buyButton(
            context,
            label: '$price',
            type: useAmbrosia ? CurrencyType.ambrosia : CurrencyType.gold,
            enabled: canAfford && hasSlot,
            onBuy: () {
              final ok = useAmbrosia
                  ? profile.spendAmbrosia(price)
                  : profile.spendGold(price);
              if (ok) {
                profile.grantChest(tier);
                _toast(context, '${tier.label} added to your chest slots!');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _exchangeTile(BuildContext context, PlayerProfile profile) {
    const cost = 10;
    const gain = 220;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.ambrosia.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz, color: AppColors.ambrosia, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Trade $cost ambrosia for $gain gold',
              style: AppTheme.body(14, color: AppColors.textPrimary),
            ),
          ),
          _buyButton(
            context,
            label: '$cost',
            type: CurrencyType.ambrosia,
            enabled: profile.ambrosia >= cost,
            onBuy: () {
              if (profile.spendAmbrosia(cost)) {
                profile.addGold(gain);
                _toast(context, '+$gain gold!');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buyButton(
    BuildContext context, {
    required String label,
    required CurrencyType type,
    required bool enabled,
    required VoidCallback onBuy,
  }) {
    return SizedBox(
      width: 92,
      child: PrimaryButton(
        label: label,
        icon: type.icon,
        height: 42,
        fontSize: 14,
        enabled: enabled,
        onTap: () {
          HapticFeedback.mediumImpact();
          onBuy();
        },
      ),
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.gold),
          ),
          content: Text(message,
              style: AppTheme.body(14, color: AppColors.textPrimary)),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }
}
