import 'package:flutter/material.dart';

/// A number that "counts" toward its new value whenever it changes.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 650),
    this.prefix = '',
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$prefix${v.round()}', style: style),
    );
  }
}
