import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/rewards/data/reward_config.dart';

/// Coin ledger access.
///
/// The balance is always derived (`SUM(amount) WHERE revokedAt IS NULL`).
/// Earnings are reconciled, never blindly inserted: every call moves the
/// ledger to match the current record statuses, so repeating it is harmless
/// and check/uncheck cannot farm coins.
class RewardRepository {
  RewardRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Displayed balance, clamped to 0 (see "known edge" in AGENTS.md 8.4).
  Future<int> getBalance() async => _clamp(await _rawBalance().getSingle());

  Stream<int> watchBalance() => _rawBalance().watchSingle().map(_clamp);

  Stream<Set<String>> watchUnlockedItemKeys() {
    return _db
        .select(_db.unlockedItems)
        .watch()
        .map((rows) => {for (final row in rows) row.itemKey});
  }

  Future<Set<String>> getUnlockedItemKeys() async {
    final rows = await _db.select(_db.unlockedItems).get();
    return {for (final row in rows) row.itemKey};
  }

  /// Buys [itemKey] for [price] coins.
  ///
  /// The balance check and the ledger insert share one transaction. The raw
  /// (unclamped) balance is checked, so a negative balance blocks spending.
  Future<void> unlockItem(String itemKey, int price) {
    if (price <= 0) throw ArgumentError.value(price, 'price', 'must be > 0');
    return _db.transaction(() async {
      final owned = await (_db.select(
        _db.unlockedItems,
      )..where((i) => i.itemKey.equals(itemKey))).getSingleOrNull();
      if (owned != null) {
        throw ItemAlreadyUnlockedException('$itemKey is already unlocked');
      }
      if (await _rawBalance().getSingle() < price) {
        throw InsufficientCoinsException('Not enough coins for $itemKey');
      }
      final now = _clock().toUtc();
      await _db
          .into(_db.rewardEvents)
          .insert(
            RewardEventsCompanion.insert(
              uniqueKey: 'unlock:$itemKey',
              type: RewardType.spend,
              amount: -price,
              createdAt: Value(now),
            ),
          );
      await _db
          .into(_db.unlockedItems)
          .insert(
            UnlockedItemsCompanion.insert(
              itemKey: itemKey,
              unlockedAt: Value(now),
            ),
          );
    });
  }

  /// Moves the `task:<id>` reward to match the record's current status.
  ///
  /// Call in the same transaction as the status change.
  Future<void> reconcileRecord(int recordId) {
    return _db.transaction(() async {
      final records = _db.dailyTaskRecords;
      final routines = _db.routineTasks;
      final row = await (_db.select(records).join([
        innerJoin(routines, routines.id.equalsExp(records.routineTaskId)),
      ])..where(records.id.equals(recordId))).getSingleOrNull();
      if (row == null) return;

      final record = row.readTable(records);
      final priority = row.readTable(routines).priority;
      await _reconcileEvent(
        uniqueKey: 'task:${record.id}',
        shouldHold: record.status == TaskStatus.completed,
        type: RewardType.taskComplete,
        amount: coinsForPriority(priority),
        dailyRecordId: record.id,
        dateKey: record.dateKey,
      );
    });
  }

  /// Moves the `day:<dateKey>` perfect-day bonus to match that day's records.
  ///
  /// Holds when there is at least one completed record and every other record
  /// is skipped. Call after any status change or record insert/delete.
  Future<void> reconcileDay(String dateKey) {
    return _db.transaction(() async {
      final statuses = await (_db.select(
        _db.dailyTaskRecords,
      )..where((r) => r.dateKey.equals(dateKey))).map((r) => r.status).get();
      final perfect =
          statuses.contains(TaskStatus.completed) &&
          !statuses.contains(TaskStatus.pending) &&
          !statuses.contains(TaskStatus.missed);
      await _reconcileEvent(
        uniqueKey: 'day:$dateKey',
        shouldHold: perfect,
        type: RewardType.perfectDay,
        amount: perfectDayBonus,
        dateKey: dateKey,
      );
    });
  }

  Future<void> _reconcileEvent({
    required String uniqueKey,
    required bool shouldHold,
    required RewardType type,
    required int amount,
    int? dailyRecordId,
    String? dateKey,
  }) async {
    final existing = await (_db.select(
      _db.rewardEvents,
    )..where((e) => e.uniqueKey.equals(uniqueKey))).getSingleOrNull();
    final byKey = _db.update(_db.rewardEvents)
      ..where((e) => e.uniqueKey.equals(uniqueKey));

    if (shouldHold) {
      if (existing == null) {
        await _db
            .into(_db.rewardEvents)
            .insert(
              RewardEventsCompanion.insert(
                uniqueKey: uniqueKey,
                type: type,
                amount: amount,
                dailyRecordId: Value(dailyRecordId),
                dateKey: Value(dateKey),
                createdAt: Value(_clock().toUtc()),
              ),
            );
      } else if (existing.revokedAt != null) {
        // Re-earned: reuse the row, never insert a second one.
        await byKey.write(const RewardEventsCompanion(revokedAt: Value(null)));
      }
    } else if (existing != null && existing.revokedAt == null) {
      await byKey.write(
        RewardEventsCompanion(revokedAt: Value(_clock().toUtc())),
      );
    }
  }

  Selectable<int> _rawBalance() {
    final sum = _db.rewardEvents.amount.sum();
    final query = _db.selectOnly(_db.rewardEvents)
      ..addColumns([sum])
      ..where(_db.rewardEvents.revokedAt.isNull());
    return query.map((row) => row.read(sum) ?? 0);
  }

  static int _clamp(int balance) => balance < 0 ? 0 : balance;
}
