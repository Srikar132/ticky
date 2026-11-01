import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/planned_notification.dart';

/// Ids of the buttons on a reminder notification.
const notificationActionDone = 'done';
const notificationActionSnooze = 'snooze';

/// What a tap on a notification means for the app.
sealed class TapOutcome {
  const TapOutcome();
}

/// Show this task's details.
class OpenTask extends TapOutcome {
  const OpenTask(this.recordId);

  final int recordId;
}

/// The "Done" button was pressed and the task is complete.
class MarkedDone extends TapOutcome {
  const MarkedDone(this.title);

  final String title;
}

/// The "Snooze" button was pressed; the reminder returns at [until].
class Snoozed extends TapOutcome {
  const Snoozed(this.title, this.until);

  final String title;
  final DateTime until;
}

/// The notification is real, but its task is gone: the routine was deleted or
/// paused, or the day was cleaned up.
class TaskGone extends TapOutcome {
  const TaskGone();
}

/// The app refused, for a reason the user can read (for example a past day).
class TapFailed extends TapOutcome {
  const TapFailed(this.message);

  final String message;
}

/// Not a Ticky reminder; do nothing.
class TapIgnored extends TapOutcome {
  const TapIgnored();
}

/// Turns a notification tap into a [TapOutcome].
///
/// It reads the payload (`ticky1|routineId|dateKey|fingerprint`), finds that
/// day's record, and performs the button's action. It knows nothing about
/// screens or the platform, so it is easy to test; the router shows the
/// outcome.
class NotificationTapResolver {
  NotificationTapResolver({
    required this.findRecord,
    required this.complete,
    required this.snooze,
  });

  /// The daily record of a routine on a date, or null.
  final Future<DailyTaskRecord?> Function(int routineId, String dateKey)
  findRecord;

  /// Completes a record (today's only; past days refuse).
  final Future<void> Function(int recordId) complete;

  /// Snoozes a record and returns when the snooze ends.
  final Future<DateTime> Function(int recordId) snooze;

  Future<TapOutcome> resolve(NotificationTap tap) async {
    final payload = ReminderPayload.parse(tap.payload);
    if (payload == null) return const TapIgnored();

    final record = await findRecord(payload.routineId, payload.dateKey);
    if (record == null) return const TaskGone();

    try {
      switch (tap.actionId) {
        case notificationActionDone:
          if (record.status != TaskStatus.completed) {
            await complete(record.id);
          }
          return MarkedDone(record.titleSnapshot);
        case notificationActionSnooze:
          return Snoozed(record.titleSnapshot, await snooze(record.id));
        default:
          return OpenTask(record.id);
      }
    } on DataException catch (error) {
      return TapFailed(error.message);
    }
  }
}
