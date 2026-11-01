import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/core/widgets/form_card.dart';
import 'package:ticky/features/categories/widgets/create_category_sheet.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';
import 'package:ticky/features/routine/data/history_repository.dart';
import 'package:ticky/features/settings/models/notification_prefs.dart';
import 'package:ticky/features/settings/screens/settings_screen.dart';
import 'package:ticky/features/tasks/screens/add_edit_task_screen.dart';
import 'package:ticky/features/tasks/screens/task_details_screen.dart';

import '../../support/home_test_support.dart';

/// Opens Settings on a tall phone so every section is on screen at once.
Future<void> openSettings(WidgetTester tester, List<Override> overrides) async {
  usePhoneScreen(tester);
  tester.view.physicalSize = const Size(1080, 9000);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.dark,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final health = category(id: 2, title: 'Health', iconKey: 'favorite');

/// A past day for the history list.
DaySummary day(
  String key, {
  int completed = 0,
  int skipped = 0,
  int missed = 0,
  int pending = 0,
}) => DaySummary(
  dateKey: key,
  completed: completed,
  skipped: skipped,
  missed: missed,
  pending: pending,
);

void main() {
  group('notifications', () {
    testWidgets('show the saved preferences', (tester) async {
      await openSettings(
        tester,
        homeOverrides(prefs: const NotificationPrefs(soundEnabled: false)),
      );

      Switch switchIn(String label) => tester.widget<Switch>(
        find.descendant(
          of: find.widgetWithText(SwitchRow, label),
          matching: find.byType(Switch),
        ),
      );

      expect(switchIn('Reminders').value, isTrue);
      expect(switchIn('Sound').value, isFalse);
      expect(switchIn('Vibration').value, isTrue);
      expect(find.text('10 min'), findsOneWidget, reason: 'default snooze');
    });

    testWidgets('each switch is saved', (tester) async {
      final actions = FakeSettingsActions();
      await openSettings(tester, homeOverrides(settingsActions: actions));

      await tester.tap(find.text('Sound'));
      await tester.tap(find.text('Vibration'));
      await tester.tap(find.text('Follow-up'));
      await tester.pump();

      expect(actions.calls, [
        'sound:false',
        'vibration:false',
        'followUp:false',
      ]);
    });

    testWidgets('with reminders off the rest are disabled', (tester) async {
      final actions = FakeSettingsActions();
      await openSettings(
        tester,
        homeOverrides(
          prefs: const NotificationPrefs(notificationsEnabled: false),
          settingsActions: actions,
        ),
      );

      await tester.tap(find.text('Sound'));
      await tester.tap(find.text('Default snooze'));
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
      expect(
        find.text(
          'How long a reminder waits when you snooze it. A task can set its own.',
        ),
        findsNothing,
      );
    });

    testWidgets('turning reminders off is saved', (tester) async {
      final actions = FakeSettingsActions();
      await openSettings(tester, homeOverrides(settingsActions: actions));

      await tester.tap(find.text('Reminders'));
      await tester.pump();

      expect(actions.calls, ['reminders:false']);
      expect(find.text('Let Ticky remind you'), findsNothing);
    });

    testWidgets('turning reminders on while blocked offers the permission '
        'sheet', (tester) async {
      final actions = FakeSettingsActions()..needsPermission = true;
      await openSettings(
        tester,
        homeOverrides(
          prefs: const NotificationPrefs(notificationsEnabled: false),
          settingsActions: actions,
        ),
      );

      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['reminders:true']);
      expect(find.text('Let Ticky remind you'), findsOneWidget);
    });

    testWidgets('a blocked phone permission is explained, and fixable', (
      tester,
    ) async {
      await openSettings(tester, homeOverrides(notificationsAllowed: false));

      expect(find.text('Notifications are blocked'), findsOneWidget);
      await tester.tap(find.text('Notifications are blocked'));
      await tester.pumpAndSettle();
      expect(find.text('Let Ticky remind you'), findsOneWidget);
    });

    testWidgets('no warning when the phone allows notifications', (
      tester,
    ) async {
      await openSettings(tester, homeOverrides());
      expect(find.text('Notifications are blocked'), findsNothing);
    });

    testWidgets('the default snooze is picked in a sheet', (tester) async {
      final actions = FakeSettingsActions();
      await openSettings(tester, homeOverrides(settingsActions: actions));

      await tester.tap(find.text('Default snooze'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10 min'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, '30 min'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['snooze:30']);
    });
  });

  group('routines', () {
    final water = routine(id: 1, title: 'Drink water', reminderMinutes: 480);
    final read = routine(
      id: 2,
      title: 'Read',
      reminderMinutes: null,
      repeatDays: 31,
    );

    testWidgets('are listed with their time and repeat days', (tester) async {
      await openSettings(tester, homeOverrides(activeRoutines: [water, read]));

      expect(find.text('Drink water'), findsOneWidget);
      expect(
        find.text('${formatMinutesOfDay(480)} · Every day'),
        findsOneWidget,
      );
      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Anytime · Weekdays'), findsOneWidget);
    });

    testWidgets('a paused routine says so', (tester) async {
      final paused = water.copyWith(isEnabled: false);
      await openSettings(tester, homeOverrides(activeRoutines: [paused]));

      expect(
        find.text('Paused · ${formatMinutesOfDay(480)} · Every day'),
        findsOneWidget,
      );
    });

    testWidgets('the switch pauses and resumes', (tester) async {
      final actions = FakeRoutineActions();
      await openSettings(
        tester,
        homeOverrides(activeRoutines: [water], routineActions: actions),
      );

      final routineSwitch = find.descendant(
        of: find.ancestor(
          of: find.text('Drink water'),
          matching: find.byType(Dismissible),
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(routineSwitch);
      await tester.pump();

      expect(actions.calls, ['setEnabled:1:false']);
    });

    testWidgets('tapping a routine opens it for editing', (tester) async {
      await openSettings(
        tester,
        homeOverrides(
          activeRoutines: [water],
          routines: FakeRoutineRepository([water]),
        ),
      );

      await tester.tap(find.text('Drink water'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditTaskScreen), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
    });

    testWidgets('swiping left deletes with an undo', (tester) async {
      final actions = FakeRoutineActions();
      await openSettings(
        tester,
        homeOverrides(activeRoutines: [water, read], routineActions: actions),
      );

      await tester.drag(find.text('Drink water'), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(actions.calls, ['delete:1']);
      expect(find.text('"Drink water" deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actions.calls, ['delete:1', 'undoDelete:1']);
    });

    testWidgets('a failed delete says why', (tester) async {
      final actions = FakeRoutineActions()
        ..failWith = const NotFoundException('Routine 1 not found');
      await openSettings(
        tester,
        homeOverrides(activeRoutines: [water], routineActions: actions),
      );

      await tester.drag(find.text('Drink water'), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Routine 1 not found'), findsOneWidget);
    });

    testWidgets('dragging the handle saves the new order', (tester) async {
      final actions = FakeRoutineActions();
      await openSettings(
        tester,
        homeOverrides(activeRoutines: [water, read], routineActions: actions),
      );

      final handles = find.byIcon(Icons.drag_indicator_rounded);
      await tester.drag(handles.first, const Offset(0, 140));
      await tester.pumpAndSettle();

      expect(actions.calls, ['reorder:2,1']);
    });

    testWidgets('with none yet, the first one is one tap away', (tester) async {
      await openSettings(tester, homeOverrides());

      await tester.tap(find.text('Add your first routine'));
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsOneWidget);
    });

    testWidgets('"Add routine" opens the new task form', (tester) async {
      await openSettings(tester, homeOverrides(activeRoutines: [water]));

      await tester.tap(find.text('Add routine'));
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsOneWidget);
    });
  });

  group('categories', () {
    testWidgets('are listed, with General marked as the default', (
      tester,
    ) async {
      await openSettings(
        tester,
        homeOverrides(categories: [category(), health]),
      );

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
    });

    testWidgets('one can be renamed', (tester) async {
      final repo = FakeCategoryRepository();
      await openSettings(
        tester,
        homeOverrides(
          categories: [category(), health],
          categoryRepository: repo,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('category-2')));
      await tester.pumpAndSettle();
      expect(find.text('Edit category'), findsOneWidget);

      final field = find.descendant(
        of: find.byType(CreateCategorySheet),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(field).controller!.text, 'Health');
      await tester.enterText(field, 'Fitness');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.updated.keys, [2]);
      expect(repo.updated[2]!.trimmedTitle, 'Fitness');
      expect(find.byType(CreateCategorySheet), findsNothing);
    });

    testWidgets('a blank name is refused in the sheet', (tester) async {
      final repo = FakeCategoryRepository();
      await openSettings(
        tester,
        homeOverrides(
          categories: [category(), health],
          categoryRepository: repo,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('category-2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(CreateCategorySheet),
          matching: find.byType(TextField),
        ),
        '   ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name must be 1-40 characters'), findsOneWidget);
      expect(repo.updated, isEmpty);
    });

    testWidgets(
      'one can be deleted after confirming, and says where tasks go',
      (tester) async {
        final repo = FakeCategoryRepository();
        await openSettings(
          tester,
          homeOverrides(
            categories: [category(), health],
            categoryRepository: repo,
          ),
        );

        await tester.tap(find.byKey(const ValueKey('category-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete category'));
        await tester.pumpAndSettle();
        expect(find.text('Delete "Health"?'), findsOneWidget);
        expect(find.textContaining('move to General'), findsOneWidget);

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(repo.archived, [2]);
        expect(find.byType(CreateCategorySheet), findsNothing);
      },
    );

    testWidgets('keeping a category changes nothing', (tester) async {
      final repo = FakeCategoryRepository();
      await openSettings(
        tester,
        homeOverrides(
          categories: [category(), health],
          categoryRepository: repo,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('category-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep category'));
      await tester.pumpAndSettle();

      expect(repo.archived, isEmpty);
    });

    testWidgets('General cannot be deleted', (tester) async {
      await openSettings(
        tester,
        homeOverrides(categories: [category(), health]),
      );

      await tester.tap(find.byKey(const ValueKey('category-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit category'), findsOneWidget);
      expect(find.text('Delete category'), findsNothing);
    });

    testWidgets('a new one is created', (tester) async {
      final repo = FakeCategoryRepository();
      await openSettings(tester, homeOverrides(categoryRepository: repo));

      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(CreateCategorySheet),
          matching: find.byType(TextField),
        ),
        'Pets',
      );
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();

      expect(repo.created.single.trimmedTitle, 'Pets');
    });
  });

  group('Ticky shop', () {
    testWidgets('shows the balance, one Ticky, and every item', (tester) async {
      await openSettings(tester, homeOverrides(coins: 25));

      expect(find.text('25 coins'), findsOneWidget);
      expect(
        find.byType(TickyMascot),
        findsOneWidget,
        reason: 'only one Ticky, never one per item',
      );
      for (final name in [
        'Classic',
        'Relaxed',
        'Thumbs up',
        'Out for a walk',
        'Cheering',
        'Jumping',
        'On the run',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text('Wearing'), findsOneWidget, reason: 'Classic');
    });

    testWidgets('tapping an item tries it on without buying', (tester) async {
      final actions = FakeShopActions();
      await openSettings(tester, homeOverrides(shopActions: actions));

      await tester.tap(find.text('Cheering'));
      await tester.pump();

      expect(
        tester.widget<TickyMascot>(find.byType(TickyMascot)).idlePose,
        'cheer',
      );
      expect(actions.calls, isEmpty);
    });

    testWidgets('buying an item you can afford', (tester) async {
      final actions = FakeShopActions();
      await openSettings(
        tester,
        homeOverrides(coins: 100, shopActions: actions),
      );

      await tester.tap(find.byKey(const ValueKey('shop-pose_relax')).first);
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('shop-pose_relax')),
          matching: find.byType(OutlinedButton),
        ),
      );
      await tester.pump();

      expect(actions.calls, ['buy:pose_relax']);
      expect(find.text('Ticky is now Relaxed'), findsOneWidget);
    });

    testWidgets('an item you cannot afford says how many coins are missing', (
      tester,
    ) async {
      final actions = FakeShopActions();
      await openSettings(tester, homeOverrides(coins: 5, shopActions: actions));

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('shop-pose_relax')),
          matching: find.byType(OutlinedButton),
        ),
      );
      await tester.pump();

      expect(actions.calls, isEmpty);
      expect(
        find.text('Not enough coins yet. You need 15 more.'),
        findsOneWidget,
      );
    });

    testWidgets('a purchase that fails says why', (tester) async {
      final actions = FakeShopActions()
        ..failWith = const ItemAlreadyUnlockedException('Already yours');
      await openSettings(
        tester,
        homeOverrides(coins: 100, shopActions: actions),
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('shop-pose_relax')),
          matching: find.byType(OutlinedButton),
        ),
      );
      await tester.pump();

      expect(find.text('Already yours'), findsOneWidget);
    });

    testWidgets('a bought item can be worn, and Classic put back', (
      tester,
    ) async {
      final actions = FakeShopActions();
      await openSettings(
        tester,
        homeOverrides(
          unlockedItems: {'pose_relax', 'pose_cheer'},
          equippedItem: 'pose_cheer',
          shopActions: actions,
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shop-pose_cheer')),
          matching: find.text('Wearing'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('shop-pose_relax')),
          matching: find.text('Wear'),
        ),
      );
      await tester.pump();
      expect(actions.calls, ['equip:pose_relax']);

      await tester.tap(find.widgetWithText(TextButton, 'Wear').first);
      await tester.pump();
      expect(actions.calls.last, startsWith('equip:'));
    });

    testWidgets('the preview starts on what Ticky wears', (tester) async {
      await openSettings(
        tester,
        homeOverrides(
          unlockedItems: {'pose_cheer'},
          equippedItem: 'pose_cheer',
        ),
      );

      expect(
        tester.widget<TickyMascot>(find.byType(TickyMascot)).idlePose,
        'cheer',
      );
    });

    testWidgets('an item that is equipped but not bought is not worn', (
      tester,
    ) async {
      await openSettings(tester, homeOverrides(equippedItem: 'pose_cheer'));

      expect(
        tester.widget<TickyMascot>(find.byType(TickyMascot)).idlePose,
        isNull,
      );
      expect(find.text('Wearing'), findsOneWidget, reason: 'Classic');
    });
  });

  group('history', () {
    testWidgets('says so when there are no finished days', (tester) async {
      await openSettings(tester, homeOverrides());
      expect(find.text('Finished days show up here.'), findsOneWidget);
    });

    testWidgets('lists past days with how they went', (tester) async {
      await openSettings(
        tester,
        homeOverrides(
          historyDays: [
            day('2026-11-01', completed: 3, skipped: 1),
            day('2026-10-31', completed: 1, missed: 2),
            day('2026-10-30', skipped: 2),
          ],
        ),
      );

      expect(find.text('Sun 1 Nov'), findsOneWidget);
      expect(find.text('3 of 4 done'), findsOneWidget);
      expect(find.text('1 of 3 done'), findsOneWidget);
      expect(find.text('All skipped'), findsOneWidget);
    });

    testWidgets('shows a week, then older days on request', (tester) async {
      final days = [
        for (var d = 20; d >= 1; d--)
          day('2026-10-${d.toString().padLeft(2, '0')}', completed: 1),
      ];
      await openSettings(tester, homeOverrides(historyDays: days));

      expect(find.byKey(const ValueKey('day-2026-10-20')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-14')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-2026-10-13')), findsNothing);

      await tester.tap(find.text('Show older days'));
      await tester.pump();
      expect(find.byKey(const ValueKey('day-2026-10-01')), findsOneWidget);
      expect(find.text('Show fewer days'), findsOneWidget);

      await tester.tap(find.text('Show fewer days'));
      await tester.pump();
      expect(find.byKey(const ValueKey('day-2026-10-01')), findsNothing);
    });

    testWidgets('a week or less has no "show older" row', (tester) async {
      await openSettings(
        tester,
        homeOverrides(historyDays: [day('2026-11-01', completed: 1)]),
      );
      expect(find.text('Show older days'), findsNothing);
    });

    testWidgets('a day opens a read-only list, and a task opens its details', (
      tester,
    ) async {
      final entries = [
        entry(
          id: 7,
          title: 'Stretch',
          minutes: 450,
          status: TaskStatus.completed,
        ),
        entry(id: 8, title: 'Journal', status: TaskStatus.missed),
      ];
      await openSettings(
        tester,
        homeOverrides(
          entries: entries,
          activeRoutines: const [],
          routines: FakeRoutineRepository([routine(id: 7, title: 'Stretch')]),
          historyDays: [day('2026-11-01', completed: 1, missed: 1)],
          historyEntries: {'2026-11-01': entries},
        ),
      );

      await tester.tap(find.text('Sun 1 Nov'));
      await tester.pumpAndSettle();
      expect(find.text('Sunday, 1 November'), findsOneWidget);
      expect(find.text('Past days are read-only'), findsOneWidget);
      expect(find.text('Stretch'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);

      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsScreen), findsOneWidget);
    });
  });

  testWidgets('there is no theme setting, because Ticky is dark only', (
    tester,
  ) async {
    await openSettings(tester, homeOverrides());
    expect(find.textContaining('Theme'), findsNothing);
  });
}
