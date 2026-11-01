import 'package:flutter/material.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// What the user picked in the quick-actions sheet.
enum TaskQuickAction { complete, reopen, skip, snooze, edit, details }

/// Bottom sheet opened by long-pressing a task. Returns the chosen action, or
/// null if the sheet was dismissed.
Future<TaskQuickAction?> showTaskActionsSheet(
  BuildContext context,
  DailyTaskEntry entry,
) {
  return showModalBottomSheet<TaskQuickAction>(
    context: context,
    useSafeArea: true,
    builder: (_) => _TaskActionsSheet(entry: entry),
  );
}

class _TaskActionsSheet extends StatelessWidget {
  const _TaskActionsSheet({required this.entry});

  final DailyTaskEntry entry;

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final status = record.status;
    final scheduled = record.scheduledMinutes;
    final canSnooze = status == TaskStatus.pending && scheduled != null;

    Widget action({
      required IconData icon,
      required String label,
      required TaskQuickAction value,
      Color? color,
    }) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(label),
        onTap: () => Navigator.of(context).pop(value),
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.titleSnapshot,
                  style: text.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scheduled != null)
                  Text(
                    formatMinutesOfDay(scheduled),
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (status == TaskStatus.completed)
            action(
              icon: Icons.undo_rounded,
              label: 'Mark as not done',
              value: TaskQuickAction.reopen,
            )
          else
            action(
              icon: Icons.check_circle_outline_rounded,
              label: 'Mark as done',
              value: TaskQuickAction.complete,
            ),
          if (status == TaskStatus.skipped)
            action(
              icon: Icons.undo_rounded,
              label: 'Undo skip',
              value: TaskQuickAction.reopen,
            )
          else if (status == TaskStatus.pending)
            action(
              icon: Icons.skip_next_rounded,
              label: 'Skip for today',
              value: TaskQuickAction.skip,
            ),
          if (canSnooze)
            action(
              icon: Icons.snooze_rounded,
              label: 'Snooze reminder',
              value: TaskQuickAction.snooze,
            ),
          action(
            icon: Icons.edit_outlined,
            label: 'Edit task',
            value: TaskQuickAction.edit,
          ),
          action(
            icon: Icons.info_outline_rounded,
            label: 'Details',
            value: TaskQuickAction.details,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
