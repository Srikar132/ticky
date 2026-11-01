import 'package:intl/intl.dart';

/// "8:00 AM" for a time stored as minutes from midnight.
String formatMinutesOfDay(int minutes) {
  return DateFormat.jm().format(
    DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60),
  );
}

/// "Monday, 2 November".
String formatLongDate(DateTime date) => DateFormat('EEEE, d MMMM').format(date);

/// "15 min", "1 h", "1 h 30 min".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// Minutes from midnight of [time].
int minutesOfDay(DateTime time) => time.hour * 60 + time.minute;

/// "Sun 1 Nov".
String formatShortDate(DateTime date) => DateFormat('EEE d MMM').format(date);
