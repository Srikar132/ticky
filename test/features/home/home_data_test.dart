import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/home/providers/home_providers.dart';
import 'package:ticky/features/home/providers/notification_prompt_controller.dart';
import 'package:ticky/features/routine/data/streak_repository.dart';
import 'package:ticky/features/routine/models/streak.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  group('streak from the database', () {
    late StreakRepository streaks;

    setUp(() => streaks = StreakRepository(env.db));

    Future<void> completeAll() async {
      for (final entry in await env.records.getForDate(
        '${env.now.year}-${env.now.month.toString().padLeft(2, '0')}-${env.now.day.toString().padLeft(2, '0')}',
      )) {
        await env.records.setStatus(entry.record.id, TaskStatus.completed);
      }
    }

    Future<void> nextDay() async {
      env.now = DateTime(env.now.year, env.now.month, env.now.day + 1, 9);
      await env.reconciler.reconcile(env.now);
    }

    test('no history, no streak', () async {
      expect(await streaks.getCurrent('2026-11-02'), StreakInfo.none);
    });

    test('grows each day everything is completed', () async {
      await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      await completeAll();
      expect(
        await streaks.getCurrent('2026-11-02'),
        const StreakInfo(count: 1, includesToday: true),
      );

      await nextDay();
      expect(
        await streaks.getCurrent('2026-11-03'),
        const StreakInfo(count: 1, includesToday: false),
        reason: 'today pending: not counted yet, not broken',
      );
      await completeAll();
      expect(
        await streaks.getCurrent('2026-11-03'),
        const StreakInfo(count: 2, includesToday: true),
      );
    });

    test('a missed day breaks it', () async {
      await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      await completeAll();
      await nextDay(); // 11-03 left pending
      await nextDay(); // 11-03 becomes missed

      expect(await streaks.getCurrent('2026-11-04'), StreakInfo.none);
    });

    test('a day with only skipped tasks is neutral', () async {
      final id = await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      await completeAll();
      await nextDay();
      await env.records.setStatus(
        (await env.recordFor(id, '2026-11-03')).id,
        TaskStatus.skipped,
      );
      await nextDay();
      await completeAll();

      expect(
        await streaks.getCurrent('2026-11-04'),
        const StreakInfo(count: 2, includesToday: true),
      );
    });

    test('un-checking today removes it from the streak', () async {
      final id = await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      await completeAll();
      await env.records.setStatus(
        (await env.recordFor(id, '2026-11-02')).id,
        TaskStatus.pending,
      );

      expect(await streaks.getCurrent('2026-11-02'), StreakInfo.none);
    });

    test('watching re-emits when a record changes', () async {
      final id = await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      final stream = streaks.watchCurrent('2026-11-02');

      final expectation = expectLater(
        stream.map((s) => s.count),
        emitsInOrder([0, 1]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await env.records.setStatus(
        (await env.recordFor(id, '2026-11-02')).id,
        TaskStatus.completed,
      );
      await expectation;
    });
  });

  group('Home providers on a real database', () {
    ProviderContainer containerFor() {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(env.db),
          clockProvider.overrideWithValue(env.clock),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('today entries follow the database, in time order', () async {
      await env.addRoutine(title: 'Late', reminderMinutes: 1200);
      await env.addRoutine(title: 'Early', reminderMinutes: 300);
      await env.addRoutine(title: 'Anytime', reminderMinutes: null);
      await env.reconciler.reconcile(env.now);

      final container = containerFor()..listen(todayEntriesProvider, (_, _) {});
      final entries = await container.read(todayEntriesProvider.future);

      expect(entries.map((e) => e.record.titleSnapshot), [
        'Early',
        'Late',
        'Anytime',
      ]);
    });

    test('hasRoutines is false until a routine exists', () async {
      final container = containerFor()..listen(hasRoutinesProvider, (_, _) {});
      expect(await container.read(hasRoutinesProvider.future), isFalse);

      await env.addRoutine();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(hasRoutinesProvider).value, isTrue);
    });

    test('today key follows the clock', () async {
      final container = containerFor()..listen(todayKeyProvider, (_, _) {});

      expect(await container.read(todayKeyProvider.future), '2026-11-02');
    });
  });

  group('reminders prompt', () {
    ProviderContainer containerFor() {
      final container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(env.notifications),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          clockProvider.overrideWithValue(env.clock),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('due when permission is missing and never dismissed', () async {
      env.gateway.notificationsAllowed = false;

      expect(
        await containerFor().read(notificationPromptDueProvider.future),
        isTrue,
      );
    });

    test('not due when notifications are already allowed', () async {
      env.gateway.notificationsAllowed = true;

      expect(
        await containerFor().read(notificationPromptDueProvider.future),
        isFalse,
      );
    });

    test('after "maybe later" it waits a week', () async {
      env.gateway.notificationsAllowed = false;
      await env.settings.setNotificationPromptDismissedAt(
        env.now.subtract(const Duration(days: 6)),
      );
      expect(
        await containerFor().read(notificationPromptDueProvider.future),
        isFalse,
      );

      await env.settings.setNotificationPromptDismissedAt(
        env.now.subtract(const Duration(days: 7)),
      );
      expect(
        await containerFor().read(notificationPromptDueProvider.future),
        isTrue,
      );
    });

    test('dismissal time is stored as an instant and read back', () async {
      expect(await env.settings.getNotificationPromptDismissedAt(), isNull);

      final stamp = DateTime.utc(2026, 11, 2, 9, 30);
      await env.settings.setNotificationPromptDismissedAt(stamp);

      expect(await env.settings.getNotificationPromptDismissedAt(), stamp);
    });
  });

  group('prompt controller', () {
    late ProviderContainer container;

    PromptStep step() => container.read(notificationPromptControllerProvider);
    NotificationPromptController controller() =>
        container.read(notificationPromptControllerProvider.notifier);

    setUp(() {
      container = ProviderContainer(
        overrides: [
          notificationServiceProvider.overrideWithValue(env.notifications),
          settingsRepositoryProvider.overrideWithValue(env.settings),
          clockProvider.overrideWithValue(env.clock),
        ],
      );
      container.listen(notificationPromptControllerProvider, (_, _) {});
      addTearDown(container.dispose);
    });

    test('asks nothing until the user acts', () {
      env.gateway.notificationsAllowed = false;

      expect(step(), PromptStep.ask);
      expect(env.gateway.exactPermissionRequests, 0);
    });

    test('everything granted finishes', () async {
      env.gateway.notificationsAllowed = false;
      env.gateway.exact = true;

      await controller().enable();

      expect(step(), PromptStep.done);
    });

    test(
      'notifications granted but exact alarms missing is one more step',
      () async {
        env.gateway
          ..notificationsAllowed = false
          ..exact = false;

        await controller().enable();
        expect(step(), PromptStep.needsExact);

        env.gateway.exact = true;
        await controller().allowExactTiming();
        expect(step(), PromptStep.done);
        expect(env.gateway.exactPermissionRequests, 1);
      },
    );

    test('a refusal leads to the settings step, and recovers', () async {
      env.gateway
        ..notificationsAllowed = false
        ..grantOnRequest = false;

      await controller().enable();
      expect(step(), PromptStep.denied);

      // The user turns notifications on in system settings and comes back.
      env.gateway.notificationsAllowed = true;
      await controller().recheck();
      expect(step(), PromptStep.done);
    });

    test('recheck does nothing before the user has acted', () async {
      env.gateway.notificationsAllowed = true;

      await controller().recheck();

      expect(step(), PromptStep.ask);
    });
  });
}
