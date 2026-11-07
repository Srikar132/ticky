import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_shell.dart';
import 'package:ticky/features/tasks/models/task_suggestion.dart';
import 'package:ticky/features/tasks/screens/add_edit_task_screen.dart';
import 'package:ticky/features/tasks/screens/task_details_screen.dart';

/// Route names. Navigate with the typed helpers on [AppRoutes], which take
/// care of the route arguments.
abstract final class AppRoutes {
  static const home = '/';
  static const addTask = '/task/add';
  static const editTask = '/task/edit';
  static const taskDetails = '/task/details';

  /// Settings is a root tab: close anything pushed over the shell, then switch.
  static void openSettings(BuildContext context) {
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(mainTabProvider.notifier).select(MainTab.settings);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// [suggestion] pre-fills the form with a starting point.
  static Future<void> openAddTask(
    BuildContext context, {
    TaskSuggestion? suggestion,
  }) => Navigator.of(context).pushNamed(addTask, arguments: suggestion);

  /// [routineId] is the permanent routine, not a daily record.
  static Future<void> openEditTask(BuildContext context, int routineId) =>
      Navigator.of(context).pushNamed(editTask, arguments: routineId);

  /// [recordId] is a daily record, so the screen can show that day's status.
  static Future<void> openTaskDetails(BuildContext context, int recordId) =>
      Navigator.of(context).pushNamed(taskDetails, arguments: recordId);
}

/// Maps route names to screens. A missing or wrongly typed argument falls back
/// to Home instead of crashing.
abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget screen = switch (settings.name) {
      AppRoutes.addTask => AddEditTaskScreen(
        suggestion: args is TaskSuggestion ? args : null,
      ),
      AppRoutes.editTask when args is int => AddEditTaskScreen(routineId: args),
      AppRoutes.taskDetails when args is int => TaskDetailsScreen(
        recordId: args,
      ),
      _ => const AppShell(),
    };
    return MaterialPageRoute<void>(builder: (_) => screen, settings: settings);
  }
}
