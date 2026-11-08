import 'package:flutter/material.dart';
import 'package:ticky/core/feedback/app_feedback.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/features/focus/models/focus_block.dart';

/// Undo, the type of the current line, moving it, and deleting it. Scrolls
/// sideways on a narrow phone; "hide keyboard" stays pinned at the end.
class FocusToolbar extends StatelessWidget {
  const FocusToolbar({
    super.key,
    required this.focused,
    required this.canUndo,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onUndo,
    required this.onType,
    required this.onMove,
    required this.onDelete,
    required this.keyboardOpen,
  });

  final FocusBlock? focused;
  final bool canUndo;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onUndo;
  final ValueChanged<FocusBlockType> onType;

  /// -1 moves the line up, 1 moves it down.
  final ValueChanged<int> onMove;
  final VoidCallback onDelete;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = focused;
    final divider = SizedBox(
      width: AppSpacing.md,
      height: 24,
      child: VerticalDivider(
        width: AppSpacing.md,
        color: scheme.onSurface.withValues(alpha: 0.12),
      ),
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _ToolButton(
                          icon: Icons.undo_rounded,
                          label: 'Undo',
                          active: false,
                          enabled: canUndo,
                          onTap: onUndo,
                        ),
                        divider,
                        _ToolButton(
                          icon: Icons.check_circle_outline_rounded,
                          label: 'Goal',
                          active: active?.type == FocusBlockType.todo,
                          enabled: active != null,
                          onTap: () => onType(FocusBlockType.todo),
                        ),
                        _ToolButton(
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'List',
                          active: active?.type == FocusBlockType.bullet,
                          enabled: active != null,
                          onTap: () => onType(FocusBlockType.bullet),
                        ),
                        _ToolButton(
                          icon: Icons.title_rounded,
                          label: 'Heading',
                          active: active?.type == FocusBlockType.heading,
                          enabled: active != null,
                          onTap: () => onType(FocusBlockType.heading),
                        ),
                        divider,
                        _ToolButton(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Move line up',
                          active: false,
                          enabled: active != null && canMoveUp,
                          onTap: () => onMove(-1),
                        ),
                        _ToolButton(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Move line down',
                          active: false,
                          enabled: active != null && canMoveDown,
                          onTap: () => onMove(1),
                        ),
                        _ToolButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete line',
                          active: false,
                          enabled: active != null,
                          onTap: onDelete,
                        ),
                      ],
                    ),
                  ),
                ),
                if (keyboardOpen)
                  _ToolButton(
                    icon: Icons.keyboard_hide_rounded,
                    label: 'Hide keyboard',
                    active: false,
                    enabled: true,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        enableFeedback: false,
        radius: 26,
        onTap: enabled
            ? () {
                AppFeedback.tap();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? scheme.inverseSurface : Colors.transparent,
          ),
          child: Icon(
            icon,
            size: 22,
            color: active
                ? scheme.onInverseSurface
                : scheme.onSurface.withValues(alpha: enabled ? 1 : 0.3),
          ),
        ),
      ),
    );
  }
}

enum _MenuAction { clearDone, copy }

/// The "more" menu in the sheet header: tidy up, or take the page elsewhere.
class FocusMoreMenu extends StatelessWidget {
  const FocusMoreMenu({
    super.key,
    required this.canClearDone,
    required this.canCopy,
    required this.onClearDone,
    required this.onCopy,
  });

  final bool canClearDone;
  final bool canCopy;
  final VoidCallback onClearDone;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_MenuAction>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurface),
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      onSelected: (action) {
        switch (action) {
          case _MenuAction.clearDone:
            onClearDone();
          case _MenuAction.copy:
            onCopy();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MenuAction.clearDone,
          enabled: canClearDone,
          child: const Text('Clear done goals'),
        ),
        PopupMenuItem(
          value: _MenuAction.copy,
          enabled: canCopy,
          child: const Text('Copy as text'),
        ),
      ],
    );
  }
}
