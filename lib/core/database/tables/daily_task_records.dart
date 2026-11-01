import 'package:drift/drift.dart';

import '../enums.dart';
import 'routine_tasks.dart';

/// One row per routine per scheduled local date.
///
/// Title and time are snapshots, so editing a routine never rewrites history.
@DataClassName('DailyTaskRecord')
@TableIndex(name: 'daily_task_records_date', columns: {#dateKey})
@TableIndex(
  name: 'daily_task_records_date_status',
  columns: {#dateKey, #status},
)
class DailyTaskRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get routineTaskId =>
      integer().references(RoutineTasks, #id, onDelete: KeyAction.restrict)();

  /// Local calendar date, `yyyy-MM-dd`. Never a DateTime.
  TextColumn get dateKey => text().withLength(min: 10, max: 10)();

  TextColumn get titleSnapshot => text()();

  /// Snapshot of the routine's `reminderMinutes`.
  IntColumn get scheduledMinutes => integer().nullable()();

  TextColumn get status =>
      textEnum<TaskStatus>().withDefault(Constant(TaskStatus.pending.name))();

  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {routineTaskId, dateKey},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK ((status = 'completed') = (completed_at IS NOT NULL))",
  ];
}
