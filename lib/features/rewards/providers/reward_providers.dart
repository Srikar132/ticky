import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/rewards/data/reward_repository.dart';

final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Coin balance, never below 0.
final coinBalanceProvider = StreamProvider<int>(
  (ref) => ref.watch(rewardRepositoryProvider).watchBalance(),
);
