import 'package:flutter/material.dart';

import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import 'currency_pill.dart';
import 'storm_background.dart';

/// Shared page chrome for meta screens: storm backdrop + optional top bar
/// with back button, title and (optionally) the currency strip.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.title,
    this.showBack = false,
    this.profile,
    this.darken = 0.6,
    this.showFlash = false,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final bool showBack;

  /// When set, gold/ambrosia pills are shown in the header.
  final PlayerProfile? profile;
  final double darken;
  final bool showFlash;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StormBackground(
        darken: darken,
        showFlash: showFlash,
        child: SafeArea(
          child: Column(
            children: [
              if (title != null || showBack || profile != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 12, 4),
                  child: Row(
                    children: [
                      if (showBack)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: AppColors.textMuted, size: 20),
                        )
                      else
                        const SizedBox(width: 12),
                      if (title != null)
                        Expanded(
                          child: Text(
                            title!,
                            style: AppTheme.title(18, color: AppColors.goldLight),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                      if (profile != null)
                        AnimatedBuilder(
                          animation: profile!,
                          builder: (_, _) => Row(
                            children: [
                              CurrencyPill(
                                type: CurrencyType.gold,
                                amount: profile!.gold,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              CurrencyPill(
                                type: CurrencyType.ambrosia,
                                amount: profile!.ambrosia,
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
