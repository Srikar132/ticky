import 'package:flutter/material.dart';

/// Part of the day that picks the Home header artwork.
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

  /// Header art. Missing files fall back to [fallbackGradient].
  String get headerAsset => 'assets/home/header_$name.png';

  /// Shown until the real artwork exists, and behind it while it loads.
  List<Color> get fallbackGradient => switch (this) {
    morning => const [Color(0xFF6D4BD6), Color(0xFFB794F6), Color(0xFFF0ABFC)],
    afternoon => const [
      Color(0xFF4C2FB0),
      Color(0xFF7C5CE8),
      Color(0xFFA78BFA),
    ],
    night => const [Color(0xFF0B0912), Color(0xFF1E1250), Color(0xFF3B2478)],
  };
}

/// "Good morning", "Good afternoon", "Good evening", "Good night".
String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 17) return 'Good afternoon';
  if (hour >= 17 && hour < 21) return 'Good evening';
  return 'Good night';
}
