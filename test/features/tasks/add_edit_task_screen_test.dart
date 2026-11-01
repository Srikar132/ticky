import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/categories/widgets/create_category_sheet.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';
import 'package:ticky/features/tasks/screens/add_edit_task_screen.dart';

import '../../support/home_test_support.dart';

/// Opens the form on top of a launcher page, so closing it is observable.
Future<void> openForm(
  WidgetTester tester, {
  List<Override>? overrides,
  int? routineId,
  TaskSuggestion? suggestion,

  /// False stops right after tapping, so the page can be checked mid-slide.
  bool settle = true,
}) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? homeOverrides(),
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddEditTaskScreen(
                      routineId: routineId,
                      suggestion: suggestion,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  if (settle) await tester.pumpAndSettle();
}

Finder get titleField => find.byType(TextField).first;

bool titleHasFocus(WidgetTester tester) =>
    tester.widget<TextField>(titleField).focusNode!.hasFocus;

/// A routine repository that answers only when told to.
class SlowRoutineRepository extends FakeRoutineRepository {
  SlowRoutineRepository(super.routines);

  final gate = Completer<void>();

  @override
  Future<RoutineTask?> getById(int id) async {
    await gate.future;
    return super.getById(id);
  }
}

void main() {
  group('opening the page', () {
    testWidgets('the keyboard waits until the page has finished sliding in', (
      tester,
    ) async {
      await openForm(tester, settle: false);
      await tester.pump(); // route starts
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 100));

      expect(titleField, findsOneWidget, reason: 'form is already there');
      expect(titleHasFocus(tester), isFalse, reason: 'still animating');

      await tester.pumpAndSettle();
      expect(titleHasFocus(tester), isTrue, reason: 'settled, keyboard up');
    });

    testWidgets('a prefilled suggestion does not pop the keyboard up', (
      tester,
    ) async {
      await openForm(tester, suggestion: taskSuggestions.first);
      expect(titleHasFocus(tester), isFalse);
    });

    testWidgets('editing does not pop the keyboard up', (tester) async {
      await openForm(
        tester,
        routineId: 5,
        overrides: homeOverrides(
          routines: FakeRoutineRepository([routine(id: 5)]),
        ),
      );
      expect(titleHasFocus(tester), isFalse);
    });

    testWidgets(
      'while an edit loads, the page shows its title and no spinner',
      (tester) async {
        final routines = SlowRoutineRepository([routine(id: 5)]);
        await openForm(
          tester,
          routineId: 5,
          overrides: homeOverrides(routines: routines),
          settle: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Edit task'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Save changes'), findsNothing);

        routines.gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Save changes'), findsOneWidget);
      },
    );
  });

  group('adding a task', () {
    testWidgets('opens empty with sensible defaults', (tester) async {
      await openForm(tester);

      expect(find.text('New task'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('Anytime'), findsOneWidget);
      expect(find.text('Every day'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Earns 2 coins when done'), findsOneWidget);
    });

    testWidgets('saves what was typed and closes', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));

      await tester.enterText(titleField, '  Read a chapter ');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(routines.created, hasLength(1));
      expect(routines.created.single.trimmedTitle, 'Read a chapter');
      expect(routines.created.single.reminderMinutes, isNull);
      expect(find.text('New task'), findsNothing, reason: 'form closed');
    });

    testWidgets('an empty title shows the error under the field', (
      tester,
    ) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.text('Title must be 1-80 characters'), findsOneWidget);
      expect(routines.created, isEmpty);
      expect(find.text('New task'), findsOneWidget, reason: 'stays open');

      await tester.enterText(titleField, 'Read');
      await tester.pump();
      expect(find.text('Title must be 1-80 characters'), findsNothing);
    });

    testWidgets('a suggestion fills in the title and the time', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(
        tester,
        overrides: homeOverrides(routines: routines),
        suggestion: taskSuggestions.first,
      );

      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text(formatMinutesOfDay(8 * 60)), findsOneWidget);

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.reminderMinutes, 8 * 60);
    });

    testWidgets('priority is a single tap', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));

      await tester.tap(find.text('High'));
      await tester.pump();
      expect(find.text('Earns 3 coins when done'), findsOneWidget);

      await tester.enterText(titleField, 'Pay rent');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.priority, Priority.high);
    });
  });

  group('reminder and alarm', () {
    testWidgets('the time sheet starts at the next full hour', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));

      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Reminder time'), findsOneWidget);
      expect(find.text('No reminder (Anytime)'), findsNothing);

      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(find.text(formatMinutesOfDay(10 * 60)), findsOneWidget);

      await tester.enterText(titleField, 'Stretch');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.reminderMinutes, 10 * 60);
    });

    testWidgets('a reminder can be removed again', (tester) async {
      await openForm(tester, suggestion: taskSuggestions.first);

      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pump();

      expect(find.text('Anytime'), findsOneWidget);
      expect(find.byTooltip('Remove reminder'), findsNothing);
    });

    testWidgets('switching the alarm on without a time asks for one', (
      tester,
    ) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));
      expect(find.text('Set a reminder time first'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Reminder time'), findsOneWidget);

      await tester.tap(find.text('Set time'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.enterText(titleField, 'Wake up');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.alarmEnabled, isTrue);
      expect(routines.created.single.reminderMinutes, 10 * 60);
    });

    testWidgets('dismissing the time sheet leaves the alarm off', (
      tester,
    ) async {
      await openForm(tester);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10)); // outside the sheet
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('Anytime'), findsOneWidget);
    });
  });

  group('repeat days', () {
    testWidgets('quick picks and single days update the row', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));

      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekdays'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('repeat-day-4')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Mon, Tue, Wed, Thu'), findsOneWidget);

      await tester.enterText(titleField, 'Gym');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.repeatDays, 15);
    });

    testWidgets('with no day picked the sheet cannot be confirmed', (
      tester,
    ) async {
      await openForm(tester);

      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      for (var day = 0; day < 7; day++) {
        await tester.tap(find.byKey(ValueKey('repeat-day-$day')));
        await tester.pump();
      }

      expect(find.text('Pick at least one day'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('leaving the sheet with no day shows the error on save', (
      tester,
    ) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));

      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      for (var day = 0; day < 7; day++) {
        await tester.tap(find.byKey(ValueKey('repeat-day-$day')));
        await tester.pump();
      }
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.enterText(titleField, 'Gym');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.text('Pick at least one repeat day'), findsOneWidget);
      expect(routines.created, isEmpty);
    });
  });

  group('category', () {
    final categories = [category(), category(id: 2, title: 'Health')];

    testWidgets('pick one from the sheet', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(
        tester,
        overrides: homeOverrides(routines: routines, categories: categories),
      );

      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      expect(find.text('Health'), findsOneWidget);
      await tester.tap(find.text('Health'));
      await tester.pumpAndSettle();

      expect(find.text('Health'), findsOneWidget, reason: 'now on the row');
      await tester.enterText(titleField, 'Run');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.categoryId, 2);
    });

    testWidgets('create a new one and it is selected', (tester) async {
      final routines = FakeRoutineRepository();
      final categoryRepo = FakeCategoryRepository();
      await openForm(
        tester,
        overrides: homeOverrides(
          routines: routines,
          categories: categories,
          categoryRepository: categoryRepo,
        ),
      );

      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();

      final nameField = find.descendant(
        of: find.byType(CreateCategorySheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(nameField, 'Pets');
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();

      expect(categoryRepo.created.single.trimmedTitle, 'Pets');
      expect(find.byType(CreateCategorySheet), findsNothing);
      expect(find.text('Category'), findsOneWidget, reason: 'picker closed');

      await tester.enterText(titleField, 'Walk the dog');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect(routines.created.single.categoryId, 9);
    });

    testWidgets('a nameless category shows its error and stays open', (
      tester,
    ) async {
      final categoryRepo = FakeCategoryRepository();
      await openForm(
        tester,
        overrides: homeOverrides(
          categories: categories,
          categoryRepository: categoryRepo,
        ),
      );

      await tester.tap(find.text('General'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create category'));
      await tester.pumpAndSettle();

      expect(find.text('Name must be 1-40 characters'), findsOneWidget);
      expect(find.byType(CreateCategorySheet), findsOneWidget);
      expect(categoryRepo.created, isEmpty);
    });
  });

  group('more options', () {
    testWidgets('are collapsed until asked for', (tester) async {
      await openForm(tester);

      expect(find.text('Snooze for'), findsNothing);
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Snooze for'), findsOneWidget);
    });

    testWidgets('duration, message and snooze are saved', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));
      await tester.enterText(titleField, 'Stretch');

      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      final thirty = find.text('30 min').first;
      await tester.ensureVisible(thirty);
      await tester.tap(thirty);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Shown in the notification').first,
        'Time to move',
      );
      final snooze = find.text('15 min').last;
      await tester.ensureVisible(snooze);
      await tester.tap(snooze);
      await tester.pump();

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      final draft = routines.created.single;
      expect(draft.durationMinutes, 30);
      expect(draft.normalizedReminderMessage, 'Time to move');
      expect(draft.snoozeMinutes, 15);
    });

    testWidgets('open by themselves when the task already uses them', (
      tester,
    ) async {
      await openForm(
        tester,
        routineId: 5,
        overrides: homeOverrides(
          routines: FakeRoutineRepository([routine(id: 5, snoozeMinutes: 5)]),
        ),
      );

      expect(find.text('Snooze for'), findsOneWidget);
    });
  });

  group('editing a task', () {
    testWidgets('shows the saved values and saves changes', (tester) async {
      final routines = FakeRoutineRepository([
        routine(
          id: 5,
          title: 'Stretch',
          reminderMinutes: 7 * 60 + 30,
          description: 'Back and neck',
          repeatDays: 31,
          priority: Priority.high,
        ),
      ]);
      await openForm(
        tester,
        routineId: 5,
        overrides: homeOverrides(routines: routines),
      );

      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('Stretch'), findsOneWidget);
      expect(find.text('Back and neck'), findsOneWidget);
      expect(find.text(formatMinutesOfDay(7 * 60 + 30)), findsOneWidget);
      expect(find.text('Weekdays'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);

      await tester.enterText(titleField, 'Stretch and breathe');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(routines.created, isEmpty);
      expect(routines.updated.keys, [5]);
      expect(routines.updated[5]!.trimmedTitle, 'Stretch and breathe');
      expect(routines.updated[5]!.priority, Priority.high);
      expect(find.text('Edit task'), findsNothing, reason: 'form closed');
    });

    testWidgets('a task that no longer exists says so', (tester) async {
      await openForm(tester, routineId: 404);

      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('This task no longer exists'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);

      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);
    });
  });

  group('leaving with unsaved changes', () {
    testWidgets('an untouched form closes without asking', (tester) async {
      await openForm(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New task'), findsNothing);
    });

    testWidgets('a suggestion left untouched closes without asking', (
      tester,
    ) async {
      await openForm(tester, suggestion: taskSuggestions.first);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New task'), findsNothing);
    });

    testWidgets('"Keep editing" stays, "Discard" leaves', (tester) async {
      final routines = FakeRoutineRepository();
      await openForm(tester, overrides: homeOverrides(routines: routines));
      await tester.enterText(titleField, 'Half-written');
      await tester.pump(); // let the form notice it is dirty

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('Half-written'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsNothing);
      expect(routines.created, isEmpty);
    });
  });

  group('notification permission', () {
    testWidgets('a new reminder with notifications off offers the sheet', (
      tester,
    ) async {
      final routines = FakeRoutineRepository();
      final settings = FakeSettings();
      await openForm(
        tester,
        overrides: homeOverrides(
          routines: routines,
          settings: settings,
          notifications: FakeNotificationService(notificationsAllowed: false),
        ),
        suggestion: taskSuggestions.first,
      );

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(routines.created, hasLength(1), reason: 'saved first');
      expect(find.text('Let Ticky remind you'), findsOneWidget);

      await tester.tap(find.text('Maybe later'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsNothing, reason: 'then closes');
      expect(settings.dismissedAt, isNotNull, reason: 'remembers "later"');
    });

    testWidgets('no sheet when notifications are already on', (tester) async {
      await openForm(tester, suggestion: taskSuggestions.first);

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.text('Let Ticky remind you'), findsNothing);
      expect(find.text('New task'), findsNothing);
    });

    testWidgets('no sheet for a task without a reminder', (tester) async {
      await openForm(
        tester,
        overrides: homeOverrides(
          notifications: FakeNotificationService(notificationsAllowed: false),
        ),
      );

      await tester.enterText(titleField, 'Journal');
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.text('Let Ticky remind you'), findsNothing);
    });
  });
}
