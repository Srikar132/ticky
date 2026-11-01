import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// Ticky's main call-to-action: a solid, classic white button with dark text
/// and a dark icon badge. No gradient, no glow; depth comes from a soft shadow.
///
/// Pressing it eases it down slightly. [compact] shrinks it to fit its
/// content, for use as a floating button.
class PrimaryActionButton extends StatefulWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final bool compact;

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const ink = AppColors.deepBackground;
    final radius = BorderRadius.circular(widget.compact ? 18 : 20);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final badge = const DecoratedBox(
      decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Icon(Icons.add_rounded, size: 18, color: AppColors.white),
      ),
    );

    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.labelLarge?.copyWith(
        color: ink,
        fontSize: widget.compact ? 15 : 16,
        fontWeight: FontWeight.w700,
      ),
    );

    final content = Row(
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        widget.icon == Icons.add_rounded
            ? badge
            : DecoratedBox(
                decoration: const BoxDecoration(
                  color: ink,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(widget.icon, size: 18, color: AppColors.white),
                ),
              ),
        const SizedBox(width: AppSpacing.md),
        if (widget.compact)
          label
        else ...[
          Expanded(child: label),
          Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: ink.withValues(alpha: 0.55),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFFE4E0F4) : AppColors.white,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              splashColor: ink.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              onHighlightChanged: _setPressed,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onPressed();
              },
              child: SizedBox(
                height: widget.compact ? 52 : 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Align(
                    alignment: widget.compact
                        ? Alignment.center
                        : Alignment.centerLeft,
                    widthFactor: widget.compact ? 1 : null,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
