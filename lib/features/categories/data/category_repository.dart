import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/categories/models/category_draft.dart';

/// Task categories. Categories are archived, never deleted.
///
/// `General` is the fallback and can never be archived. Archiving another
/// category first moves its active routines to General. Past daily records are
/// not re-categorized, because they never store a category of their own.
class CategoryRepository {
  CategoryRepository(this._db, this._clock);

  final AppDatabase _db;
  final Clock _clock;

  /// Categories offered in pickers, in display order.
  Stream<List<Category>> watchActive() {
    return (_db.select(_db.categories)
          ..where((c) => c.archivedAt.isNull())
          ..orderBy(_order))
        .watch();
  }

  /// Every category, archived ones included, so old history can still show
  /// the title, icon and colour it was filed under.
  Stream<List<Category>> watchAll() {
    return (_db.select(_db.categories)..orderBy(_order)).watch();
  }

  Future<List<Category>> getActive() {
    return (_db.select(_db.categories)
          ..where((c) => c.archivedAt.isNull())
          ..orderBy(_order))
        .get();
  }

  /// Returns archived categories too.
  Future<Category?> getById(int id) {
    return (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Id of the fallback category.
  Future<int> getGeneralId() async {
    final general = await (_db.select(
      _db.categories,
    )..where((c) => c.key.equals(generalCategoryKey))).getSingle();
    return general.id;
  }

  Future<int> create(CategoryDraft draft) async {
    draft.validate();
    return _db.transaction(() async {
      final now = _clock().toUtc();
      return _db
          .into(_db.categories)
          .insert(
            CategoriesCompanion.insert(
              title: draft.trimmedTitle,
              iconKey: draft.iconKey,
              colorValue: draft.colorValue,
              sortOrder: Value(await _nextSortOrder()),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });
  }

  /// Changes title, icon and colour. The stable `key` of seeded defaults is
  /// never touched, so General stays identifiable even if renamed.
  Future<void> update(int id, CategoryDraft draft) async {
    draft.validate();
    return _db.transaction(() async {
      await _requireActive(id);
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          title: Value(draft.trimmedTitle),
          iconKey: Value(draft.iconKey),
          colorValue: Value(draft.colorValue),
          updatedAt: Value(_clock().toUtc()),
        ),
      );
    });
  }

  /// Hides the category from pickers.
  ///
  /// Its active routines move to General first, in the same transaction.
  /// Throws [InvalidCategoryException] for General.
  Future<void> archive(int id) {
    return _db.transaction(() async {
      final category = await _requireActive(id);
      if (category.key == generalCategoryKey) {
        throw const InvalidCategoryException('General cannot be archived');
      }
      final now = _clock().toUtc();
      final generalId = await getGeneralId();

      await (_db.update(
        _db.routineTasks,
      )..where((t) => t.categoryId.equals(id) & t.archivedAt.isNull())).write(
        RoutineTasksCompanion(
          categoryId: Value(generalId),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(archivedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  Future<Category> _requireActive(int id) async {
    final category = await getById(id);
    if (category == null || category.archivedAt != null) {
      throw NotFoundException('Category $id not found');
    }
    return category;
  }

  Future<int> _nextSortOrder() async {
    final maxOrder = _db.categories.sortOrder.max();
    final query = _db.selectOnly(_db.categories)..addColumns([maxOrder]);
    final current = await query.map((r) => r.read(maxOrder)).getSingle();
    return (current ?? -1) + 1;
  }

  static List<OrderingTerm Function($CategoriesTable)> get _order => [
    (c) => OrderingTerm.asc(c.sortOrder),
    (c) => OrderingTerm.asc(c.id),
  ];
}
