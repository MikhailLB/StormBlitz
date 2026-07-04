import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class StormNavItem {
  const StormNavItem({required this.icon, required this.label, this.badge = false});
  final IconData icon;
  final String label;

  /// Shows a small gold dot (e.g. claimable quest).
  final bool badge;
}

/// Custom bottom navigation: sliding gold indicator + bouncing active icon.
class StormNavBar extends StatelessWidget {
  const StormNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<StormNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.97),
        border: const Border(
          top: BorderSide(color: AppColors.panelBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  // Sliding indicator.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    left: slotWidth * index + slotWidth * 0.25,
                    top: 0,
                    child: Container(
                      width: slotWidth * 0.5,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.gold, AppColors.goldLight],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.7),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(child: _item(i)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _item(int i) {
    final item = items[i];
    final active = i == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (i != index) {
          HapticFeedback.selectionClick();
          onChanged(i);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: active ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Icon(
                  item.icon,
                  size: 24,
                  color: active ? AppColors.goldLight : AppColors.textMuted,
                ),
              ),
              if (item.badge)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: AppTheme.body(
              11,
              color: active ? AppColors.goldLight : AppColors.textMuted,
              weight: active ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
