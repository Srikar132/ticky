import 'package:drift/drift.dart';

/// Mascot items the user has bought. The item catalog itself lives in code.
@DataClassName('UnlockedItem')
class UnlockedItems extends Table {
  TextColumn get itemKey => text()();
  DateTimeColumn get unlockedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {itemKey};
}
