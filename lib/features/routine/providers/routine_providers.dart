import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/features/rewards/providers/reward_providers.dart';
import 'package:ticky/features/routine/data/daily_reconciler.dart';
import 'package:ticky/features/routine/data/streak_repository.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

final streakRepositoryProvider = Provider<StreakRepository>(
  (ref) => StreakRepository(ref.watch(appDatabaseProvider)),
);

final dailyReconcilerProvider = Provider<DailyReconciler>(
  (ref) => DailyReconciler(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsRepositoryProvider),
    ref.watch(rewardRepositoryProvider),
  ),
);
