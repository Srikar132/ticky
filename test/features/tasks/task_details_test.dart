import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/database/enums.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/models/task_details.dart';
import 'package:ticky/features/tasks/screens/add_edit_task_screen.dart';
import 'package:ticky/features/tasks/screens/task_details_screen.dart';

import '../../support/home_test_support.dart';

DailyTaskRecord record({
  int id = 1,
  String dateKey = '2026-11-02',
  TaskStatus status = TaskStatus.pending,
  int? minutes = 600,
  String title = 'Drink water',
  DateTime? completedAt,
  DateTime? snoozedUntil,
}) {
  return DailyTaskRecord(
    id: id,
    routineTaskId: id,
    dateKey: dateKey,
    titleSnapshot: title,
    scheduledMinutes: minutes,
    status: status,
    completedAt: completedAt,
    snoozedUntil: snoozedUntil,
  );
}

void main() {
  group('TaskDetails rules', () {
    TaskDetails details({
      DailyTaskRecord? rec,
      RoutineTask? routine,
      String today = '2026-11-02',
    }) => TaskDetails(
      record: rec ?? record(),
      routine: routine ?? _routine(),
      todayKey: today,
    );

    test('today\'s pending task can be changed and snoozed', () {
      final d = details();
      expect(d.isToday, isTrue);
      expect(d.canChangeStatus, isTrue);
      expect(d.canSnooze, isTrue);
      expect(d.canEdit, isTrue);
      expect(d.canDelete, isTrue);
    });

    test('a task without a time cannot be snoozed', () {
      expect(details(rec: record(minutes: null)).canSnooze, isFalse);
    });

    test('only pending tasks can be snoozed', () {
      for (final status in [
        TaskStatus.completed,
        TaskStatus.skipped,
        TaskStatus.missed,
      ]) {
        expect(details(rec: record(status: status)).canSnooze, isFalse);
      }
    });

    test('a past day is read-only, though the routine can still be edited', () {
      final d = details(rec: record(dateKey: '2026-11-01'));
      expect(d.isToday, isFalse);
      expect(d.canChangeStatus, isFalse);
      expect(d.canSnooze, isFalse);
      expect(d.canEdit, isTrue);
    });

    test('a deleted routine cannot be edited or deleted again', () {
      final d = details(routine: _routine(archivedAt: DateTime.utc(2026)));
      expect(d.canEdit, isFalse);
      expect(d.canDelete, isFalse);
    });

    test('a missing routine row is handled', () {
      final d = TaskDetails(
        record: record(),
        routine: null,
        todayKey: '2026-11-02',
      );
      expect(d.canEdit, isFalse);
      expect(d.canChangeStatus, isTrue);
    });

    test('a snooze counts only while it runs, for a pending task today', () {
      final now = DateTime(2026, 11, 2, 9);
      final until = DateTime(2026, 11, 2, 9, 10).toUtc();

      expect(
        details(rec: record(snoozedUntil: until)).activeSnoozeEnd(now),
        DateTime(2026, 11, 2, 9, 10),
      );
      expect(
        details(
          rec: record(snoozedUntil: until),
        ).activeSnoozeEnd(DateTime(2026, 11, 2, 9, 30)),
        isNull,
        reason: 'already over',
      );
      expect(
        details(
          rec: record(snoozedUntil: until, status: TaskStatus.completed),
        ).activeSnoozeEnd(now),
        isNull,
      );
      expect(details().activeSnoozeEnd(now), isNull);
    });
  });

  group('screen', () {
    Future<void> openDetails(
      WidgetTester tester, {
      required List<DailyTaskEntry> entries,
      int recordId = 1,
      List<RoutineTask> routines = const [],
      FakeTaskActions? actions,
      FakeRoutineActions? detailsActions,
      DateTime? now,
      List<Override> extra = const [],
    }) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...homeOverrides(
              entries: entries,
              routines: FakeRoutineRepository(routines),
              actions: actions,
              routineActions: detailsActions,
              now: now,
              categories: [
                category(),
                category(id: 2, title: 'Health', iconKey: 'favorite'),
              ],
            ),
            ...extra,
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TaskDetailsScreen(recordId: recordId),
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
      await tester.pumpAndSettle();
    }

    DailyTaskEntry pending({int id = 1, int? minutes = 600}) =>
        entry(id: id, title: 'Drink water', minutes: minutes);

    testWidgets('shows the title, status, day and every setting', (
      tester,
    ) async {
      await openDetails(
        tester,
        entries: [pending()],
        routines: [
          _routine(
            id: 1,
            description: 'Two glasses',
            alarmEnabled: true,
            repeatDays: 31,
            priority: Priority.high,
            categoryId: 2,
            durationMinutes: 5,
            snoozeMinutes: 15,
            message: 'Hydrate!',
          ),
        ],
      );

      expect(find.text('Drink water'), findsOneWidget);
      expect(find.text('To do'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Two glasses'), findsOneWidget);
      expect(find.text('${formatMinutesOfDay(600)} · Alarm'), findsOneWidget);
      expect(find.text('Weekdays'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('High · 3 coins'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.text('Hydrate!'), findsOneWidget);
    });

    testWidgets('settings that are not used are not shown', (tester) async {
      await openDetails(
        tester,
        entries: [pending(minutes: null)],
        routines: [_routine(id: 1, reminderMinutes: null)],
      );

      expect(find.text('Anytime'), findsOneWidget);
      expect(find.text('Duration'), findsNothing);
      expect(find.text('Snooze for'), findsNothing);
      expect(find.text('Message'), findsNothing);
      expect(find.text('Snooze'), findsNothing, reason: 'no time, no snooze');
    });

    testWidgets('Done completes the task and offers undo', (tester) async {
      final actions = FakeTaskActions();
      await openDetails(
        tester,
        entries: [pending()],
        routines: [_routine(id: 1, priority: Priority.low)],
        actions: actions,
      );

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(actions.calls, ['complete:1']);
      expect(find.text('Nice! +1 coin'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actions.calls, ['complete:1', 'reopen:1']);
    });

    testWidgets('Skip and Snooze go through the same actions as Home', (
      tester,
    ) async {
      final actions = FakeTaskActions();
      await openDetails(
        tester,
        entries: [pending()],
        routines: [_routine(id: 1)],
        actions: actions,
      );

      await tester.tap(find.text('Snooze'));
      await tester.pump();
      expect(actions.calls, ['snooze:1']);
      expect(
        find.text('Snoozed until ${formatMinutesOfDay(9 * 60 + 10)}'),
        findsOneWidget,
      );

      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(actions.calls, ['snooze:1', 'skip:1']);
    });

    testWidgets('a completed task offers to undo and shows when it was done', (
      tester,
    ) async {
      final actions = FakeTaskActions();
      await openDetails(
        tester,
        entries: [
          entry(id: 1, title: 'Drink water', status: TaskStatus.completed),
        ],
        routines: [_routine(id: 1)],
        actions: actions,
      );

      expect(find.text('Done'), findsOneWidget, reason: 'status pill');
      expect(find.text('Done at'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);

      await tester.tap(find.text('Mark as not done'));
      await tester.pump();
      expect(actions.calls, ['reopen:1']);
    });

    testWidgets('a skipped task offers Undo skip', (tester) async {
      final actions = FakeTaskActions();
      await openDetails(
        tester,
        entries: [
          entry(id: 1, title: 'Drink water', status: TaskStatus.skipped),
        ],
        routines: [_routine(id: 1)],
        actions: actions,
      );

      await tester.tap(find.text('Undo skip'));
      await tester.pump();
      expect(actions.calls, ['reopen:1']);
    });

    testWidgets('a rejected change shows the reason', (tester) async {
      final actions = FakeTaskActions()
        ..failWith = const ReadOnlyDayException('Past days are read-only');
      await openDetails(
        tester,
        entries: [pending()],
        routines: [_routine(id: 1)],
        actions: actions,
      );

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(find.text('Past days are read-only'), findsOneWidget);
    });

    testWidgets('a past day shows history without any action', (tester) async {
      await openDetails(
        tester,
        entries: [
          DailyTaskEntry(
            record: record(dateKey: '2026-11-01', status: TaskStatus.missed),
            priority: Priority.medium,
            categoryId: 1,
          ),
        ],
        routines: [_routine(id: 1)],
      );

      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Sunday, 1 November'), findsOneWidget);
      expect(find.text('Past days are read-only'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Snooze'), findsNothing);
      expect(find.byTooltip('Edit task'), findsOneWidget, reason: 'routine');
    });

    testWidgets('the pencil opens the edit form', (tester) async {
      await openDetails(
        tester,
        entries: [pending()],
        routines: [_routine(id: 1)],
      );

      await tester.tap(find.byTooltip('Edit task'));
      await tester.pumpAndSettle();

      expect(find.byType(AddEditTaskScreen), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
    });

    testWidgets('a record that is gone says so', (tester) async {
      await openDetails(tester, entries: const [], recordId: 99);

      expect(find.text('This task no longer exists'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskDetailsScreen), findsNothing);
    });

    testWidgets('a deleted routine keeps its history but loses actions on '
        'the routine', (tester) async {
      await openDetails(
        tester,
        entries: [
          entry(id: 1, title: 'Old habit', status: TaskStatus.completed),
        ],
        routines: [_routine(id: 1, archivedAt: DateTime.utc(2026, 11))],
      );

      expect(find.text('Old habit'), findsOneWidget);
      expect(find.byTooltip('Edit task'), findsNothing);
      expect(find.text('Delete task'), findsNothing);
      expect(
        find.text('This task was deleted. Its history stays.'),
        findsOneWidget,
      );
    });
  });

  group('deleting', () {
    Future<void> open(WidgetTester tester, FakeRoutineActions actions) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: homeOverrides(
            entries: [entry(id: 1, title: 'Drink water', minutes: 600)],
            routines: FakeRoutineRepository([_routine(id: 1)]),
            routineActions: actions,
          ),
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TaskDetailsScreen(recordId: 1),
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
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, and "Keep task" changes nothing', (tester) async {
      final actions = FakeRoutineActions();
      await open(tester, actions);

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this task?'), findsOneWidget);

      await tester.tap(find.text('Keep task'));
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
      expect(find.byType(TaskDetailsScreen), findsOneWidget);
    });

    testWidgets('confirming deletes, closes and offers undo', (tester) async {
      final actions = FakeRoutineActions();
      await open(tester, actions);

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['delete:1']);
      expect(find.byType(TaskDetailsScreen), findsNothing);
      expect(find.text('Task deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actions.calls, ['delete:1', 'undoDelete:1']);
    });

    testWidgets('a failed delete keeps the screen and says why', (
      tester,
    ) async {
      final actions = FakeRoutineActions()
        ..failWith = const NotFoundException('Routine 1 not found');
      await open(tester, actions);

      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailsScreen), findsOneWidget);
      expect(find.text('Routine 1 not found'), findsOneWidget);
      expect(find.text('Drink water'), findsOneWidget);
    });
  });
}

RoutineTask _routine({
  int id = 1,
  int? reminderMinutes = 600,
  bool alarmEnabled = false,
  int repeatDays = 127,
  Priority priority = Priority.medium,
  int categoryId = 1,
  int? durationMinutes,
  int? snoozeMinutes,
  String? description,
  String? message,
  DateTime? archivedAt,
}) => routine(
  id: id,
  reminderMinutes: reminderMinutes,
  alarmEnabled: alarmEnabled,
  repeatDays: repeatDays,
  priority: priority,
  categoryId: categoryId,
  durationMinutes: durationMinutes,
  snoozeMinutes: snoozeMinutes,
  description: description,
  customReminderMessage: message,
  archivedAt: archivedAt,
);
