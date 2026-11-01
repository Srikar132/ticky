/// What happened on one day, reduced to what the streak rule needs.
class DayTally {
  const DayTally({
    required this.dateKey,
    required this.completed,
    required this.open,
  });

  final String dateKey;

  /// Records completed that day.
  final int completed;

  /// Records still `pending` or already `missed`.
  final int open;
}

class StreakInfo {
  const StreakInfo({required this.count, required this.includesToday});

  static const none = StreakInfo(count: 0, includesToday: false);

  /// Days in the current streak.
  final int count;

  /// Whether today already counts towards [count].
  final bool includesToday;

  @override
  bool operator ==(Object other) =>
      other is StreakInfo &&
      other.count == count &&
      other.includesToday == includesToday;

  @override
  int get hashCode => Object.hash(count, includesToday);
}

/// Current streak, derived from daily tallies (never stored).
///
/// - A day extends the streak when it has a completed record and nothing
///   pending or missed. Skipped records are fine.
/// - A past day with anything pending or missed breaks the streak.
/// - A day with no records, or only skipped ones, is neutral.
/// - Today, while in progress, never breaks the streak.
///
/// [tallies] may be in any order and may include days after [todayKey], which
/// are ignored.
StreakInfo computeStreak(List<DayTally> tallies, String todayKey) {
  final days = tallies.where((t) => t.dateKey.compareTo(todayKey) <= 0).toList()
    ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

  var count = 0;
  var includesToday = false;
  for (final day in days) {
    final extends_ = day.completed > 0 && day.open == 0;
    if (day.dateKey == todayKey) {
      if (extends_) {
        count++;
        includesToday = true;
      }
      continue;
    }
    if (extends_) {
      count++;
    } else if (day.open > 0) {
      break;
    }
  }
  return StreakInfo(count: count, includesToday: includesToday);
}
