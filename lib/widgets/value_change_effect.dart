import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Wraps any widget and plays a reactive effect whenever [value] changes:
///  - damage (value drops): red flash + shake + floating "-N"
///  - gain   (value rises): green flash + floating "+N"
///
/// Used for both hero HP and minion health so combat reads clearly.
class ValueChangeEffect extends StatefulWidget {
  const ValueChangeEffect({
    super.key,
    required this.value,
    required this.child,
    this.borderRadius = 12,
    this.numberFontSize = 26,
  });

  final int value;
  final Widget child;
  final double borderRadius;
  final double numberFontSize;

  @override
  State<ValueChangeEffect> createState() => _ValueChangeEffectState();
}

class _ValueChangeEffectState extends State<ValueChangeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _delta = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void didUpdateWidget(covariant ValueChangeEffect old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      _delta = widget.value - old.value;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDamage = _delta < 0;
    final color = isDamage ? AppColors.hpRed : const Color(0xFF4CD964);

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final flashOpacity = t == 0 ? 0.0 : (1 - t) * 0.55;
        // Quick decaying shake only for damage.
        final shake = (isDamage && t > 0 && t < 0.5)
            ? sin(t * pi * 6) * 6 * (1 - t * 2)
            : 0.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Transform.translate(
              offset: Offset(shake, 0),
              child: child,
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: flashOpacity),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                  ),
                ),
              ),
            ),
            if (t > 0 && t < 1 && _delta != 0)
              Positioned(
                top: -widget.numberFontSize * 0.4 - t * 34,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Text(
                    _delta > 0 ? '+$_delta' : '$_delta',
                    style: AppTheme.title(
                      widget.numberFontSize,
                      color: color,
                    ).copyWith(
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
