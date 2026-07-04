import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The game's main CTA button: gold gradient (primary) or dark panel
/// (secondary), with a press-down scale animation and haptic feedback.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = true,
    this.height = 60,
    this.fontSize,
    this.accent,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool primary;
  final double height;
  final double? fontSize;

  /// Overrides the accent color of a secondary button's border/icon.
  final Color? accent;
  final bool enabled;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.onTap != null;
    final gradient = widget.primary && enabled
        ? const LinearGradient(colors: [AppColors.gold, AppColors.goldLight])
        : LinearGradient(colors: [
            AppColors.panel.withValues(alpha: 0.95),
            AppColors.backgroundLight.withValues(alpha: 0.95),
          ]);
    final fg = widget.primary && enabled
        ? Colors.black
        : enabled
            ? (widget.accent ?? AppColors.textPrimary)
            : AppColors.textMuted;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.primary && enabled
                  ? AppColors.goldLight
                  : (widget.accent ?? AppColors.panelBorder)
                      .withValues(alpha: enabled ? 0.8 : 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.primary && enabled
                        ? AppColors.gold
                        : Colors.black)
                    .withValues(alpha: 0.45),
                blurRadius: widget.primary && enabled ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: fg, size: (widget.fontSize ?? 18) + 5),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.title(widget.fontSize ?? 18, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
