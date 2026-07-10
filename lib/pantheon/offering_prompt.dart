import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'keeper.dart';
import 'push_channel.dart';
import 'push_consent.dart';
import 'settings.dart';
import 'web_shell.dart';

/// In-house consent prompt shown before the OS permission dialog. The
/// artwork is orientation-aware so the "storm" theme reads well on both
/// portrait and landscape.
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
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final mq = MediaQuery.of(context);
          final btnW = landscape
              ? (mq.size.width * 0.32).clamp(240.0, 380.0)
              : mq.size.width * 0.78;
          final bottomInset = landscape
              ? mq.size.height * 0.08
              : mq.size.height * 0.10;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                landscape
                    ? 'assets/notify_landscape.png'
                    : 'assets/notify_portrait.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xFF0A0E1A)),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AcceptChip(
                          width: btnW,
                          busy: _busy,
                          glow: _glow,
                          onTap: _accept,
                          compact: landscape,
                        ),
                        SizedBox(height: mq.size.height * 0.022),
                        _SkipChip(onTap: _dismiss, compact: landscape),
                      ],
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
                    ? [const Color(0xFFCC9200), const Color(0xFF7B4A00)]
                    : [const Color(0xFFFFD400), const Color(0xFFA26E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(52),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD400).withValues(
                      alpha: _down ? 0.2 : 0.32 + 0.25 * widget.glow.value),
                  blurRadius: _down ? 6 : 18 + widget.glow.value * 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? SizedBox(
                      width: fontSize + 4, height: fontSize + 4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5, color: Color(0xFF1A0F00),
                      ),
                    )
                  : Text('Allow',
                      style: TextStyle(
                        color: const Color(0xFF1A0F00),
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
        opacity: _down ? 0.45 : 0.85,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Text('Maybe later',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 16 : 20,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
              )),
        ),
      ),
    );
  }
}
