import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small "LV N" badge overlaid on cards in the collection. Max-level cards
/// get a golden "ASC" (Ascension) treatment.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.maxLevel = 5});

  final int level;
  final int maxLevel;

  @override
  Widget build(BuildContext context) {
    final ascended = level >= maxLevel;
    final color = ascended ? AppColors.legendary : AppColors.lightning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ascended ? Icons.auto_awesome : Icons.arrow_upward,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            ascended ? 'ASC' : 'LV $level',
            style: AppTheme.body(10, color: color, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
