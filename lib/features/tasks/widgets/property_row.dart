import 'package:flutter/material.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';

/// One line of a task's properties: a small muted label on the left, the value
/// on the right. No box around it; whitespace does the grouping.
class PropertyRow extends StatelessWidget {
  const PropertyRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.leading,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Shown before the value text, such as a category dot.
  final Widget? leading;

  static const labelWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: labelWidth,
            child: Row(
              children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// A small, quiet status label: a dot and a word.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.tickyColors;
    final (label, color) = switch (status) {
      TaskStatus.pending => ('To do', scheme.onSurfaceVariant),
      TaskStatus.completed => ('Done', colors.success),
      TaskStatus.skipped => ('Skipped', scheme.onSurfaceVariant),
      TaskStatus.missed => ('Missed', colors.warning),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm - 1),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
