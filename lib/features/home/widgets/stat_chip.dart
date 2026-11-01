import 'package:flutter/material.dart';
import 'package:ticky/core/theme/app_tokens.dart';

/// A small pill with an icon and a number, such as the streak or coin balance.
/// The number animates when it changes.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final Color color;
  final int value;

  /// Spoken by screen readers, together with [value].
  final String label;
  final VoidCallback? onTap;

  /// Greyed out, for example a streak that is not lit yet.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const shape = StadiumBorder();
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface.withValues(alpha: 0.72),
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: dimmed ? scheme.onSurfaceVariant : color,
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$value',
                    key: ValueKey(value),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
