import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

/// One daily record, live.
final detailRecordProvider = StreamProvider.autoDispose
    .family<DailyTaskRecord?, int>(
      (ref, recordId) =>
          ref.watch(dailyRecordRepositoryProvider).watchById(recordId),
    );

/// A routine, live. Archived routines are included, so history still shows
/// their settings.
final detailRoutineProvider = StreamProvider.autoDispose
    .family<RoutineTask?, int>(
      (ref, routineId) =>
          ref.watch(routineRepositoryProvider).watchById(routineId),
    );
