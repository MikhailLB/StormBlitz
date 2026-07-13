import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'models/player_profile.dart';
import 'pantheon/beacon.dart';
import 'pantheon/boot_stage.dart';
import 'pantheon/keeper.dart';
import 'pantheon/omen_signal.dart';
import 'pantheon/payload_forge.dart';
import 'pantheon/push_channel.dart';
import 'pantheon/push_consent.dart';
import 'screens/home_shell_screen.dart';
import 'screens/loading_screen.dart';
import 'services/profile_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final keeper = OracleKeeper();
  await keeper.bringUp();

  final signal  = OmenSignal();
  final channel = PushChannel(keeper);
  final consent = PushConsent(channel: channel, keeper: keeper);
  final forge   = PayloadForge(signal: signal, keeper: keeper);

  unawaited(skyBeacon.heatUa());

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(_BootRoot(
    keeper: keeper,
    signal: signal,
    forge: forge,
    channel: channel,
    consent: consent,
  ));
}

class _BootRoot extends StatelessWidget {
  const _BootRoot({
    required this.keeper,
    required this.signal,
    required this.forge,
    required this.channel,
    required this.consent,
  });

  final OracleKeeper keeper;
  final OmenSignal signal;
  final PayloadForge forge;
  final PushChannel channel;
  final PushConsent consent;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF0A0E1A)),
      home: BootStage(
        keeper: keeper,
        signal: signal,
        forge: forge,
        channel: channel,
        consent: consent,
        goGame: () => _launchGame(),
      ),
    );
  }

  Future<void> _launchGame() async {
    final repository = ProfileRepository();
    final profile = await repository.load();
    profile.refreshDailyQuests(Random());
    profile.onMutated = () => repository.save(profile);

    // Lock to portrait before launching the game (same as LoadingScreen does).
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    runApp(
      ChangeNotifierProvider<PlayerProfile>.value(
        value: profile,
        // skipLoading=true: BootStage already showed a loading screen,
        // so we go straight to HomeShellScreen.
        child: const StormBlitzApp(skipLoading: true),
      ),
    );
  }
}

class StormBlitzApp extends StatelessWidget {
  const StormBlitzApp({super.key, this.skipLoading = false});

  /// When true the BootStage loading screen has already been shown, so we
  /// navigate directly to HomeShellScreen instead of showing LoadingScreen again.
  final bool skipLoading;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storm Blitz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: skipLoading ? const HomeShellScreen() : const LoadingScreen(),
    );
  }
}
