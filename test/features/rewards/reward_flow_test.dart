import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  Future<int> recordIdOf(int routineId) async =>
      (await env.recordFor(routineId, '2026-11-02')).id;

  Future<void> setStatus(int routineId, TaskStatus status) async {
    await env.records.setStatus(await recordIdOf(routineId), status);
  }

  group('coins', () {
    test(
      'completing awards by priority, no perfect day while pending',
      () async {
        final high = await env.addRoutine(title: 'A', priority: Priority.high);
        await env.addRoutine(title: 'B');
        await env.reconciler.reconcile(env.now);

        await setStatus(high, TaskStatus.completed);

        expect(await env.rewards.getBalance(), 3);
      },
    );

    test('perfect day adds the bonus when everything is done', () async {
      final a = await env.addRoutine(title: 'A', priority: Priority.low);
      final b = await env.addRoutine(title: 'B', priority: Priority.medium);
      await env.reconciler.reconcile(env.now);

      await setStatus(a, TaskStatus.completed);
      await setStatus(b, TaskStatus.completed);

      expect(await env.rewards.getBalance(), 1 + 2 + 5);
    });

    test(
      'completed plus skipped is a perfect day, skipped earns nothing',
      () async {
        final a = await env.addRoutine(title: 'A', priority: Priority.low);
        final b = await env.addRoutine(title: 'B', priority: Priority.high);
        await env.reconciler.reconcile(env.now);

        await setStatus(a, TaskStatus.completed);
        await setStatus(b, TaskStatus.skipped);

        expect(await env.rewards.getBalance(), 1 + 5);
      },
    );

    test('only skipped records never pay a perfect day', () async {
      final a = await env.addRoutine();
      await env.reconciler.reconcile(env.now);

      await setStatus(a, TaskStatus.skipped);

      expect(await env.rewards.getBalance(), 0);
      expect(await env.allRewards(), isEmpty);
    });

    test('uncheck revokes, re-check reuses the row, no farming', () async {
      final a = await env.addRoutine(priority: Priority.high);
      await env.reconciler.reconcile(env.now);

      for (var i = 0; i < 3; i++) {
        await setStatus(a, TaskStatus.completed);
        expect(await env.rewards.getBalance(), 3 + 5);
        await setStatus(a, TaskStatus.pending);
        expect(await env.rewards.getBalance(), 0);
      }

      final rewards = await env.allRewards();
      expect(rewards.map((r) => r.uniqueKey).toSet(), hasLength(2));
      expect(rewards, hasLength(2));
      expect(rewards.every((r) => r.revokedAt != null), isTrue);
    });

    test('new pending routine revokes an earned perfect day', () async {
      final a = await env.addRoutine(priority: Priority.low);
      await env.reconciler.reconcile(env.now);
      await setStatus(a, TaskStatus.completed);
      expect(await env.rewards.getBalance(), 1 + 5);

      await env.addRoutine(title: 'Late addition');

      expect(await env.rewards.getBalance(), 1);
    });

    test('completed record stores completedAt, clears it on undo', () async {
      final a = await env.addRoutine();
      await env.reconciler.reconcile(env.now);

      await setStatus(a, TaskStatus.completed);
      expect((await env.recordFor(a, '2026-11-02')).completedAt, isNotNull);

      await setStatus(a, TaskStatus.pending);
      expect((await env.recordFor(a, '2026-11-02')).completedAt, isNull);
    });
  });

  group('read-only past days', () {
    test('past records cannot change', () async {
      final a = await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      final recordId = await recordIdOf(a);

      env.now = DateTime(2026, 11, 3, 8);
      await env.reconciler.reconcile(env.now);

      expect(
        env.records.setStatus(recordId, TaskStatus.completed),
        throwsA(isA<ReadOnlyDayException>()),
      );
    });

    test('missed cannot be set by the user', () async {
      final a = await env.addRoutine();
      await env.reconciler.reconcile(env.now);
      final recordId = await recordIdOf(a);

      expect(
        () => env.records.setStatus(recordId, TaskStatus.missed),
        throwsArgumentError,
      );
    });

    test('unknown record is not found', () {
      expect(
        env.records.setStatus(999, TaskStatus.completed),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('checklist query', () {
    test('orders timed tasks first by time, anytime last', () async {
      await env.addRoutine(title: 'Anytime', reminderMinutes: null);
      await env.addRoutine(title: 'Late', reminderMinutes: 1200);
      await env.addRoutine(title: 'Early', reminderMinutes: 300);
      await env.reconciler.reconcile(env.now);

      final entries = await env.records.getForDate('2026-11-02');

      expect(entries.map((e) => e.record.titleSnapshot), [
        'Early',
        'Late',
        'Anytime',
      ]);
    });
  });

  group('spending', () {
    Future<void> earn(int coins) async {
      // high = 3 coins; a single routine also pays the 5 coin perfect day.
      final id = await env.addRoutine(priority: Priority.high);
      await env.reconciler.reconcile(env.now);
      await setStatus(id, TaskStatus.completed);
      expect(await env.rewards.getBalance(), coins);
    }

    test('unlock deducts coins and records the item', () async {
      await earn(8);

      await env.rewards.unlockItem('hat', 5);

      expect(await env.rewards.getBalance(), 3);
      expect(await env.rewards.watchUnlockedItemKeys().first, {'hat'});
    });

    test('insufficient balance is rejected without side effects', () async {
      await earn(8);

      await expectLater(
        env.rewards.unlockItem('crown', 9),
        throwsA(isA<InsufficientCoinsException>()),
      );

      expect(await env.rewards.getBalance(), 8);
      expect(await env.rewards.watchUnlockedItemKeys().first, isEmpty);
    });

    test('an item cannot be bought twice', () async {
      await earn(8);
      await env.rewards.unlockItem('hat', 2);

      await expectLater(
        env.rewards.unlockItem('hat', 2),
        throwsA(isA<ItemAlreadyUnlockedException>()),
      );
      expect(await env.rewards.getBalance(), 6);
    });

    test('undo after spending clamps to 0 and blocks spending', () async {
      await earn(8);
      await env.rewards.unlockItem('hat', 8);
      final routine = (await env.records.getForDate('2026-11-02')).single;

      await env.records.setStatus(routine.record.id, TaskStatus.pending);

      expect(await env.rewards.getBalance(), 0);
      await expectLater(
        env.rewards.unlockItem('cape', 1),
        throwsA(isA<InsufficientCoinsException>()),
      );
    });
  });
}
