import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticky/app.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/theme/app_colors.dart';
import 'package:ticky/features/tasks/screens/task_details_screen.dart';

import 'support/home_test_support.dart';

Future<void> pumpApp(WidgetTester tester) async {
  usePhoneScreen(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: homeOverrides(
        entries: [entry(id: 1, title: 'Drink water', minutes: 10 * 60)],
      ),
      child: const TickyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on Home with the lavender page', (tester) async {
    await pumpApp(tester);

    expect(find.text('Good morning'), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.byType(Scaffold).first),
      ).scaffoldBackgroundColor,
      AppColors.canvas,
    );
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Ticky');
  });

  testWidgets('the bottom bar switches tabs and adds a task', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget, reason: 'Settings tab');
    expect(find.text('Good morning'), findsNothing, reason: 'Home is hidden');

    await tester.tap(find.byTooltip('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Good morning'), findsOneWidget);

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);
    expect(
      find.byTooltip('Home'),
      findsNothing,
      reason: 'the form covers the bottom bar',
    );
  });

  testWidgets('typed routes pass their arguments', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);

    AppRoutes.openEditTask(context, 7);
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);

    Navigator.of(tester.element(find.text('Edit task'))).pop();
    await tester.pumpAndSettle();
    AppRoutes.openTaskDetails(context, 1);
    await tester.pumpAndSettle();
    expect(find.byType(TaskDetailsScreen), findsOneWidget);
    expect(find.text('Drink water'), findsWidgets);
  });

  testWidgets('a route with a bad argument falls back to Home', (tester) async {
    await pumpApp(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.pushNamed(AppRoutes.taskDetails, arguments: 'not-an-int');
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailsScreen), findsNothing);
    expect(find.text('Good morning'), findsWidgets);
  });

  group('theme', () {
    Future<void> pumpWith(WidgetTester tester, ThemeMode mode) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: homeOverrides(themeMode: mode),
          child: const TickyApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Brightness shown(WidgetTester tester) =>
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

    testWidgets('light and dark follow the saved choice at once', (
      tester,
    ) async {
      await pumpWith(tester, ThemeMode.dark);
      expect(shown(tester), Brightness.dark);
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).first),
        ).scaffoldBackgroundColor,
        AppDarkColors.canvas,
      );
    });

    testWidgets('System follows the phone', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpWith(tester, ThemeMode.system);
      expect(shown(tester), Brightness.dark);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(shown(tester), Brightness.light);
    });

    testWidgets('choosing in Settings changes the whole app straight away', (
      tester,
    ) async {
      await pumpWith(tester, ThemeMode.light);
      expect(shown(tester), Brightness.light);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(shown(tester), Brightness.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
    });
  });
}
