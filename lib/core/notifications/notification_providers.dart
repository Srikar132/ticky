import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/core/database/database_provider.dart';
import 'package:ticky/core/notifications/local_notifications_gateway.dart';
import 'package:ticky/core/notifications/notification_gateway.dart';
import 'package:ticky/core/notifications/notification_service.dart';
import 'package:ticky/core/notifications/reminder_coordinator.dart';
import 'package:ticky/core/utils/clock.dart';
import 'package:ticky/features/routine/providers/routine_providers.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';
import 'package:ticky/features/tasks/providers/task_providers.dart';

final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => LocalNotificationsGateway(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(
    gateway: ref.watch(notificationGatewayProvider),
    routines: ref.watch(routineRepositoryProvider),
    records: ref.watch(dailyRecordRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final reminderCoordinatorProvider = Provider<ReminderCoordinator>((ref) {
  final coordinator = ReminderCoordinator(
    database: ref.watch(appDatabaseProvider),
    reconciler: ref.watch(dailyReconcilerProvider),
    notifications: ref.watch(notificationServiceProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
