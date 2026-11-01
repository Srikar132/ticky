import 'package:ticky/core/utils/date_keys.dart';

/// Weekday bitmasks (Mon = bit 0 ... Sun = bit 6).
const weekdaysMask = 31;
const weekendMask = 96;

const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// One letter per weekday, for compact chips.
const weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// "Every day", "Weekdays", "Weekends" or the picked days: "Mon, Wed, Fri".
String repeatSummary(int mask) {
  if (mask == everyDay) return 'Every day';
  if (mask == weekdaysMask) return 'Weekdays';
  if (mask == weekendMask) return 'Weekends';
  if (mask < 1) return 'Pick a day';
  return [
    for (var i = 0; i < 7; i++)
      if (mask & (1 << i) != 0) weekdayShortNames[i],
  ].join(', ');
}
