/// User notification preferences (Settings -> Notification preferences,
/// Sound and vibration).
class NotificationPrefs {
  const NotificationPrefs({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.followUpEnabled = true,
    this.defaultSnoozeMinutes = defaultSnooze,
  });

  static const defaultSnooze = 10;

  /// Master switch. When off, nothing is scheduled.
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  /// One gentle follow-up for a reminder that is still pending.
  final bool followUpEnabled;

  /// Used by tasks without their own `snoozeMinutes`.
  final int defaultSnoozeMinutes;
}
