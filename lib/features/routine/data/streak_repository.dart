import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/features/routine/models/streak.dart';

/// Derives the streak from daily records. Nothing is stored.
class StreakRepository {
  StreakRepository(this._db);

  final AppDatabase _db;

  Future<StreakInfo> getCurrent(String todayKey) async {
    return computeStreak(await _tallies(todayKey).get(), todayKey);
  }

  /// Re-emits whenever a daily record changes.
  Stream<StreakInfo> watchCurrent(String todayKey) {
    return _tallies(
      todayKey,
    ).watch().map((tallies) => computeStreak(tallies, todayKey));
  }

  Selectable<DayTally> _tallies(String todayKey) {
    return _db
        .customSelect(
          'SELECT date_key, '
          "SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed, "
          "SUM(CASE WHEN status IN ('pending', 'missed') THEN 1 ELSE 0 END) "
          'AS open '
          'FROM daily_task_records WHERE date_key <= ? GROUP BY date_key',
          variables: [Variable.withString(todayKey)],
          readsFrom: {_db.dailyTaskRecords},
        )
        .map(
          (row) => DayTally(
            dateKey: row.read<String>('date_key'),
            completed: row.read<int>('completed'),
            open: row.read<int>('open'),
          ),
        );
  }
}
