import 'package:flutter/material.dart';

/// Shared visual language for the full-screen "hero" overlays (push consent
/// + offline). A single artwork is used for every orientation; the text
/// plaque and buttons are drawn in Flutter so copy stays crisp at any
/// resolution.
class HeroPalette {
  static const Color ink        = Color(0xFF0A0E1A);
  static const Color goldBright = Color(0xFFFFD86B);
  static const Color gold       = Color(0xFFFFC53D);
  static const Color goldDeep   = Color(0xFFA26E00);
  static const Color goldDark   = Color(0xFF1A0F00);
}

/// Full-bleed background artwork with a readability gradient baked on top.
/// Uses a portrait-specific crop in portrait mode and the wide artwork in
/// landscape so neither image is over-scaled.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          landscape ? 'assets/zeus_hero.png' : 'assets/zeus_hero_portrait.png',
          fit: BoxFit.cover,
          alignment: landscape ? Alignment.center : Alignment.topCenter,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: HeroPalette.ink),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HeroPalette.ink.withValues(alpha: 0.30),
                HeroPalette.ink.withValues(alpha: 0.05),
                HeroPalette.ink.withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ornate dark plaque with a gold frame that carries a title + subtitle.
class HeroPlaque extends StatelessWidget {
  const HeroPlaque({
    super.key,
    required this.title,
    required this.subtitle,
    required this.width,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 22.0 : 27.0;
    final subSize = compact ? 13.5 : 15.5;

    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 22 : 28,
        vertical: compact ? 18 : 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HeroPalette.ink.withValues(alpha: 0.82),
            const Color(0xFF060912).withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HeroPalette.gold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: HeroPalette.gold.withValues(alpha: 0.35),
            blurRadius: 26,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                HeroPalette.goldBright,
                HeroPalette.gold,
                HeroPalette.goldDeep,
              ],
            ).createShader(rect),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                height: 1.12,
                letterSpacing: 0.5,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: subSize,
              fontWeight: FontWeight.w600,
              height: 1.25,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary gold call-to-action button. Slightly narrower than the plaque so
/// it visually nests inside the frame.
class HeroGoldButton extends StatefulWidget {
  const HeroGoldButton({
    super.key,
    required this.label,
    required this.width,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.compact = false,
    this.glow,
  });

  final String label;
  final double width;
  final VoidCallback onTap;
  final IconData? icon;
  final bool busy;
  final bool compact;
  final Animation<double>? glow;

  @override
  State<HeroGoldButton> createState() => _HeroGoldButtonState();
}

class _HeroGoldButtonState extends State<HeroGoldButton>
    with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _press = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.compact ? 17.0 : 20.0;
    final listenables = <Listenable>[_press];
    if (widget.glow != null) listenables.add(widget.glow!);

    return GestureDetector(
      onTapDown: widget.busy
          ? null
          : (_) { setState(() => _down = true); _press.forward(); },
      onTapUp: widget.busy
          ? null
          : (_) {
              setState(() => _down = false);
              _press.reverse();
              widget.onTap();
            },
      onTapCancel: () { setState(() => _down = false); _press.reverse(); },
      child: AnimatedBuilder(
        animation: Listenable.merge(listenables),
        builder: (_, __) {
          final glowV = widget.glow?.value ?? 0.0;
          return Transform.scale(
            scale: 1.0 - 0.04 * _press.value,
            child: Container(
              width: widget.width,
              padding:
                  EdgeInsets.symmetric(vertical: widget.compact ? 13 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _down
                      ? [const Color(0xFFCC9200), const Color(0xFF7B4A00)]
                      : [HeroPalette.gold, HeroPalette.goldDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: HeroPalette.goldDark, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: HeroPalette.gold
                        .withValues(alpha: _down ? 0.2 : 0.34 + 0.25 * glowV),
                    blurRadius: _down ? 6 : 16 + glowV * 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: widget.busy
                    ? SizedBox(
                        width: fontSize + 4, height: fontSize + 4,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5, color: HeroPalette.goldDark,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon,
                                color: HeroPalette.goldDark,
                                size: fontSize + 2),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: HeroPalette.goldDark,
                              fontSize: fontSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Text-only secondary action ("Skip"). Bordered pill so it reads clearly
/// over the busy artwork.
class HeroGhostButton extends StatefulWidget {
  const HeroGhostButton({
    super.key,
    required this.label,
    required this.width,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final double width;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<HeroGhostButton> createState() => _HeroGhostButtonState();
}

class _HeroGhostButtonState extends State<HeroGhostButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) { setState(() => _down = false); widget.onTap(); },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 11 : 13),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: _down ? 0.5 : 0.34),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: HeroPalette.gold.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 15 : 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
