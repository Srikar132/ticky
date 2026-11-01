import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/rewards/data/reward_repository.dart';

/// A daily record plus the routine fields the checklist needs.
///
/// Title and time come from the record's snapshot; priority and category are
/// the routine's current values.
class DailyTaskEntry {
  const DailyTaskEntry({
    required this.record,
    required this.priority,
    required this.categoryId,
  });

  final DailyTaskRecord record;
  final Priority priority;
  final int categoryId;
}

/// Daily checklist records. Only today's records can be changed.
class DailyRecordRepository {
  DailyRecordRepository(this._db, this._rewards, this._clock);

  final AppDatabase _db;
  final RewardRepository _rewards;
  final Clock _clock;

  /// Records for [dateKey]: timed tasks by time, then "anytime" tasks.
  Stream<List<DailyTaskEntry>> watchForDate(String dateKey) =>
      _entries(dateKey).watch();

  Future<List<DailyTaskEntry>> getForDate(String dateKey) =>
      _entries(dateKey).get();

  /// Sets today's record to [status] and reconciles coins in one transaction.
  ///
  /// Only `pending`, `completed` and `skipped` can be set by the user;
  /// `missed` is assigned by the daily reconcile.
  /// Throws [ReadOnlyDayException] for any date other than today.
  Future<void> setStatus(int recordId, TaskStatus status) {
    if (status == TaskStatus.missed) {
      throw ArgumentError.value(status, 'status', 'missed is system-assigned');
    }
    return _db.transaction(() async {
      final record = await (_db.select(
        _db.dailyTaskRecords,
      )..where((r) => r.id.equals(recordId))).getSingleOrNull();
      if (record == null) {
        throw NotFoundException('Record $recordId not found');
      }
      final now = _clock();
      if (record.dateKey != dateKeyOf(now)) {
        throw const ReadOnlyDayException('Past days are read-only');
      }
      if (record.status == status) return;

      await (_db.update(
        _db.dailyTaskRecords,
      )..where((r) => r.id.equals(recordId))).write(
        DailyTaskRecordsCompanion(
          status: Value(status),
          completedAt: Value(
            status == TaskStatus.completed ? now.toUtc() : null,
          ),
          snoozedUntil: const Value(null),
        ),
      );
      await _rewards.reconcileRecord(recordId);
      await _rewards.reconcileDay(record.dateKey);
    });
  }

  /// One record, live. Emits null if it does not exist (for example a pending
  /// record removed when its routine was archived).
  Stream<DailyTaskRecord?> watchById(int recordId) {
    return (_db.select(
      _db.dailyTaskRecords,
    )..where((r) => r.id.equals(recordId))).watchSingleOrNull();
  }

  /// The record of [routineId] on [dateKey], or null. Notification taps use
  /// this: their payload carries the routine and the day, not the record.
  Future<DailyTaskRecord?> getByRoutineAndDate(int routineId, String dateKey) {
    return (_db.select(_db.dailyTaskRecords)..where(
          (r) => r.routineTaskId.equals(routineId) & r.dateKey.equals(dateKey),
        ))
        .getSingleOrNull();
  }

  Future<DailyTaskRecord?> getById(int recordId) {
    return (_db.select(
      _db.dailyTaskRecords,
    )..where((r) => r.id.equals(recordId))).getSingleOrNull();
  }

  /// Sets (or clears, with null) the snooze end of today's pending record.
  ///
  /// Throws [ReadOnlyDayException] for past days and
  /// [InvalidRecordStateException] when the record is not pending.
  Future<void> setSnoozedUntil(int recordId, DateTime? until) {
    return _db.transaction(() async {
      final record = await getById(recordId);
      if (record == null) {
        throw NotFoundException('Record $recordId not found');
      }
      if (record.dateKey != dateKeyOf(_clock())) {
        throw const ReadOnlyDayException('Past days are read-only');
      }
      if (record.status != TaskStatus.pending) {
        throw const InvalidRecordStateException('Only pending tasks snooze');
      }
      await (_db.update(
        _db.dailyTaskRecords,
      )..where((r) => r.id.equals(recordId))).write(
        DailyTaskRecordsCompanion(snoozedUntil: Value(until?.toUtc())),
      );
    });
  }

  Selectable<DailyTaskEntry> _entries(String dateKey) {
    final records = _db.dailyTaskRecords;
    final routines = _db.routineTasks;
    final query =
        _db.select(records).join([
            innerJoin(routines, routines.id.equalsExp(records.routineTaskId)),
          ])
          ..where(records.dateKey.equals(dateKey))
          ..orderBy([
            OrderingTerm.asc(records.scheduledMinutes.isNull()),
            OrderingTerm.asc(records.scheduledMinutes),
            OrderingTerm.asc(routines.sortOrder),
            OrderingTerm.asc(records.id),
          ]);
    return query.map(
      (row) => DailyTaskEntry(
        record: row.readTable(records),
        priority: row.readTable(routines).priority,
        categoryId: row.readTable(routines).categoryId,
      ),
    );
  }
}
