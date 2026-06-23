import 'package:flutter/material.dart';

import '../models/game_card.dart';
import '../theme/app_theme.dart';
import 'card_view.dart';

/// Opens a centered popup showing the full art, every stat and the complete
/// ability text of [card] (handy when a card's description is clipped in hand).
void showCardDetail(BuildContext context, GameCard card) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.82),
    builder: (dialogContext) => _CardDetailDialog(card: card),
  );
}

class _CardDetailDialog extends StatelessWidget {
  const _CardDetailDialog({required this.card});

  final GameCard card;

  Color get _rarityColor {
    switch (card.rarity) {
      case Rarity.legendary:
        return AppColors.legendary;
      case Rarity.rare:
        return AppColors.rare;
      case Rarity.common:
        return AppColors.common;
    }
  }

  String get _rarityLabel {
    switch (card.rarity) {
      case Rarity.legendary:
        return 'Legendary';
      case Rarity.rare:
        return 'Rare';
      case Rarity.common:
        return 'Common';
    }
  }

  String? get _keywordExplanation {
    switch (card.keyword) {
      case Keyword.taunt:
        return 'Taunt — enemies must attack this god before any other target.';
      case Keyword.charge:
        return 'Charge — this god can attack the same turn it is summoned.';
      case Keyword.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // absorb taps inside the card so it doesn't dismiss
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _rarityColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _rarityColor.withValues(alpha: 0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(card.name, style: AppTheme.title(26)),
                      ],
                    ),
                    Text(
                      card.title,
                      style: AppTheme.body(14, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    _rarityChip(),
                    const SizedBox(height: 16),
                    CardView(
                      card: card,
                      width: (maxWidth * 0.42).clamp(150.0, 190.0),
                      showDescription: false,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statColumn(
                          icon: Icons.water_drop,
                          color: AppColors.manaBlue,
                          label: 'MANA',
                          value: '${card.cost}',
                        ),
                        _statColumn(
                          icon: Icons.bolt,
                          color: AppColors.attackOrange,
                          label: 'ATTACK',
                          value: '${card.attack}',
                        ),
                        _statColumn(
                          icon: Icons.favorite,
                          color: AppColors.hpRed,
                          label: 'HEALTH',
                          value: '${card.currentHealth}/${card.health}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_keywordExplanation != null) ...[
                      _infoBox(
                        icon: Icons.shield_moon,
                        text: _keywordExplanation!,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _infoBox(
                      icon: Icons.auto_awesome,
                      text: card.description,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: AppTheme.title(16, color: Colors.black),
                        ),
                        child: const Text('CLOSE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rarityChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: BoxDecoration(
        color: _rarityColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _rarityColor, width: 1),
      ),
      child: Text(
        _rarityLabel.toUpperCase(),
        style: AppTheme.body(12, color: _rarityColor, weight: FontWeight.w700),
      ),
    );
  }

  Widget _statColumn({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.background.withValues(alpha: 0.85),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
          child: Text(value, style: AppTheme.title(17, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 3),
            Text(label,
                style: AppTheme.body(11, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }

  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.lightning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.body(14, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
