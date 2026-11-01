import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/reminder_coordinator.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;
  late ReminderCoordinator coordinator;

  setUp(() {
    env = TestEnv();
    coordinator = ReminderCoordinator(
      database: env.db,
      reconciler: env.reconciler,
      notifications: env.notifications,
      clock: env.clock,
      debounce: Duration.zero,
      observeLifecycle: false,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    await env.close();
  });

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue, reason: 'condition not met in time');
  }

  test('start reconciles the day and schedules reminders', () async {
    await env.addRoutine(reminderMinutes: 600);
    await env.db.delete(env.db.dailyTaskRecords).go(); // pretend: new day

    await coordinator.start();

    expect(await env.allRecords(), hasLength(1));
    expect(await env.settings.getLastReconciledDateKey(), '2026-11-02');
    expect(env.gateway.scheduled, isNotEmpty);
  });

  test('adding a routine schedules it without anyone calling sync', () async {
    await coordinator.start();
    expect(env.gateway.scheduled, isEmpty);

    await env.addRoutine(reminderMinutes: 600);

    await waitFor(() => env.gateway.scheduled.isNotEmpty);
  });

  test('completing a task cancels its reminder automatically', () async {
    final id = await env.addRoutine(reminderMinutes: 600);
    await coordinator.start();
    final today = env.gateway.scheduled.values.where(
      (n) => n.dateKey == '2026-11-02',
    );
    expect(today, isNotEmpty);

    final record = await env.recordFor(id, '2026-11-02');
    await env.records.setStatus(record.id, TaskStatus.completed);

    await waitFor(
      () =>
          env.gateway.scheduled.values.every((n) => n.dateKey != '2026-11-02'),
    );
  });

  test('deleting a routine cancels its reminders automatically', () async {
    final id = await env.addRoutine(reminderMinutes: 600);
    await coordinator.start();
    expect(env.gateway.scheduled, isNotEmpty);

    await env.routines.archive(id);

    await waitFor(() => env.gateway.scheduled.isEmpty);
  });

  test('settings changes are picked up', () async {
    await env.addRoutine(reminderMinutes: 600);
    await coordinator.start();
    expect(env.gateway.scheduled, isNotEmpty);

    await env.settings.setNotificationsEnabled(false);

    await waitFor(() => env.gateway.scheduled.isEmpty);
  });

  test('refresh after the date changes rolls the day over', () async {
    final id = await env.addRoutine(reminderMinutes: 600);
    await coordinator.start();

    env.now = DateTime(2026, 11, 3, 7);
    await coordinator.refresh();

    final yesterday = await env.recordFor(id, '2026-11-02');
    expect(yesterday.status, TaskStatus.missed);
    expect((await env.recordFor(id, '2026-11-03')).status, TaskStatus.pending);
  });
}
