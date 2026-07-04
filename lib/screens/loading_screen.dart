import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../widgets/app_transitions.dart';
import 'home_shell_screen.dart';

/// First screen the player sees. It adapts to BOTH orientations (the rest of
/// the game is locked to portrait afterwards). A horizontal progress bar fills
/// left -> right and only reaches 100% in the instant before the menu opens.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _fillDuration = Duration(milliseconds: 2600);
  static const double _holdValue = 0.9;

  double _progress = 0;
  Timer? _timer;
  bool _launching = false;

  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    // The loading screen is allowed to rotate freely.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _startLoading();
  }

  void _startLoading() {
    const tick = Duration(milliseconds: 40);
    final step = _holdValue * tick.inMilliseconds / _fillDuration.inMilliseconds;

    _timer = Timer.periodic(tick, (timer) {
      setState(() {
        _progress += step;
        // Stop just short of full; we only "complete" right before launch.
        if (_progress >= _holdValue) {
          _progress = _holdValue;
          timer.cancel();
          _finish();
        }
      });
    });
  }

  Future<void> _finish() async {
    // Tiny pause at ~90%, then snap to 100% just before the transition.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _launching = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    // Lock the actual game strictly to portrait.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      AppTransitions.fade(const HomeShellScreen()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final asset = isPortrait
              ? 'assets/Vertical_LoadingScreen.webp'
              : 'assets/Horizontal_LoadingScreen.webp';

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Container(color: AppColors.background),
              ),
              // Subtle bottom scrim so the loader is readable on any art.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              // Pushed well below the logo (lower on both orientations so it
              // never overlaps the artwork).
              Align(
                alignment: Alignment(0, isPortrait ? 0.66 : 0.82),
                child: _loaderBlock(context, isPortrait),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loaderBlock(BuildContext context, bool isPortrait) {
    final screenWidth = MediaQuery.of(context).size.width;
    final barWidth = isPortrait ? screenWidth * 0.62 : screenWidth * 0.42;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProgressBar(progress: _progress, width: barWidth),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _dotsController,
          builder: (_, _) {
            final dotCount =
                _launching ? 3 : (_dotsController.value * 4).floor() % 4;
            return Text(
              'Loading${'.' * dotCount}',
              style: AppTheme.body(
                20,
                color: AppColors.textPrimary,
                weight: FontWeight.w700,
              ).copyWith(
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 6),
                ],
                letterSpacing: 2,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Glowing horizontal progress bar that fills left -> right.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.width});

  final double progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    const height = 16.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 1.5),
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
                  colors: [
                    AppColors.lightningDeep,
                    AppColors.lightning,
                    AppColors.goldLight,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lightning.withValues(alpha: 0.8),
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
