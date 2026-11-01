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
  testWidgets('opens on Home with the dark brand background', (tester) async {
    await pumpApp(tester);

    expect(find.text('Good morning'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      AppColors.deepBackground,
    );
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).title, 'Ticky');
  });

  testWidgets('Home opens Settings and Add task, and goes back', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);
  });

  testWidgets('typed routes pass their arguments', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold));

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
}
