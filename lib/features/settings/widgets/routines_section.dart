import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/tasks/models/repeat_days.dart';
import 'package:ticky/features/tasks/providers/routine_actions.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

/// Every routine: tap to edit, switch to pause, drag the handle to reorder,
/// swipe left to delete (with undo).
class RoutinesSection extends ConsumerWidget {
  const RoutinesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(activeRoutinesProvider).value ?? const [];
    final actions = ref.read(routineActionsProvider);
    final messenger = ScaffoldMessenger.of(context);

    void say(String message, {VoidCallback? onUndo}) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: onUndo == null
                ? null
                : SnackBarAction(label: 'Undo', onPressed: onUndo),
          ),
        );
    }

    /// Runs a change; says why and returns false when it is refused.
    Future<bool> attempt(Future<void> Function() change) async {
      try {
        await change();
        return true;
      } on DataException catch (error) {
        say(error.message);
        return false;
      }
    }

    void onReorder(int oldIndex, int newIndex) {
      final ids = [for (final routine in routines) routine.id];
      ids.insert(newIndex, ids.removeAt(oldIndex));
      attempt(() => actions.reorder(ids));
    }

    Future<void> delete(RoutineTask routine) async {
      if (!await attempt(() => actions.delete(routine.id))) return;
      HapticFeedback.mediumImpact();
      say(
        '"${routine.title}" deleted',
        onUndo: () => attempt(() => actions.undoDelete(routine.id)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Routines'),
        FormCard(
          children: [
            if (routines.isNotEmpty)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: routines.length,
                onReorderItem: onReorder,
                proxyDecorator: (child, index, animation) => Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  return _RoutineRow(
                    key: ValueKey('routine-${routine.id}'),
                    routine: routine,
                    index: index,
                    onOpen: () => AppRoutes.openEditTask(context, routine.id),
                    onToggle: (enabled) =>
                        attempt(() => actions.setEnabled(routine.id, enabled)),
                    onDelete: () => delete(routine),
                  );
                },
              ),
            FormRow(
              icon: Icons.add_rounded,
              label: routines.isEmpty
                  ? 'Add your first routine'
                  : 'Add routine',
              onTap: () => AppRoutes.openAddTask(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  const _RoutineRow({
    super.key,
    required this.routine,
    required this.index,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final RoutineTask routine;
  final int index;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  String get _subtitle {
    final minutes = routine.reminderMinutes;
    final parts = [
      if (!routine.isEnabled) 'Paused',
      minutes == null ? 'Anytime' : formatMinutesOfDay(minutes),
      repeatSummary(routine.repeatDays),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey('dismiss-${routine.id}'),
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(color: scheme.error.withValues(alpha: 0.18)),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Icon(Icons.delete_outline_rounded, color: scheme.error),
          ),
        ),
      ),
      // Act, then refuse the dismissal: the list rebuilds from the database.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Opacity(
        opacity: routine.isEnabled ? 1 : 0.55,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onOpen,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant,
                    width: AppStroke.hairline,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.title,
                            style: text.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _subtitle,
                            style: text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Switch(value: routine.isEnabled, onChanged: onToggle),
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: scheme.onSurfaceVariant,
                          semanticLabel: 'Drag to reorder',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
