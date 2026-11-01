import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_tokens.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/primary_action_button.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/home/widgets/notification_permission_sheet.dart';
import 'package:ticky/features/rewards/data/reward_config.dart';
import 'package:ticky/features/tasks/models/repeat_days.dart';
import 'package:ticky/features/tasks/models/task_form_state.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';
import 'package:ticky/features/tasks/providers/task_form_controller.dart';
import 'package:ticky/features/tasks/widgets/category_picker_sheet.dart';
import 'package:ticky/features/tasks/widgets/discard_changes_sheet.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/tasks/widgets/option_chips.dart';
import 'package:ticky/features/tasks/widgets/reminder_time_sheet.dart';
import 'package:ticky/features/tasks/widgets/repeat_days_sheet.dart';

const _durationPresets = [5, 10, 15, 20, 30, 45, 60, 90, 120];
const _snoozePresets = [5, 10, 15, 30, 60];

/// Adds a task, or edits one when [routineId] is given. A [suggestion]
/// pre-fills a new task.
///
/// This widget only shows the form and forwards what the user does to
/// [TaskFormController]; validation and saving live there.
class AddEditTaskScreen extends ConsumerWidget {
  const AddEditTaskScreen({super.key, this.routineId, this.suggestion});

  final int? routineId;
  final TaskSuggestion? suggestion;

  bool get isEditing => routineId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = TaskFormArgs(routineId: routineId, suggestion: suggestion);
    final form = ref.watch(taskFormControllerProvider(args));
    final title = isEditing ? 'Edit task' : 'New task';

    if (form.hasValue) {
      return _TaskForm(key: ValueKey(args), args: args, title: title);
    }
    // While loading (a few milliseconds) the page shows only its title, with
    // no spinner, so nothing flashes before the form appears.
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: form.hasError
          ? _UnavailableTask(
              message: form.error is DataException
                  ? (form.error! as DataException).message
                  : 'Could not open this task',
            )
          : const SizedBox.shrink(),
    );
  }
}

class _UnavailableTask extends StatelessWidget {
  const _UnavailableTask({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
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

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({super.key, required this.args, required this.title});

  final TaskFormArgs args;
  final String title;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _message;
  final _scroll = ScrollController();
  final _fieldKeys = {
    for (final field in RoutineField.values) field: GlobalKey(),
  };

  late final _provider = taskFormControllerProvider(widget.args);

  TaskFormController get _controller => ref.read(_provider.notifier);

  final _titleFocus = FocusNode();
  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeListener;
  bool _focusHandled = false;

  @override
  void initState() {
    super.initState();
    final values = ref.read(_provider).requireValue.values;
    _title = TextEditingController(text: values.title);
    _description = TextEditingController(text: values.description);
    _message = TextEditingController(text: values.customReminderMessage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_focusHandled) return;
    _focusHandled = true;
    _focusTitleOnceSettled();
  }

  /// A blank new task starts with the keyboard up, but only once the page has
  /// finished sliding in. Opening the keyboard during the transition makes the
  /// layout jump, which looks like a glitch.
  void _focusTitleOnceSettled() {
    final form = ref.read(_provider).requireValue;
    if (form.isEditing || form.values.title.isNotEmpty) return;

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _titleFocus.requestFocus();
      return;
    }
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      _detachRouteListener();
      if (mounted) _titleFocus.requestFocus();
    }

    _routeAnimation = animation;
    _routeListener = onStatus;
    animation.addStatusListener(onStatus);
  }

  void _detachRouteListener() {
    final listener = _routeListener;
    if (listener != null) _routeAnimation?.removeStatusListener(listener);
    _routeListener = null;
    _routeAnimation = null;
  }

  @override
  void dispose() {
    _detachRouteListener();
    _titleFocus.dispose();
    _title.dispose();
    _description.dispose();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the time sheet. Returns true when a time was set.
  Future<bool> _pickTime(TaskFormValues values) async {
    final choice = await showReminderTimeSheet(
      context,
      initialMinutes:
          values.reminderMinutes ??
          suggestedReminderMinutes(ref.read(clockProvider)()),
      canClear: values.hasReminder,
    );
    if (choice == null || !mounted) return false;
    _controller.setReminder(choice.minutes);
    return choice.minutes != null;
  }

  Future<void> _toggleAlarm(TaskFormValues values, bool enabled) async {
    if (_controller.setAlarm(enabled)) return;
    // An alarm needs a time: ask for one, then switch the alarm on.
    if (await _pickTime(values)) _controller.setAlarm(true);
  }

  Future<void> _pickCategory(TaskFormValues values) async {
    final categories = ref.read(activeCategoriesProvider).value ?? const [];
    final id = await showCategoryPickerSheet(
      context,
      categories: categories,
      selectedId: values.categoryId,
    );
    if (id != null && mounted) _controller.setCategory(id);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final result = await _controller.save();
    if (!mounted) return;
    switch (result) {
      case TaskSaveResult.invalid:
        _revealFirstError();
      case TaskSaveResult.saved:
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
      case TaskSaveResult.savedNeedsPermission:
        HapticFeedback.selectionClick();
        // The task is saved already; this only offers working reminders.
        await showNotificationPermissionSheet(context, ref);
        if (mounted) Navigator.of(context).pop();
    }
  }

  void _revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final errors = ref.read(_provider).value?.errors ?? const {};
      for (final field in RoutineField.values) {
        if (!errors.containsKey(field)) continue;
        final target = _fieldKeys[field]!.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: 0.1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.medium,
            curve: AppMotion.curve,
          );
        }
        return;
      }
    });
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDiscardChangesSheet(context);
    if (discard && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(_provider).requireValue;
    final values = form.values;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(activeCategoriesProvider).value ?? const [];
    final Category? category = categories
        .where((c) => c.id == values.categoryId)
        .firstOrNull;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      canPop: !form.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: [
                  if (form.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: FieldError(form.message!),
                    ),
                  KeyedSubtree(
                    key: _fieldKeys[RoutineField.title],
                    child: TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                      minLines: 1,
                      maxLines: 3,
                      style: text.headlineSmall,
                      decoration: bareInputDecoration(
                        context,
                        hint: 'What do you want to do?',
                        hintStyle: text.headlineSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        errorText: form.errors[RoutineField.title],
                      ),
                      onChanged: _controller.setTitle,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    style: text.bodyLarge,
                    decoration: bareInputDecoration(
                      context,
                      hint: 'Add notes',
                      hintStyle: text.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    onChanged: _controller.setDescription,
                  ),
                  const SectionLabel('When'),
                  FormCard(
                    children: [
                      KeyedSubtree(
                        key: _fieldKeys[RoutineField.reminder],
                        child: Column(
                          children: [
                            FormRow(
                              icon: Icons.schedule_rounded,
                              label: 'Reminder',
                              value: values.reminderMinutes == null
                                  ? 'Anytime'
                                  : formatMinutesOfDay(values.reminderMinutes!),
                              error: form.errors[RoutineField.reminder],
                              onTap: () => _pickTime(values),
                              trailing: values.hasReminder
                                  ? IconButton(
                                      tooltip: 'Remove reminder',
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () =>
                                          _controller.setReminder(null),
                                    )
                                  : null,
                            ),
                            const Divider(),
                            FormRow(
                              icon: Icons.alarm_rounded,
                              label: 'Alarm',
                              subtitle: values.hasReminder
                                  ? 'Loud, alarm-style alert'
                                  : 'Set a reminder time first',
                              onTap: () =>
                                  _toggleAlarm(values, !values.alarmEnabled),
                              trailing: Switch(
                                value: values.alarmEnabled,
                                onChanged: (on) => _toggleAlarm(values, on),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      KeyedSubtree(
                        key: _fieldKeys[RoutineField.repeatDays],
                        child: FormRow(
                          icon: Icons.repeat_rounded,
                          label: 'Repeat',
                          value: repeatSummary(values.repeatDays),
                          error: form.errors[RoutineField.repeatDays],
                          onTap: () =>
                              showRepeatDaysSheet(context, widget.args),
                        ),
                      ),
                    ],
                  ),
                  const SectionLabel('Details'),
                  FormCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Priority', style: text.bodyLarge),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<Priority>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: Priority.low,
                                    label: Text('Low'),
                                  ),
                                  ButtonSegment(
                                    value: Priority.medium,
                                    label: Text('Medium'),
                                  ),
                                  ButtonSegment(
                                    value: Priority.high,
                                    label: Text('High'),
                                  ),
                                ],
                                selected: {values.priority},
                                onSelectionChanged: (s) =>
                                    _controller.setPriority(s.first),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Earns ${_coinsLabel(values.priority)} when done',
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      KeyedSubtree(
                        key: _fieldKeys[RoutineField.category],
                        child: FormRow(
                          icon: Icons.label_outline_rounded,
                          label: 'Category',
                          value: category?.title ?? 'General',
                          error: form.errors[RoutineField.category],
                          onTap: () => _pickCategory(values),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FormCard(
                    children: [
                      ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        expansionAnimationStyle: reduceMotion
                            ? AnimationStyle.noAnimation
                            : null,
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(
                          bottom: AppSpacing.lg,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        initiallyExpanded:
                            values.durationMinutes != null ||
                            values.snoozeMinutes != null ||
                            values.customReminderMessage.isNotEmpty,
                        title: Text('More options', style: text.bodyLarge),
                        children: [
                          Text('Duration', style: text.bodyLarge),
                          const SizedBox(height: AppSpacing.sm),
                          KeyedSubtree(
                            key: _fieldKeys[RoutineField.duration],
                            child: MinuteChips(
                              presets: _durationPresets,
                              selected: values.durationMinutes,
                              nullLabel: 'None',
                              labelFor: formatDuration,
                              onSelected: _controller.setDuration,
                            ),
                          ),
                          if (form.errors[RoutineField.duration] != null)
                            FieldError(form.errors[RoutineField.duration]!),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Reminder message', style: text.bodyLarge),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _message,
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 120,
                            decoration: const InputDecoration(
                              hintText: 'Shown in the notification',
                              counterText: '',
                            ),
                            onChanged: _controller.setCustomMessage,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Snooze for', style: text.bodyLarge),
                          const SizedBox(height: AppSpacing.sm),
                          KeyedSubtree(
                            key: _fieldKeys[RoutineField.snooze],
                            child: MinuteChips(
                              presets: _snoozePresets,
                              selected: values.snoozeMinutes,
                              nullLabel: 'Default',
                              labelFor: formatDuration,
                              onSelected: _controller.setSnooze,
                            ),
                          ),
                          if (form.errors[RoutineField.snooze] != null)
                            FieldError(form.errors[RoutineField.snooze]!),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: PrimaryActionButton(
                  label: form.saving
                      ? 'Saving…'
                      : (form.isEditing ? 'Save changes' : 'Add task'),
                  icon: form.isEditing
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  onPressed: _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _coinsLabel(Priority priority) {
    final coins = coinsForPriority(priority);
    return coins == 1 ? '1 coin' : '$coins coins';
  }
}
