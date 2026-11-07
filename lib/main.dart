import 'dart:async';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app.dart';
import 'package:ticky/app_notification_router.dart';
import 'package:ticky/core/notifications/notification_providers.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lists Outfit in the app's open-source licence page.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Outfit',
    ], await rootBundle.loadString('assets/fonts/outfit/OFL.txt'));
  });
  final container = ProviderContainer();
  // The saved theme, before the first frame: no flash of the wrong theme.
  await container.read(themeModeProvider.notifier).load();
  try {
    // Daily reconcile + reminder scheduling. Also re-runs on resume.
    await container.read(reminderCoordinatorProvider).start();
  } on Object catch (error, stack) {
    // The app must still open if reminders fail to start.
    debugPrint('Reminder startup failed: $error\n$stack');
  }
  runApp(
    UncontrolledProviderScope(container: container, child: const TickyApp()),
  );
  // Taps on notifications, and the tap that opened the app. After runApp so
  // the navigator exists; the plugin is already initialised above.
  unawaited(container.read(notificationRouterProvider).start());
}
