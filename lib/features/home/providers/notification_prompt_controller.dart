import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/core/notifications/notification_service.dart';

/// Where the user is in the "turn on reminders" sheet.
enum PromptStep {
  /// Explaining why, waiting for the user to opt in.
  ask,

  /// A system dialog or settings page is open.
  working,

  /// Notifications are on; exact alarm timing is the last step.
  needsExact,

  /// Notifications are blocked; only system settings can change that.
  denied,

  /// Everything needed is on.
  done,
}

/// Drives the permission sheet. Nothing is requested until the user taps.
class NotificationPromptController extends Notifier<PromptStep> {
  @override
  PromptStep build() => PromptStep.ask;

  NotificationService get _service => ref.read(notificationServiceProvider);

  PromptStep _stepFor(NotificationPermissionStatus status) {
    if (!status.notificationsAllowed) return PromptStep.denied;
    if (!status.exactAlarmsAllowed) return PromptStep.needsExact;
    return PromptStep.done;
  }

  /// Asks the system for notification permission.
  Future<void> enable() async {
    state = PromptStep.working;
    state = _stepFor(await _service.requestNotificationPermission());
  }

  /// Opens the system page for exact alarms (Android 12+).
  Future<void> allowExactTiming() async {
    state = PromptStep.working;
    state = _stepFor(await _service.requestExactAlarms());
  }

  Future<void> openSystemSettings() => _service.openSystemSettings();

  /// The user may have changed a permission in system settings; look again.
  Future<void> recheck() async {
    if (state != PromptStep.denied && state != PromptStep.needsExact) return;
    state = _stepFor(await _service.getPermissionStatus());
  }
}

final notificationPromptControllerProvider =
    NotifierProvider.autoDispose<NotificationPromptController, PromptStep>(
      NotificationPromptController.new,
    );
