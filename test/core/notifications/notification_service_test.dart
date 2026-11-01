import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_ids.dart';
import 'package:ticky/core/notifications/reminder_planner.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

import '../../support/test_env.dart';

// Fixed clock: Monday 2026-11-02, 09:00 local.
void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  /// Reconcile (as the app does on start), then sync reminders.
  Future<void> startOfDay() async {
    await env.reconciler.reconcile(env.now);
    await env.notifications.sync();
  }

  int count(ReminderKind kind) => env.gateway.ofKind(kind).length;

  Iterable<String> datesOf(ReminderKind kind) =>
      env.gateway.ofKind(kind).map((n) => n.dateKey).toList()..sort();

  group('what gets scheduled', () {
    test(
      'rolling window of reminders, follow-ups for today and tomorrow',
      () async {
        await env.addRoutine(reminderMinutes: 600); // 10:00 daily
        await startOfDay();

        expect(count(ReminderKind.reminder), 14);
        expect(datesOf(ReminderKind.followUp), ['2026-11-02', '2026-11-03']);
        final today = env.gateway
            .ofKind(ReminderKind.reminder)
            .firstWhere((n) => n.dateKey == '2026-11-02');
        expect(today.when, DateTime(2026, 11, 2, 10));
        expect(today.title, 'Drink water');
        expect(today.body, defaultReminderBody);
      },
    );

    test('follow-up comes 30 minutes after the reminder', () async {
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();

      final followUp = env.gateway
          .ofKind(ReminderKind.followUp)
          .firstWhere((n) => n.dateKey == '2026-11-02');
      expect(followUp.when, DateTime(2026, 11, 2, 10, 30));
      expect(followUp.body, followUpBody);
    });

    test('times already passed today are not scheduled', () async {
      await env.addRoutine(reminderMinutes: 480); // 08:00, now is 09:00
      await startOfDay();

      expect(datesOf(ReminderKind.reminder).first, '2026-11-03');
      expect(datesOf(ReminderKind.followUp), ['2026-11-03']);
    });

    test('only scheduled weekdays get reminders', () async {
      await env.addRoutine(reminderMinutes: 600, repeatDays: 2); // Tuesday
      await startOfDay();

      expect(datesOf(ReminderKind.reminder), ['2026-11-03', '2026-11-10']);
    });

    test('anytime tasks never notify', () async {
      await env.addRoutine(reminderMinutes: null);
      await startOfDay();

      expect(env.gateway.scheduled, isEmpty);
    });

    test('a follow-up never crosses midnight', () async {
      await env.addRoutine(reminderMinutes: 23 * 60 + 50);
      await startOfDay();

      expect(count(ReminderKind.reminder), 14);
      expect(count(ReminderKind.followUp), 0);
    });

    test(
      'alarm routines schedule an alarm reminder, follow-up is gentle',
      () async {
        await env.addRoutine(reminderMinutes: 600, alarmEnabled: true);
        await startOfDay();

        expect(
          env.gateway.ofKind(ReminderKind.reminder).every((n) => n.alarm),
          isTrue,
        );
        expect(
          env.gateway.ofKind(ReminderKind.followUp).every((n) => !n.alarm),
          isTrue,
        );
      },
    );

    test('custom reminder message is used', () async {
      await env.addRoutine(
        reminderMinutes: 600,
        customReminderMessage: 'Glass of water, friend!',
      );
      await startOfDay();

      expect(
        env.gateway
            .ofKind(ReminderKind.reminder)
            .every((n) => n.body == 'Glass of water, friend!'),
        isTrue,
      );
    });

    test('never schedules more than the cap, earliest first', () async {
      for (var i = 0; i < 10; i++) {
        await env.addRoutine(title: 'Task $i', reminderMinutes: 600 + i);
      }
      await startOfDay();

      expect(env.gateway.scheduled.length, 60);
      // All of today's reminders survive the cut.
      expect(
        env.gateway
            .ofKind(ReminderKind.reminder)
            .where((n) => n.dateKey == '2026-11-02'),
        hasLength(10),
      );
    });
  });

  group('staying in sync', () {
    test('sync is idempotent and does not touch the platform again', () async {
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final scheduleCalls = env.gateway.scheduleCalls;
      final cancelCalls = env.gateway.cancelCalls;

      final report = await env.notifications.sync();

      expect(report.scheduled, 0);
      expect(report.cancelled, 0);
      expect(env.gateway.scheduleCalls, scheduleCalls);
      expect(env.gateway.cancelCalls, cancelCalls);
    });

    test('completing a task cancels only that day', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final record = await env.recordFor(id, '2026-11-02');

      await env.records.setStatus(record.id, TaskStatus.completed);
      await env.notifications.sync();

      expect(datesOf(ReminderKind.reminder).first, '2026-11-03');
      expect(datesOf(ReminderKind.reminder), hasLength(13));
      expect(datesOf(ReminderKind.followUp), ['2026-11-03']);
    });

    test('skipping a task cancels today as well', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final record = await env.recordFor(id, '2026-11-02');

      await env.records.setStatus(record.id, TaskStatus.skipped);
      await env.notifications.sync();

      expect(datesOf(ReminderKind.reminder).first, '2026-11-03');
    });

    test('un-checking a task brings its reminder back', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final record = await env.recordFor(id, '2026-11-02');
      await env.records.setStatus(record.id, TaskStatus.completed);
      await env.notifications.sync();

      await env.records.setStatus(record.id, TaskStatus.pending);
      await env.notifications.sync();

      expect(datesOf(ReminderKind.reminder).first, '2026-11-02');
    });

    test(
      'editing the time moves the existing notification, no duplicates',
      () async {
        final id = await env.addRoutine(reminderMinutes: 600);
        await startOfDay();
        final before = env.gateway.scheduled.length;
        final routine = (await env.routines.getById(id))!;

        await env.routines.update(
          id,
          RoutineDraft(
            title: routine.title,
            categoryId: routine.categoryId,
            reminderMinutes: 660,
          ),
        );
        await env.notifications.sync();

        expect(env.gateway.scheduled.length, before);
        final today = env.gateway
            .ofKind(ReminderKind.reminder)
            .firstWhere((n) => n.dateKey == '2026-11-02');
        expect(today.when, DateTime(2026, 11, 2, 11));
      },
    );

    test('renaming updates the notification text', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final routine = (await env.routines.getById(id))!;

      await env.routines.update(
        id,
        RoutineDraft(
          title: 'Hydrate',
          categoryId: routine.categoryId,
          reminderMinutes: 600,
        ),
      );
      await env.notifications.sync();

      expect(
        env.gateway.scheduled.values.every((n) => n.title == 'Hydrate'),
        isTrue,
      );
    });

    test('removing the reminder time cancels everything', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final routine = (await env.routines.getById(id))!;

      await env.routines.update(
        id,
        RoutineDraft(title: routine.title, categoryId: routine.categoryId),
      );
      await env.notifications.sync();

      expect(env.gateway.scheduled, isEmpty);
    });

    test('archiving a routine cancels its notifications', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await env.addRoutine(title: 'Other', reminderMinutes: 700);
      await startOfDay();

      await env.routines.archive(id);
      await env.notifications.sync();

      expect(
        env.gateway.scheduled.values.every((n) => n.routineId != id),
        isTrue,
      );
      expect(env.gateway.scheduled, isNotEmpty);
    });

    test('pausing cancels, resuming schedules again', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();

      await env.routines.setEnabled(id, false);
      await env.notifications.sync();
      expect(env.gateway.scheduled, isEmpty);

      await env.routines.setEnabled(id, true);
      await env.notifications.sync();
      expect(count(ReminderKind.reminder), 14);
    });

    test('master switch off cancels everything, on restores it', () async {
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();

      await env.settings.setNotificationsEnabled(false);
      await env.notifications.sync();
      expect(env.gateway.scheduled, isEmpty);

      await env.settings.setNotificationsEnabled(true);
      await env.notifications.sync();
      expect(count(ReminderKind.reminder), 14);
    });

    test('follow-ups can be turned off', () async {
      await env.addRoutine(reminderMinutes: 600);
      await env.settings.setFollowUpEnabled(false);
      await startOfDay();

      expect(count(ReminderKind.followUp), 0);
      expect(count(ReminderKind.reminder), 14);
    });

    test('sound and vibration changes reach existing notifications', () async {
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();

      await env.settings.setSoundEnabled(false);
      await env.settings.setVibrationEnabled(false);
      final report = await env.notifications.sync();

      expect(report.scheduled, env.gateway.scheduled.length);
      expect(
        env.gateway.scheduled.values.every((n) => !n.sound && !n.vibration),
        isTrue,
      );
    });

    test('a timezone change reschedules everything', () async {
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final total = env.gateway.scheduled.length;

      env.gateway.timezone = 'America/New_York';
      final report = await env.notifications.sync();

      expect(report.scheduled, total);
      expect(
        env.gateway.scheduled.values.every(
          (n) => n.timezone == 'America/New_York',
        ),
        isTrue,
      );
    });

    test('granting exact alarms upgrades existing notifications', () async {
      env.gateway.exact = false;
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      expect(env.gateway.scheduled.values.every((n) => !n.exact), isTrue);

      env.gateway.exact = true;
      await env.notifications.sync();

      expect(env.gateway.scheduled.values.every((n) => n.exact), isTrue);
    });

    test('a new day drops yesterday and plans the new window', () async {
      await env.addRoutine(reminderMinutes: 600);
      await startOfDay();

      env.now = DateTime(2026, 11, 3, 7);
      await startOfDay();

      expect(
        env.gateway.scheduled.values.every(
          (n) => n.dateKey.compareTo('2026-11-03') >= 0,
        ),
        isTrue,
      );
      expect(count(ReminderKind.reminder), 14);
      expect(datesOf(ReminderKind.reminder).last, '2026-11-16');
    });

    test('one failing notification does not block the rest', () async {
      await env.addRoutine(reminderMinutes: 600);
      env.gateway.failingIds.add(
        NotificationIds.encode(
          routineId: 1,
          dateKey: '2026-11-03',
          kind: ReminderKind.reminder,
        ),
      );
      await env.reconciler.reconcile(env.now);

      final report = await env.notifications.sync();

      expect(report.failed, 1);
      expect(env.gateway.scheduled.length, report.scheduled);
      expect(count(ReminderKind.reminder), 13);
    });
  });

  group('delivered notifications', () {
    test('are dismissed once the task is completed', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final reminderId = NotificationIds.encode(
        routineId: id,
        dateKey: '2026-11-02',
        kind: ReminderKind.reminder,
      );
      env.gateway.fire(reminderId);
      await env.notifications.sync();
      expect(env.gateway.active, {reminderId}, reason: 'still pending: keep');

      final record = await env.recordFor(id, '2026-11-02');
      await env.records.setStatus(record.id, TaskStatus.completed);
      await env.notifications.sync();

      expect(env.gateway.active, isEmpty);
    });

    test('from a past day are dismissed', () async {
      final id = await env.addRoutine(reminderMinutes: 600);
      await startOfDay();
      final yesterday = NotificationIds.encode(
        routineId: id,
        dateKey: '2026-11-02',
        kind: ReminderKind.reminder,
      );
      env.gateway.fire(yesterday);

      env.now = DateTime(2026, 11, 3, 7);
      await startOfDay();

      expect(env.gateway.active, isEmpty);
    });
  });

  group('snooze', () {
    test('uses the global default and replaces the follow-up', () async {
      final id = await env.addRoutine(reminderMinutes: 480); // 08:00, passed
      await startOfDay();
      final record = await env.recordFor(id, '2026-11-02');

      final until = await env.notifications.snooze(record.id);

      expect(until, DateTime(2026, 11, 2, 9, 10));
      final snooze = env.gateway.ofKind(ReminderKind.snooze).single;
      expect(snooze.when, DateTime(2026, 11, 2, 9, 10));
      expect(snooze.dateKey, '2026-11-02');
      final followUp = env.gateway
          .ofKind(ReminderKind.followUp)
          .firstWhere((n) => n.dateKey == '2026-11-02');
      expect(followUp.when, DateTime(2026, 11, 2, 9, 40));
    });

    test('uses the task snooze length when set', () async {
      final id = await env.addRoutine(reminderMinutes: 480, snoozeMinutes: 5);
      await startOfDay();
      final record = await env.recordFor(id, '2026-11-02');

      final until = await env.notifications.snooze(record.id);

      expect(until, DateTime(2026, 11, 2, 9, 5));
    });

    test('uses the configured default length', () async {
      final id = await env.addRoutine(reminderMinutes: 480);
      await env.settings.setDefaultSnoozeMinutes(20);
      await startOfDay();
      final record = await env.recordFor(id, '2026-11-02');

      expect(
        await env.notifications.snooze(record.id),
        DateTime(2026, 11, 2, 9, 20),
      );
    });

    test(
      'completing a snoozed task cancels the snooze and follow-up',
      () async {
        final id = await env.addRoutine(reminderMinutes: 480);
        await startOfDay();
        final record = await env.recordFor(id, '2026-11-02');
        await env.notifications.snooze(record.id);

        await env.records.setStatus(record.id, TaskStatus.completed);
        await env.notifications.sync();

        expect(count(ReminderKind.snooze), 0);
        expect(
          env.gateway.scheduled.values.every((n) => n.dateKey != '2026-11-02'),
          isTrue,
        );
      },
    );

    test('is rejected for anytime, completed and past records', () async {
      final anytime = await env.addRoutine(
        title: 'Anytime',
        reminderMinutes: null,
      );
      final timed = await env.addRoutine(title: 'Timed', reminderMinutes: 480);
      await startOfDay();
      final anytimeRecord = await env.recordFor(anytime, '2026-11-02');
      final timedRecord = await env.recordFor(timed, '2026-11-02');

      await expectLater(
        env.notifications.snooze(anytimeRecord.id),
        throwsA(isA<InvalidRecordStateException>()),
      );

      await env.records.setStatus(timedRecord.id, TaskStatus.completed);
      await expectLater(
        env.notifications.snooze(timedRecord.id),
        throwsA(isA<InvalidRecordStateException>()),
      );

      env.now = DateTime(2026, 11, 3, 9);
      await env.reconciler.reconcile(env.now);
      await expectLater(
        env.notifications.snooze(anytimeRecord.id),
        throwsA(isA<InvalidRecordStateException>()),
        reason: 'anytime check comes first',
      );
      await expectLater(
        env.notifications.snooze(999),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('permissions', () {
    test('requesting asks for exact alarms when missing', () async {
      env.gateway
        ..notificationsAllowed = false
        ..exact = false;

      final status = await env.notifications.requestPermissions();

      expect(status.notificationsAllowed, isTrue);
      expect(status.exactAlarmsAllowed, isFalse);
      expect(env.gateway.exactPermissionRequests, 1);
    });

    test('a denied notification permission skips the exact request', () async {
      env.gateway
        ..notificationsAllowed = false
        ..grantOnRequest = false
        ..exact = false;

      final status = await env.notifications.requestPermissions();

      expect(status.notificationsAllowed, isFalse);
      expect(env.gateway.exactPermissionRequests, 0);
    });
  });
}
