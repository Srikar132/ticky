import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/categories/data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Categories for pickers (archived ones hidden).
final activeCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchActive(),
);

/// All categories, archived included, for rendering history.
final allCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);
