import 'package:flutter/material.dart';
import 'package:ticky/features/focus/models/focus_block.dart';
import 'package:ticky/features/focus/widgets/focus_marks.dart';

/// The text style of a block, shared by the editor and the read-only views.
TextStyle focusTextStyle(BuildContext context, FocusBlock block) {
  final text = Theme.of(context).textTheme;
  final scheme = Theme.of(context).colorScheme;
  return switch (block.type) {
    FocusBlockType.heading => (text.titleLarge ?? const TextStyle()),
    FocusBlockType.todo when block.checked =>
      (text.bodyLarge ?? const TextStyle()).copyWith(
        color: scheme.onSurfaceVariant,
        decoration: TextDecoration.lineThrough,
        decorationColor: scheme.onSurfaceVariant,
      ),
    _ => text.bodyLarge ?? const TextStyle(),
  };
}

/// One line of the notebook shown as plain text: on the Home card (where a goal
/// can be ticked) and in history (where nothing can be changed).
class FocusPreviewRow extends StatelessWidget {
  const FocusPreviewRow({super.key, required this.block, this.onToggle});

  final FocusBlock block;

  /// Ticks or unticks a to-do. Null makes the row read-only.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = focusTextStyle(context, block);
    final Widget leading;
    if (block.isTodo) {
      leading = onToggle != null
          ? FocusCheck(
              checked: block.checked,
              onTap: onToggle!,
              size: 22,
              extent: 38,
            )
          : SizedBox(
              width: 38,
              height: 32,
              child: Icon(
                block.checked
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 22,
                color: block.checked
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.4),
                semanticLabel: block.checked ? 'Done' : 'Not done',
              ),
            );
    } else if (block.type == FocusBlockType.bullet) {
      leading = SizedBox(
        width: 38,
        height: 28,
        child: Center(
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      leading = const SizedBox(width: 4);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              block.text,
              style: style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// The non-blank lines of a notebook, up to [maxRows] (all when null).
class FocusPreviewList extends StatelessWidget {
  const FocusPreviewList({
    super.key,
    required this.blocks,
    this.maxRows,
    this.onToggle,
  });

  final List<FocusBlock> blocks;
  final int? maxRows;
  final void Function(FocusBlock block)? onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = blocks.where((b) => !b.isBlank).toList();
    final shown = maxRows == null ? visible : visible.take(maxRows!).toList();
    final hidden = visible.length - shown.length;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in shown)
          FocusPreviewRow(
            key: ValueKey('preview-${block.id}'),
            block: block,
            onToggle: block.isTodo && onToggle != null
                ? () => onToggle!(block)
                : null,
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '+ $hidden more',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
