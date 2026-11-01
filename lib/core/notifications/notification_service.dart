import 'package:flutter/foundation.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/notification_ids.dart';
import 'package:ticky/core/notifications/reminder_planner.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/settings/data/settings_repository.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/data/routine_repository.dart';

/// What the operating system currently allows.
class NotificationPermissionStatus {
  const NotificationPermissionStatus({
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
  });

  final bool notificationsAllowed;

  /// When false, reminders still arrive but may be a few minutes late.
  final bool exactAlarmsAllowed;
}

/// Outcome of one [NotificationService.sync].
class SyncReport {
  const SyncReport({
    required this.scheduled,
    required this.cancelled,
    required this.failed,
  });

  final int scheduled;
  final int cancelled;
  final int failed;
}

/// The only place that schedules or cancels notifications.
///
/// [sync] makes the platform's pending notifications match the database. It is
/// idempotent and cheap when nothing changed, so it is safe to call after any
/// change, on app start, and on resume. Delivery stays up to the OS: exact
/// timing is requested but not guaranteed.
class NotificationService {
  NotificationService({
    required NotificationGateway gateway,
    required RoutineRepository routines,
    required DailyRecordRepository records,
    required SettingsRepository settings,
    required Clock clock,
    ReminderPlanner planner = const ReminderPlanner(),
  }) : _gateway = gateway,
       _routines = routines,
       _records = records,
       _settings = settings,
       _clock = clock,
       _planner = planner;

  final NotificationGateway _gateway;
  final RoutineRepository _routines;
  final DailyRecordRepository _records;
  final SettingsRepository _settings;
  final Clock _clock;
  final ReminderPlanner _planner;

  Future<void> _tail = Future.value();

  Future<void> initialize() => _gateway.initialize();

  Future<NotificationPermissionStatus> getPermissionStatus() async {
    return NotificationPermissionStatus(
      notificationsAllowed: await _gateway.areNotificationsAllowed(),
      exactAlarmsAllowed: await _gateway.canScheduleExact(),
    );
  }

  /// Asks for notification permission, then (if needed) for exact alarms.
  ///
  /// Call this at a sensible moment, such as when the user first saves a task
  /// with a reminder, not blindly on launch.
  Future<NotificationPermissionStatus> requestPermissions() async {
    final allowed = await _gateway.requestNotificationPermission();
    if (allowed && !await _gateway.canScheduleExact()) {
      await _gateway.requestExactAlarmPermission();
    }
    await sync();
    return getPermissionStatus();
  }

  /// Step one of [requestPermissions]: notifications only.
  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    await _gateway.requestNotificationPermission();
    await sync();
    return getPermissionStatus();
  }

  /// Step two of [requestPermissions]: exact alarms. On Android 12+ this opens
  /// a system settings page, so the answer may only be known after the user
  /// returns; call [getPermissionStatus] then.
  Future<NotificationPermissionStatus> requestExactAlarms() async {
    await _gateway.requestExactAlarmPermission();
    return getPermissionStatus();
  }

  Future<void> openSystemSettings() => _gateway.openSystemSettings();

  /// Snoozes today's pending task and returns when the snooze ends.
  ///
  /// Uses the task's own snooze length, else the global default.
  Future<DateTime> snooze(int recordId) async {
    final record = await _records.getById(recordId);
    if (record == null) throw NotFoundException('Record $recordId not found');
    if (record.scheduledMinutes == null) {
      throw const InvalidRecordStateException('Task has no reminder to snooze');
    }
    final routine = await _routines.getById(record.routineTaskId);
    final prefs = await _settings.getNotificationPrefs();
    final minutes = routine?.snoozeMinutes ?? prefs.defaultSnoozeMinutes;

    final now = _clock();
    final until = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + minutes,
      now.second,
    );
    await _records.setSnoozedUntil(recordId, until);
    await sync();
    return until;
  }

  /// Aligns platform notifications with the database. Calls never overlap.
  Future<SyncReport> sync() {
    final run = _tail.then((_) => _syncOnce());
    _tail = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<SyncReport> _syncOnce() async {
    final now = _clock();
    final today = dateKeyOf(now);

    final prefs = await _settings.getNotificationPrefs();
    final timezone = await _gateway.refreshTimezone();
    final exact = await _gateway.canScheduleExact();
    final routines = await _routines.getReminderRoutines();
    final todayEntries = await _records.getForDate(today);
    final todayRecords = {
      for (final entry in todayEntries)
        entry.record.routineTaskId: entry.record,
    };

    final plan = _planner.plan(
      now: now,
      routines: routines,
      todayRecords: todayRecords,
      prefs: prefs,
      timezone: timezone,
      exactAllowed: exact,
    );
    final wanted = {for (final item in plan) item.id: item};
    final pending = await _gateway.pending();
    final pendingById = {for (final item in pending) item.id: item};

    var scheduled = 0;
    var cancelled = 0;
    var failed = 0;

    // Cancel obsolete or changed notifications.
    for (final item in pending) {
      final target = wanted[item.id];
      if (target != null && target.payload == item.payload) continue;
      if (await _guard(() => _gateway.cancel(item.id))) {
        cancelled++;
      } else {
        failed++;
      }
    }

    // Schedule what is missing or changed.
    for (final item in plan) {
      if (pendingById[item.id]?.payload == item.payload) continue;
      if (await _guard(() => _gateway.schedule(item))) {
        scheduled++;
      } else {
        failed++;
      }
    }

    // Dismiss delivered notifications that no longer apply: the task was
    // completed or skipped, the routine was removed, or it is from a past day.
    for (final id in await _gateway.activeIds()) {
      final decoded = NotificationIds.decode(id);
      if (decoded == null) continue;
      final record = todayRecords[decoded.routineId];
      final stillRelevant =
          decoded.dateKey == today &&
          record != null &&
          record.status == TaskStatus.pending;
      if (stillRelevant) continue;
      if (await _guard(() => _gateway.cancel(id))) cancelled++;
    }

    return SyncReport(
      scheduled: scheduled,
      cancelled: cancelled,
      failed: failed,
    );
  }

  /// One failing notification must not stop the rest from being scheduled.
  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on Exception catch (error, stack) {
      debugPrint('Notification operation failed: $error\n$stack');
      return false;
    }
  }
}
