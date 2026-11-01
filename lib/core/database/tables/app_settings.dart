import 'package:drift/drift.dart';

/// Key/value preferences. Access only through a typed settings wrapper.
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
