import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/date_keys.dart';

/// Editable routine fields, as entered on the Add/Edit Task screen.
class RoutineDraft {
  const RoutineDraft({
    required this.title,
    required this.categoryId,
    this.description,
    this.reminderMinutes,
    this.alarmEnabled = false,
    this.repeatDays = everyDay,
    this.priority = Priority.medium,
    this.durationMinutes,
    this.customReminderMessage,
    this.snoozeMinutes,
  });

  final String title;
  final int categoryId;
  final String? description;

  /// Minutes from midnight (0-1439). Null means an "anytime" task.
  final int? reminderMinutes;
  final bool alarmEnabled;

  /// Weekday bitmask, Mon = bit 0 ... Sun = bit 6.
  final int repeatDays;
  final Priority priority;
  final int? durationMinutes;
  final String? customReminderMessage;
  final int? snoozeMinutes;

  String get trimmedTitle => title.trim();
  String? get normalizedDescription => _blankToNull(description);
  String? get normalizedReminderMessage => _blankToNull(customReminderMessage);

  /// Throws [InvalidRoutineException] when a domain rule is broken.
  void validate() {
    final length = trimmedTitle.length;
    if (length < 1 || length > 80) {
      throw const InvalidRoutineException(
        'Title must be 1-80 characters',
        field: RoutineField.title,
      );
    }
    final minutes = reminderMinutes;
    if (minutes != null && (minutes < 0 || minutes > 1439)) {
      throw const InvalidRoutineException(
        'Reminder time must be within a day',
        field: RoutineField.reminder,
      );
    }
    if (alarmEnabled && minutes == null) {
      throw const InvalidRoutineException(
        'An alarm needs a reminder time',
        field: RoutineField.reminder,
      );
    }
    if (repeatDays < 1 || repeatDays > everyDay) {
      throw const InvalidRoutineException(
        'Pick at least one repeat day',
        field: RoutineField.repeatDays,
      );
    }
    if (durationMinutes != null && durationMinutes! <= 0) {
      throw const InvalidRoutineException(
        'Duration must be positive',
        field: RoutineField.duration,
      );
    }
    if (snoozeMinutes != null && snoozeMinutes! <= 0) {
      throw const InvalidRoutineException(
        'Snooze must be positive',
        field: RoutineField.snooze,
      );
    }
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
