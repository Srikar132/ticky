import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/features/tasks/data/routine_repository.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

/// What the UI can do to a routine (Task Details and Settings). A seam for the
/// UI, and for tests.
class RoutineActions {
  RoutineActions(this._routines);

  final RoutineRepository _routines;

  /// Deletes by archiving: history stays, future days stop.
  Future<void> delete(int routineId) => _routines.archive(routineId);

  /// Undoes [delete].
  Future<void> undoDelete(int routineId) => _routines.restore(routineId);

  /// Pauses (false) or resumes (true) a routine without deleting it.
  Future<void> setEnabled(int routineId, bool enabled) =>
      _routines.setEnabled(routineId, enabled);

  /// Saves the manual order, first = top.
  Future<void> reorder(List<int> orderedIds) => _routines.reorder(orderedIds);
}

final routineActionsProvider = Provider<RoutineActions>(
  (ref) => RoutineActions(ref.watch(routineRepositoryProvider)),
);
