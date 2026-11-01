import 'package:drift/drift.dart';

import '../enums.dart';
import 'daily_task_records.dart';

/// Coin ledger. The balance is `SUM(amount) WHERE revoked_at IS NULL`.
///
/// Rows are revoked, never deleted. [uniqueKey] keeps every award idempotent:
/// `task:<recordId>`, `day:<dateKey>` or `unlock:<itemKey>`.
@DataClassName('RewardEvent')
class RewardEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uniqueKey => text().unique()();
  TextColumn get type => textEnum<RewardType>()();

  /// Positive for earnings, negative for [RewardType.spend].
  IntColumn get amount => integer()();

  IntColumn get dailyRecordId => integer().nullable().references(
    DailyTaskRecords,
    #id,
    onDelete: KeyAction.restrict,
  )();

  TextColumn get dateKey => text().nullable()();
  DateTimeColumn get revokedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    "CHECK (amount <> 0 AND ((type = 'spend') = (amount < 0)))",
  ];
}
