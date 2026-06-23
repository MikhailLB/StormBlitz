import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A reusable stormy backdrop: the Olympus key art, darkened with a gradient,
/// plus an occasional full-screen lightning flash for atmosphere.
class StormBackground extends StatefulWidget {
  const StormBackground({
    super.key,
    required this.child,
    this.showArt = true,
    this.darken = 0.55,
    this.showFlash = true,
  });

  final Widget child;
  final bool showArt;
  final double darken;

  /// When false, the periodic lightning flash animation is disabled
  /// (used by the main menu for a calm, static backdrop).
  final bool showFlash;

  @override
  State<StormBackground> createState() => _StormBackgroundState();
}

class _StormBackgroundState extends State<StormBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.showFlash) _scheduleFlash();
  }

  void _scheduleFlash() {
    // Random pause between lightning strikes (3.5s - 8s).
    final delay = Duration(milliseconds: 3500 + _rng.nextInt(4500));
    Future.delayed(delay, () {
      if (!mounted) return;
      _flash.forward(from: 0).then((_) {
        if (mounted) _flash.reverse();
      });
      _scheduleFlash();
    });
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.background),
        if (widget.showArt)
          Image.asset(
            'assets/bg.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        // Darkening gradient to keep UI legible over the art.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: widget.darken * 0.7),
                AppColors.background.withValues(alpha: widget.darken),
                AppColors.background.withValues(alpha: widget.darken + 0.25),
              ],
            ),
          ),
        ),
        // Lightning flash overlay (disabled when showFlash is false).
        if (widget.showFlash)
          AnimatedBuilder(
            animation: _flash,
            builder: (_, _) => IgnorePointer(
              child: Container(
                color: AppColors.lightning
                    .withValues(alpha: 0.12 * _flash.value),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}
