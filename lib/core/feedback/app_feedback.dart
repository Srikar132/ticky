import 'dart:async';

import 'package:flutter/services.dart';

/// Taps, ticks and the celebration buzz, built on Flutter's own
/// [HapticFeedback] and [SystemSound]. No audio package and no sound files:
/// the click is the phone's system click, so it follows the phone's volume and
/// "touch sounds" setting.
///
/// Call it from anywhere, including widgets without a `ref`. The two switches
/// in Settings keep [hapticsEnabled] and [soundsEnabled] up to date (see
/// `TickyApp`).
abstract final class AppFeedback {
  /// Buzz on taps, checks and the celebration.
  static bool hapticsEnabled = true;

  /// The system click on taps and checks.
  static bool soundsEnabled = true;

  /// Sets both switches at once.
  static void configure({required bool haptics, required bool sounds}) {
    hapticsEnabled = haptics;
    soundsEnabled = sounds;
  }

  /// A light tap: a tab, a choice, a button.
  static void tap() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
    _click();
  }

  /// Something got done: a task checked, an item bought, a task deleted.
  static void success() {
    if (hapticsEnabled) HapticFeedback.mediumImpact();
    _click();
  }

  /// The whole day is done: a firm buzz, then a softer one.
  static Future<void> celebrate() async {
    _click();
    if (!hapticsEnabled) return;
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (hapticsEnabled) await HapticFeedback.mediumImpact();
  }

  static void _click() {
    if (soundsEnabled) unawaited(SystemSound.play(SystemSoundType.click));
  }
}
