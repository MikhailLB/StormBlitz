import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'beacon.dart';

/// Full-screen "no connection" fallback. Uses the storm-themed offline
/// artwork provided with the game and a single "Retry" affordance.
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
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _stillOffline = false;
  Timer? _hideHint;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 130),
    );
  }

  @override
  void dispose() {
    _hideHint?.cancel();
    _press.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final mq = MediaQuery.of(context);
          final btnW = landscape
              ? (mq.size.width * 0.26).clamp(200.0, 340.0)
              : (mq.size.width * 0.56).clamp(200.0, 320.0);
          final btnBottom = landscape
              ? mq.size.height * 0.08
              : mq.size.height * 0.18;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                landscape
                    ? 'assets/nowifi_landscape.png'
                    : 'assets/nowifi_portrait.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF0A0E1A)),
              ),
              Positioned(
                left: 0, right: 0, bottom: btnBottom,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _press,
                    builder: (_, child) => Transform.scale(
                      scale: 1.0 - 0.05 * _press.value, child: child,
                    ),
                    child: GestureDetector(
                      onTap: _busy ? null : _retry,
                      child: Container(
                        width: btnW,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _busy
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD400),
                                    Color(0xFFA26E00),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _busy
                              ? Colors.orange.withValues(alpha: 0.3)
                              : null,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: const Color(0xFF1A0F00), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD400)
                                  .withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _busy
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF1A0F00),
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded,
                                        color: Color(0xFF1A0F00),
                                        size: 22),
                                    SizedBox(width: 8),
                                    Text('Retry',
                                        style: TextStyle(
                                          color: Color(0xFF1A0F00),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                        )),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: landscape
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: landscape ? 12 : 16,
                    ),
                    child: AnimatedOpacity(
                      opacity: _stillOffline ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Text(
                            'Still no internet — please try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
