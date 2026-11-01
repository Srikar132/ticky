import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';

/// How one past day went. Derived from the daily records by query, never
/// stored, so editing a routine later cannot change it (records keep their
/// own snapshots).
class DaySummary {
  const DaySummary({
    required this.dateKey,
    required this.completed,
    required this.skipped,
    required this.missed,
    required this.pending,
  });

  final String dateKey;
  final int completed;
  final int skipped;
  final int missed;
  final int pending;

  int get total => completed + skipped + missed + pending;

  /// Every task was completed or skipped, and at least one was completed:
  /// the same rule as the perfect-day bonus.
  bool get isPerfect => completed > 0 && missed == 0 && pending == 0;

  /// Tasks that were left undone.
  int get undone => missed + pending;
}

/// Read-only history of past days. Today is never included: it lives on Home
/// and can still change.
class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  /// Days before [todayKey] that have at least one record, newest first.
  Stream<List<DaySummary>> watchPastDays(String todayKey, {int limit = 30}) {
    final records = _db.dailyTaskRecords;
    int countOf(TypedResult row, Expression<int> column) =>
        row.read(column) ?? 0;

    final completed = records.id.count(
      filter: records.status.equalsValue(TaskStatus.completed),
    );
    final skipped = records.id.count(
      filter: records.status.equalsValue(TaskStatus.skipped),
    );
    final missed = records.id.count(
      filter: records.status.equalsValue(TaskStatus.missed),
    );
    final pending = records.id.count(
      filter: records.status.equalsValue(TaskStatus.pending),
    );

    final query = _db.selectOnly(records)
      ..addColumns([records.dateKey, completed, skipped, missed, pending])
      ..where(records.dateKey.isSmallerThanValue(todayKey))
      ..groupBy([records.dateKey])
      ..orderBy([OrderingTerm.desc(records.dateKey)])
      ..limit(limit);

    return query.watch().map(
      (rows) => [
        for (final row in rows)
          DaySummary(
            dateKey: row.read(records.dateKey)!,
            completed: countOf(row, completed),
            skipped: countOf(row, skipped),
            missed: countOf(row, missed),
            pending: countOf(row, pending),
          ),
      ],
    );
  }
}
