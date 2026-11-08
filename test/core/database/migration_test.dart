import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';

import '../../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('a fresh database matches the version 2 schema', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);
  });

  test('1 to 2 adds day_notes and keeps existing data', () async {
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        "INSERT INTO categories (title, icon_key, color_value) VALUES ('Mine', 'star', 4278190080)",
      )
      ..execute(
        "INSERT INTO app_settings (key, value) VALUES ('themeMode', 'dark')",
      );

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 2);

    final categories = await db.select(db.categories).get();
    expect(categories.map((c) => c.title), ['Mine']);
    final settings = await db.select(db.appSettings).get();
    expect(settings.single.value, 'dark');

    // The new table works.
    await db
        .into(db.dayNotes)
        .insert(
          DayNotesCompanion.insert(dateKey: '2026-11-08', body: '- [ ] x'),
        );
    expect((await db.select(db.dayNotes).get()).single.body, '- [ ] x');
  });
}
