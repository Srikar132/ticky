import 'package:drift/drift.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/default_categories.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/routine/data/daily_reconciler.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

/// Permanent routine configuration. Routines are archived, never deleted.
///
/// Every change also aligns today's checklist (see
/// [DailyReconciler.syncRoutineForToday]); past records are never touched.
class RoutineRepository {
  RoutineRepository(this._db, this._reconciler, this._clock);

  final AppDatabase _db;
  final DailyReconciler _reconciler;
  final Clock _clock;

  /// Non-archived routines (including paused ones) in manual order.
  Stream<List<RoutineTask>> watchActive() {
    return (_db.select(_db.routineTasks)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// Enabled, non-archived routines that have a reminder time.
  Future<List<RoutineTask>> getReminderRoutines() {
    return (_db.select(_db.routineTasks)
          ..where(
            (t) =>
                t.archivedAt.isNull() &
                t.isEnabled.equals(true) &
                t.reminderMinutes.isNotNull(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  Stream<RoutineTask?> watchById(int id) {
    return (_db.select(
      _db.routineTasks,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<RoutineTask?> getById(int id) {
    return (_db.select(
      _db.routineTasks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> create(RoutineDraft draft) async {
    draft.validate();
    return _db.transaction(() async {
      await _requireUsableCategory(draft.categoryId);
      final now = _clock();
      final id = await _db
          .into(_db.routineTasks)
          .insert(
            RoutineTasksCompanion.insert(
              title: draft.trimmedTitle,
              categoryId: draft.categoryId,
              description: Value(draft.normalizedDescription),
              reminderMinutes: Value(draft.reminderMinutes),
              alarmEnabled: Value(draft.alarmEnabled),
              repeatDays: Value(draft.repeatDays),
              priority: Value(draft.priority),
              durationMinutes: Value(draft.durationMinutes),
              customReminderMessage: Value(draft.normalizedReminderMessage),
              snoozeMinutes: Value(draft.snoozeMinutes),
              sortOrder: Value(await _nextSortOrder()),
              createdAt: Value(now.toUtc()),
              updatedAt: Value(now.toUtc()),
            ),
          );
      await _reconciler.syncRoutineForToday(id, now);
      return id;
    });
  }

  Future<void> update(int id, RoutineDraft draft) async {
    draft.validate();
    return _db.transaction(() async {
      final existing = await _requireActive(id);
      if (existing.categoryId != draft.categoryId) {
        await _requireUsableCategory(draft.categoryId);
      }
      final now = _clock();
      await (_db.update(_db.routineTasks)..where((t) => t.id.equals(id))).write(
        RoutineTasksCompanion(
          title: Value(draft.trimmedTitle),
          categoryId: Value(draft.categoryId),
          description: Value(draft.normalizedDescription),
          reminderMinutes: Value(draft.reminderMinutes),
          alarmEnabled: Value(draft.alarmEnabled),
          repeatDays: Value(draft.repeatDays),
          priority: Value(draft.priority),
          durationMinutes: Value(draft.durationMinutes),
          customReminderMessage: Value(draft.normalizedReminderMessage),
          snoozeMinutes: Value(draft.snoozeMinutes),
          updatedAt: Value(now.toUtc()),
        ),
      );
      await _reconciler.syncRoutineForToday(id, now);
    });
  }

  /// Puts the active routines in [orderedIds] order (first = top). Pass every
  /// active routine; ids that are archived or unknown are ignored. Only the
  /// manual order changes, never any routine's settings or history.
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      var position = 0;
      for (final id in orderedIds) {
        final updated =
            await (_db.update(_db.routineTasks)
                  ..where((t) => t.id.equals(id) & t.archivedAt.isNull()))
                .write(RoutineTasksCompanion(sortOrder: Value(position)));
        if (updated > 0) position++;
      }
    });
  }

  /// Pauses or resumes a routine without archiving it.
  Future<void> setEnabled(int id, bool enabled) {
    return _db.transaction(() async {
      await _requireActive(id);
      final now = _clock();
      await (_db.update(_db.routineTasks)..where((t) => t.id.equals(id))).write(
        RoutineTasksCompanion(
          isEnabled: Value(enabled),
          updatedAt: Value(now.toUtc()),
        ),
      );
      await _reconciler.syncRoutineForToday(id, now);
    });
  }

  /// Soft delete. History stays; the routine leaves future generation.
  Future<void> archive(int id) {
    return _db.transaction(() async {
      await _requireActive(id);
      final now = _clock();
      await (_db.update(_db.routineTasks)..where((t) => t.id.equals(id))).write(
        RoutineTasksCompanion(
          archivedAt: Value(now.toUtc()),
          updatedAt: Value(now.toUtc()),
        ),
      );
      await _reconciler.syncRoutineForToday(id, now);
    });
  }

  /// Undoes [archive]. Today's checklist gets the task back if it runs today.
  ///
  /// A category archived in the meantime is replaced by General, because
  /// archived categories are hidden from pickers. Restoring a routine that is
  /// not archived does nothing.
  Future<void> restore(int id) {
    return _db.transaction(() async {
      final routine = await getById(id);
      if (routine == null) throw NotFoundException('Routine $id not found');
      if (routine.archivedAt == null) return;

      final category = await (_db.select(
        _db.categories,
      )..where((c) => c.id.equals(routine.categoryId))).getSingleOrNull();
      var categoryId = routine.categoryId;
      if (category == null || category.archivedAt != null) {
        final general = await (_db.select(
          _db.categories,
        )..where((c) => c.key.equals(generalCategoryKey))).getSingle();
        categoryId = general.id;
      }

      final now = _clock();
      await (_db.update(_db.routineTasks)..where((t) => t.id.equals(id))).write(
        RoutineTasksCompanion(
          archivedAt: const Value(null),
          categoryId: Value(categoryId),
          updatedAt: Value(now.toUtc()),
        ),
      );
      await _reconciler.syncRoutineForToday(id, now);
    });
  }

  Future<RoutineTask> _requireActive(int id) async {
    final routine = await getById(id);
    if (routine == null || routine.archivedAt != null) {
      throw NotFoundException('Routine $id not found');
    }
    return routine;
  }

  Future<void> _requireUsableCategory(int categoryId) async {
    final category = await (_db.select(
      _db.categories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    if (category == null || category.archivedAt != null) {
      throw const InvalidRoutineException(
        'Category is not available',
        field: RoutineField.category,
      );
    }
  }

  Future<int> _nextSortOrder() async {
    final maxOrder = _db.routineTasks.sortOrder.max();
    final query = _db.selectOnly(_db.routineTasks)..addColumns([maxOrder]);
    final current = await query.map((r) => r.read(maxOrder)).getSingle();
    return (current ?? -1) + 1;
  }
}
