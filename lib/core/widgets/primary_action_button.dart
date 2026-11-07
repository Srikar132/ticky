import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// Ticky's main call-to-action: a solid near-black pill with white text and a
/// small white icon badge, like the dark pills in the design.
///
/// Pressing it eases it down slightly. [compact] shrinks it to fit its
/// content.
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
    final scheme = Theme.of(context).colorScheme;
    final ink = scheme.inverseSurface;
    final onInk = scheme.onInverseSurface;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    const radius = BorderRadius.all(Radius.circular(AppRadius.pill));

    final label = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: text.labelLarge?.copyWith(
        color: onInk,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );

    final badge = DecoratedBox(
      decoration: BoxDecoration(color: onInk, shape: BoxShape.circle),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(widget.icon, size: 18, color: ink),
      ),
    );

    final content = Row(
      mainAxisSize: widget.compact ? MainAxisSize.min : MainAxisSize.max,
      children: [
        badge,
        const SizedBox(width: AppSpacing.md),
        if (widget.compact)
          label
        else ...[
          Expanded(child: label),
          Icon(
            Icons.arrow_forward_rounded,
            size: 20,
            color: onInk.withValues(alpha: 0.6),
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
            color: _pressed ? Color.lerp(ink, onInk, 0.14) : ink,
            borderRadius: radius,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              splashColor: onInk.withValues(alpha: 0.12),
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
