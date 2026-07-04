import 'dart:math';

import 'package:flutter/material.dart';

/// A one-shot radial particle explosion (sparks + confetti shards).
/// Drop it into a Stack and give it a [trigger] that changes to replay.
class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    required this.colors,
    this.trigger = 0,
    this.particleCount = 26,
    this.duration = const Duration(milliseconds: 900),
    this.spread = 130,
  });

  final List<Color> colors;

  /// Changing this value replays the burst.
  final int trigger;
  final int particleCount;
  final Duration duration;

  /// Max travel distance in logical pixels.
  final double spread;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _Particle {
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.isSpark,
  });

  final double angle;
  final double speed; // 0..1 multiplier of spread
  final double size;
  final Color color;
  final double spin;
  final bool isSpark;
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final Random _rng = Random();
  List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _spawn();
    _c.forward();
  }

  @override
  void didUpdateWidget(covariant ParticleBurst old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) {
      _spawn();
      _c.forward(from: 0);
    }
  }

  void _spawn() {
    _particles = List.generate(widget.particleCount, (i) {
      return _Particle(
        angle: _rng.nextDouble() * 2 * pi,
        speed: 0.45 + _rng.nextDouble() * 0.55,
        size: 3 + _rng.nextDouble() * 5,
        color: widget.colors[_rng.nextInt(widget.colors.length)],
        spin: (_rng.nextDouble() - 0.5) * 10,
        isSpark: _rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          painter: _BurstPainter(
            particles: _particles,
            t: Curves.easeOutCubic.transform(_c.value),
            raw: _c.value,
            spread: widget.spread,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.particles,
    required this.t,
    required this.raw,
    required this.spread,
  });

  final List<_Particle> particles;
  final double t;
  final double raw;
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    if (raw == 0 || raw == 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final opacity = (1 - raw).clamp(0.0, 1.0);

    for (final p in particles) {
      final distance = spread * p.speed * t;
      // Slight gravity pull on confetti shards.
      final gravity = p.isSpark ? 0.0 : 30.0 * raw * raw;
      final pos = center +
          Offset(cos(p.angle) * distance, sin(p.angle) * distance + gravity);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);

      if (p.isSpark) {
        canvas.drawCircle(pos, p.size * (1 - raw * 0.5), paint);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(p.spin * raw);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size * 1.6, height: p.size),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.raw != raw;
}
