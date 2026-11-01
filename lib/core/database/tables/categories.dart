import 'package:drift/drift.dart';

/// User-visible task categories. Seeded defaults have a stable [key].
///
/// Categories are archived, never deleted, so history keeps its meaning.
@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Stable key for seeded defaults (for example `general`). Null for custom.
  TextColumn get key => text().nullable().unique()();

  TextColumn get title => text().withLength(min: 1, max: 40)();

  /// Key into the curated icon map in code. Never an icon code point.
  TextColumn get iconKey => text()();

  /// ARGB color value.
  IntColumn get colorValue => integer()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
