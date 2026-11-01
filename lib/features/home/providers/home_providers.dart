import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/notifications/notification_service.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/core/utils/date_keys.dart';
import 'package:ticky/features/routine/models/streak.dart';
import 'package:ticky/features/routine/providers/routine_providers.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

DateTime _minuteOf(DateTime t) =>
    DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// The current time, re-emitted whenever the minute changes. Drives overdue
/// styling, the time-of-day header and Ticky's mood.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  var last = _minuteOf(clock());
  yield last;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
    final current = _minuteOf(clock());
    if (current != last) {
      last = current;
      yield current;
    }
  }
});

/// Today's local date key, re-emitted just after midnight.
final todayKeyProvider = StreamProvider<String>((ref) {
  final clock = ref.watch(clockProvider);
  final controller = StreamController<String>();
  Timer? timer;

  // Emits today's key now (queued until someone listens), then again just
  // after every midnight.
  void emitAndRearm() {
    if (controller.isClosed) return;
    final now = clock();
    controller.add(dateKeyOf(now));
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    timer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 2),
      emitAndRearm,
    );
  }

  emitAndRearm();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Today's checklist, ordered by time with "anytime" tasks last.
final todayEntriesProvider = StreamProvider<List<DailyTaskEntry>>((ref) async* {
  final key = await ref.watch(todayKeyProvider.future);
  yield* ref.watch(dailyRecordRepositoryProvider).watchForDate(key);
});

/// Whether any (non-archived) routine exists, paused ones included.
final hasRoutinesProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(routineRepositoryProvider)
      .watchActive()
      .map((routines) => routines.isNotEmpty),
);

final streakProvider = StreamProvider<StreakInfo>((ref) async* {
  final key = await ref.watch(todayKeyProvider.future);
  yield* ref.watch(streakRepositoryProvider).watchCurrent(key);
});

/// What the checklist can do to a task. A seam for the UI, and for tests.
class TaskActions {
  TaskActions({
    required DailyRecordRepository records,
    required NotificationService notifications,
  }) : _records = records,
       _notifications = notifications;

  final DailyRecordRepository _records;
  final NotificationService _notifications;

  Future<void> complete(int recordId) =>
      _records.setStatus(recordId, TaskStatus.completed);

  Future<void> skip(int recordId) =>
      _records.setStatus(recordId, TaskStatus.skipped);

  /// Back to pending: un-completes or un-skips.
  Future<void> reopen(int recordId) =>
      _records.setStatus(recordId, TaskStatus.pending);

  /// Returns when the snooze ends.
  Future<DateTime> snooze(int recordId) => _notifications.snooze(recordId);
}

final taskActionsProvider = Provider<TaskActions>(
  (ref) => TaskActions(
    records: ref.watch(dailyRecordRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  ),
);

/// How long Home waits after opening before offering the reminders sheet, so
/// the screen is seen first. Tests override this.
final homePromptDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 900),
);

/// How long to leave the user alone after they close the reminders sheet.
const notificationPromptCooldown = Duration(days: 7);

/// Whether Home should offer the "turn on reminders" sheet: permission is
/// missing, and the user has not recently said "maybe later".
final notificationPromptDueProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final status = await ref
      .read(notificationServiceProvider)
      .getPermissionStatus();
  if (status.notificationsAllowed) return false;
  final dismissedAt = await ref
      .read(settingsRepositoryProvider)
      .getNotificationPromptDismissedAt();
  if (dismissedAt == null) return true;
  final now = ref.read(clockProvider)().toUtc();
  return now.difference(dismissedAt) >= notificationPromptCooldown;
});
