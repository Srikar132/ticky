import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/rewards/data/reward_repository.dart';
import 'package:ticky/features/settings/data/settings_repository.dart';

/// Daily reset. Generates the checklist for the current local date.
///
/// Idempotent: safe to run on every app start and resume. Never deletes
/// routine configuration or past records.
class DailyReconciler {
  DailyReconciler(this._db, this._settings, this._rewards);

  final AppDatabase _db;
  final SettingsRepository _settings;
  final RewardRepository _rewards;

  /// Gap days older than this are not backfilled.
  static const maxBackfillDays = 30;

  /// Brings the database up to date for the local date of [now].
  ///
  /// 1. Past `pending` records become `missed`.
  /// 2. Days the app was not opened (since the last reconcile) are backfilled
  ///    as `missed`, for scheduled routines only, capped at [maxBackfillDays]
  ///    and never before a routine's creation.
  /// 3. Today's missing records are created (insert-or-ignore, with snapshots).
  /// 4. The perfect-day bonus for today is re-evaluated.
  /// 5. `lastReconciledDateKey` is stored.
  ///
  /// Scheduling notifications is the notification service's job, not this one.
  Future<void> reconcile(DateTime now) {
    return _db.transaction(() async {
      final today = dateKeyOf(now);
      final lastReconciled = await _settings.getLastReconciledDateKey();

      await (_db.update(_db.dailyTaskRecords)..where(
            (r) =>
                r.dateKey.isSmallerThanValue(today) &
                r.status.equalsValue(TaskStatus.pending),
          ))
          .write(
            const DailyTaskRecordsCompanion(status: Value(TaskStatus.missed)),
          );

      final routines = await (_db.select(
        _db.routineTasks,
      )..where((t) => t.archivedAt.isNull() & t.isEnabled.equals(true))).get();

      if (lastReconciled != null) {
        await _backfillGapDays(
          routines,
          first: addDaysToKey(lastReconciled, 1),
          last: addDaysToKey(today, -1),
          today: today,
        );
      }

      await _insertRecords(
        routines.where((r) => isScheduledOn(r.repeatDays, now)),
        today,
        TaskStatus.pending,
      );
      await _rewards.reconcileDay(today);
      await _settings.setLastReconciledDateKey(today);
    });
  }

  /// Aligns today's record for one routine with its configuration.
  ///
  /// Call after creating, editing, enabling, disabling or archiving a routine.
  /// - Routine runs today: ensure the record exists, refresh a pending
  ///   record's snapshot (title, time). Completed/skipped records are kept.
  /// - Routine does not run today any more: drop a still-pending record so it
  ///   cannot turn into a `missed` day (and break the streak) tomorrow.
  Future<void> syncRoutineForToday(int routineId, DateTime now) {
    return _db.transaction(() async {
      final routine = await (_db.select(
        _db.routineTasks,
      )..where((t) => t.id.equals(routineId))).getSingleOrNull();
      if (routine == null) return;

      final today = dateKeyOf(now);
      final records = _db.dailyTaskRecords;
      final pendingToday = (_db.update(records)
        ..where(
          (r) =>
              r.routineTaskId.equals(routineId) &
              r.dateKey.equals(today) &
              r.status.equalsValue(TaskStatus.pending),
        ));

      final runsToday =
          routine.isEnabled &&
          routine.archivedAt == null &&
          isScheduledOn(routine.repeatDays, now);

      if (runsToday) {
        await _insertRecords([routine], today, TaskStatus.pending);
        await pendingToday.write(
          DailyTaskRecordsCompanion(
            titleSnapshot: Value(routine.title),
            scheduledMinutes: Value(routine.reminderMinutes),
          ),
        );
      } else {
        await (_db.delete(records)..where(
              (r) =>
                  r.routineTaskId.equals(routineId) &
                  r.dateKey.equals(today) &
                  r.status.equalsValue(TaskStatus.pending),
            ))
            .go();
      }
      await _rewards.reconcileDay(today);
    });
  }

  Future<void> _backfillGapDays(
    List<RoutineTask> routines, {
    required String first,
    required String last,
    required String today,
  }) async {
    final earliest = addDaysToKey(today, -maxBackfillDays);
    final start = first.compareTo(earliest) < 0 ? earliest : first;

    for (final routine in routines) {
      final created = dateKeyOf(routine.createdAt.toLocal());
      var day = start.compareTo(created) < 0 ? created : start;
      final missedDays = <String>[];
      while (day.compareTo(last) <= 0) {
        if (isScheduledOn(routine.repeatDays, parseDateKey(day))) {
          missedDays.add(day);
        }
        day = addDaysToKey(day, 1);
      }
      for (final dateKey in missedDays) {
        await _insertRecords([routine], dateKey, TaskStatus.missed);
      }
    }
  }

  Future<void> _insertRecords(
    Iterable<RoutineTask> routines,
    String dateKey,
    TaskStatus status,
  ) async {
    if (routines.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(_db.dailyTaskRecords, [
        for (final routine in routines)
          DailyTaskRecordsCompanion.insert(
            routineTaskId: routine.id,
            dateKey: dateKey,
            titleSnapshot: routine.title,
            scheduledMinutes: Value(routine.reminderMinutes),
            status: Value(status),
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }
}
