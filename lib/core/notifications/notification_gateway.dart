import 'package:ticky/core/notifications/planned_notification.dart';

/// A notification the platform currently holds as scheduled.
class PendingReminder {
  const PendingReminder({required this.id, required this.payload});

  final int id;
  final String? payload;
}

/// The user tapped a notification, or one of its buttons.
class NotificationTap {
  const NotificationTap({this.payload, this.actionId});

  /// What the notification was scheduled with (see `ReminderPayload`).
  final String? payload;

  /// The button that was pressed, or null for a tap on the notification itself.
  final String? actionId;
}

/// Thin boundary around the platform notification APIs.
///
/// All scheduling policy lives in `NotificationService`; implementations only
/// translate calls. This keeps the policy testable without a device.
abstract interface class NotificationGateway {
  Future<void> initialize();

  /// Taps on notifications (and their buttons) while the app is running.
  Stream<NotificationTap> get taps;

  /// The tap that started the app from closed, or null when it was opened
  /// normally. Only meaningful after [initialize].
  Future<NotificationTap?> getLaunchTap();

  /// Reads the device timezone, applies it, and returns its IANA id.
  Future<String> refreshTimezone();

  Future<bool> areNotificationsAllowed();
  Future<bool> requestNotificationPermission();

  /// Whether exact alarms can be scheduled (Android 12+ may deny this).
  Future<bool> canScheduleExact();
  Future<bool> requestExactAlarmPermission();

  Future<List<PendingReminder>> pending();

  /// Ids of notifications currently shown in the notification shade.
  Future<List<int>> activeIds();

  /// Schedules [notification], replacing any pending one with the same id.
  Future<void> schedule(PlannedNotification notification);

  /// Cancels a pending notification and dismisses it if it is showing.
  Future<void> cancel(int id);

  /// Opens the system notification settings for this app.
  Future<void> openSystemSettings();
}
