import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/features/home/providers/home_providers.dart';
import 'package:ticky/features/routine/data/history_repository.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(appDatabaseProvider)),
);

/// Past days, newest first. Today is not included.
final historyDaysProvider = StreamProvider.autoDispose<List<DaySummary>>((
  ref,
) async* {
  final today = await ref.watch(todayKeyProvider.future);
  yield* ref.watch(historyRepositoryProvider).watchPastDays(today);
});

/// The tasks of one past day, for the history sheet.
final historyDayEntriesProvider = StreamProvider.autoDispose
    .family<List<DailyTaskEntry>, String>(
      (ref, dateKey) =>
          ref.watch(dailyRecordRepositoryProvider).watchForDate(dateKey),
    );
