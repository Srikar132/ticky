import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';

/// One daily record seen together with its routine, and what the user may do
/// with it. Pure, so the rules are easy to test.
///
/// Only today's record can be changed; every other day is read-only history.
class TaskDetails {
  const TaskDetails({
    required this.record,
    required this.routine,
    required this.todayKey,
  });

  final DailyTaskRecord record;

  /// The routine behind the record. Null only if its row is missing.
  final RoutineTask? routine;
  final String todayKey;

  TaskStatus get status => record.status;

  bool get isToday => record.dateKey == todayKey;

  /// The routine can be edited or deleted only while it is not archived.
  bool get routineIsActive => routine != null && routine!.archivedAt == null;

  bool get canEdit => routineIsActive;
  bool get canDelete => routineIsActive;

  /// Complete, skip or undo: today's record only.
  bool get canChangeStatus => isToday;

  /// A reminder can be snoozed while the task is pending and has a time.
  bool get canSnooze =>
      isToday &&
      status == TaskStatus.pending &&
      record.scheduledMinutes != null;

  /// When a running snooze ends, or null when none is active at [now].
  DateTime? activeSnoozeEnd(DateTime now) {
    final until = record.snoozedUntil?.toLocal();
    if (!isToday || status != TaskStatus.pending) return null;
    return until != null && until.isAfter(now) ? until : null;
  }
}
