import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/database/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> generalId() async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.key.equals(generalCategoryKey))).getSingle();
    return row.id;
  }

  Future<int> insertRoutine({
    String title = 'Drink water',
    int? reminderMinutes = 480,
    bool alarmEnabled = false,
    int repeatDays = 127,
  }) async {
    return db
        .into(db.routineTasks)
        .insert(
          RoutineTasksCompanion.insert(
            title: title,
            categoryId: await generalId(),
            reminderMinutes: Value(reminderMinutes),
            alarmEnabled: Value(alarmEnabled),
            repeatDays: Value(repeatDays),
          ),
        );
  }

  Future<int> insertRecord(
    int routineId,
    String dateKey, {
    TaskStatus status = TaskStatus.pending,
    DateTime? completedAt,
  }) {
    return db
        .into(db.dailyTaskRecords)
        .insert(
          DailyTaskRecordsCompanion.insert(
            routineTaskId: routineId,
            dateKey: dateKey,
            titleSnapshot: 'Drink water',
            status: Value(status),
            completedAt: Value(completedAt),
          ),
        );
  }

  group('seeding', () {
    test('creates the default categories in order', () async {
      final rows = await (db.select(
        db.categories,
      )..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get();

      expect(rows.map((c) => c.key), defaultCategories.map((c) => c.key));
      expect(rows.every((c) => c.isDefault), isTrue);
      expect(rows.first.key, generalCategoryKey);
    });
  });

  group('routine_tasks', () {
    test('applies defaults', () async {
      final id = await insertRoutine();
      final row = await (db.select(
        db.routineTasks,
      )..where((t) => t.id.equals(id))).getSingle();

      expect(row.repeatDays, 127);
      expect(row.priority, Priority.medium);
      expect(row.isEnabled, isTrue);
      expect(row.alarmEnabled, isFalse);
      expect(row.archivedAt, isNull);
    });

    test('allows an anytime task with no reminder', () async {
      final id = await insertRoutine(reminderMinutes: null);
      final row = await (db.select(
        db.routineTasks,
      )..where((t) => t.id.equals(id))).getSingle();

      expect(row.reminderMinutes, isNull);
    });

    test('rejects an alarm without a reminder time', () async {
      expect(
        insertRoutine(reminderMinutes: null, alarmEnabled: true),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects reminder minutes outside a day', () async {
      expect(
        insertRoutine(reminderMinutes: 1440),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects repeatDays of 0 or above 127', () async {
      expect(insertRoutine(repeatDays: 0), throwsA(isA<SqliteException>()));
      expect(insertRoutine(repeatDays: 128), throwsA(isA<SqliteException>()));
    });

    test('foreign keys are enforced for categories', () async {
      expect(
        db
            .into(db.routineTasks)
            .insert(
              RoutineTasksCompanion.insert(title: 'Orphan', categoryId: 9999),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a category in use cannot be hard deleted', () async {
      await insertRoutine();

      expect(
        (db.delete(db.categories)..where((c) => c.id.equals(1))).go(),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('daily_task_records', () {
    test('rejects a duplicate record for the same routine and date', () async {
      final routineId = await insertRoutine();
      await insertRecord(routineId, '2026-11-01');

      expect(
        insertRecord(routineId, '2026-11-01'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('insert-or-ignore leaves exactly one record per day', () async {
      final routineId = await insertRoutine();

      for (var i = 0; i < 3; i++) {
        await db
            .into(db.dailyTaskRecords)
            .insert(
              DailyTaskRecordsCompanion.insert(
                routineTaskId: routineId,
                dateKey: '2026-11-01',
                titleSnapshot: 'Drink water',
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      expect(await db.select(db.dailyTaskRecords).get(), hasLength(1));
    });

    test('allows the same routine on different dates', () async {
      final routineId = await insertRoutine();
      await insertRecord(routineId, '2026-11-01');
      await insertRecord(routineId, '2026-11-02');

      expect(await db.select(db.dailyTaskRecords).get(), hasLength(2));
    });

    test('completed requires completedAt, and vice versa', () async {
      final routineId = await insertRoutine();

      expect(
        insertRecord(routineId, '2026-11-01', status: TaskStatus.completed),
        throwsA(isA<SqliteException>()),
      );
      expect(
        insertRecord(
          routineId,
          '2026-11-02',
          status: TaskStatus.pending,
          completedAt: DateTime.utc(2026, 11, 2),
        ),
        throwsA(isA<SqliteException>()),
      );
      await insertRecord(
        routineId,
        '2026-11-03',
        status: TaskStatus.completed,
        completedAt: DateTime.utc(2026, 11, 3),
      );
    });

    test('a routine with history cannot be hard deleted', () async {
      final routineId = await insertRoutine();
      await insertRecord(routineId, '2026-11-01');

      expect(
        (db.delete(db.routineTasks)..where((t) => t.id.equals(routineId))).go(),
        throwsA(isA<SqliteException>()),
      );
    });

    test('keeps the title snapshot when the routine is renamed', () async {
      final routineId = await insertRoutine();
      await insertRecord(routineId, '2026-11-01');

      await (db.update(db.routineTasks)..where((t) => t.id.equals(routineId)))
          .write(const RoutineTasksCompanion(title: Value('Hydrate')));

      final record = await db.select(db.dailyTaskRecords).getSingle();
      expect(record.titleSnapshot, 'Drink water');
    });
  });

  group('reward_events', () {
    Future<void> insertReward(String uniqueKey, RewardType type, int amount) {
      return db
          .into(db.rewardEvents)
          .insert(
            RewardEventsCompanion.insert(
              uniqueKey: uniqueKey,
              type: type,
              amount: amount,
            ),
          );
    }

    test('uniqueKey blocks a second award', () async {
      await insertReward('task:1', RewardType.taskComplete, 2);

      expect(
        insertReward('task:1', RewardType.taskComplete, 2),
        throwsA(isA<SqliteException>()),
      );
    });

    test('earnings must be positive and spends negative', () async {
      expect(
        insertReward('task:2', RewardType.taskComplete, -1),
        throwsA(isA<SqliteException>()),
      );
      expect(
        insertReward('unlock:hat', RewardType.spend, 10),
        throwsA(isA<SqliteException>()),
      );
      expect(
        insertReward('task:3', RewardType.taskComplete, 0),
        throwsA(isA<SqliteException>()),
      );
      await insertReward('unlock:hat', RewardType.spend, -10);
    });

    test('balance sums active rows only', () async {
      await insertReward('task:1', RewardType.taskComplete, 3);
      await insertReward('task:2', RewardType.taskComplete, 2);
      await insertReward('unlock:hat', RewardType.spend, -1);
      await (db.update(db.rewardEvents)
            ..where((r) => r.uniqueKey.equals('task:2')))
          .write(RewardEventsCompanion(revokedAt: Value(DateTime.utc(2026))));

      final sum = db.rewardEvents.amount.sum();
      final query = db.selectOnly(db.rewardEvents)
        ..addColumns([sum])
        ..where(db.rewardEvents.revokedAt.isNull());
      final balance = await query.map((row) => row.read(sum)).getSingle();

      expect(balance, 2);
    });
  });

  group('app_settings and unlocked_items', () {
    test('settings are keyed', () async {
      await db
          .into(db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: 'themeMode', value: 'dark'),
          );
      await db
          .into(db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(key: 'themeMode', value: 'light'),
          );

      final rows = await db.select(db.appSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.value, 'light');
    });

    test('an item can be unlocked only once', () async {
      await db
          .into(db.unlockedItems)
          .insert(UnlockedItemsCompanion.insert(itemKey: 'hat'));

      expect(
        db
            .into(db.unlockedItems)
            .insert(UnlockedItemsCompanion.insert(itemKey: 'hat')),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
