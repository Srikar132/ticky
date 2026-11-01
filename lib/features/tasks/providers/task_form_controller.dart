import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/features/categories/providers/category_providers.dart';
import 'package:ticky/features/tasks/models/task_form_state.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

/// Where the time picker starts when the task has no time yet: the next full
/// hour.
int suggestedReminderMinutes(DateTime now) => ((now.hour + 1) % 24) * 60;

/// Holds and validates the Add/Edit Task form. The screen only shows
/// [TaskFormState] and forwards what the user does.
///
/// Validation rules live in `RoutineDraft`; this class only keeps the form
/// consistent (no alarm without a time) and turns repository errors into
/// per-field messages. Saving goes through `RoutineRepository`, which also
/// aligns today's checklist; reminders are re-synced by the coordinator.
class TaskFormController extends AsyncNotifier<TaskFormState> {
  TaskFormController(this.args);

  final TaskFormArgs args;

  bool get _isEditing => args.routineId != null;

  @override
  FutureOr<TaskFormState> build() {
    // Riverpod 3 pauses a stream provider nobody listens to, so a plain
    // `read(...future)` would wait forever for its first value. Listening
    // (without rebuilding) keeps it running while this form is open.
    ref.listen(activeCategoriesProvider, (_, _) {});

    // A new task needs nothing but the categories. If Home already loaded
    // them, answer right now, so the page opens with its form already there
    // instead of flashing an empty frame first.
    final loaded = ref.read(activeCategoriesProvider).value;
    if (loaded != null && !_isEditing) return _newTask(loaded);
    return _load();
  }

  Category _general(List<Category> categories) => categories.firstWhere(
    (c) => c.key == generalCategoryKey,
    orElse: () => categories.first,
  );

  TaskFormState _newTask(List<Category> categories) {
    final suggestion = args.suggestion;
    final values = TaskFormValues(
      categoryId: _general(categories).id,
      title: suggestion?.title ?? '',
      reminderMinutes: suggestion?.reminderMinutes,
    );
    return TaskFormState(values: values, initial: values, isEditing: false);
  }

  Future<TaskFormState> _load() async {
    final categories = await ref.read(activeCategoriesProvider.future);
    if (!_isEditing) return _newTask(categories);

    final general = _general(categories);
    final routine = await ref
        .read(routineRepositoryProvider)
        .getById(args.routineId!);
    if (routine == null || routine.archivedAt != null) {
      throw const NotFoundException('This task no longer exists');
    }
    // A category archived behind our back falls back to General.
    final categoryUsable = categories.any((c) => c.id == routine.categoryId);
    final values = TaskFormValues(
      title: routine.title,
      description: routine.description ?? '',
      reminderMinutes: routine.reminderMinutes,
      alarmEnabled: routine.alarmEnabled,
      repeatDays: routine.repeatDays,
      priority: routine.priority,
      categoryId: categoryUsable ? routine.categoryId : general.id,
      durationMinutes: routine.durationMinutes,
      customReminderMessage: routine.customReminderMessage ?? '',
      snoozeMinutes: routine.snoozeMinutes,
    );
    return TaskFormState(values: values, initial: values, isEditing: true);
  }

  /// Applies [change], and forgets the errors of the fields it touches.
  void _edit(
    TaskFormValues Function(TaskFormValues) change, {
    Set<RoutineField> clears = const {},
  }) {
    final current = state.value;
    if (current == null || current.saving) return;
    state = AsyncData(
      current.copyWith(
        values: change(current.values),
        errors: {
          for (final e in current.errors.entries)
            if (!clears.contains(e.key)) e.key: e.value,
        },
        message: null,
      ),
    );
  }

  void setTitle(String value) =>
      _edit((v) => v.copyWith(title: value), clears: {RoutineField.title});

  void setDescription(String value) =>
      _edit((v) => v.copyWith(description: value));

  void setCustomMessage(String value) =>
      _edit((v) => v.copyWith(customReminderMessage: value));

  /// Sets the reminder time, or clears it with null (an "anytime" task).
  /// Clearing the time also turns the alarm off, since an alarm needs a time.
  void setReminder(int? minutes) => _edit(
    (v) => v.copyWith(
      reminderMinutes: minutes,
      alarmEnabled: minutes == null ? false : v.alarmEnabled,
    ),
    clears: {RoutineField.reminder},
  );

  /// Turns the alarm on or off. Returns false when asked to turn it on while
  /// the task has no reminder time; the caller should ask for a time first.
  bool setAlarm(bool enabled) {
    final current = state.value;
    if (current == null || current.saving) return false;
    if (enabled && !current.values.hasReminder) return false;
    _edit(
      (v) => v.copyWith(alarmEnabled: enabled),
      clears: {RoutineField.reminder},
    );
    return true;
  }

  /// Replaces the whole weekday mask (the quick picks).
  void setRepeatDays(int mask) => _edit(
    (v) => v.copyWith(repeatDays: mask),
    clears: {RoutineField.repeatDays},
  );

  /// Flips one weekday, 0 = Monday ... 6 = Sunday.
  void toggleDay(int weekdayIndex) {
    final current = state.value;
    if (current == null) return;
    setRepeatDays(current.values.repeatDays ^ (1 << weekdayIndex));
  }

  void setPriority(Priority value) => _edit((v) => v.copyWith(priority: value));

  void setCategory(int categoryId) => _edit(
    (v) => v.copyWith(categoryId: categoryId),
    clears: {RoutineField.category},
  );

  void setDuration(int? minutes) => _edit(
    (v) => v.copyWith(durationMinutes: minutes),
    clears: {RoutineField.duration},
  );

  /// Null means "use the default snooze from Settings".
  void setSnooze(int? minutes) => _edit(
    (v) => v.copyWith(snoozeMinutes: minutes),
    clears: {RoutineField.snooze},
  );

  /// Validates and stores the task.
  Future<TaskSaveResult> save() async {
    final current = state.value;
    if (current == null || current.saving) return TaskSaveResult.invalid;
    final values = current.values;
    state = AsyncData(
      current.copyWith(saving: true, errors: const {}, message: null),
    );

    try {
      final routines = ref.read(routineRepositoryProvider);
      final draft = values.toDraft();
      if (_isEditing) {
        await routines.update(args.routineId!, draft);
      } else {
        await routines.create(draft);
      }
    } on InvalidRoutineException catch (error) {
      final field = error.field;
      state = AsyncData(
        current.copyWith(
          saving: false,
          errors: field == null ? const {} : {field: error.message},
          message: field == null ? error.message : null,
        ),
      );
      return TaskSaveResult.invalid;
    } on NotFoundException catch (error) {
      state = AsyncData(
        current.copyWith(saving: false, message: error.message),
      );
      return TaskSaveResult.invalid;
    }

    final askForPermission = await _needsPermissionPrompt(current, values);
    state = AsyncData(
      current.copyWith(
        values: values,
        initial: values,
        saving: false,
        errors: const {},
        message: null,
      ),
    );
    return askForPermission
        ? TaskSaveResult.savedNeedsPermission
        : TaskSaveResult.saved;
  }

  /// Only a reminder the user just set or changed is worth interrupting for.
  /// The task is already saved, so a failure here must not undo it.
  Future<bool> _needsPermissionPrompt(
    TaskFormState before,
    TaskFormValues saved,
  ) async {
    final minutes = saved.reminderMinutes;
    if (minutes == null) return false;
    if (before.isEditing && minutes == before.initial.reminderMinutes) {
      return false;
    }
    try {
      final status = await ref
          .read(notificationServiceProvider)
          .getPermissionStatus();
      return !status.notificationsAllowed;
    } on Exception {
      return false;
    }
  }
}

/// No automatic retry: a task that is gone will not come back by asking again.
final taskFormControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TaskFormController, TaskFormState, TaskFormArgs>(
      TaskFormController.new,
      retry: (_, _) => null,
    );
