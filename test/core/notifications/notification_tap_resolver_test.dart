import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/notification_tap_resolver.dart';
import 'package:ticky/core/notifications/planned_notification.dart';
import 'package:ticky/core/notifications/notification_ids.dart';

import '../../support/test_env.dart';

String payloadFor(int routineId, String dateKey) => ReminderPayload(
  routineId: routineId,
  dateKey: dateKey,
  fingerprint: 'abc12345',
).encode();

DailyTaskRecord record({
  int id = 7,
  TaskStatus status = TaskStatus.pending,
  String title = 'Drink water',
}) => DailyTaskRecord(
  id: id,
  routineTaskId: 1,
  dateKey: '2026-11-02',
  titleSnapshot: title,
  scheduledMinutes: 480,
  status: status,
  completedAt: status == TaskStatus.completed
      ? DateTime.utc(2026, 11, 2)
      : null,
);

void main() {
  group('with stand-in data', () {
    final calls = <String>[];
    DailyTaskRecord? stored;
    Object? completeError;

    NotificationTapResolver resolver() => NotificationTapResolver(
      findRecord: (routineId, dateKey) async {
        calls.add('find:$routineId:$dateKey');
        return stored;
      },
      complete: (id) async {
        calls.add('complete:$id');
        if (completeError != null) throw completeError!;
      },
      snooze: (id) async {
        calls.add('snooze:$id');
        return DateTime(2026, 11, 2, 9, 10);
      },
    );

    setUp(() {
      calls.clear();
      stored = record();
      completeError = null;
    });

    test('a tap on the notification opens that task', () async {
      final outcome = await resolver().resolve(
        NotificationTap(payload: payloadFor(1, '2026-11-02')),
      );

      expect(outcome, isA<OpenTask>());
      expect((outcome as OpenTask).recordId, 7);
      expect(calls, ['find:1:2026-11-02'], reason: 'nothing else is done');
    });

    test('an unknown button just opens the task', () async {
      final outcome = await resolver().resolve(
        NotificationTap(payload: payloadFor(1, '2026-11-02'), actionId: 'wat'),
      );
      expect(outcome, isA<OpenTask>());
    });

    test('"Done" completes the task', () async {
      final outcome = await resolver().resolve(
        NotificationTap(
          payload: payloadFor(1, '2026-11-02'),
          actionId: notificationActionDone,
        ),
      );

      expect(outcome, isA<MarkedDone>());
      expect((outcome as MarkedDone).title, 'Drink water');
      expect(calls, ['find:1:2026-11-02', 'complete:7']);
    });

    test('"Done" on a task that is already done does nothing twice', () async {
      stored = record(status: TaskStatus.completed);

      final outcome = await resolver().resolve(
        NotificationTap(
          payload: payloadFor(1, '2026-11-02'),
          actionId: notificationActionDone,
        ),
      );

      expect(outcome, isA<MarkedDone>());
      expect(calls, ['find:1:2026-11-02'], reason: 'no second completion');
    });

    test('"Snooze" snoozes the task and reports when it returns', () async {
      final outcome = await resolver().resolve(
        NotificationTap(
          payload: payloadFor(1, '2026-11-02'),
          actionId: notificationActionSnooze,
        ),
      );

      expect(outcome, isA<Snoozed>());
      expect((outcome as Snoozed).until, DateTime(2026, 11, 2, 9, 10));
      expect(outcome.title, 'Drink water');
      expect(calls, ['find:1:2026-11-02', 'snooze:7']);
    });

    test('a task that no longer exists is reported, not opened', () async {
      stored = null;

      final outcome = await resolver().resolve(
        NotificationTap(payload: payloadFor(1, '2026-11-02')),
      );

      expect(outcome, isA<TaskGone>());
    });

    test('a button on a task that is gone does nothing', () async {
      stored = null;

      final outcome = await resolver().resolve(
        NotificationTap(
          payload: payloadFor(1, '2026-11-02'),
          actionId: notificationActionDone,
        ),
      );

      expect(outcome, isA<TaskGone>());
      expect(calls, ['find:1:2026-11-02']);
    });

    test('a refusal comes back as a readable message', () async {
      completeError = const ReadOnlyDayException('Past days are read-only');

      final outcome = await resolver().resolve(
        NotificationTap(
          payload: payloadFor(1, '2026-11-02'),
          actionId: notificationActionDone,
        ),
      );

      expect(outcome, isA<TapFailed>());
      expect((outcome as TapFailed).message, 'Past days are read-only');
    });

    test('anything that is not a Ticky reminder is ignored', () async {
      for (final payload in [
        null,
        '',
        'hello',
        'ticky1|x|2026-11-02|f',
        'ticky2|1|2026-11-02|f',
      ]) {
        final outcome = await resolver().resolve(
          NotificationTap(payload: payload),
        );
        expect(outcome, isA<TapIgnored>(), reason: '$payload');
      }
      expect(calls, isEmpty, reason: 'the database is never asked');
    });
  });

  group('with a real database', () {
    late TestEnv env;
    late NotificationTapResolver resolver;

    setUp(() {
      env = TestEnv();
      resolver = NotificationTapResolver(
        findRecord: env.records.getByRoutineAndDate,
        complete: (id) => env.records.setStatus(id, TaskStatus.completed),
        snooze: env.notifications.snooze,
      );
    });
    tearDown(() => env.close());

    /// The payload of a notification the app itself scheduled.
    Future<String> scheduledPayload(int routineId) async {
      await env.notifications.sync();
      final planned = env.gateway.scheduled.values.firstWhere(
        (n) => n.routineId == routineId,
      );
      return planned.payload;
    }

    test('a scheduled reminder opens exactly its own task', () async {
      env.now = DateTime(2026, 11, 2, 7);
      final water = await env.addRoutine(title: 'Water', reminderMinutes: 480);
      await env.addRoutine(title: 'Stretch', reminderMinutes: 540);

      final outcome = await resolver.resolve(
        NotificationTap(payload: await scheduledPayload(water)),
      );

      final expected = await env.recordFor(water, '2026-11-02');
      expect((outcome as OpenTask).recordId, expected.id);
    });

    test(
      '"Done" from a real notification completes the task and pays coins',
      () async {
        env.now = DateTime(2026, 11, 2, 7);
        final id = await env.addRoutine(reminderMinutes: 480);
        final payload = await scheduledPayload(id);

        final outcome = await resolver.resolve(
          NotificationTap(payload: payload, actionId: notificationActionDone),
        );

        expect(outcome, isA<MarkedDone>());
        final record = await env.recordFor(id, '2026-11-02');
        expect(record.status, TaskStatus.completed);
        expect(await env.rewards.getBalance(), greaterThan(0));
      },
    );

    test(
      '"Snooze" from a real notification reschedules the reminder',
      () async {
        env.now = DateTime(2026, 11, 2, 8, 1);
        final id = await env.addRoutine(reminderMinutes: 480);
        env.now = DateTime(2026, 11, 2, 8);
        final payload = await scheduledPayload(id);
        env.now = DateTime(2026, 11, 2, 8, 1);

        final outcome = await resolver.resolve(
          NotificationTap(payload: payload, actionId: notificationActionSnooze),
        );

        expect(outcome, isA<Snoozed>());
        final snoozed = env.gateway.ofKind(ReminderKind.snooze);
        expect(snoozed, hasLength(1));
        expect(snoozed.single.when.isAfter(env.now), isTrue);
      },
    );

    test(
      'a notification for a deleted routine says the task is gone',
      () async {
        env.now = DateTime(2026, 11, 2, 7);
        final id = await env.addRoutine(reminderMinutes: 480);
        final payload = await scheduledPayload(id);
        await env.routines.archive(id);

        final outcome = await resolver.resolve(
          NotificationTap(payload: payload),
        );

        expect(outcome, isA<TaskGone>());
      },
    );

    test('yesterday\'s notification still opens yesterday\'s record', () async {
      env.now = DateTime(2026, 11, 2, 7);
      final id = await env.addRoutine(reminderMinutes: 480);
      final payload = await scheduledPayload(id);
      final yesterdayRecord = await env.recordFor(id, '2026-11-02');
      env.now = DateTime(2026, 11, 3, 7);
      await env.reconciler.reconcile(env.now);

      final outcome = await resolver.resolve(NotificationTap(payload: payload));

      expect((outcome as OpenTask).recordId, yesterdayRecord.id);
    });

    test(
      '"Done" from yesterday\'s notification is refused, not applied',
      () async {
        env.now = DateTime(2026, 11, 2, 7);
        final id = await env.addRoutine(reminderMinutes: 480);
        final payload = await scheduledPayload(id);
        env.now = DateTime(2026, 11, 3, 7);
        await env.reconciler.reconcile(env.now);

        final outcome = await resolver.resolve(
          NotificationTap(payload: payload, actionId: notificationActionDone),
        );

        expect(outcome, isA<TapFailed>());
        expect((outcome as TapFailed).message, 'Past days are read-only');
        expect(
          (await env.recordFor(id, '2026-11-02')).status,
          isNot(TaskStatus.completed),
        );
      },
    );

    test(
      'every kind of reminder carries a payload that opens the task',
      () async {
        env.now = DateTime(2026, 11, 2, 7, 30);
        final id = await env.addRoutine(reminderMinutes: 480);
        await env.notifications.sync();

        final kinds = env.gateway.scheduled.values
            .where((n) => n.routineId == id && n.dateKey == '2026-11-02')
            .map((n) => n.kind)
            .toSet();
        expect(
          kinds,
          containsAll([ReminderKind.reminder, ReminderKind.followUp]),
        );
        for (final planned in env.gateway.scheduled.values.where(
          (n) => n.routineId == id && n.dateKey == '2026-11-02',
        )) {
          final outcome = await resolver.resolve(
            NotificationTap(payload: planned.payload),
          );
          expect(outcome, isA<OpenTask>(), reason: '${planned.kind}');
        }
      },
    );
  });
}
