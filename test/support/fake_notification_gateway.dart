import 'dart:async';

import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/planned_notification.dart';

/// In-memory stand-in for the platform notification APIs.
class FakeNotificationGateway implements NotificationGateway {
  final scheduled = <int, PlannedNotification>{};
  final active = <int>{};

  String timezone = 'Asia/Kolkata';
  bool exact = true;
  bool notificationsAllowed = true;
  bool grantOnRequest = true;

  /// Ids whose `schedule` call throws, to test failure isolation.
  final failingIds = <int>{};

  /// What the next [getLaunchTap] answers: the tap that opened the app.
  NotificationTap? launchTap;

  final _taps = StreamController<NotificationTap>.broadcast();

  /// Simulates the user tapping a notification, or one of its buttons.
  void tap({String? payload, String? actionId}) =>
      _taps.add(NotificationTap(payload: payload, actionId: actionId));

  int scheduleCalls = 0;
  int cancelCalls = 0;
  int exactPermissionRequests = 0;

  /// Simulates the OS delivering a notification: it leaves the pending list
  /// and shows up in the shade.
  void fire(int id) {
    scheduled.remove(id);
    active.add(id);
  }

  Iterable<PlannedNotification> ofKind(Object kind) =>
      scheduled.values.where((n) => n.kind == kind);

  @override
  Future<void> initialize() async {}

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<NotificationTap?> getLaunchTap() async => launchTap;

  @override
  Future<String> refreshTimezone() async => timezone;

  @override
  Future<bool> areNotificationsAllowed() async => notificationsAllowed;

  @override
  Future<bool> requestNotificationPermission() async {
    notificationsAllowed = grantOnRequest;
    return notificationsAllowed;
  }

  @override
  Future<bool> canScheduleExact() async => exact;

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactPermissionRequests++;
    return exact;
  }

  @override
  Future<List<PendingReminder>> pending() async => [
    for (final n in scheduled.values)
      PendingReminder(id: n.id, payload: n.payload),
  ];

  @override
  Future<List<int>> activeIds() async => active.toList();

  @override
  Future<void> schedule(PlannedNotification notification) async {
    scheduleCalls++;
    if (failingIds.contains(notification.id)) throw Exception('boom');
    scheduled[notification.id] = notification;
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls++;
    scheduled.remove(id);
    active.remove(id);
  }

  @override
  Future<void> openSystemSettings() async {}
}
