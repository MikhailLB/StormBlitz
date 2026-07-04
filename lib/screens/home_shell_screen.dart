import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/player_profile.dart';
import '../widgets/bottom_nav_bar.dart';
import 'battle_hub_screen.dart';
import 'collection_screen.dart';
import 'profile_screen.dart';
import 'quests_screen.dart';
import 'shop_screen.dart';

/// Root of the meta-game: five tabs behind a custom bottom bar.
class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PlayerProfile>();
    final hasClaimableQuest = profile.quests
            .any((q) => q.isComplete && !q.claimed) ||
        !profile.dailyBonusClaimed;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          BattleHubScreen(),
          CollectionScreen(),
          ShopScreen(),
          QuestsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: StormNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        items: [
          const StormNavItem(icon: Icons.bolt, label: 'Battle'),
          const StormNavItem(icon: Icons.style, label: 'Cards'),
          const StormNavItem(icon: Icons.storefront, label: 'Shop'),
          StormNavItem(
              icon: Icons.task_alt, label: 'Quests', badge: hasClaimableQuest),
          const StormNavItem(icon: Icons.person, label: 'Profile'),
        ],
      ),
    );
  }
}
