import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';

/// Today's progress. Skipped tasks do not count against the day, matching the
/// streak and perfect-day rules.
class DailyProgress {
  const DailyProgress({
    required this.total,
    required this.completed,
    required this.skipped,
  });

  factory DailyProgress.fromEntries(List<DailyTaskEntry> entries) {
    var completed = 0;
    var skipped = 0;
    for (final entry in entries) {
      switch (entry.record.status) {
        case TaskStatus.completed:
          completed++;
        case TaskStatus.skipped:
          skipped++;
        case TaskStatus.pending:
        case TaskStatus.missed:
          break;
      }
    }
    return DailyProgress(
      total: entries.length,
      completed: completed,
      skipped: skipped,
    );
  }

  static const empty = DailyProgress(total: 0, completed: 0, skipped: 0);

  final int total;
  final int completed;
  final int skipped;

  /// Tasks that can still be completed (everything except skipped).
  int get target => total - skipped;

  /// Tasks still to do.
  int get remaining => target - completed;

  double get fraction => target <= 0 ? 0 : completed / target;

  bool get isEmpty => total == 0;

  /// Everything is completed or skipped, with at least one completed.
  bool get allDone => target > 0 && completed == target;

  /// Nothing to do because everything was skipped.
  bool get allSkipped => total > 0 && target == 0;
}

/// A pending timed task whose time has passed.
bool isOverdue(DailyTaskEntry entry, DateTime now) {
  final scheduled = entry.record.scheduledMinutes;
  return entry.record.status == TaskStatus.pending &&
      scheduled != null &&
      scheduled < minutesOfDay(now);
}

bool hasOverdue(List<DailyTaskEntry> entries, DateTime now) =>
    entries.any((e) => isOverdue(e, now));

/// A pending timed task coming up within [within] minutes.
bool hasDueSoon(List<DailyTaskEntry> entries, DateTime now, {int within = 30}) {
  final current = minutesOfDay(now);
  return entries.any((e) {
    final scheduled = e.record.scheduledMinutes;
    return e.record.status == TaskStatus.pending &&
        scheduled != null &&
        scheduled >= current &&
        scheduled - current <= within;
  });
}
