/// Weekday bitmask for "every day" (Mon = bit 0 ... Sun = bit 6).
const everyDay = 127;

/// Formats the local calendar day of [date] as `yyyy-MM-dd`.
///
/// Calendar days are always stored as this text, never as a DateTime.
String dateKeyOf(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses a `yyyy-MM-dd` key into a local midnight DateTime.
DateTime parseDateKey(String key) {
  return DateTime(
    int.parse(key.substring(0, 4)),
    int.parse(key.substring(5, 7)),
    int.parse(key.substring(8, 10)),
  );
}

/// Shifts [key] by [days] calendar days (DST safe).
String addDaysToKey(String key, int days) {
  final date = parseDateKey(key);
  return dateKeyOf(DateTime(date.year, date.month, date.day + days));
}

/// Whether a `repeatDays` bitmask includes the weekday of [date].
bool isScheduledOn(int repeatDays, DateTime date) {
  return repeatDays & (1 << (date.weekday - 1)) != 0;
}
