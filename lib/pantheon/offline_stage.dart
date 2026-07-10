import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'beacon.dart';

/// Full-screen "no connection" fallback. Renders programmatically so the
/// resulting bytes don't collide with sibling builds' offline artwork.
class OfflineStage extends StatefulWidget {
  const OfflineStage({
    super.key,
    required this.retryBuilder,
  });

  final WidgetBuilder retryBuilder;

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage>
    with TickerProviderStateMixin {
  bool _busy = false;
  bool _stillOffline = false;
  Timer? _hideHint;
  late final AnimationController _press;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 130),
    );
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hideHint?.cancel();
    _press.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    await _press.forward();
    await _press.reverse();
    if (!mounted) return;
    setState(() => _busy = true);
    final online = await skyBeacon.reachable();
    if (!mounted) return;
    if (!online) {
      _hideHint?.cancel();
      setState(() { _busy = false; _stillOffline = true; });
      _hideHint = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _stillOffline = false);
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _StormyBackdrop(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: landscape ? 40 : 28,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, _) => Icon(
                      Icons.cloud_off_rounded,
                      size: landscape ? 68 : 90,
                      color: Colors.white.withValues(
                        alpha: 0.55 + 0.25 * _pulse.value,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'No connection',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: landscape ? 22 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Check your network and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _RetryButton(
                    busy: _busy,
                    press: _press,
                    onTap: _retry,
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _stillOffline ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Still no internet — please try again.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.busy,
    required this.press,
    required this.onTap,
  });
  final bool busy;
  final AnimationController press;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: press,
      builder: (_, child) => Transform.scale(
        scale: 1.0 - 0.05 * press.value, child: child,
      ),
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            gradient: busy
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF3E76FF), Color(0xFF1E3A8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: busy ? Colors.blueGrey.withValues(alpha: 0.3) : null,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF0A0E1A), width: 2),
          ),
          child: busy
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        )),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StormyBackdrop extends StatelessWidget {
  const _StormyBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [Color(0xFF14213D), Color(0xFF0A0E1A)],
          stops: [0.0, 1.0],
        ),
      ),
    );
  }
}
