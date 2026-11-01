import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/character/widgets/ticky_mascot.dart';
import 'package:ticky/features/home/widgets/task_tile.dart';
import 'package:ticky/features/tasks/screens/task_details_screen.dart';
import 'package:ticky/features/home/providers/notification_prompt_controller.dart';
import 'package:ticky/features/routine/models/streak.dart';

import '../../support/home_test_support.dart';

Future<void> pumpHome(WidgetTester tester, List<Override> overrides) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const TickyApp()),
  );
  await tester.pumpAndSettle();
}

final completedCheck = find.byWidgetPredicate(
  (w) => w is TaskCheck && w.status == TaskStatus.completed,
);

/// Lets Ticky's short reaction timer finish before the test ends.
Future<void> letReactionsFade(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  group('empty states', () {
    testWidgets('new user: example day, one clear action, suggestions', (
      tester,
    ) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));

      expect(find.text('Build your day'), findsOneWidget);
      expect(find.text('Morning walk'), findsOneWidget, reason: 'example row');
      expect(find.text('Create your first routine'), findsOneWidget);
      expect(find.byType(ActionChip), findsNWidgets(4));
      expect(
        find.text('New task'),
        findsNothing,
        reason: 'no button when empty',
      );
      expect(
        find.byType(TickyMascot),
        findsOneWidget,
        reason: 'only the header Ticky, never a second one',
      );
    });

    testWidgets('the main action opens the new task form', (tester) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));

      await tester.tap(find.text('Create your first routine'));
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsOneWidget);
      expect(
        find.text('Drink water'),
        findsNothing,
        reason: 'nothing prefilled',
      );
    });

    testWidgets('a suggestion opens the form already filled in', (
      tester,
    ) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));

      await tester.tap(find.widgetWithText(ActionChip, 'Read 10 minutes'));
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsOneWidget);
      expect(find.text('Read 10 minutes'), findsOneWidget);
      expect(find.text(formatMinutesOfDay(21 * 60)), findsOneWidget);
    });

    testWidgets('routines exist but none run today: short and quiet', (
      tester,
    ) async {
      await pumpHome(tester, homeOverrides(hasRoutines: true));

      expect(find.text('Nothing planned today'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(TickyMascot), findsOneWidget);
    });
  });

  group('header', () {
    testWidgets('greets by time of day and shows the date', (tester) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));

      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('Monday, 2 November'), findsOneWidget);
    });

    testWidgets('evening greeting', (tester) async {
      await pumpHome(
        tester,
        homeOverrides(hasRoutines: false, now: DateTime(2026, 11, 2, 19)),
      );

      expect(find.text('Good evening'), findsOneWidget);
    });

    testWidgets('shows streak and coins, and explains them on tap', (
      tester,
    ) async {
      await pumpHome(
        tester,
        homeOverrides(
          hasRoutines: false,
          streak: const StreakInfo(count: 4, includesToday: true),
          coins: 27,
        ),
      );

      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(find.text('4 day streak'), findsOneWidget);
      expect(find.textContaining('Today counts'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('27'));
      await tester.pumpAndSettle();
      expect(find.text('27 coins'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('a zero streak says so', (tester) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));

      await tester.tap(find.byIcon(Icons.local_fire_department_rounded));
      await tester.pumpAndSettle();

      expect(find.text('No streak yet'), findsOneWidget);
    });

    testWidgets('tapping Ticky makes him react and speak', (tester) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));
      // No routines yet: Ticky is thinking.
      expect(find.text('Hmm… what shall we do each day?'), findsOneWidget);

      await tester.tap(find.byType(TickyMascot).first);
      await tester.pumpAndSettle();

      // Then surprised: the second of his two surprised lines.
      expect(find.text('Hehe, that tickles!'), findsOneWidget);
      expect(find.text('Hmm… what shall we do each day?'), findsNothing);
      await letReactionsFade(tester);
    });
  });

  group('checklist', () {
    final entries = [
      entry(id: 1, title: 'Drink water', minutes: 8 * 60),
      entry(id: 2, title: 'Stretch', minutes: 10 * 60),
      entry(id: 3, title: 'Read', minutes: 20 * 60, priority: Priority.high),
      entry(id: 4, title: 'Journal', status: TaskStatus.completed),
    ];

    testWidgets('groups by time with Anytime last, plus progress', (
      tester,
    ) async {
      await pumpHome(tester, homeOverrides(entries: entries));

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
      expect(find.text('Anytime'), findsOneWidget);
      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('1 of 4 done'), findsOneWidget);
      expect(find.text('3 tasks to go'), findsOneWidget);
      expect(find.text('New task'), findsOneWidget, reason: 'FAB present');
    });

    testWidgets('flags overdue tasks, not upcoming ones', (tester) async {
      await pumpHome(tester, homeOverrides(entries: entries));

      expect(
        find.text('${formatMinutesOfDay(8 * 60)} · Overdue'),
        findsOneWidget,
      );
      expect(find.text(formatMinutesOfDay(10 * 60)), findsOneWidget);
    });

    testWidgets('shows the category and the coin reward', (tester) async {
      await pumpHome(tester, homeOverrides(entries: entries));

      expect(find.text('General'), findsWidgets);
      expect(find.text('+3'), findsOneWidget, reason: 'high priority');
      expect(find.text('+2'), findsWidgets, reason: 'medium priority');
    });

    testWidgets('tapping the circle completes, and Undo reopens', (
      tester,
    ) async {
      final actions = FakeTaskActions();
      await pumpHome(tester, homeOverrides(entries: entries, actions: actions));

      await tester.tap(find.byType(TaskCheck).first);
      await tester.pump();
      expect(actions.calls, ['complete:1']);
      expect(find.text('Nice! +2 coins'), findsOneWidget);

      await tester.pump(
        const Duration(milliseconds: 500),
      ); // snackbar slides in
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actions.calls, ['complete:1', 'reopen:1']);
      await letReactionsFade(tester);
    });

    testWidgets('tapping a completed circle reopens it', (tester) async {
      final actions = FakeTaskActions();
      await pumpHome(tester, homeOverrides(entries: entries, actions: actions));

      await tester.tap(completedCheck);
      await tester.pump();

      expect(actions.calls, ['reopen:4']);
    });

    testWidgets('finishing the last task celebrates the perfect day', (
      tester,
    ) async {
      final actions = FakeTaskActions();
      final nearlyDone = [
        entry(id: 1, title: 'Only one', minutes: 10 * 60),
        entry(id: 2, title: 'Done', status: TaskStatus.completed),
      ];
      await pumpHome(
        tester,
        homeOverrides(entries: nearlyDone, actions: actions),
      );

      await tester.tap(find.byType(TaskCheck).first);
      await tester.pumpAndSettle();

      expect(
        find.text('All done! +2 coins and +5 perfect day bonus'),
        findsOneWidget,
      );
      // Ticky celebrates; each reaction moves on to his next line.
      expect(find.text('Perfect! I am so proud of you!'), findsOneWidget);
      await letReactionsFade(tester);
    });

    testWidgets('swipe right completes, swipe left skips, rows stay', (
      tester,
    ) async {
      final actions = FakeTaskActions();
      await pumpHome(tester, homeOverrides(entries: entries, actions: actions));

      await tester.drag(find.text('Stretch'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(actions.calls, ['complete:2']);
      expect(find.text('Stretch'), findsOneWidget);

      await tester.drag(find.text('Read'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(actions.calls, ['complete:2', 'skip:3']);
      expect(find.text('Read'), findsOneWidget);
      await letReactionsFade(tester);
    });

    testWidgets('a skipped task offers undo on swipe', (tester) async {
      final actions = FakeTaskActions();
      final skipped = [
        entry(
          id: 1,
          title: 'Later',
          minutes: 10 * 60,
          status: TaskStatus.skipped,
        ),
        entry(id: 2, title: 'Other', minutes: 11 * 60),
      ];
      await pumpHome(tester, homeOverrides(entries: skipped, actions: actions));

      expect(find.text('Skipped'), findsOneWidget);
      await tester.drag(find.text('Later'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(actions.calls, ['reopen:1']);
    });

    testWidgets('long press opens quick actions', (tester) async {
      final actions = FakeTaskActions();
      await pumpHome(tester, homeOverrides(entries: entries, actions: actions));

      await tester.longPress(find.text('Stretch'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as done'), findsOneWidget);
      expect(find.text('Skip for today'), findsOneWidget);
      expect(find.text('Snooze reminder'), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);

      await tester.tap(find.text('Snooze reminder'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['snooze:2']);
      expect(
        find.text('Snoozed until ${formatMinutesOfDay(9 * 60 + 10)}'),
        findsOneWidget,
      );
    });

    testWidgets('quick actions differ for anytime and completed tasks', (
      tester,
    ) async {
      await pumpHome(tester, homeOverrides(entries: entries));

      await tester.longPress(find.text('Journal'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as not done'), findsOneWidget);
      expect(find.text('Snooze reminder'), findsNothing);
      expect(find.text('Skip for today'), findsNothing);
    });

    testWidgets('quick actions open edit and details', (tester) async {
      await pumpHome(tester, homeOverrides(entries: entries));

      await tester.longPress(find.text('Stretch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit task'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget, reason: 'screen title');
    });

    testWidgets('tapping a row opens its details', (tester) async {
      await pumpHome(tester, homeOverrides(entries: entries));

      await tester.tap(find.text('Stretch'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailsScreen), findsOneWidget);
      expect(find.text('Stretch'), findsWidgets);
    });

    testWidgets('a rejected change shows the reason instead of crashing', (
      tester,
    ) async {
      final actions = FakeTaskActions()
        ..failWith = const ReadOnlyDayException('Past days are read-only');
      await pumpHome(tester, homeOverrides(entries: entries, actions: actions));

      await tester.tap(find.byType(TaskCheck).first);
      await tester.pump();

      expect(find.text('Past days are read-only'), findsOneWidget);
    });
  });

  group('reminders sheet', () {
    testWidgets('is not shown when permission is fine', (tester) async {
      await pumpHome(tester, homeOverrides(hasRoutines: false));

      expect(find.text('Let Ticky remind you'), findsNothing);
    });

    testWidgets('Ticky asks first; nothing is enabled until the button', (
      tester,
    ) async {
      final prompt = FakePromptController();
      await pumpHome(
        tester,
        homeOverrides(hasRoutines: false, promptDue: true, prompt: prompt),
      );

      expect(find.text('Let Ticky remind you'), findsOneWidget);
      expect(find.text('Turn on reminders'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);
      expect(prompt.enableCalls, 0);
    });

    testWidgets('turning on shows success and closes by itself', (
      tester,
    ) async {
      final prompt = FakePromptController();
      final settings = FakeSettings();
      await pumpHome(
        tester,
        homeOverrides(
          hasRoutines: false,
          promptDue: true,
          prompt: prompt,
          settings: settings,
        ),
      );

      await tester.tap(find.text('Turn on reminders'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text("You're all set!"), findsOneWidget);
      expect(prompt.enableCalls, 1);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Let Ticky remind you'), findsNothing);
      expect(settings.dismissedAt, isNull, reason: 'accepted, not dismissed');
    });

    testWidgets('"Maybe later" closes it and remembers the answer', (
      tester,
    ) async {
      final settings = FakeSettings();
      await pumpHome(
        tester,
        homeOverrides(
          hasRoutines: false,
          promptDue: true,
          prompt: FakePromptController(),
          settings: settings,
        ),
      );

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();

      expect(find.text('Let Ticky remind you'), findsNothing);
      expect(settings.dismissedAt, DateTime(2026, 11, 2, 9));
    });

    testWidgets('a refusal explains how to turn them on in settings', (
      tester,
    ) async {
      final prompt = FakePromptController(result: PromptStep.denied);
      await pumpHome(
        tester,
        homeOverrides(hasRoutines: false, promptDue: true, prompt: prompt),
      );

      await tester.tap(find.text('Turn on reminders'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications are off'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    });

    testWidgets('exact timing is a separate, skippable step', (tester) async {
      final prompt = FakePromptController(result: PromptStep.needsExact);
      await pumpHome(
        tester,
        homeOverrides(hasRoutines: false, promptDue: true, prompt: prompt),
      );

      await tester.tap(find.text('Turn on reminders'));
      await tester.pumpAndSettle();

      expect(find.text('Almost there!'), findsOneWidget);
      expect(find.text('Allow exact timing'), findsOneWidget);
      await tester.tap(find.text('Skip, a little late is fine'));
      await tester.pumpAndSettle();
      expect(find.text('Almost there!'), findsNothing);
    });
  });

  group('item shop pose', () {
    testWidgets('Ticky wears the equipped pose while he is idle', (
      tester,
    ) async {
      await pumpHome(
        tester,
        homeOverrides(
          equippedItem: 'pose_cheer',
          unlockedItems: {'pose_cheer'},
        ),
      );

      expect(
        tester.widget<TickyMascot>(find.byType(TickyMascot)).idlePose,
        'cheer',
      );
    });

    testWidgets('a pose that was not bought is not shown', (tester) async {
      await pumpHome(tester, homeOverrides(equippedItem: 'pose_cheer'));

      expect(
        tester.widget<TickyMascot>(find.byType(TickyMascot)).idlePose,
        isNull,
      );
    });

    testWidgets('there is still only one Ticky on Home', (tester) async {
      await pumpHome(
        tester,
        homeOverrides(
          equippedItem: 'pose_cheer',
          unlockedItems: {'pose_cheer'},
        ),
      );

      expect(find.byType(TickyMascot), findsOneWidget);
    });
  });
}
