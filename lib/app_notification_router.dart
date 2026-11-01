import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_navigation.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/notifications/notification_tap_resolver.dart';
import 'package:ticky/core/utils/time_formatting.dart';
import 'package:ticky/features/home/providers/home_providers.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

/// Shows what a tapped notification means: opens the task's details, or
/// confirms a button press ("Done", "Snooze") in a message.
///
/// It handles taps while the app runs and the tap that started it. Nothing
/// here depends on the app running in the background: the notification buttons
/// open the app, and the work happens right here with the live database.
class NotificationRouter {
  NotificationRouter({
    required NotificationGateway gateway,
    required NotificationTapResolver resolver,
    required AppNavigation navigation,
  }) : _gateway = gateway,
       _resolver = resolver,
       _navigation = navigation;

  final NotificationGateway _gateway;
  final NotificationTapResolver _resolver;
  final AppNavigation _navigation;

  StreamSubscription<NotificationTap>? _subscription;
  bool _started = false;

  /// Start listening, then handle the tap that opened the app, if any. Call
  /// after the notification plugin is initialised.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _gateway.taps.listen((tap) => unawaited(handle(tap)));
    try {
      final launchTap = await _gateway.getLaunchTap();
      if (launchTap != null) await handle(launchTap);
    } on Exception catch (error, stack) {
      debugPrint('Launch notification failed: $error\n$stack');
    }
  }

  void dispose() {
    _subscription?.cancel();
    _started = false;
  }

  Future<void> handle(NotificationTap tap) async {
    final TapOutcome outcome;
    try {
      outcome = await _resolver.resolve(tap);
    } on Exception catch (error, stack) {
      debugPrint('Notification tap failed: $error\n$stack');
      return;
    }
    switch (outcome) {
      case TapIgnored():
        return;
      case OpenTask(:final recordId):
        await _openDetails(recordId);
      case MarkedDone(:final title):
        await _say('Marked "$title" done');
      case Snoozed(:final title, :final until):
        await _say(
          '"$title" snoozed until ${formatMinutesOfDay(minutesOfDay(until))}',
        );
      case TaskGone():
        await _say('That task is no longer on your list');
      case TapFailed(:final message):
        await _say(message);
    }
  }

  /// On a cold start the app is not on screen yet; wait for its first frames.
  Future<bool> _waitForApp() async {
    for (var frames = 0; frames < 60; frames++) {
      if (_navigation.navigatorKey.currentState != null) return true;
      await SchedulerBinding.instance.endOfFrame;
    }
    return false;
  }

  Future<void> _openDetails(int recordId) async {
    if (!await _waitForApp()) return;
    final navigator = _navigation.navigatorKey.currentState!;
    // One details page at a time: replace an open one instead of stacking.
    // A form on top is left alone, so unsaved edits are never discarded.
    navigator.popUntil(
      (route) => route.isFirst || route.settings.name != AppRoutes.taskDetails,
    );
    unawaited(navigator.pushNamed(AppRoutes.taskDetails, arguments: recordId));
  }

  Future<void> _say(String message) async {
    if (!await _waitForApp()) return;
    _navigation.messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final notificationRouterProvider = Provider<NotificationRouter>((ref) {
  final records = ref.watch(dailyRecordRepositoryProvider);
  final actions = ref.watch(taskActionsProvider);
  final router = NotificationRouter(
    gateway: ref.watch(notificationGatewayProvider),
    resolver: NotificationTapResolver(
      findRecord: records.getByRoutineAndDate,
      complete: actions.complete,
      snooze: actions.snooze,
    ),
    navigation: ref.watch(appNavigationProvider),
  );
  ref.onDispose(router.dispose);
  return router;
});
