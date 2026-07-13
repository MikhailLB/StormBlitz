import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hero_ui.dart';
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
      backgroundColor: HeroPalette.ink,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final landscape = orientation == Orientation.landscape;
          final mq = MediaQuery.of(context);
          final plaqueW = landscape
              ? (mq.size.width * 0.52).clamp(340.0, 540.0)
              : (mq.size.width * 0.88).clamp(280.0, 460.0);
          final btnW = plaqueW * 0.82;

          return Stack(
            fit: StackFit.expand,
            children: [
              const HeroBackground(),
              SafeArea(
                child: Align(
                  alignment:
                      landscape ? const Alignment(0, 0.45) : Alignment.center,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: landscape ? 8 : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HeroPlaque(
                          title:
                              'ALLOW NOTIFICATIONS\nABOUT BONUSES AND PROMOS',
                          subtitle:
                              'Stay tuned for special offers and rewards',
                          width: plaqueW,
                          compact: landscape,
                        ),
                        SizedBox(height: landscape ? 20 : 24),
                        HeroGoldButton(
                          label: 'Allow',
                          width: btnW,
                          busy: _busy,
                          glow: _glow,
                          compact: landscape,
                          onTap: _accept,
                        ),
                        SizedBox(height: landscape ? 10 : 14),
                        HeroGhostButton(
                          label: 'Skip',
                          width: btnW,
                          compact: landscape,
                          onTap: _dismiss,
                        ),
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
