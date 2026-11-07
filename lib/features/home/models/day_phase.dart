/// Part of the day.
enum DayPhase {
  morning,
  afternoon,
  night;

  /// morning 05:00-11:59, afternoon 12:00-17:59, night 18:00-04:59.
  static DayPhase at(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return morning;
    if (hour >= 12 && hour < 18) return afternoon;
    return night;
  }
}

/// "Good morning", "Good afternoon", "Good evening", "Good night".
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 21) return 'Good evening';
  return 'Good night';
}
