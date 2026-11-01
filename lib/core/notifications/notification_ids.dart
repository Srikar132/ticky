import 'package:ticky/core/utils/date_keys.dart';

/// What a scheduled notification is for.
enum ReminderKind {
  /// The task's own reminder time.
  reminder,

  /// One gentle nudge after a reminder that is still pending.
  followUp,

  /// The user snoozed a task; fires when the snooze ends.
  snooze,
}

/// Deterministic notification ids: one id per (routine, date, kind).
///
/// Layout of the 31-bit positive id:
/// `routineId (15 bits) | kind (2 bits) | days since 2020-01-01 (14 bits)`.
///
/// Deterministic ids make scheduling idempotent (no duplicates) and let the
/// service work out what an id belongs to without extra storage.
abstract final class NotificationIds {
  static final _epoch = DateTime.utc(2020);

  /// Largest routine id that fits the layout.
  static const maxRoutineId = 0x7FFF;

  /// Last day index that fits the layout (about the year 2064).
  static const maxDayIndex = 0x3FFF;

  static int encode({
    required int routineId,
    required String dateKey,
    required ReminderKind kind,
  }) {
    RangeError.checkValueInInterval(routineId, 1, maxRoutineId, 'routineId');
    final day = _dayIndex(dateKey);
    RangeError.checkValueInInterval(day, 0, maxDayIndex, 'dateKey');
    return (routineId << 16) | (kind.index << 14) | day;
  }

  /// Reverses [encode]. Returns null for ids this app did not produce.
  static ({int routineId, ReminderKind kind, String dateKey})? decode(int id) {
    if (id <= 0) return null;
    final kindIndex = (id >> 14) & 0x3;
    if (kindIndex >= ReminderKind.values.length) return null;
    final routineId = id >> 16;
    if (routineId == 0) return null;
    final date = _epoch.add(Duration(days: id & maxDayIndex));
    return (
      routineId: routineId,
      kind: ReminderKind.values[kindIndex],
      dateKey: dateKeyOf(date),
    );
  }

  static int _dayIndex(String dateKey) {
    final date = parseDateKey(dateKey);
    return DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).difference(_epoch).inDays;
  }
}
