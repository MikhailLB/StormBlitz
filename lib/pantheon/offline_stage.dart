import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'beacon.dart';
import 'hero_ui.dart';

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

class _OfflineStageState extends State<OfflineStage> {
  bool _busy = false;
  bool _stillOffline = false;
  Timer? _hideHint;

  @override
  void dispose() {
    _hideHint?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
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
                  // Shift content slightly below center in landscape so the
                  // button clears the visual midpoint of the artwork.
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
                          title: 'NO INTERNET CONNECTION',
                          subtitle: 'Check your connection and try again',
                          width: plaqueW,
                          compact: landscape,
                        ),
                        SizedBox(height: landscape ? 20 : 24),
                        HeroGoldButton(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          width: btnW,
                          busy: _busy,
                          compact: landscape,
                          onTap: _retry,
                        ),
                        SizedBox(height: landscape ? 10 : 14),
                        AnimatedOpacity(
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
