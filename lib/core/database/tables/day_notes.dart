import 'package:drift/drift.dart';

/// One markdown notebook per local date: the user's own goals and notes for
/// the day ("Today's focus"). Separate from routines, so it never touches
/// streaks, coins or the checklist.
@DataClassName('DayNote')
class DayNotes extends Table {
  /// Local calendar date, `yyyy-MM-dd`. Never a DateTime.
  TextColumn get dateKey => text().withLength(min: 10, max: 10)();

  /// Markdown, one block per line. A day with nothing written has no row.
  TextColumn get body => text()();

  /// UTC instant of the last save.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {dateKey};
}
