import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/date_keys.dart';

/// How long after midnight the previous day can still be saved. Someone
/// writing at 23:59 must not lose their last edit to a save that lands at
/// 00:01.
const focusMidnightGrace = Duration(hours: 2);

/// How far back "bring yesterday over" looks for the last written day.
const focusCarryLookbackDays = 7;

/// Reads and writes the markdown notebook of each day ("Today's focus").
///
/// Only today is writable (plus the short [focusMidnightGrace] after
/// midnight). A day with nothing written has no row.
class FocusRepository {
  FocusRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// The saved markdown of [dateKey], or `''` when nothing was written.
  Future<String> getBody(String dateKey) async {
    final row = await (_db.select(
      _db.dayNotes,
    )..where((n) => n.dateKey.equals(dateKey))).getSingleOrNull();
    return row?.body ?? '';
  }

  /// The day's markdown, live. Emits `''` for a day with nothing written.
  Stream<String> watchBody(String dateKey) {
    return (_db.select(_db.dayNotes)..where((n) => n.dateKey.equals(dateKey)))
        .watchSingleOrNull()
        .map((row) => row?.body ?? '');
  }

  /// The most recent written day before [dateKey], within
  /// [focusCarryLookbackDays], or null.
  Future<DayNote?> latestBefore(String dateKey) {
    final oldest = addDaysToKey(dateKey, -focusCarryLookbackDays);
    return (_db.select(_db.dayNotes)
          ..where(
            (n) =>
                n.dateKey.isSmallerThanValue(dateKey) &
                n.dateKey.isBiggerOrEqualValue(oldest),
          )
          ..orderBy([(n) => OrderingTerm.desc(n.dateKey)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Days that have a note, among [dateKeys]. For history.
  Future<Set<String>> daysWithNotes(Iterable<String> dateKeys) async {
    final rows = await (_db.select(
      _db.dayNotes,
    )..where((n) => n.dateKey.isIn(dateKeys))).get();
    return {for (final row in rows) row.dateKey};
  }

  /// Saves [body] for [dateKey]. A blank body removes the row, so an empty day
  /// leaves no trace. Throws [ReadOnlyDayException] for a past day.
  Future<void> save(String dateKey, String body) async {
    if (!_isWritable(dateKey)) {
      throw const ReadOnlyDayException('Past days are read-only');
    }
    if (body.trim().isEmpty) {
      await (_db.delete(
        _db.dayNotes,
      )..where((n) => n.dateKey.equals(dateKey))).go();
      return;
    }
    await _db
        .into(_db.dayNotes)
        .insertOnConflictUpdate(
          DayNotesCompanion.insert(
            dateKey: dateKey,
            body: body,
            updatedAt: Value(_clock().toUtc()),
          ),
        );
  }

  bool _isWritable(String dateKey) {
    final now = _clock();
    final today = dateKeyOf(now);
    if (dateKey == today) return true;
    final sinceMidnight = now.difference(
      DateTime(now.year, now.month, now.day),
    );
    return dateKey == addDaysToKey(today, -1) &&
        sinceMidnight < focusMidnightGrace;
  }
}
