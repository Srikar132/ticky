import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticky/app_navigation.dart';
import 'package:ticky/app_router.dart';
import 'package:ticky/core/theme/app_theme.dart';
import 'package:ticky/features/settings/providers/settings_providers.dart';

/// Root widget. The theme follows the user's choice in Settings: system,
/// light or dark.
class TickyApp extends ConsumerWidget {
  const TickyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigation = ref.watch(appNavigationProvider);
    return MaterialApp(
      title: 'Ticky',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigation.navigatorKey,
      scaffoldMessengerKey: navigation.messengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
