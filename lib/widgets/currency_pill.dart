import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'animated_counter.dart';

enum CurrencyType { gold, ambrosia }

extension CurrencyStyle on CurrencyType {
  Color get color =>
      this == CurrencyType.gold ? AppColors.gold : AppColors.ambrosia;
  IconData get icon =>
      this == CurrencyType.gold ? Icons.monetization_on : Icons.local_drink;
  String get label => this == CurrencyType.gold ? 'Gold' : 'Ambrosia';
}

/// Compact "icon + amount" pill shown in headers. The number animates
/// whenever the value changes.
class CurrencyPill extends StatelessWidget {
  const CurrencyPill({
    super.key,
    required this.type,
    required this.amount,
    this.compact = false,
  });

  final CurrencyType type;
  final int amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: type.color.withValues(alpha: 0.7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: type.color.withValues(alpha: 0.18),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, color: type.color, size: compact ? 15 : 18),
          SizedBox(width: compact ? 4 : 6),
          AnimatedCounter(
            value: amount,
            style: AppTheme.title(compact ? 13 : 15, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
