import 'package:flutter/material.dart';

import '../models/game_card.dart';
import '../theme/app_theme.dart';
import 'value_change_effect.dart';

/// Visual representation of a single god card. Used both in the hand
/// (full detail) and on the board (stats + portrait). Everything except the
/// god portrait is drawn in code, so the only image asset is the .webp art.
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.card,
    this.width = 96,
    this.onTap,
    this.onLongPress,
    this.playable = false,
    this.selected = false,
    this.readyToAttack = false,
    this.targetable = false,
    this.showDescription = true,
  });

  final GameCard card;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Affordable in hand -> gold glow.
  final bool playable;

  /// Tapped attacker on the board -> bright selection ring.
  final bool selected;

  /// Board minion that can still attack this turn -> subtle green glow.
  final bool readyToAttack;

  /// Valid attack target -> red pulsing ring.
  final bool targetable;

  final bool showDescription;

  Color get _frameColor {
    switch (card.rarity) {
      case Rarity.legendary:
        return AppColors.legendary;
      case Rarity.rare:
        return AppColors.rare;
      case Rarity.common:
        return AppColors.common;
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;
    final glow = selected
        ? AppColors.lightning
        : targetable
            ? AppColors.hpRed
            : readyToAttack
                ? const Color(0xFF4CD964)
                : playable
                    ? AppColors.gold
                    : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ValueChangeEffect(
        value: card.currentHealth,
        borderRadius: width * 0.10,
        numberFontSize: width * 0.26,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _frameColor.withValues(alpha: 0.95),
              _frameColor.withValues(alpha: 0.45),
            ],
          ),
          boxShadow: [
            if (glow != Colors.transparent)
              BoxShadow(
                color: glow.withValues(alpha: 0.8),
                blurRadius: 14,
                spreadRadius: 1.5,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.all(width * 0.035),
        child: Column(
          children: [
            _nameBar(),
            SizedBox(height: width * 0.03),
            Expanded(child: _portrait()),
            if (showDescription && width > 90) ...[
              SizedBox(height: width * 0.03),
              _descriptionBox(),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _nameBar() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: width * 0.02, horizontal: width * 0.04),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(width * 0.05),
      ),
      child: Text(
        card.name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.title(width * 0.135, color: _frameColor),
      ),
    );
  }

  Widget _portrait() {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.06),
            child: Image.asset(
              card.asset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.panel,
                child: const Icon(Icons.bolt, color: AppColors.lightning),
              ),
            ),
          ),
        ),
        // Cost gem (top-left).
        Positioned(
          top: 0,
          left: 0,
          child: _statBadge(
            value: card.cost,
            color: AppColors.manaBlue,
            icon: Icons.water_drop,
          ),
        ),
        // Keyword badge (top-right).
        if (card.keyword != Keyword.none)
          Positioned(
            top: 0,
            right: 0,
            child: _keywordBadge(),
          ),
        // Attack (bottom-left) & Health (bottom-right).
        Positioned(
          bottom: 0,
          left: 0,
          child: _statBadge(
            value: card.attack,
            color: AppColors.attackOrange,
            icon: Icons.bolt,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _statBadge(
            value: card.currentHealth,
            color: AppColors.hpRed,
            icon: Icons.favorite,
            damaged: card.currentHealth < card.health,
          ),
        ),
      ],
    );
  }

  Widget _keywordBadge() {
    final isTaunt = card.keyword == Keyword.taunt;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: width * 0.05, vertical: width * 0.015),
      decoration: BoxDecoration(
        color: (isTaunt ? AppColors.common : const Color(0xFF4CD964))
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(width * 0.04),
        border: Border.all(color: Colors.black54, width: 1),
      ),
      child: Text(
        isTaunt ? 'TAUNT' : 'CHARGE',
        style: AppTheme.body(width * 0.085,
            color: Colors.black, weight: FontWeight.w700),
      ),
    );
  }

  Widget _statBadge({
    required int value,
    required Color color,
    required IconData icon,
    bool damaged = false,
  }) {
    final size = width * 0.30;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background.withValues(alpha: 0.9),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5),
        ],
      ),
      child: Text(
        '$value',
        style: AppTheme.title(
          width * 0.16,
          color: damaged ? AppColors.hpRed : Colors.white,
        ),
      ),
    );
  }

  Widget _descriptionBox() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.04),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(width * 0.05),
      ),
      child: Text(
        card.description,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.body(width * 0.092, color: AppColors.textPrimary),
      ),
    );
  }
}
