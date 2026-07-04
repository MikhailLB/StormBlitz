import 'dart:math';

import 'package:flutter/material.dart';

import '../models/chest.dart';
import '../theme/app_theme.dart';

extension ChestTierStyle on ChestTier {
  Color get color {
    switch (this) {
      case ChestTier.common:
        return AppColors.common;
      case ChestTier.rare:
        return AppColors.rare;
      case ChestTier.epic:
        return AppColors.epic;
      case ChestTier.olympian:
        return AppColors.legendary;
    }
  }
}

/// Fully vector chest: painted body + lid + lock, tier-colored, with an
/// optional pulsing glow (ready to open) and idle wobble (unlocking).
class ChestWidget extends StatefulWidget {
  const ChestWidget({
    super.key,
    required this.tier,
    this.size = 64,
    this.glowing = false,
    this.wobbling = false,
    this.open = false,
  });

  final ChestTier tier;
  final double size;
  final bool glowing;
  final bool wobbling;
  final bool open;

  @override
  State<ChestWidget> createState() => _ChestWidgetState();
}

class _ChestWidgetState extends State<ChestWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final wobble = widget.wobbling ? sin(t * 2 * pi * 2) * 0.045 : 0.0;
        final glowPulse =
            widget.glowing ? 0.55 + 0.45 * sin(t * 2 * pi) : 0.0;

        return Transform.rotate(
          angle: wobble,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: widget.glowing
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.tier.color
                            .withValues(alpha: 0.35 + 0.35 * glowPulse),
                        blurRadius: widget.size * 0.35,
                        spreadRadius: widget.size * 0.04,
                      ),
                    ],
                  )
                : null,
            child: CustomPaint(
              painter: _ChestPainter(
                color: widget.tier.color,
                open: widget.open,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChestPainter extends CustomPainter {
  _ChestPainter({required this.color, required this.open});

  final Color color;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyRect = Rect.fromLTWH(w * 0.12, h * 0.42, w * 0.76, h * 0.44);
    final lidRect = open
        ? Rect.fromLTWH(w * 0.08, h * 0.10, w * 0.84, h * 0.24)
        : Rect.fromLTWH(w * 0.10, h * 0.26, w * 0.80, h * 0.24);

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.black, 0.25)!,
          Color.lerp(color, Colors.black, 0.6)!,
        ],
      ).createShader(bodyRect);
    final lidPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
      ).createShader(lidRect);

    // Open chests spill light from inside.
    if (open) {
      final lightPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(w * 0.5, h * 0.40), radius: w * 0.4));
      canvas.drawCircle(Offset(w * 0.5, h * 0.40), w * 0.4, lightPaint);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.07)),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, Radius.circular(w * 0.09)),
      lidPaint,
    );

    // Metal bands.
    final bandPaint = Paint()
      ..color = Color.lerp(color, Colors.white, 0.45)!
      ..strokeWidth = w * 0.035
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.5, lidRect.top),
      Offset(w * 0.5, bodyRect.bottom),
      bandPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.07)),
      bandPaint..strokeWidth = w * 0.02,
    );

    // Lock.
    if (!open) {
      final lockCenter = Offset(w * 0.5, h * 0.47);
      canvas.drawCircle(
        lockCenter,
        w * 0.09,
        Paint()..color = Color.lerp(color, Colors.white, 0.6)!,
      );
      canvas.drawCircle(
        lockCenter,
        w * 0.045,
        Paint()..color = Color.lerp(color, Colors.black, 0.7)!,
      );
    }
  }

  @override
  bool shouldRepaint(_ChestPainter old) =>
      old.color != color || old.open != open;
}

/// Formats a chest countdown like "4:37" or "1h 12m".
String formatChestDuration(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
  }
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
