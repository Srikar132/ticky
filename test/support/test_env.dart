import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_service.dart';
import 'package:ticky/features/categories/data/category_repository.dart';
import 'package:ticky/features/rewards/data/reward_repository.dart';
import 'package:ticky/features/routine/data/daily_reconciler.dart';
import 'package:ticky/features/routine/data/history_repository.dart';
import 'package:ticky/features/settings/data/settings_repository.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart'
    show ShopActions;
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/data/routine_repository.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

import 'fake_notification_gateway.dart';

/// In-memory database plus repositories wired to a controllable clock.
///
/// 2026-11-02 is a Monday.
class TestEnv {
  TestEnv([DateTime? start])
    : now = start ?? DateTime(2026, 11, 2, 9),
      db = AppDatabase(NativeDatabase.memory()) {
    settings = SettingsRepository(db);
    rewards = RewardRepository(db, clock);
    reconciler = DailyReconciler(db, settings, rewards);
    routines = RoutineRepository(db, reconciler, clock);
    records = DailyRecordRepository(db, rewards, clock);
    categories = CategoryRepository(db, clock);
    history = HistoryRepository(db);
    shop = ShopActions(rewards: rewards, settings: settings);
    notifications = NotificationService(
      gateway: gateway,
      routines: routines,
      records: records,
      settings: settings,
      clock: clock,
    );
  }

  final gateway = FakeNotificationGateway();
  late final NotificationService notifications;
  late final CategoryRepository categories;
  late final HistoryRepository history;
  late final ShopActions shop;

  DateTime now;
  final AppDatabase db;
  late final SettingsRepository settings;
  late final RewardRepository rewards;
  late final DailyReconciler reconciler;
  late final RoutineRepository routines;
  late final DailyRecordRepository records;

  DateTime clock() => now;

  Future<void> close() => db.close();

  Future<int> generalId() async {
    final row = await (db.select(
      db.categories,
    )..where((c) => c.key.equals(generalCategoryKey))).getSingle();
    return row.id;
  }

  Future<int> addRoutine({
    String title = 'Drink water',
    int? reminderMinutes = 480,
    int repeatDays = 127,
    Priority priority = Priority.medium,
    bool alarmEnabled = false,
    String? customReminderMessage,
    int? snoozeMinutes,
  }) async {
    return routines.create(
      RoutineDraft(
        title: title,
        categoryId: await generalId(),
        reminderMinutes: reminderMinutes,
        repeatDays: repeatDays,
        priority: priority,
        alarmEnabled: alarmEnabled,
        customReminderMessage: customReminderMessage,
        snoozeMinutes: snoozeMinutes,
      ),
    );
  }

  Future<List<DailyTaskRecord>> allRecords() {
    return (db.select(db.dailyTaskRecords)..orderBy([
          (r) => OrderingTerm.asc(r.dateKey),
          (r) => OrderingTerm.asc(r.id),
        ]))
        .get();
  }

  Future<List<RewardEvent>> allRewards() => db.select(db.rewardEvents).get();

  Future<DailyTaskRecord> recordFor(int routineId, String dateKey) {
    return (db.select(db.dailyTaskRecords)..where(
          (r) => r.routineTaskId.equals(routineId) & r.dateKey.equals(dateKey),
        ))
        .getSingle();
  }
}
