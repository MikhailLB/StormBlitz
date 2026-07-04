import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/relic_data.dart';
import '../game/game_controller.dart';
import '../models/player_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_transitions.dart';
import '../widgets/primary_button.dart';
import 'battle_screen.dart';

class _TutorialPage {
  const _TutorialPage({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
}

/// Full-screen swipeable tutorial replacing the old rules dialog.
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_TutorialPage> _pages = [
    _TutorialPage(
      icon: Icons.flag,
      title: 'THE GOAL',
      lines: [
        'Reduce the enemy hero to 0 HP to win.',
        'Each turn you gain a mana crystal (max 10). Spend mana to summon gods from your hand.',
        'Tap a card to summon it. Tap your god, then a target, to attack.',
        'The enemy hero is protected while their gods live: clear the enemy battlefield before striking the hero.',
      ],
    ),
    _TutorialPage(
      icon: Icons.style,
      title: 'READING A CARD',
      lines: [
        'BLUE drop (top-left) — mana cost.',
        'ORANGE bolt (bottom-left) — attack.',
        'RED heart (bottom-right) — health.',
        'Press and hold any card to inspect it full-size.',
      ],
    ),
    _TutorialPage(
      icon: Icons.flash_on,
      title: 'THUNDERBOLT',
      lines: [
        'Your hero wields the Thunderbolt power — the bolt button beside your portrait.',
        'Once per turn, pay 2 mana to deal 1 damage to any enemy god (or the hero, once their field is clear).',
        'Perfect for finishing off wounded gods or popping Divine Shields.',
      ],
    ),
    _TutorialPage(
      icon: Icons.shield_moon,
      title: 'KEYWORDS',
      lines: [
        'TAUNT — enemies must destroy this god first.',
        'CHARGE — attacks the turn it is summoned.',
        'FRENZY — gains +2 Attack the first time it survives damage.',
        'LIFESTEAL — its combat damage heals your hero.',
        'DIVINE SHIELD — absorbs the next hit (Ascended cards).',
        'Battlecries trigger automatically when a god is summoned.',
      ],
    ),
    _TutorialPage(
      icon: Icons.inventory_2,
      title: 'CHESTS & CARDS',
      lines: [
        'Win battles to earn gold, trophies and chests.',
        'Start a chest\'s unlock timer, then open it for gold, ambrosia and card copies.',
        'Collect copies + gold to upgrade cards: stats grow each level.',
        'Level 3 unlocks bonus keywords; level 5 grants Ascension (Divine Shield).',
      ],
    ),
    _TutorialPage(
      icon: Icons.auto_awesome,
      title: 'RELICS & TRIALS',
      lines: [
        'Relics are passive artifacts found in chests and achievements.',
        'Equip one relic before battle for its power.',
        'Conquer the Pantheon Trials campaign — nine battles ending with the enraged Titan.',
        'Complete daily quests and achievements for extra rewards.',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return AppScaffold(
      title: 'HOW TO PLAY',
      showBack: true,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _pageView(_pages[i]),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.gold
                        : AppColors.panelBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              children: [
                PrimaryButton(
                  label: 'PRACTICE BATTLE',
                  icon: Icons.school,
                  primary: false,
                  height: 50,
                  fontSize: 15,
                  onTap: () {
                    // Re-run the guided step-by-step tutorial in an easy match.
                    final profile = context.read<PlayerProfile>();
                    profile.tutorialDone = false;
                    Navigator.of(context).push(
                      AppTransitions.slideUp(
                        BattleScreen(
                          difficulty: Difficulty.easy,
                          deckLevels: profile.deckLevels,
                          relic: RelicData.byId(profile.equippedRelicId),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: isLast ? 'GOT IT' : 'NEXT',
                  icon: isLast ? Icons.check : Icons.arrow_forward,
                  onTap: () {
                    if (isLast) {
                      Navigator.of(context).pop();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageView(_TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.lightning.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.lightning, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightning.withValues(alpha: 0.3),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Icon(page.icon, color: AppColors.lightning, size: 40),
          ),
          const SizedBox(height: 18),
          Text(page.title, style: AppTheme.title(24)),
          const SizedBox(height: 18),
          for (final line in page.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt,
                      color: AppColors.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(line,
                        style: AppTheme.body(15,
                            color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
