import 'package:ticky/core/database/enums.dart';

/// Bonus for a day where every task is completed or skipped (>= 1 completed).
const perfectDayBonus = 5;

/// Coins earned by completing a task of the given [priority].
int coinsForPriority(Priority priority) => switch (priority) {
  Priority.low => 1,
  Priority.medium => 2,
  Priority.high => 3,
};
