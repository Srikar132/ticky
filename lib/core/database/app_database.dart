import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'default_categories.dart';
import 'enums.dart';
import 'schema_versions.dart';
import 'tables/app_settings.dart';
import 'tables/categories.dart';
import 'tables/daily_task_records.dart';
import 'tables/day_notes.dart';
import 'tables/reward_events.dart';
import 'tables/routine_tasks.dart';
import 'tables/unlocked_items.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Categories,
    RoutineTasks,
    DailyTaskRecords,
    RewardEvents,
    UnlockedItems,
    AppSettings,
    DayNotes,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database, or [executor] when given (tests).
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'ticky'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultCategories();
    },
    // One step per version, from `schema_versions.dart` (regenerate it with
    // `dart run drift_dev schema steps` after each bump). Never drop and
    // recreate tables: user data must survive upgrades.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.dayNotes);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seedDefaultCategories() async {
    for (final (index, category) in defaultCategories.indexed) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          key: Value(category.key),
          title: category.title,
          iconKey: category.iconKey,
          colorValue: category.colorValue,
          sortOrder: Value(index),
          isDefault: const Value(true),
        ),
      );
    }
  }
}
