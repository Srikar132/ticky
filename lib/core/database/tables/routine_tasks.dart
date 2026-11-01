import 'package:drift/drift.dart';

import '../enums.dart';
import 'categories.dart';

/// Permanent task configuration. Completion lives in `daily_task_records`.
@DataClassName('RoutineTask')
class RoutineTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 80)();
  TextColumn get description => text().nullable()();

  /// Local time of day as minutes from midnight (0-1439).
  /// Null means an "anytime" task with no reminder.
  IntColumn get reminderMinutes => integer().nullable().check(
    // ignore: recursive_getters
    reminderMinutes.isBetweenValues(0, 1439),
  )();

  /// Alarm-style reminder. Requires [reminderMinutes] (see [customConstraints]).
  BoolColumn get alarmEnabled => boolean().withDefault(const Constant(false))();

  /// Weekday bitmask, Mon = bit 0 ... Sun = bit 6. 127 means every day.
  IntColumn get repeatDays => integer()
      .withDefault(const Constant(127))
      // ignore: recursive_getters
      .check(repeatDays.isBetweenValues(1, 127))();

  TextColumn get priority =>
      textEnum<Priority>().withDefault(Constant(Priority.medium.name))();

  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.restrict)();

  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get customReminderMessage => text().nullable()();

  /// Per-task snooze length. Null falls back to the global setting.
  IntColumn get snoozeMinutes => integer().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (alarm_enabled = 0 OR reminder_minutes IS NOT NULL)',
  ];
}
