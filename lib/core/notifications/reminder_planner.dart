import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_ids.dart';
import 'package:ticky/core/notifications/planned_notification.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';

const defaultReminderBody = "It's time! Tap to check it off.";
const followUpBody = 'Still on your list. Ready to tick it off?';
const snoozeEndedBody = 'Snooze is over. Ready now?';

/// Works out which notifications should exist, as a pure function.
///
/// Every reminder is a one-shot notification for one (routine, date), not a
/// repeating series. That is what makes it possible to cancel only today's
/// reminder when today's task is completed.
///
/// The plan is a rolling window, rebuilt on every app start/resume and after
/// every change. The platform limits are respected by keeping the earliest
/// [maxScheduled] notifications (iOS allows 64 pending).
class ReminderPlanner {
  const ReminderPlanner({
    this.horizonDays = 14,
    this.followUpDays = 2,
    this.followUpDelayMinutes = 30,
    this.maxScheduled = 60,
  });

  /// How many days ahead (including today) reminders are planned.
  final int horizonDays;

  /// Follow-ups are planned for today and the next days up to this count.
  final int followUpDays;

  /// Delay between a reminder and its single follow-up.
  final int followUpDelayMinutes;

  /// Hard cap on planned notifications.
  final int maxScheduled;

  /// [routines] must be enabled, non-archived and have a reminder time.
  /// [todayRecords] maps routine id to today's daily record.
  ///
  /// Today's tasks that are completed or skipped get nothing. A today task
  /// without a record yet is treated as pending.
  List<PlannedNotification> plan({
    required DateTime now,
    required List<RoutineTask> routines,
    required Map<int, DailyTaskRecord> todayRecords,
    required NotificationPrefs prefs,
    required String timezone,
    required bool exactAllowed,
  }) {
    if (!prefs.notificationsEnabled) return const [];

    final planned = <PlannedNotification>[];
    for (var offset = 0; offset < horizonDays; offset++) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final dateKey = dateKeyOf(date);

      for (final routine in routines) {
        final minutes = routine.reminderMinutes;
        if (minutes == null || !isScheduledOn(routine.repeatDays, date)) {
          continue;
        }
        final record = offset == 0 ? todayRecords[routine.id] : null;
        if (record != null && record.status != TaskStatus.pending) continue;

        PlannedNotification make(
          ReminderKind kind,
          DateTime when,
          String body, {
          required bool alarm,
        }) {
          return PlannedNotification(
            routineId: routine.id,
            dateKey: dateKey,
            kind: kind,
            when: when,
            title: routine.title,
            body: body,
            alarm: alarm,
            sound: prefs.soundEnabled,
            vibration: prefs.vibrationEnabled,
            exact: exactAllowed,
            timezone: timezone,
          );
        }

        final message = routine.customReminderMessage ?? defaultReminderBody;
        final reminderAt = DateTime(
          date.year,
          date.month,
          date.day,
          0,
          minutes,
        );
        if (reminderAt.isAfter(now)) {
          planned.add(
            make(
              ReminderKind.reminder,
              reminderAt,
              message,
              alarm: routine.alarmEnabled,
            ),
          );
        }

        final snoozedUntil = record?.snoozedUntil?.toLocal();
        final snoozeActive =
            snoozedUntil != null &&
            snoozedUntil.isAfter(now) &&
            dateKeyOf(snoozedUntil) == dateKey;
        if (snoozeActive) {
          planned.add(
            make(
              ReminderKind.snooze,
              snoozedUntil,
              routine.customReminderMessage ?? snoozeEndedBody,
              alarm: routine.alarmEnabled,
            ),
          );
        }

        if (prefs.followUpEnabled && offset < followUpDays) {
          final base = snoozeActive ? snoozedUntil : reminderAt;
          final followUpAt = DateTime(
            base.year,
            base.month,
            base.day,
            base.hour,
            base.minute + followUpDelayMinutes,
          );
          // A follow-up never crosses midnight: that day is already over.
          if (followUpAt.isAfter(now) && dateKeyOf(followUpAt) == dateKey) {
            planned.add(
              make(
                ReminderKind.followUp,
                followUpAt,
                followUpBody,
                alarm: false,
              ),
            );
          }
        }
      }
    }

    planned.sort((a, b) {
      final byTime = a.when.compareTo(b.when);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return planned.length > maxScheduled
        ? planned.sublist(0, maxScheduled)
        : planned;
  }
}
