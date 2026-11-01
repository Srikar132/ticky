import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// The single app database. Closed when the provider container is disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
