import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/rewards/providers/reward_providers.dart';
import 'package:ticky/features/routine/providers/routine_providers.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/data/routine_repository.dart';

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(dailyReconcilerProvider),
    ref.watch(clockProvider),
  ),
);

final dailyRecordRepositoryProvider = Provider<DailyRecordRepository>(
  (ref) => DailyRecordRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(rewardRepositoryProvider),
    ref.watch(clockProvider),
  ),
);

/// Every routine that is not deleted, paused ones included, in manual order.
final activeRoutinesProvider = StreamProvider<List<RoutineTask>>(
  (ref) => ref.watch(routineRepositoryProvider).watchActive(),
);
