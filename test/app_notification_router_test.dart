import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app.dart';
import 'package:ticky/app_navigation.dart';
import 'package:ticky/app_notification_router.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/database/app_database.dart';
import 'package:ticky/core/database/data_exceptions.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/notification_tap_resolver.dart';
import 'package:ticky/core/notifications/planned_notification.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/tasks/data/daily_record_repository.dart';
import 'package:ticky/features/tasks/screens/add_edit_task_screen.dart';
import 'package:ticky/features/tasks/screens/task_details_screen.dart';

import 'support/fake_notification_gateway.dart';
import 'support/home_test_support.dart';

String payload(int routineId, [String dateKey = '2026-11-02']) =>
    ReminderPayload(
      routineId: routineId,
      dateKey: dateKey,
      fingerprint: 'abc12345',
    ).encode();

/// The app shell plus a router wired to a fake gateway and fake task actions.
class Harness {
  Harness(
    this.tester, {
    List<DailyTaskEntry>? entries,
    List<RoutineTask> routines = const [],
  }) : entries =
           entries ?? [entry(id: 1, title: 'Drink water', minutes: 8 * 60)] {
    container = ProviderContainer(
      overrides: homeOverrides(
        entries: this.entries,
        routines: FakeRoutineRepository(routines),
        actions: actions,
      ),
    );
    addTearDown(container.dispose);
    router = NotificationRouter(
      gateway: gateway,
      resolver: NotificationTapResolver(
        findRecord: (routineId, dateKey) async => this.entries
            .map((e) => e.record)
            .where((r) => r.routineTaskId == routineId && r.dateKey == dateKey)
            .firstOrNull,
        complete: actions.complete,
        snooze: actions.snooze,
      ),
      navigation: container.read(appNavigationProvider),
    );
    addTearDown(router.dispose);
  }

  final WidgetTester tester;
  final List<DailyTaskEntry> entries;
  final gateway = FakeNotificationGateway();
  final actions = FakeTaskActions();
  late final ProviderContainer container;
  late final NotificationRouter router;

  Future<void> pumpApp() async {
    usePhoneScreen(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const TickyApp()),
    );
    await tester.pumpAndSettle();
  }

  /// Taps a notification while the app is running.
  Future<void> tapNotification({String? payload, String? actionId}) async {
    gateway.tap(payload: payload, actionId: actionId);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }
}

void main() {
  group('tapping a notification', () {
    testWidgets('opens that task\'s details', (tester) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(payload: payload(1));

      expect(find.byType(TaskDetailsScreen), findsOneWidget);
      expect(find.text('Drink water'), findsWidgets);
    });

    testWidgets('a second tap replaces the open details instead of stacking', (
      tester,
    ) async {
      final h = Harness(
        tester,
        entries: [
          entry(id: 1, title: 'Drink water', minutes: 8 * 60),
          entry(id: 2, title: 'Stretch', minutes: 9 * 60),
        ],
      );
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(payload: payload(1));
      await h.tapNotification(payload: payload(2));

      expect(find.byType(TaskDetailsScreen), findsOneWidget);
      expect(find.text('Stretch'), findsWidgets);

      final navigator = h.container.read(appNavigationProvider).navigatorKey;
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        find.byType(TaskDetailsScreen),
        findsNothing,
        reason: 'one back press returns to Home',
      );
    });

    testWidgets('never discards a form the user is filling in', (tester) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();
      final navigator = h.container.read(appNavigationProvider).navigatorKey;
      unawaited(navigator.currentState!.pushNamed(AppRoutes.addTask));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Half-written');
      await tester.pump();

      await h.tapNotification(payload: payload(1));
      expect(find.byType(TaskDetailsScreen), findsOneWidget);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(AddEditTaskScreen), findsOneWidget);
      expect(find.text('Half-written'), findsOneWidget);
    });

    testWidgets('a task that is gone shows a message and goes nowhere', (
      tester,
    ) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(payload: payload(99));

      expect(find.text('That task is no longer on your list'), findsOneWidget);
      expect(find.byType(TaskDetailsScreen), findsNothing);
    });

    testWidgets('something that is not a reminder is ignored quietly', (
      tester,
    ) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(payload: 'hello');
      await h.tapNotification();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(TaskDetailsScreen), findsNothing);
    });

    testWidgets('taps after dispose do nothing', (tester) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();
      h.router.dispose();

      await h.tapNotification(payload: payload(1));

      expect(find.byType(TaskDetailsScreen), findsNothing);
    });
  });

  group('notification buttons', () {
    testWidgets('Done completes the task and says so', (tester) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(
        payload: payload(1),
        actionId: notificationActionDone,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(h.actions.calls, ['complete:1']);
      expect(find.text('Marked "Drink water" done'), findsOneWidget);
      expect(find.byType(TaskDetailsScreen), findsNothing);
    });

    testWidgets('Snooze snoozes the task and says when it returns', (
      tester,
    ) async {
      final h = Harness(tester);
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(
        payload: payload(1),
        actionId: notificationActionSnooze,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(h.actions.calls, ['snooze:1']);
      expect(
        find.text(
          '"Drink water" snoozed until ${formatMinutesOfDay(9 * 60 + 10)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a refusal is shown as a message', (tester) async {
      final h = Harness(tester);
      h.actions.failWith = const ReadOnlyDayException(
        'Past days are read-only',
      );
      await h.pumpApp();
      await h.router.start();

      await h.tapNotification(
        payload: payload(1),
        actionId: notificationActionDone,
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Past days are read-only'), findsOneWidget);
    });
  });

  group('opening the app from a notification', () {
    testWidgets('the tap that launched the app opens the task', (tester) async {
      final h = Harness(tester);
      h.gateway.launchTap = NotificationTap(payload: payload(1));
      await h.pumpApp();

      await h.router.start();
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailsScreen), findsOneWidget);
    });

    testWidgets('a button that launched the app is carried out', (
      tester,
    ) async {
      final h = Harness(tester);
      h.gateway.launchTap = NotificationTap(
        payload: payload(1),
        actionId: notificationActionDone,
      );
      await h.pumpApp();

      await h.router.start();
      await tester.pump(const Duration(milliseconds: 500));

      expect(h.actions.calls, ['complete:1']);
      expect(find.text('Marked "Drink water" done'), findsOneWidget);
    });

    testWidgets('a tap that arrives before the app is on screen waits for it', (
      tester,
    ) async {
      final h = Harness(tester);
      h.gateway.launchTap = NotificationTap(payload: payload(1));

      final started = h.router.start();
      await h.pumpApp();
      await started;
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailsScreen), findsOneWidget);
    });

    testWidgets('opening normally does nothing extra', (tester) async {
      final h = Harness(tester);
      await h.pumpApp();

      await h.router.start();
      await tester.pumpAndSettle();

      expect(find.byType(TaskDetailsScreen), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('starting twice does not handle the launch tap twice', (
      tester,
    ) async {
      final h = Harness(tester);
      h.gateway.launchTap = NotificationTap(
        payload: payload(1),
        actionId: notificationActionDone,
      );
      await h.pumpApp();

      await h.router.start();
      await h.router.start();
      await tester.pump(const Duration(milliseconds: 500));

      expect(h.actions.calls, ['complete:1']);
    });
  });
}
