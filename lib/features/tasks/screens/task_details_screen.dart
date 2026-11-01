import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/confirm_sheet.dart';
import 'package:ticky/features/categories/models/category_options.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/home/providers/home_providers.dart';
import 'package:ticky/features/rewards/data/reward_config.dart';
import 'package:ticky/features/tasks/models/repeat_days.dart';
import 'package:ticky/features/tasks/models/task_details.dart';
import 'package:ticky/features/tasks/providers/routine_actions.dart';
import 'package:ticky/features/tasks/providers/task_details_providers.dart';
import 'package:ticky/features/tasks/widgets/property_row.dart';

/// One daily record ([recordId]) with its routine's settings.
///
/// Today's task can be completed, skipped, snoozed, edited or deleted. Past
/// days are read-only. Deleting archives the routine, so history stays.
class TaskDetailsScreen extends ConsumerStatefulWidget {
  const TaskDetailsScreen({super.key, required this.recordId});

  final int recordId;

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  /// Set while deleting, so the screen does not flash "no longer exists" when
  /// the record disappears just before it closes.
  bool _leaving = false;

  void _say(String message, {String? undoLabel, VoidCallback? onUndo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: onUndo == null
              ? null
              : SnackBarAction(label: undoLabel ?? 'Undo', onPressed: onUndo),
        ),
      );
  }

  /// Runs a change and reports expected failures as a message.
  Future<bool> _attempt(Future<void> Function() change) async {
    try {
      await change();
      return true;
    } on DataException catch (error) {
      if (mounted) _say(error.message);
      return false;
    }
  }

  Future<void> _complete(TaskDetails details) async {
    final actions = ref.read(taskActionsProvider);
    final id = details.record.id;
    if (!await _attempt(() => actions.complete(id))) return;
    HapticFeedback.mediumImpact();
    final coins = coinsForPriority(
      details.routine?.priority ?? Priority.medium,
    );
    if (mounted) {
      _say(
        'Nice! +$coins ${coins == 1 ? 'coin' : 'coins'}',
        onUndo: () => _attempt(() => actions.reopen(id)),
      );
    }
  }

  Future<void> _skip(TaskDetails details) async {
    final actions = ref.read(taskActionsProvider);
    final id = details.record.id;
    if (!await _attempt(() => actions.skip(id))) return;
    HapticFeedback.selectionClick();
    if (mounted) {
      _say(
        'Skipped for today',
        onUndo: () => _attempt(() => actions.reopen(id)),
      );
    }
  }

  Future<void> _reopen(TaskDetails details) async {
    if (await _attempt(
      () => ref.read(taskActionsProvider).reopen(details.record.id),
    )) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _snooze(TaskDetails details) async {
    try {
      final until = await ref
          .read(taskActionsProvider)
          .snooze(details.record.id);
      HapticFeedback.selectionClick();
      if (mounted) {
        _say('Snoozed until ${formatMinutesOfDay(minutesOfDay(until))}');
      }
    } on DataException catch (error) {
      if (mounted) _say(error.message);
    }
  }

  Future<void> _delete(TaskDetails details) async {
    final routineId = details.record.routineTaskId;
    final confirmed = await showConfirmSheet(
      context,
      title: 'Delete this task?',
      message:
          'It leaves your routine from now on. Your history and coins stay.',
      keepLabel: 'Keep task',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;

    final actions = ref.read(routineActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _leaving = true);
    try {
      await actions.delete(routineId);
    } on DataException catch (error) {
      if (mounted) {
        setState(() => _leaving = false);
        _say(error.message);
      }
      return;
    }
    HapticFeedback.mediumImpact();
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Task deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => actions.undoDelete(routineId),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final recordAsync = ref.watch(detailRecordProvider(widget.recordId));
    final record = recordAsync.value;

    if (_leaving) return Scaffold(appBar: AppBar());
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task')),
        body: recordAsync.hasError
            ? const _Message('Could not open this task')
            : recordAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const _Message('This task no longer exists'),
      );
    }

    final routine = ref
        .watch(detailRoutineProvider(record.routineTaskId))
        .value;
    final now = ref.watch(nowProvider).value ?? ref.read(clockProvider)();
    final todayKey = ref.watch(todayKeyProvider).value ?? dateKeyOf(now);
    final categories = {
      for (final c
          in ref.watch(allCategoriesProvider).value ?? const <Category>[])
        c.id: c,
    };
    final details = TaskDetails(
      record: record,
      routine: routine,
      todayKey: todayKey,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (details.canEdit)
            IconButton(
              tooltip: 'Edit task',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  AppRoutes.openEditTask(context, record.routineTaskId),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          _Header(details: details),
          const SizedBox(height: AppSpacing.xl),
          if (details.canChangeStatus)
            _StatusActions(
              details: details,
              onComplete: () => _complete(details),
              onSkip: () => _skip(details),
              onReopen: () => _reopen(details),
              onSnooze: () => _snooze(details),
            )
          else
            const _ReadOnlyNote(),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _Properties(
            details: details,
            category: categories[routine?.categoryId],
            now: now,
          ),
          if (!details.routineIsActive) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'This task was deleted. Its history stays.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (details.canDelete) ...[
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _delete(details),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete task'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Title, status and day, then the notes.
class _Header extends StatelessWidget {
  const _Header({required this.details});

  final TaskDetails details;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = details.status == TaskStatus.completed;
    final description = details.routine?.description;
    final day = details.isToday
        ? 'Today'
        : formatLongDate(parseDateKey(details.record.dateKey));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          details.record.titleSnapshot,
          style: text.headlineSmall?.copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            decorationColor: scheme.onSurfaceVariant,
            color: done ? scheme.onSurfaceVariant : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            StatusPill(status: details.status),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                day,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            description,
            style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _ReadOnlyNote extends StatelessWidget {
  const _ReadOnlyNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Past days are read-only',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The few things you can do to today's task, as compact buttons.
class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.details,
    required this.onComplete,
    required this.onSkip,
    required this.onReopen,
    required this.onSnooze,
  });

  final TaskDetails details;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onReopen;
  final VoidCallback onSnooze;

  static const _size = Size.fromHeight(AppSizes.compactControl);

  @override
  Widget build(BuildContext context) {
    final filled = FilledButton.styleFrom(minimumSize: _size);
    final outlined = OutlinedButton.styleFrom(minimumSize: _size);
    const gap = SizedBox(width: AppSpacing.sm);

    switch (details.status) {
      case TaskStatus.pending:
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: FilledButton(
                style: filled,
                onPressed: onComplete,
                child: const Text('Done'),
              ),
            ),
            gap,
            Expanded(
              flex: 2,
              child: OutlinedButton(
                style: outlined,
                onPressed: onSkip,
                child: const Text('Skip'),
              ),
            ),
            if (details.canSnooze) ...[
              gap,
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: outlined,
                  onPressed: onSnooze,
                  child: const Text('Snooze'),
                ),
              ),
            ],
          ],
        );
      case TaskStatus.completed:
        return OutlinedButton(
          style: outlined,
          onPressed: onReopen,
          child: const Text('Mark as not done'),
        );
      case TaskStatus.skipped:
        return OutlinedButton(
          style: outlined,
          onPressed: onReopen,
          child: const Text('Undo skip'),
        );
      case TaskStatus.missed:
        return const SizedBox.shrink();
    }
  }
}

class _Properties extends StatelessWidget {
  const _Properties({
    required this.details,
    required this.category,
    required this.now,
  });

  final TaskDetails details;
  final Category? category;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final record = details.record;
    final routine = details.routine;
    final scheduled = record.scheduledMinutes;
    final snoozeEnd = details.activeSnoozeEnd(now);
    final completedAt = record.completedAt?.toLocal();
    final message = routine?.customReminderMessage;

    String time() {
      final base = scheduled == null
          ? 'Anytime'
          : formatMinutesOfDay(scheduled);
      return routine != null && routine.alarmEnabled && scheduled != null
          ? '$base · Alarm'
          : base;
    }

    String priority(Priority value) {
      final coins = coinsForPriority(value);
      final label = value.name[0].toUpperCase() + value.name.substring(1);
      return '$label · $coins ${coins == 1 ? 'coin' : 'coins'}';
    }

    return Column(
      children: [
        PropertyRow(icon: Icons.schedule_rounded, label: 'Time', value: time()),
        if (snoozeEnd != null)
          PropertyRow(
            icon: Icons.snooze_rounded,
            label: 'Snoozed',
            value: 'Until ${formatMinutesOfDay(minutesOfDay(snoozeEnd))}',
          ),
        if (completedAt != null)
          PropertyRow(
            icon: Icons.check_rounded,
            label: 'Done at',
            value: formatMinutesOfDay(minutesOfDay(completedAt)),
          ),
        if (routine != null) ...[
          PropertyRow(
            icon: Icons.repeat_rounded,
            label: 'Repeat',
            value: repeatSummary(routine.repeatDays),
          ),
          if (category != null)
            PropertyRow(
              icon: Icons.label_outline_rounded,
              label: 'Category',
              value: category!.title,
              leading: Icon(
                iconForCategoryKey(category!.iconKey),
                size: 16,
                color: Color(category!.colorValue),
              ),
            ),
          PropertyRow(
            icon: Icons.flag_outlined,
            label: 'Priority',
            value: priority(routine.priority),
          ),
          if (routine.durationMinutes != null)
            PropertyRow(
              icon: Icons.timer_outlined,
              label: 'Duration',
              value: formatDuration(routine.durationMinutes!),
            ),
          if (routine.snoozeMinutes != null)
            PropertyRow(
              icon: Icons.snooze_rounded,
              label: 'Snooze for',
              value: formatDuration(routine.snoozeMinutes!),
            ),
          if (message != null && message.isNotEmpty)
            PropertyRow(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              value: message,
            ),
        ],
      ],
    );
  }
}
