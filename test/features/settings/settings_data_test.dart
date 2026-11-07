import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/features/character/models/mascot_assets.dart';
import 'package:ticky/features/character/models/mascot_mood.dart';
import 'package:ticky/features/rewards/models/shop_item.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/tasks/models/routine_draft.dart';

import '../../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() => env = TestEnv());
  tearDown(() => env.close());

  /// Gives the player [amount] coins without completing tasks.
  Future<void> grantCoins(int amount) async {
    await env.db
        .into(env.db.rewardEvents)
        .insert(
          RewardEventsCompanion.insert(
            uniqueKey:
                'test:grant:$amount:${DateTime.now().microsecondsSinceEpoch}',
            type: RewardType.taskComplete,
            amount: amount,
          ),
        );
  }

  group('notification preferences', () {
    test('start with everything on and a 10 minute snooze', () async {
      final prefs = await env.settings.getNotificationPrefs();

      expect(prefs.notificationsEnabled, isTrue);
      expect(prefs.soundEnabled, isTrue);
      expect(prefs.vibrationEnabled, isTrue);
      expect(prefs.followUpEnabled, isTrue);
      expect(prefs.defaultSnoozeMinutes, NotificationPrefs.defaultSnooze);
    });

    test('each switch is saved on its own', () async {
      await env.settings.setSoundEnabled(false);
      await env.settings.setFollowUpEnabled(false);

      final prefs = await env.settings.getNotificationPrefs();
      expect(prefs.soundEnabled, isFalse);
      expect(prefs.followUpEnabled, isFalse);
      expect(prefs.vibrationEnabled, isTrue);
      expect(prefs.notificationsEnabled, isTrue);
    });

    test('watching emits again whenever a preference changes', () async {
      final seen = <NotificationPrefs>[];
      final sub = env.settings.watchNotificationPrefs().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await env.settings.setNotificationsEnabled(false);
      await pumpEventQueue();
      await env.settings.setDefaultSnoozeMinutes(30);
      await pumpEventQueue();

      expect(seen.first.notificationsEnabled, isTrue);
      expect(seen.last.notificationsEnabled, isFalse);
      expect(seen.last.defaultSnoozeMinutes, 30);
    });

    test('a snooze must be positive', () {
      expect(
        () => env.settings.setDefaultSnoozeMinutes(0),
        throwsArgumentError,
      );
    });
  });

  group('theme mode', () {
    test('follows the system until the user chooses', () async {
      expect(await env.settings.getThemeMode(), ThemeMode.system);
    });

    test('each choice is saved and read back', () async {
      for (final mode in ThemeMode.values) {
        await env.settings.setThemeMode(mode);
        expect(await env.settings.getThemeMode(), mode);
      }
    });

    test('an unknown stored value falls back to the system', () async {
      await env.db
          .into(env.db.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'themeMode', value: 'sepia'),
          );
      expect(await env.settings.getThemeMode(), ThemeMode.system);
    });

    test(
      'the controller loads the saved choice before the first frame',
      () async {
        await env.settings.setThemeMode(ThemeMode.dark);
        final container = ProviderContainer(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(env.settings),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(themeModeProvider), ThemeMode.system);
        await container.read(themeModeProvider.notifier).load();
        expect(container.read(themeModeProvider), ThemeMode.dark);
      },
    );

    test('selecting switches at once and saves', () async {
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(env.settings)],
      );
      addTearDown(container.dispose);

      final saving = container
          .read(themeModeProvider.notifier)
          .select(ThemeMode.light);
      expect(
        container.read(themeModeProvider),
        ThemeMode.light,
        reason: 'no wait for the database',
      );
      await saving;
      expect(await env.settings.getThemeMode(), ThemeMode.light);
    });
  });

  group('equipped item setting', () {
    test('is empty by default, can be set, and cleared again', () async {
      expect(await env.settings.getEquippedMascotItem(), isNull);

      await env.settings.setEquippedMascotItem('pose_relax');
      expect(await env.settings.getEquippedMascotItem(), 'pose_relax');

      await env.settings.setEquippedMascotItem(null);
      expect(await env.settings.getEquippedMascotItem(), isNull);
    });

    test('watching follows the setting', () async {
      final seen = <String?>[];
      final sub = env.settings.watchEquippedMascotItem().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await env.settings.setEquippedMascotItem('pose_cheer');
      await pumpEventQueue();
      await env.settings.setEquippedMascotItem(null);
      await pumpEventQueue();

      expect(seen, [null, 'pose_cheer', null]);
    });
  });

  group('routine order', () {
    test('reorder sets the manual order', () async {
      final a = await env.addRoutine(title: 'A');
      final b = await env.addRoutine(title: 'B');
      final c = await env.addRoutine(title: 'C');

      await env.routines.reorder([c, a, b]);

      final list = await env.routines.watchActive().first;
      expect(list.map((r) => r.title), ['C', 'A', 'B']);
      expect(list.map((r) => r.sortOrder), [0, 1, 2]);
    });

    test(
      'reorder skips deleted and unknown routines, keeping order dense',
      () async {
        final a = await env.addRoutine(title: 'A');
        final b = await env.addRoutine(title: 'B');
        final gone = await env.addRoutine(title: 'Gone');
        await env.routines.archive(gone);

        await env.routines.reorder([b, gone, 999, a]);

        final list = await env.routines.watchActive().first;
        expect(list.map((r) => r.title), ['B', 'A']);
        expect(list.map((r) => r.sortOrder), [0, 1]);
      },
    );

    test('reorder changes nothing but the order', () async {
      final a = await env.addRoutine(title: 'A', reminderMinutes: 600);
      final b = await env.addRoutine(title: 'B');
      final before = (await env.routines.getById(a))!;

      await env.routines.reorder([b, a]);

      final after = (await env.routines.getById(a))!;
      expect(after.title, before.title);
      expect(after.reminderMinutes, before.reminderMinutes);
      expect(after.updatedAt, before.updatedAt);
      expect(await env.allRecords(), hasLength(2));
    });

    test('a new routine goes after the reordered ones', () async {
      final a = await env.addRoutine(title: 'A');
      final b = await env.addRoutine(title: 'B');
      await env.routines.reorder([b, a]);

      await env.routines.create(
        RoutineDraft(title: 'C', categoryId: await env.generalId()),
      );

      final list = await env.routines.watchActive().first;
      expect(list.map((r) => r.title), ['B', 'A', 'C']);
    });
  });

  group('history', () {
    Future<void> addDay(String dateKey, List<TaskStatus> statuses) async {
      for (final status in statuses) {
        final routine = await env.addRoutine(title: 'T$dateKey$status');
        // The routine also got today's record; add the past one directly.
        await env.db
            .into(env.db.dailyTaskRecords)
            .insert(
              DailyTaskRecordsCompanion.insert(
                routineTaskId: routine,
                dateKey: dateKey,
                titleSnapshot: 'Task',
                status: Value(status),
                completedAt: Value(
                  status == TaskStatus.completed
                      ? DateTime.utc(2026, 10, 30)
                      : null,
                ),
              ),
            );
      }
    }

    test('summarises each past day, newest first, without today', () async {
      await addDay('2026-10-30', [TaskStatus.completed, TaskStatus.missed]);
      await addDay('2026-11-01', [
        TaskStatus.completed,
        TaskStatus.completed,
        TaskStatus.skipped,
      ]);

      final days = await env.history.watchPastDays('2026-11-02').first;

      expect(days.map((d) => d.dateKey), ['2026-11-01', '2026-10-30']);
      final latest = days.first;
      expect(latest.completed, 2);
      expect(latest.skipped, 1);
      expect(latest.total, 3);
      expect(latest.isPerfect, isTrue);
      final earlier = days.last;
      expect(earlier.missed, 1);
      expect(earlier.undone, 1);
      expect(earlier.isPerfect, isFalse);
    });

    test('today is never listed, even though it has records', () async {
      await env.addRoutine();

      expect(await env.history.watchPastDays('2026-11-02').first, isEmpty);
    });

    test('a day with only skipped tasks is not perfect', () async {
      await addDay('2026-11-01', [TaskStatus.skipped]);

      final day = (await env.history.watchPastDays('2026-11-02').first).single;
      expect(day.isPerfect, isFalse);
    });

    test('the limit caps how many days come back', () async {
      for (var d = 1; d <= 5; d++) {
        await addDay('2026-10-0$d', [TaskStatus.completed]);
      }

      final days = await env.history
          .watchPastDays('2026-11-02', limit: 3)
          .first;

      expect(days.map((d) => d.dateKey), [
        '2026-10-05',
        '2026-10-04',
        '2026-10-03',
      ]);
    });
  });

  group('shop', () {
    test('every item uses a pose that exists, at a unique price and key', () {
      expect(shopItems.map((i) => i.key).toSet(), hasLength(shopItems.length));
      expect(
        shopItems.map((i) => i.price),
        orderedEquals([...shopItems.map((i) => i.price)]..sort()),
      );
      for (final item in shopItems) {
        expect(item.price, greaterThan(0));
        expect(MascotAssets.poses, contains(item.pose));
        expect(File(item.asset).existsSync(), isTrue, reason: item.asset);
      }
      expect(File(MascotAssets.classicIdle).existsSync(), isTrue);
    });

    test('shopItemFor finds items and ignores unknown keys', () {
      expect(shopItemFor('pose_relax')?.name, 'Relaxed');
      expect(shopItemFor('nope'), isNull);
      expect(shopItemFor(null), isNull);
    });

    test(
      'buying spends coins, unlocks the item and puts it on Ticky',
      () async {
        await grantCoins(50);
        final item = shopItemFor('pose_relax')!;

        await env.shop.buy(item);

        expect(await env.rewards.getBalance(), 50 - item.price);
        expect(await env.rewards.getUnlockedItemKeys(), {'pose_relax'});
        expect(await env.settings.getEquippedMascotItem(), 'pose_relax');
      },
    );

    test('buying without enough coins changes nothing', () async {
      await grantCoins(10);
      final item = shopItemFor('pose_relax')!;

      await expectLater(
        env.shop.buy(item),
        throwsA(isA<InsufficientCoinsException>()),
      );

      expect(await env.rewards.getBalance(), 10);
      expect(await env.rewards.getUnlockedItemKeys(), isEmpty);
      expect(await env.settings.getEquippedMascotItem(), isNull);
    });

    test('an item cannot be bought twice', () async {
      await grantCoins(100);
      final item = shopItemFor('pose_relax')!;
      await env.shop.buy(item);

      await expectLater(
        env.shop.buy(item),
        throwsA(isA<ItemAlreadyUnlockedException>()),
      );
      expect(await env.rewards.getBalance(), 100 - item.price);
    });

    test('switching between bought items, and back to the default', () async {
      await grantCoins(200);
      await env.shop.buy(shopItemFor('pose_relax')!);
      await env.shop.buy(shopItemFor('pose_cheer')!);
      expect(await env.settings.getEquippedMascotItem(), 'pose_cheer');

      await env.shop.equip('pose_relax');
      expect(await env.settings.getEquippedMascotItem(), 'pose_relax');

      await env.shop.equip(null);
      expect(await env.settings.getEquippedMascotItem(), isNull);
    });

    test('an item that was not bought cannot be worn', () async {
      await expectLater(
        env.shop.equip('pose_running'),
        throwsA(isA<ItemNotOwnedException>()),
      );
      expect(await env.settings.getEquippedMascotItem(), isNull);
    });
  });

  group('idle pose', () {
    ProviderContainer containerWith({String? equipped, Set<String>? owned}) {
      final container = ProviderContainer(
        overrides: [
          equippedItemKeyProvider.overrideWith((ref) => Stream.value(equipped)),
          unlockedItemKeysProvider.overrideWith(
            (ref) => Stream.value(owned ?? const {}),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
        ..listen(equippedItemKeyProvider, (_, _) {})
        ..listen(unlockedItemKeysProvider, (_, _) {});
      return container;
    }

    test('is the equipped, bought item', () async {
      final container = containerWith(
        equipped: 'pose_cheer',
        owned: {'pose_cheer'},
      );
      await pumpEventQueue();

      expect(container.read(idlePoseProvider), 'cheer');
    });

    test('is none when nothing is equipped', () async {
      final container = containerWith(owned: {'pose_cheer'});
      await pumpEventQueue();

      expect(container.read(idlePoseProvider), isNull);
    });

    test('is none for an item that was not bought', () async {
      final container = containerWith(equipped: 'pose_cheer', owned: {});
      await pumpEventQueue();

      expect(container.read(idlePoseProvider), isNull);
    });

    test('is none for an item the catalog no longer has', () async {
      final container = containerWith(equipped: 'old_hat', owned: {'old_hat'});
      await pumpEventQueue();

      expect(container.read(idlePoseProvider), isNull);
    });
  });

  group('mascot pictures', () {
    test('the idle mood wears the pose, every other mood ignores it', () {
      expect(
        MascotAssets.pathFor(MascotMood.idle, idlePose: 'relax'),
        MascotAssets.poseAsset('relax'),
      );
      for (final mood in MascotMood.values.where((m) => m != MascotMood.idle)) {
        expect(
          MascotAssets.pathFor(mood, idlePose: 'relax'),
          MascotAssets.pathFor(mood),
          reason: '$mood keeps its own picture',
        );
      }
    });

    test('an unknown pose falls back to the plain idle picture', () {
      expect(
        MascotAssets.pathFor(MascotMood.idle, idlePose: 'moonwalk'),
        MascotAssets.classicIdle,
      );
      expect(MascotAssets.pathFor(MascotMood.idle), MascotAssets.classicIdle);
    });

    test('every pose picture is in the asset pack', () {
      for (final pose in MascotAssets.poses) {
        expect(File(MascotAssets.poseAsset(pose)).existsSync(), isTrue);
      }
    });
  });
}
