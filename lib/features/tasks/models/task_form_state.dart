import 'package:flutter/foundation.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';

/// Which task the form works on. Equality makes it a stable provider key.
@immutable
class TaskFormArgs {
  const TaskFormArgs({this.routineId, this.suggestion});

  /// The routine being edited. Null when adding a task.
  final int? routineId;

  /// Pre-fills a new task. Ignored when editing.
  final TaskSuggestion? suggestion;

  @override
  bool operator ==(Object other) =>
      other is TaskFormArgs &&
      other.routineId == routineId &&
      other.suggestion == suggestion;

  @override
  int get hashCode => Object.hash(routineId, suggestion);
}

const _keep = Object();

/// Everything the user can type or pick on the form. Plain values with
/// equality, so "did anything change?" is a simple comparison.
@immutable
class TaskFormValues {
  const TaskFormValues({
    required this.categoryId,
    this.title = '',
    this.description = '',
    this.reminderMinutes,
    this.alarmEnabled = false,
    this.repeatDays = everyDay,
    this.priority = Priority.medium,
    this.durationMinutes,
    this.customReminderMessage = '',
    this.snoozeMinutes,
  });

  final String title;
  final String description;

  /// Minutes from midnight. Null means an "anytime" task.
  final int? reminderMinutes;
  final bool alarmEnabled;
  final int repeatDays;
  final Priority priority;
  final int categoryId;
  final int? durationMinutes;
  final String customReminderMessage;

  /// Null means "use the global default".
  final int? snoozeMinutes;

  bool get hasReminder => reminderMinutes != null;

  /// The domain object the repository validates and stores.
  RoutineDraft toDraft() => RoutineDraft(
    title: title,
    categoryId: categoryId,
    description: description,
    reminderMinutes: reminderMinutes,
    alarmEnabled: alarmEnabled,
    repeatDays: repeatDays,
    priority: priority,
    durationMinutes: durationMinutes,
    customReminderMessage: customReminderMessage,
    snoozeMinutes: snoozeMinutes,
  );

  /// Nullable fields use [Object?] so passing `null` clears them while
  /// leaving the argument out keeps the current value.
  TaskFormValues copyWith({
    String? title,
    String? description,
    Object? reminderMinutes = _keep,
    bool? alarmEnabled,
    int? repeatDays,
    Priority? priority,
    int? categoryId,
    Object? durationMinutes = _keep,
    String? customReminderMessage,
    Object? snoozeMinutes = _keep,
  }) {
    return TaskFormValues(
      title: title ?? this.title,
      description: description ?? this.description,
      reminderMinutes: identical(reminderMinutes, _keep)
          ? this.reminderMinutes
          : reminderMinutes as int?,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      repeatDays: repeatDays ?? this.repeatDays,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      durationMinutes: identical(durationMinutes, _keep)
          ? this.durationMinutes
          : durationMinutes as int?,
      customReminderMessage:
          customReminderMessage ?? this.customReminderMessage,
      snoozeMinutes: identical(snoozeMinutes, _keep)
          ? this.snoozeMinutes
          : snoozeMinutes as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TaskFormValues &&
      other.title == title &&
      other.description == description &&
      other.reminderMinutes == reminderMinutes &&
      other.alarmEnabled == alarmEnabled &&
      other.repeatDays == repeatDays &&
      other.priority == priority &&
      other.categoryId == categoryId &&
      other.durationMinutes == durationMinutes &&
      other.customReminderMessage == customReminderMessage &&
      other.snoozeMinutes == snoozeMinutes;

  @override
  int get hashCode => Object.hash(
    title,
    description,
    reminderMinutes,
    alarmEnabled,
    repeatDays,
    priority,
    categoryId,
    durationMinutes,
    customReminderMessage,
    snoozeMinutes,
  );
}

/// The form as the screen sees it.
@immutable
class TaskFormState {
  const TaskFormState({
    required this.values,
    required this.initial,
    required this.isEditing,
    this.saving = false,
    this.errors = const {},
    this.message,
  });

  final TaskFormValues values;

  /// What the form started with, to tell whether there are unsaved changes.
  final TaskFormValues initial;
  final bool isEditing;
  final bool saving;

  /// Validation messages by field, shown next to the input.
  final Map<RoutineField, String> errors;

  /// A problem that belongs to no single field (the routine vanished...).
  final String? message;

  bool get isDirty => values != initial;

  TaskFormState copyWith({
    TaskFormValues? values,
    TaskFormValues? initial,
    bool? saving,
    Map<RoutineField, String>? errors,
    Object? message = _keep,
  }) {
    return TaskFormState(
      values: values ?? this.values,
      initial: initial ?? this.initial,
      isEditing: isEditing,
      saving: saving ?? this.saving,
      errors: errors ?? this.errors,
      message: identical(message, _keep) ? this.message : message as String?,
    );
  }
}

/// How [TaskFormController.save] ended.
enum TaskSaveResult {
  /// The form has a problem; see [TaskFormState.errors] and `message`.
  invalid,

  /// Saved.
  saved,

  /// Saved, but a reminder was set while notifications are blocked, so the
  /// screen should offer the permission sheet.
  savedNeedsPermission,
}
