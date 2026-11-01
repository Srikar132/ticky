import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:ticky/core/notifications/android_channel_spec.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/notification_tap_resolver.dart'
    show notificationActionDone, notificationActionSnooze;
import 'package:ticky/core/notifications/planned_notification.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// [NotificationGateway] backed by `flutter_local_notifications`.
///
/// Works on Android and iOS. On other platforms (desktop, web) every call is
/// a harmless no-op so the app still runs during development.
class LocalNotificationsGateway implements NotificationGateway {
  LocalNotificationsGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _taps = StreamController<NotificationTap>.broadcast();

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    if (!_supported) return;
    await _plugin.initialize(
      onDidReceiveNotificationResponse: (response) => _taps.add(
        NotificationTap(payload: response.payload, actionId: response.actionId),
      ),
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permissions are requested explicitly, at a sensible moment.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await _removeLegacyChannels();
  }

  /// Old alarm channels keep their old (notification) sound forever, so they
  /// are deleted; alarms now use a new channel with the alarm tone.
  Future<void> _removeLegacyChannels() async {
    if (!_isAndroid) return;
    for (final id in legacyChannelIds) {
      try {
        await _android?.deleteNotificationChannel(channelId: id);
      } on PlatformException catch (error) {
        debugPrint('Could not remove channel $id: ${error.message}');
      }
    }
  }

  @override
  Stream<NotificationTap> get taps => _taps.stream;

  @override
  Future<NotificationTap?> getLaunchTap() async {
    if (!_supported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details == null || !details.didNotificationLaunchApp) return null;
    if (response == null) return null;
    return NotificationTap(
      payload: response.payload,
      actionId: response.actionId,
    );
  }

  @override
  Future<String> refreshTimezone() async {
    if (!_supported) return tz.local.name;
    final info = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on tz.LocationNotFoundException {
      // Unknown id: keep the previous location rather than scheduling wrong.
      debugPrint('Unknown timezone ${info.identifier}; keeping ${tz.local}');
    }
    return tz.local.name;
  }

  @override
  Future<bool> areNotificationsAllowed() async {
    if (_isAndroid) return await _android?.areNotificationsEnabled() ?? false;
    if (_supported) return (await _ios?.checkPermissions())?.isEnabled ?? false;
    return true;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    if (_isAndroid) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    if (_supported) {
      return await _ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  @override
  Future<bool> canScheduleExact() async {
    if (_isAndroid) {
      return await _android?.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    if (_isAndroid) {
      return await _android?.requestExactAlarmsPermission() ?? false;
    }
    return true;
  }

  @override
  Future<List<PendingReminder>> pending() async {
    if (!_supported) return const [];
    final requests = await _plugin.pendingNotificationRequests();
    return [
      for (final request in requests)
        PendingReminder(id: request.id, payload: request.payload),
    ];
  }

  @override
  Future<List<int>> activeIds() async {
    if (!_supported) return const [];
    final active = await _plugin.getActiveNotifications();
    return [
      for (final notification in active)
        if (notification.id != null) notification.id!,
    ];
  }

  @override
  Future<void> schedule(PlannedNotification notification) async {
    if (!_supported) return;
    final when = tz.TZDateTime(
      tz.local,
      notification.when.year,
      notification.when.month,
      notification.when.day,
      notification.when.hour,
      notification.when.minute,
      notification.when.second,
    );
    Future<void> zoned(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id: notification.id,
      scheduledDate: when,
      notificationDetails: _details(notification),
      androidScheduleMode: mode,
      title: notification.title,
      body: notification.body,
      payload: notification.payload,
    );

    final mode = !notification.exact
        ? AndroidScheduleMode.inexactAllowWhileIdle
        : notification.alarm
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;
    try {
      await zoned(mode);
    } on PlatformException catch (error) {
      // Exact alarm permission can be revoked between our check and now.
      if (error.code != 'exact_alarms_not_permitted') rethrow;
      await zoned(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_supported) return;
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> openSystemSettings() async {
    if (!_supported) return;
    await _plugin.openAppNotificationSettings();
  }

  /// Channel, sound and looping come from [AndroidChannelSpec].
  NotificationDetails _details(PlannedNotification n) {
    final spec = AndroidChannelSpec.forNotification(n);
    final soundUri = spec.soundUri;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        spec.id,
        spec.name,
        channelDescription: spec.description,
        importance: n.alarm ? Importance.max : Importance.high,
        priority: n.alarm ? Priority.max : Priority.high,
        playSound: n.sound,
        sound: soundUri == null ? null : UriAndroidNotificationSound(soundUri),
        enableVibration: n.vibration,
        additionalFlags: spec.insistent
            ? Int32List.fromList([insistentFlag])
            : null,
        timeoutAfter: spec.timeout?.inMilliseconds,
        // Buttons open the app, so what they do runs in the app itself with
        // the live database. A background handler could not refresh the UI.
        actions: const [
          AndroidNotificationAction(
            notificationActionDone,
            'Done',
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            notificationActionSnooze,
            'Snooze',
            showsUserInterface: true,
          ),
        ],
        category: n.alarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        audioAttributesUsage: n.alarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: n.sound,
      ),
    );
  }
}
