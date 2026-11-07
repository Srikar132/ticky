import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/theme/ticky_colors.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/core/widgets/round_icon_button.dart';
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
        leading: const RoundBackButton(),
        actions: [
          if (details.canEdit)
            RoundIconButton(
              tooltip: 'Edit task',
              icon: Icons.edit_outlined,
              onPressed: () =>
                  AppRoutes.openEditTask(context, record.routineTaskId),
            ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg + 4,
          AppSpacing.sm,
          AppSpacing.lg + 4,
          AppSpacing.xxl,
        ),
        children: [
          _Header(details: details),
          const SizedBox(height: AppSpacing.lg),
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
          _Properties(
            details: details,
            category: categories[routine?.categoryId],
            now: now,
          ),
          if (!details.routineIsActive) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                'This task was deleted. Its history stays.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (details.canDelete) ...[
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => _delete(details),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(0, AppSizes.compactControl),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
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

/// A pastel card with the status, the day, the title and the notes. The colour
/// follows the status: lavender to do, mint done, butter skipped, pink missed.
class _Header extends StatelessWidget {
  const _Header({required this.details});

  final TaskDetails details;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = context.tickyColors;
    final done = details.status == TaskStatus.completed;
    final description = details.routine?.description;
    final day = details.isToday
        ? 'Today'
        : formatLongDate(parseDateKey(details.record.dateKey));
    final tint = switch (details.status) {
      TaskStatus.pending => colors.tileLavender,
      TaskStatus.completed => colors.tileMint,
      TaskStatus.skipped => colors.tileButter,
      TaskStatus.missed => colors.tilePink,
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: tint, borderRadius: AppRadius.xlAll),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(status: details.status),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: Text(
                    day,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              details.record.titleSnapshot,
              style: text.headlineMedium?.copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: scheme.onSurfaceVariant,
              ),
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                description,
                style: text.bodyLarge?.copyWith(color: scheme.onSurface),
              ),
            ],
          ],
        ),
      ),
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

/// The few things you can do to today's task. A big Done button, then Skip
/// and Snooze as soft pills that share the row.
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

  @override
  Widget build(BuildContext context) {
    switch (details.status) {
      case TaskStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.control + 2),
              ),
              onPressed: onComplete,
              icon: const Icon(Icons.check_rounded, size: 22),
              label: const Text('Done'),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Expanded(
                  child: _SoftAction(
                    icon: Icons.skip_next_rounded,
                    label: 'Skip',
                    onTap: onSkip,
                  ),
                ),
                if (details.canSnooze) ...[
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: _SoftAction(
                      icon: Icons.snooze_rounded,
                      label: 'Snooze',
                      onTap: onSnooze,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      case TaskStatus.completed:
        return _SoftAction(
          icon: Icons.undo_rounded,
          label: 'Mark as not done',
          onTap: onReopen,
        );
      case TaskStatus.skipped:
        return _SoftAction(
          icon: Icons.undo_rounded,
          label: 'Undo skip',
          onTap: onReopen,
        );
      case TaskStatus.missed:
        return const SizedBox.shrink();
    }
  }
}

/// A white rounded pill with an icon and a label.
class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: AppSizes.control,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: scheme.onSurface),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    return FormCard(
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
