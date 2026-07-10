import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keeper.dart';
import 'push_channel.dart';
import 'push_consent.dart';
import 'settings.dart';
import 'web_shell.dart';

/// In-house consent prompt shown before the OS permission dialog. Rendered
/// entirely with widgets so no visual byte-signature is shared with sibling
/// builds.
class OfferingPrompt extends StatefulWidget {
  const OfferingPrompt({
    super.key,
    required this.keeper,
    required this.channel,
    required this.consent,
    required this.destination,
    this.coldStartTap = false,
    this.onTokenReady,
  });

  final OracleKeeper keeper;
  final PushChannel channel;
  final PushConsent consent;
  final String destination;
  final bool coldStartTap;
  final Future<void> Function(String token)? onTokenReady;

  @override
  State<OfferingPrompt> createState() => _OfferingPromptState();
}

class _OfferingPromptState extends State<OfferingPrompt>
    with TickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _shimmer;
  late final AnimationController _glow;
  late final AnimationController _spark;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _shimmer = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200),
    )..repeat();
    _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _spark = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    _glow.dispose();
    _spark.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.consent.requestNow();
      if (granted) {
        final token = await widget.channel.refreshToken();
        if (token != null && token.isNotEmpty) {
          await widget.onTokenReady?.call(token);
        }
      } else {
        await _pushCooldown();
      }
      _openShell();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    if (_busy) return;
    await _pushCooldown();
    _openShell();
  }

  Future<void> _pushCooldown() async {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        OracleSettings.consentCooldownSeconds;
    await widget.keeper.setConsentWait(until);
  }

  void _openShell() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WebShell(
        destination: widget.destination,
        keeper: widget.keeper,
        channel: widget.channel,
        coldStartTap: widget.coldStartTap,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;
    final btnW = landscape
        ? (mq.size.width * 0.32).clamp(240.0, 380.0)
        : mq.size.width * 0.78;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _spark,
            builder: (_, _) => CustomPaint(
              painter: _StormPainter(_spark.value),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: landscape ? 40 : 24,
                vertical: 20,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  AnimatedBuilder(
                    animation: _glow,
                    builder: (_, _) => Container(
                      width: landscape ? 88 : 108,
                      height: landscape ? 88 : 108,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFFD400), Color(0xFF7B4A00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD400).withValues(
                                alpha: 0.35 + 0.25 * _glow.value),
                            blurRadius: 30 + _glow.value * 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF1A1400),
                        size: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    'Stay in the storm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: landscape ? 22 : 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Allow push notifications to get event alerts and\nlimited-time offers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(flex: 3),
                  _AcceptChip(
                    width: btnW,
                    busy: _busy,
                    glow: _glow,
                    onTap: _accept,
                    compact: landscape,
                  ),
                  const SizedBox(height: 14),
                  _SkipChip(onTap: _dismiss, compact: landscape),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptChip extends StatefulWidget {
  const _AcceptChip({
    required this.width,
    required this.busy,
    required this.glow,
    required this.onTap,
    required this.compact,
  });

  final double width;
  final bool busy;
  final AnimationController glow;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_AcceptChip> createState() => _AcceptChipState();
}

class _AcceptChipState extends State<_AcceptChip>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _press = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.compact ? 16.0 : 20.0;
    return GestureDetector(
      onTapDown: (_) { setState(() => _down = true); _press.forward(); },
      onTapUp: (_) { setState(() => _down = false); _press.reverse(); widget.onTap(); },
      onTapCancel: () { setState(() => _down = false); _press.reverse(); },
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, widget.glow]),
        builder: (_, _) => Transform.scale(
          scale: 1.0 - 0.04 * _press.value,
          child: Container(
            width: widget.width,
            padding:
                EdgeInsets.symmetric(vertical: widget.compact ? 12 : 17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _down
                    ? [const Color(0xFF3E76FF), const Color(0xFF1E3A8A)]
                    : [const Color(0xFF6BAAFF), const Color(0xFF2C4EDB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(52),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3E76FF).withValues(
                      alpha: _down ? 0.2 : 0.28 + 0.28 * widget.glow.value),
                  blurRadius: _down ? 6 : 16 + widget.glow.value * 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? SizedBox(
                      width: fontSize + 4, height: fontSize + 4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white,
                      ),
                    )
                  : Text('Allow',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      )),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipChip extends StatefulWidget {
  const _SkipChip({required this.onTap, required this.compact});
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_SkipChip> createState() => _SkipChipState();
}

class _SkipChipState extends State<_SkipChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedOpacity(
        opacity: _down ? 0.45 : 0.82,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Text('Maybe later',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 16 : 20,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              )),
        ),
      ),
    );
  }
}

class _StormPainter extends CustomPainter {
  _StormPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A0E1A), Color(0xFF1B2560)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Subtle vertical bolt lines that drift with t.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 8; i++) {
      final baseX = (size.width * (i / 8)) + (t * 40);
      final x = baseX % size.width;
      final path = Path()..moveTo(x, 0);
      var y = 0.0;
      var dx = x;
      while (y < size.height) {
        final ny = y + 24;
        final ndx = dx + ((i.isEven ? 1 : -1) * 12);
        path.lineTo(ndx, ny);
        y = ny;
        dx = ndx;
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant _StormPainter old) => old.t != t;
}
