import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/player_profile.dart';
import 'screens/loading_screen.dart';
import 'services/profile_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Immersive, dark system bars to match the storm theme.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Load the persistent meta-progression before the first frame.
  final repository = ProfileRepository();
  final profile = await repository.load();
  profile.refreshDailyQuests(Random());
  profile.onMutated = () => repository.save(profile);

  runApp(
    ChangeNotifierProvider<PlayerProfile>.value(
      value: profile,
      child: const StormBlitzApp(),
    ),
  );
}

class StormBlitzApp extends StatelessWidget {
  const StormBlitzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storm Blitz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const LoadingScreen(),
    );
  }
}
