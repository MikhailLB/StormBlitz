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

class _BootStageState extends State<BootStage>
    with SingleTickerProviderStateMixin {
  static const Duration _fillDuration = Duration(milliseconds: 2600);
  static const double _holdValue = 0.9;

  bool _navigated = false;
  double _progress = 0;
  bool _launching = false;
  Timer? _autoFill;
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    _dots = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat();
    _startAutoFill();
    _boot();
  }

  @override
  void dispose() {
    widget.channel.onTokenRotated = null;
    _autoFill?.cancel();
    _dots.dispose();
    super.dispose();
  }

  /// Fills the progress bar 0 → 0.9 over ~2.6s so the user sees continuous
  /// motion regardless of how long the real attribution round-trip takes.
  /// The bar holds at 0.9 until [_tick] or navigation completes it.
  void _startAutoFill() {
    const tick = Duration(milliseconds: 40);
    final step = _holdValue * tick.inMilliseconds /
        _fillDuration.inMilliseconds;
    _autoFill = Timer.periodic(tick, (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _progress += step;
        if (_progress >= _holdValue) {
          _progress = _holdValue;
          t.cancel();
        }
      });
    });
  }

  void _tick(double v) {
    if (!mounted) return;
    // Auto-fill is the primary driver; only surface hard completions.
    if (v >= 1.0) {
      setState(() {
        _progress = 1.0;
        _launching = true;
      });
    }
  }

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
    // Skip if AF conversion hasn't arrived yet — the cold boot flow
    // (_handleColdLane) will compose and dispatch with the fresh token
    // once awaitConversion() completes. Re-dispatching here before that
    // would send an empty attribution payload.
    if (widget.signal.conversion.isEmpty) return;
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
    // If arm() ran while offline the FCM token will be null. Try once
    // now that we know we have a connection.
    if (widget.channel.token == null) {
      await widget.channel.refreshToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
    }
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

    // Refresh FCM token if arm() ran while offline.
    if (widget.channel.token == null) {
      await widget.channel.refreshToken()
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
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
    _doRouteToShell(url, coldStartTap: coldStartTap);
  }

  Future<void> _doRouteToShell(String url, {bool coldStartTap = false}) async {
    final needs = widget.keeper.needsConsentPrompt();
    if (!needs) {
      if (kDebugMode) debugPrint('[oracle] consent: needsConsentPrompt=false → skip prompt');
      _routeDirect(url, coldStartTap: coldStartTap);
      return;
    }
    bool canAsk = false;
    try {
      canAsk = await widget.consent.shouldOffer();
    } catch (e) {
      if (kDebugMode) debugPrint('[oracle] shouldOffer error: $e');
    }
    if (!mounted) return;
    if (kDebugMode) debugPrint('[oracle] consent: needsConsentPrompt=true canAsk=$canAsk');
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
    // The boot stage reuses the game's own loading artwork + progress bar
    // + "Loading …" text so cold start is visually seamless into the
    // white game (which shows the same widget when it takes over).
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final portrait = orientation == Orientation.portrait;
          final asset = portrait
              ? 'assets/Vertical_LoadingScreen.webp'
              : 'assets/Horizontal_LoadingScreen.webp';
          final screenWidth = MediaQuery.of(context).size.width;
          final barWidth =
              portrait ? screenWidth * 0.62 : screenWidth * 0.42;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF0A0E1A)),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      const Color(0xFF0A0E1A).withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0, portrait ? 0.66 : 0.82),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BootProgressBar(
                      progress: _progress,
                      width: barWidth,
                    ),
                    const SizedBox(height: 18),
                    AnimatedBuilder(
                      animation: _dots,
                      builder: (_, _) {
                        final dotCount = _launching
                            ? 3
                            : (_dots.value * 4).floor() % 4;
                        return Text(
                          'Loading${'.' * dotCount}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Glowing horizontal progress bar that mirrors the game's LoadingScreen
/// look — so the boot phase is visually indistinguishable from the game
/// entry animation.
class _BootProgressBar extends StatelessWidget {
  const _BootProgressBar({required this.progress, required this.width});
  final double progress;
  final double width;

  static const Color _bg     = Color(0xFF0A0E1A);
  static const Color _gold   = Color(0xFFFFC53D);
  static const Color _bolt   = Color(0xFF3E76FF);
  static const Color _accent = Color(0xFFFFD400);

  @override
  Widget build(BuildContext context) {
    const height = 16.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: _gold.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Align(
        alignment: Alignment.centerLeft,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              width: constraints.maxWidth * progress.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: const LinearGradient(
                  colors: [_bolt, _accent, _gold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _bolt.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
